"""Synthetic correctness tests only; these do NOT measure real face accuracy."""
import json
from pathlib import Path
import tempfile
import unittest
import numpy as np
from PIL import Image
import stage1_reference as ref


class ReferenceTests(unittest.TestCase):
    def setUp(self):
        self.cfg = ref.read_config()

    def test_default_config(self):
        self.assertEqual((self.cfg["CANNY_LOW"], self.cfg["CANNY_HIGH"]), (40, 80))
        self.assertEqual((self.cfg["SKIN_CB_MIN"], self.cfg["SKIN_CR_MAX"]), (77, 173))

    def test_integer_color_truth(self):
        a = np.array([[[0,0,0],[255,255,255],[255,0,0],[0,255,0],[0,0,255]]], np.uint8)
        q,y,cb,cr = ref.color_planes(a)
        self.assertEqual(y.tolist(), [[0,255,76,149,28]])
        np.testing.assert_array_equal(q, ref.quantize_rgb565(q))
        self.assertEqual((int(cb[0,0]), int(cr[0,0])), (128,128))
        self.assertTrue(np.all((cb>=0)&(cb<=255)&(cr>=0)&(cr<=255)))

    def test_existing_rtl_skin_rectangle(self):
        rgb = np.zeros((48,64,3), np.uint8)
        rgb[12:36,16:48] = [206,158,123]
        _,_,_,_,raw,_,clean = ref.masks(rgb,self.cfg)
        self.assertEqual(int(raw.sum()),768)
        self.assertEqual(int(clean.sum()),656)

    def test_isolated_noise_and_frame_clear(self):
        rgb = np.zeros((48,64,3), np.uint8)
        rgb[24,32] = [206,158,123]
        *_,raw,majority,clean = ref.masks(rgb,self.cfg)
        self.assertEqual(int(raw.sum()),1)
        self.assertEqual(int(majority.sum()),0)
        self.assertEqual(int(clean.sum()),0)
        self.assertFalse(ref.masks(np.zeros_like(rgb),self.cfg)[-1].any())

    def test_full_skin_border_and_grid(self):
        rgb = np.full((48,64,3),[206,158,123],np.uint8)
        *_,raw,majority,clean = ref.masks(rgb,self.cfg)
        self.assertEqual(int(raw.sum()),64*48)
        self.assertEqual(int(majority.sum()),62*46)
        self.assertEqual(int(clean.sum()),60*44)
        grid,boxes,_ = ref.regions(clean,self.cfg)
        self.assertTrue(grid.all())
        self.assertEqual(boxes,[[0,0,63,47]])

    def test_sobel_step_and_uniform(self):
        gray=np.zeros((48,64),np.uint8)
        gray[:,32:]=255
        result=ref.sobel_binary(gray,40)
        self.assertEqual(int(result.sum()),88)
        self.assertTrue(result[2:-2,31:33].all())
        self.assertFalse(ref.sobel_binary(np.full_like(gray,168),40).any())

    def permissive(self, **kwargs):
        cfg=dict(self.cfg,FACE_MIN_W=8,FACE_MIN_H=8,FACE_MIN_AREA=64,
                 FACE_MIN_FILL_PERCENT=1,FACE_MIN_RATIO_X10=0,FACE_MAX_RATIO_X10=100)
        cfg.update(kwargs)
        return cfg

    def test_diagonal_eight_connectivity(self):
        mask=np.zeros((48,64),bool)
        mask[8:16,8:16]=True
        mask[16:24,16:24]=True
        _,boxes,components=ref.regions(mask,self.permissive())
        self.assertEqual(boxes,[[8,8,23,23]])
        self.assertEqual(components[0]["occupied_cells"],2)

    def test_scan_order_capacity(self):
        mask=np.zeros((48,96),bool)
        for x in (0,24,48):mask[8:16,x:x+8]=True
        _,boxes,components=ref.regions(mask,self.permissive(FACE_MAX_FACES=2))
        self.assertEqual(boxes,[[0,8,7,15],[24,8,31,15]])
        self.assertEqual(components[2]["reject_reasons"],["capacity"])

    def test_metrics_one_to_one_and_undefined(self):
        self.assertEqual(ref.match_boxes([[0,0,9,9]]*2,[[0,0,9,9]]),dict(tp=1,fp=1,fn=0))
        self.assertEqual(ref.match_boxes([[0,0,9,9],[0,0,3,9]],[[0,0,5,9],[4,0,9,9]]),
                         dict(tp=2,fp=0,fn=0))
        self.assertIsNone(ref.rates(dict(tp=0,fp=0,fn=0))["precision"])

    def test_dataset_labels_and_no_overwrite(self):
        with tempfile.TemporaryDirectory(prefix="stage1_reference_test_") as tmp:
            root=Path(tmp)
            Image.fromarray(np.full((48,64,3),[206,158,123],np.uint8)).save(root/"frame.png")
            manifest=dict(schema_version=1,capture_source="SYNTHETIC_TEST_ONLY",width=64,height=48,
                          frames=[dict(id="positive",file="frame.png",format="rgb888_image",
                                       scene="synthetic",split="validation",labelled=True,boxes=[[0,0,63,47]]),
                                  dict(id="unlabelled",file="frame.png",format="rgb888_image",
                                       scene="synthetic",split="tune",labelled=False)])
            path=root/"manifest.json"
            path.write_text(json.dumps(manifest),encoding="utf-8")
            result=ref.analyze(path,root/"run")
            self.assertEqual(result["labelled_frames"],1)
            self.assertEqual(result["metrics_by_split_scene"]["validation/synthetic"]["recall"],1)
            self.assertIsNone(result["frames"][1]["metrics"])
            self.assertFalse(result["board_verified"])
            with self.assertRaises(FileExistsError):ref.analyze(path,root/"run")

    def test_empty_dataset_is_pending(self):
        with tempfile.TemporaryDirectory(prefix="stage1_empty_test_") as tmp:
            root=Path(tmp);path=root/"empty.json"
            path.write_text(json.dumps(dict(schema_version=1,width=1280,height=720,frames=[])),encoding="utf-8")
            result=ref.analyze(path,root/"run")
            self.assertEqual(result["status"],"PENDING_REAL_SAMPLES")
            self.assertEqual(result["metrics_by_split_scene"],{})

    def test_raw_rgb565_byte_order(self):
        with tempfile.TemporaryDirectory(prefix="stage1_raw_test_") as tmp:
            root=Path(tmp)
            for endian,fmt in (("<u2","rgb565_le"),(">u2","rgb565_be")):
                data=np.full((8,8),0xF800,dtype=endian)
                path=root/(fmt+".bin");path.write_bytes(data.tobytes())
                rgb,_=ref.load_frame(root,dict(file=path.name,format=fmt),8,8)
                self.assertTrue(np.all(rgb==[255,0,0]))
            with self.assertRaises(ValueError):
                ref.load_frame(root,dict(file=path.name,format=fmt),16,8)


if __name__ == "__main__":
    unittest.main(verbosity=2)
