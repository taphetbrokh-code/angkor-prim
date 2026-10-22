"""Generates assets/icon.png and assets/icon_fg.png (ANGKOR PRIM logo)."""
import os
from PIL import Image, ImageDraw

S = 1024
os.makedirs('assets', exist_ok=True)


def art(size, bg=True, scale=1.0):
    im = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    if bg:
        g = Image.new('RGBA', (size, size))
        gd = ImageDraw.Draw(g)
        for y in range(size):
            t = y / size
            gd.line([(0, y), (size, y)], fill=(int(232 * (1 - t) + 192 * t),
                                                int(163 * (1 - t) + 57 * t),
                                                int(61 * (1 - t) + 43 * t), 255))
        m = Image.new('L', (size, size), 0)
        ImageDraw.Draw(m).rounded_rectangle([0, 0, size - 1, size - 1],
                                            radius=int(size * 0.22), fill=255)
        im.paste(g, (0, 0), m)
    c = size / 2
    u = size * scale / 1024

    def P(pts):
        return [(c + (x - 512) * u, c + (y - 512) * u) for x, y in pts]

    w = (255, 255, 255, 255) if bg else (232, 163, 61, 255)
    d.polygon(P([(512, 150), (545, 250), (575, 330), (590, 420), (434, 420), (449, 330), (479, 250)]), fill=w)
    d.polygon(P([(320, 260), (345, 330), (365, 420), (275, 420), (295, 330)]), fill=w)
    d.polygon(P([(704, 260), (729, 330), (749, 420), (659, 420), (679, 330)]), fill=w)
    a, b = P([(220, 400), (804, 830)])
    d.rounded_rectangle([a, b], radius=int(46 * u), fill=w)
    d.polygon(P([(445, 505), (445, 735), (645, 620)]), fill=(20, 17, 13, 255))
    return im


art(S).save('assets/icon.png')
fg = Image.new('RGBA', (S, S), (0, 0, 0, 0))
fg.alpha_composite(art(S, bg=False, scale=0.6))
fg.save('assets/icon_fg.png')
print('icons generated')
