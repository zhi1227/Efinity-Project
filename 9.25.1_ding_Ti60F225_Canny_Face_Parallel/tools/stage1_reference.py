"""Offline integer reference and dataset evaluation for stage 1 (not board inference).
Requires numpy and Pillow. No camera access, downloads, RTL writes or automatic tuning.
Coordinates in annotations/results use inclusive x0,y0,x1,y1 as the RTL does.
"""
from __future__ import annotations
import argparse
from collections import deque
import hashlib
import json
from pathlib import Path
import re

import numpy as np
from PIL import Image, ImageDraw

PROJECT = Path(__file__).resolve().parents[1]
CONFIG = PROJECT / "src/parallel/vision_config.vh"
PROFILES = {
    "baseline": {}, "ratio12": {"FACE_MAX_RATIO_X10": 12},
    "fill40": {"FACE_MIN_FILL_PERCENT": 40}, "cell16": {"FACE_CELL_MIN": 16},
    "cell32": {"FACE_CELL_MIN": 32}, "ymin32": {"SKIN_Y_MIN": 32},
}


def read_config(path=CONFIG):
    text = Path(path).read_text(encoding="utf-8-sig")
    cfg = {name: int(value) for name, value in re.findall(
        r"(?m)^`define\s+VISION_(\w+)\s+(\d+)\s*$", text)}
    required = ("CANNY_LOW", "SKIN_CB_MIN", "SKIN_CB_MAX", "SKIN_CR_MIN",
                "SKIN_CR_MAX", "SKIN_Y_MIN", "SKIN_Y_MAX", "FACE_MAX_FACES",
                "FACE_CELL_SHIFT", "FACE_CELL_MIN", "FACE_MIN_W", "FACE_MIN_H",
                "FACE_MAX_W", "FACE_MAX_H", "FACE_MIN_AREA",
                "FACE_MIN_FILL_PERCENT", "FACE_MIN_RATIO_X10", "FACE_MAX_RATIO_X10")
    missing = set(required) - cfg.keys()
    if missing:
        raise ValueError(f"Missing decimal config macros: {sorted(missing)}")
    for ch in ("Y", "CB", "CR"):
        if not 0 <= cfg[f"SKIN_{ch}_MIN"] <= cfg[f"SKIN_{ch}_MAX"] <= 255:
            raise ValueError(f"Invalid {ch} interval")
    if not 1 <= cfg["FACE_MAX_FACES"] <= 15 or not 1 <= cfg["FACE_CELL_SHIFT"] <= 5:
        raise ValueError("Unsupported face capacity / cell shift")
    return cfg


def quantize_rgb565(rgb):
    a = np.asarray(rgb)
    if a.ndim != 3 or a.shape[2] != 3 or a.dtype != np.uint8:
        raise ValueError("Expected H x W x 3 uint8 RGB")
    a = a.astype(np.int32)
    r, g, b = a[..., 0] >> 3, a[..., 1] >> 2, a[..., 2] >> 3
    return np.stack(((r << 3) | (r >> 2), (g << 2) | (g >> 4),
                     (b << 3) | (b >> 2)), axis=-1).astype(np.uint8)


def color_planes(rgb):
    q = quantize_rgb565(rgb).astype(np.int32)
    r, g, b = q[..., 0], q[..., 1], q[..., 2]
    y = (77*r + 150*g + 29*b) >> 8
    cb = np.clip(128 + ((-43*r - 85*g + 128*b) >> 8), 0, 255)
    cr = np.clip(128 + ((128*r - 107*g - 21*b) >> 8), 0, 255)
    return q.astype(np.uint8), y, cb, cr


def sums3(mask):
    h, w = mask.shape
    out = np.zeros((h, w), dtype=np.uint16)
    for dy in range(3):
        for dx in range(3):
            out[1:-1, 1:-1] += mask[dy:dy+h-2, dx:dx+w-2]
    return out


