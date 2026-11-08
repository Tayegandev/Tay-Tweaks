"""Generate TMAC's custom multi-resolution Windows icon using Pillow."""
from PIL import Image, ImageDraw, ImageFont, ImageFilter
from pathlib import Path

root = Path(__file__).resolve().parent
N = 256
im = Image.new("RGBA", (N, N), (0, 0, 0, 0))
glow = Image.new("RGBA", (N, N), (0, 0, 0, 0))
d = ImageDraw.Draw(glow)
d.ellipse((35, 35, 225, 225), fill=(18, 43, 113, 150))
im.alpha_composite(glow.filter(ImageFilter.GaussianBlur(18)))
d = ImageDraw.Draw(im)
d.rounded_rectangle((28, 28, 228, 228), radius=55, fill=(11, 24, 60, 240),
                    outline=(44, 142, 250, 230), width=5)
d.ellipse((48, 83, 207, 182), outline=(51, 122, 253, 210), width=8)
d.arc((38, 69, 220, 190), start=195, end=325, fill=(97, 205, 255, 255), width=11)
d.arc((38, 69, 220, 190), start=17, end=145, fill=(113, 92, 255, 255), width=10)
for font in ["C:/Windows/Fonts/arialbd.ttf", "DejaVuSans-Bold.ttf"]:
    try:
        f = ImageFont.truetype(font, 127)
        break
    except OSError:
        continue
else:
    f = ImageFont.load_default()
d.text((80, 49), "T", font=f, fill=(238, 249, 255, 255),
       stroke_width=2, stroke_fill=(81, 161, 255, 255))
d.polygon([(204, 36), (211, 51), (227, 58), (211, 65),
           (204, 80), (197, 65), (182, 58), (197, 51)],
          fill=(206, 244, 255, 255))
im.save(root / "TMACs.png")
im.save(root / "TMACs.ico", format="ICO",
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
print("Generated", root / "TMACs.ico")