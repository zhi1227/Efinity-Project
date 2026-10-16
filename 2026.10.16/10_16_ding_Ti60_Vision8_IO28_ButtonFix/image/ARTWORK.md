# 人物墨水屏画面

画中文字：重生之拼好队也要拿果酱。

使用内置 image_gen 编辑原人物画面，参考用户提供的 PCB 书法截图，仅借鉴字体风格。文字不是原字体文件的精确复刻。

- 生成源图：character_calligraphy_source.png
- 实际屏幕图：epaper_preview.png（400×300、1 bit）
- 数据：epaper.hex（15000 字节，MSB 对应左边像素，1 白 0 黑）
- 处理：LANCZOS 缩放、灰度阈值 160、无抖动；可用 tools/pack_epaper_image.py 重建。

生成提示：

Edit target: first image, the existing black-and-white chibi maid character display. Second image is ONLY a Chinese brush-calligraphy lettering style reference, not a scene to copy. Create a clean monochrome 4:3 e-paper display artwork, designed for 400x300 pixels. Preserve the original character's identity, pose, costume, face, and left-side full-body composition as closely as possible. Keep white background and sharp black linework. Replace ALL existing wording ('你好呀', '很高兴见到你', 'HELLO') with exactly these simplified Chinese characters: 重生之拼好队也要拿果酱 . Arrange readable bold expressive brush calligraphy on the right in four lines: '重生之' / '拼好队' / '也要拿' / '果酱'. Follow the energetic tapered Chinese brush strokes from the second reference, but maintain clearly recognizable accurate glyphs and large thick strokes readable on a 400x300 monochrome e-paper screen. Enlarge the speech bubble vertically to contain the entire four-line phrase, with a small speech tail toward the character; right text may occupy about half the width if needed. Black on pure white, no gold, no PCB components or PCB texture, no grayscale shading, no extra words or punctuation, no additional characters or props. No cropped character or cropped lettering.