def masks(rgb, cfg):
    q, gray, cb, cr = color_planes(rgb)
    raw = ((gray >= cfg["SKIN_Y_MIN"]) & (gray <= cfg["SKIN_Y_MAX"])
           & (cb >= cfg["SKIN_CB_MIN"]) & (cb <= cfg["SKIN_CB_MAX"])
           & (cr >= cfg["SKIN_CR_MIN"]) & (cr <= cfg["SKIN_CR_MAX"]))
    majority = sums3(raw) >= 5
    clean = sums3(majority) == 9
    clean[:2] = False
    clean[-2:] = False
    clean[:, :2] = False
    clean[:, -2:] = False
    return q, gray.astype(np.uint8), cb, cr, raw, majority, clean


def sobel_binary(gray, threshold):
    # Exactly one 3x3 median window followed by a 3x3 L1 Sobel, cropped by 2.
    h, w = gray.shape
    med = np.zeros((h, w), dtype=np.int32)
    windows = np.stack([gray[dy:dy+h-2, dx:dx+w-2]
                        for dy in range(3) for dx in range(3)])
    med[1:-1, 1:-1] = np.sort(windows, axis=0)[4]
    gx = med[:-2, 2:] + 2*med[1:-1, 2:] + med[2:, 2:]
    gx -= med[:-2, :-2] + 2*med[1:-1, :-2] + med[2:, :-2]
    gy = med[2:, :-2] + 2*med[2:, 1:-1] + med[2:, 2:]
    gy -= med[:-2, :-2] + 2*med[:-2, 1:-1] + med[:-2, 2:]
    out = np.zeros((h, w), dtype=bool)
    out[1:-1, 1:-1] = np.abs(gx) + np.abs(gy) >= threshold
    out[:2] = out[-2:] = False
    out[:, :2] = out[:, -2:] = False
    return out


def regions(clean, cfg):
    h, w = clean.shape
    cell = 1 << cfg["FACE_CELL_SHIFT"]
    if h < 8 or w < 8 or h % cell or w % cell:
        raise ValueError("Image width/height must be >=8 and divisible by the cell size")
    counts = clean.reshape(h//cell, cell, w//cell, cell).sum(axis=(1, 3))
    grid = counts >= cfg["FACE_CELL_MIN"]
    unseen = grid.copy()
    gh, gw = unseen.shape
    accepted, components = [], []
    for sy in range(gh):
        for sx in range(gw):
            if not unseen[sy, sx]:
                continue
            todo = deque([(sx, sy)])
            unseen[sy, sx] = False
            xs, ys = [], []
            while todo:
                x, y = todo.popleft()
                xs.append(x); ys.append(y)
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        nx, ny = x+dx, y+dy
                        if 0 <= nx < gw and 0 <= ny < gh and unseen[ny, nx]:
                            unseen[ny, nx] = False
                            todo.append((nx, ny))
            box = [min(xs)*cell, min(ys)*cell, (max(xs)+1)*cell-1, (max(ys)+1)*cell-1]
            bw, bh = box[2]-box[0]+1, box[3]-box[1]+1
            area = len(xs)*cell*cell  # Occupied-grid estimate, NOT true skin pixels.
            reasons = []
            if not cfg["FACE_MIN_W"] <= bw <= cfg["FACE_MAX_W"]: reasons.append("width")
            if not cfg["FACE_MIN_H"] <= bh <= cfg["FACE_MAX_H"]: reasons.append("height")
            if area < cfg["FACE_MIN_AREA"]: reasons.append("grid_area")
            if area*100 < bw*bh*cfg["FACE_MIN_FILL_PERCENT"]: reasons.append("grid_fill")
            if not bh*cfg["FACE_MIN_RATIO_X10"] <= bw*10 <= bh*cfg["FACE_MAX_RATIO_X10"]:
                reasons.append("ratio")
            qualifies = not reasons
            if qualifies and len(accepted) >= cfg["FACE_MAX_FACES"]: reasons.append("capacity")
            if not reasons: accepted.append(box)
            components.append(dict(box=box, occupied_cells=len(xs), grid_area=area,
                                   bbox_area=bw*bh, qualifies=qualifies, selected=not reasons,
                                   reject_reasons=reasons))
    return grid, accepted, components


def iou(a, b):
    inter = max(0, min(a[2], b[2])-max(a[0], b[0])+1) * max(0, min(a[3], b[3])-max(a[1], b[1])+1)
    aa = (a[2]-a[0]+1)*(a[3]-a[1]+1)
    bb = (b[2]-b[0]+1)*(b[3]-b[1]+1)
    return inter/(aa+bb-inter)


def match_boxes(pred, truth, threshold=0.5):
    # Maximum-cardinality one-to-one matching; no identity inference.
    graph = [[j for j, b in sorted(enumerate(truth), key=lambda item: -iou(a, item[1]))
              if iou(a, b) >= threshold] for a in pred]
    owners = {}
    def augment(i, visited):
        for j in graph[i]:
            if j in visited: continue
            visited.add(j)
            if j not in owners or augment(owners[j], visited):
                owners[j] = i
                return True
        return False
    tp = sum(augment(i, set()) for i in range(len(pred)))
    return dict(tp=tp, fp=len(pred)-tp, fn=len(truth)-tp)


def rates(counts):
    tp, fp, fn = counts["tp"], counts["fp"], counts["fn"]
    return dict(**counts, precision=tp/(tp+fp) if tp+fp else None,
                recall=tp/(tp+fn) if tp+fn else None)


def load_frame(root, item, width, height):
    path = (root / item["file"]).resolve()
    fmt = item["format"]
    if fmt in ("rgb565_le", "rgb565_be"):
        data = path.read_bytes()
        if len(data) != width*height*2:
            raise ValueError(f"Raw byte count is wrong: {path}")
        a = np.frombuffer(data, dtype="<u2" if fmt.endswith("le") else ">u2").reshape(height, width)
        r, g, b = (a >> 11) & 31, (a >> 5) & 63, a & 31
        rgb = np.stack(((r << 3) | (r >> 2), (g << 2) | (g >> 4),
                        (b << 3) | (b >> 2)), axis=-1).astype(np.uint8)
    elif fmt == "rgb888_image":
        with Image.open(path) as img:
            rgb = np.asarray(img.convert("RGB")).copy()
    else:
        raise ValueError(f"Unsupported format: {fmt}")
    if rgb.shape != (height, width, 3):
        raise ValueError("Dimensions differ from manifest; no implicit resizing is allowed")
    return rgb, hashlib.sha256(path.read_bytes()).hexdigest()


def analyze(manifest_path, output, profile="baseline", iou_threshold=0.5):
    manifest_path, output = Path(manifest_path).resolve(), Path(output).resolve()
    manifest = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
    if manifest.get("schema_version") != 1:
        raise ValueError("schema_version must be 1")
    if not 0 < iou_threshold <= 1:
        raise ValueError("IoU threshold must be in (0,1]")
    cfg = read_config()
    cfg.update(PROFILES[profile])
    width, height = int(manifest["width"]), int(manifest["height"])
    frames = manifest["frames"]
    output.mkdir(parents=True, exist_ok=False)  # Never overwrite an existing run.
    summary = dict(status="PENDING_REAL_SAMPLES" if not frames else "OFFLINE_ONLY",
                   profile=profile, params=cfg, config_sha256=hashlib.sha256(CONFIG.read_bytes()).hexdigest(),
                   dataset_sha256=hashlib.sha256(manifest_path.read_bytes()).hexdigest(),
                   capture_source=manifest.get("capture_source", "unspecified"),
                   iou_threshold=iou_threshold, matching="maximum-cardinality one-to-one",
                   frames=[], metrics_by_split_scene={},
                   board_verified=False, temporal_metrics="not measured; requires source-frame/track annotations")
    seen = set()
    for item in frames:
        ident = item["id"]
        if not re.fullmatch(r"[A-Za-z0-9_-]+", ident) or ident in seen:
            raise ValueError("Frame IDs must be unique safe directory names")
        seen.add(ident)
        if item["split"] not in ("tune", "validation"):
            raise ValueError("split must be tune or validation")
        rgb, digest = load_frame(manifest_path.parent, item, width, height)
        q, gray, cb, cr, raw, majority, clean = masks(rgb, cfg)
        grid, boxes, components = regions(clean, cfg)
        folder = output / ident
        folder.mkdir()
        for name, arr in (("gray", gray), ("raw_skin", raw), ("majority", majority),
                          ("clean_skin", clean), ("grid", grid),
                          ("sobel_binary", sobel_binary(gray, cfg["CANNY_LOW"]))):
            Image.fromarray((arr.astype(np.uint8)*255) if arr.dtype == bool else arr).save(folder / f"{name}.png")
        canvas = Image.fromarray(q)
        draw = ImageDraw.Draw(canvas)
        for box in boxes: draw.rectangle(box, outline=(255, 0, 0), width=2)
        canvas.save(folder / "candidate_overlay.png")
        record = dict(id=ident, scene=item["scene"], split=item["split"], source_sha256=digest,
                      raw_skin_pixels=int(raw.sum()), clean_skin_pixels=int(clean.sum()),
                      boxes=boxes, components=components, metrics=None, label_roi_ycbcr=[])
        if item.get("labelled") is True:
            truth = item["boxes"]  # Explicit [] means an annotated negative; missing is an error.
            for box in truth:
                if len(box) != 4 or any(type(v) is not int for v in box):
                    raise ValueError("Box must contain four integer inclusive coordinates")
                x0, y0, x1, y1 = box
                if not (0 <= x0 <= x1 < width and 0 <= y0 <= y1 < height):
                    raise ValueError("Annotation outside image")
                record["label_roi_ycbcr"].append({
                    name: np.percentile(arr[y0:y1+1, x0:x1+1], [5, 50, 95]).tolist()
                    for name, arr in (("Y", gray), ("Cb", cb), ("Cr", cr))})
            counts = match_boxes(boxes, truth, iou_threshold)
            record["metrics"] = rates(counts)
            key = item["split"] + "/" + item["scene"]
            totals = summary["metrics_by_split_scene"].setdefault(key, dict(tp=0, fp=0, fn=0))
            for name in ("tp", "fp", "fn"): totals[name] += counts[name]
        (folder / "result.json").write_text(json.dumps(record, indent=2, ensure_ascii=False), encoding="utf-8")
        summary["frames"].append(record)
    summary["metrics_by_split_scene"] = {key: rates(value) for key, value in summary["metrics_by_split_scene"].items()}
    summary["labelled_frames"] = sum(f["metrics"] is not None for f in summary["frames"])
    summary["limitations"] = [
        "No physical camera/HDMI verification. No frame-age, jitter or latency measurement.",
        "Unlabelled images are excluded from precision/recall, not assumed to be negatives.",
        "ROI color percentiles include background inside annotated boxes; they are not automatic thresholds.",
        "Offline full-frame results do not simulate CCL deadline drops or delayed publication.",
        "Profiles are experiments only and never change RTL defaults or select a winner automatically.",
    ]
    (output / "summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")
    return summary


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--dataset", type=Path, required=True)
    ap.add_argument("--output", type=Path, required=True)
    ap.add_argument("--profile", choices=PROFILES, default="baseline")
    ap.add_argument("--iou", type=float, default=0.5)
    args = ap.parse_args()
    result = analyze(args.dataset, args.output, args.profile, args.iou)
    print(json.dumps({k: result[k] for k in ("status", "profile", "labelled_frames", "metrics_by_split_scene")}, indent=2))


if __name__ == "__main__":
    main()
