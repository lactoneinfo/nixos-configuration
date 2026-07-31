"""Generate 16x16 pixel-art icons for the cockpit, replacing nerd-font glyphs
and emoji. Flat, bold shapes so they read clearly at tiny size. Palette
matches eww.scss (sakura/sky/violet/amber/fg on transparent background).
"""
from PIL import Image, ImageDraw

SAKURA = (255, 158, 199, 255)
ROSE = (242, 112, 156, 255)
VIOLET = (181, 126, 220, 255)
SKY = (143, 184, 232, 255)
AMBER = (232, 181, 107, 255)
FG = (246, 238, 243, 255)
RED = (255, 107, 107, 255)
DIM = (246, 238, 243, 140)

W = H = 16


def canvas():
    return Image.new("RGBA", (W, H), (0, 0, 0, 0))


def px(d, x, y, c):
    if 0 <= x < W and 0 <= y < H:
        d.point((x, y), fill=c)


def rect(d, x0, y0, x1, y1, c):
    d.rectangle([x0, y0, x1, y1], fill=c)


def save(img, name):
    img.save(f"{name}.png")


# ---- system: Tux(定番のLinuxペンギン。頭の白い目パッチ+大きい白い腹+
#      オレンジのくちばし/足、というシルエットの特徴を押さえる) ----
TUX_ROWS = [
    "................",
    ".....kkkkkk.....",
    "....kkkkkkkk....",
    "...kkwwkkwwkk...",
    "...kkwwkkwwkk...",
    "...kkkwwwwkkk...",
    "....kkkooOkk....",
    "...kkkkkkkkkk...",
    "..kkwwwwwwwwkk..",
    "..kwwwwwwwwwwk..",
    "..kwwwwwwwwwwk..",
    "..kkwwwwwwwwkk..",
    "...kkkkkkkkkk...",
    "..kkk......kkk..",
    ".kkoo......ookk.",
    "................",
]
TUX_COLORS = {
    "k": (20, 20, 24, 255),
    "w": (245, 245, 248, 255),
    "o": (232, 140, 60, 255),
    "O": (255, 170, 90, 255),
}


def icon_system():
    im = canvas()
    for y, row in enumerate(TUX_ROWS):
        for x, ch in enumerate(row):
            if ch in TUX_COLORS:
                px_draw = ImageDraw.Draw(im)
                px_draw.point((x, y), fill=TUX_COLORS[ch])
    save(im, "system")


# ---- performance: mini bar chart ----
def icon_performance():
    im = canvas(); d = ImageDraw.Draw(im)
    bars = [(3, 10), (6, 6), (9, 12), (12, 4)]
    for x, top in bars:
        rect(d, x, top, x + 1, 13, SAKURA if top < 8 else SKY)
    save(im, "performance")


# ---- disk: an optical disc (CD), not a box ----
def icon_disk():
    im = canvas(); d = ImageDraw.Draw(im)
    d.ellipse([1, 1, 14, 14], fill=(226, 230, 238, 255))
    d.ellipse([1, 1, 14, 14], outline=(170, 178, 195, 255), width=1)
    d.pieslice([1, 1, 14, 14], 200, 260, fill=(255, 255, 255, 160))  # 反射ハイライト
    d.ellipse([6, 6, 9, 9], fill=AMBER)
    d.ellipse([7, 7, 8, 8], fill=(16, 18, 30, 255))  # センターホール
    save(im, "disk")


# ---- processes: stacked list ----
def icon_processes():
    im = canvas(); d = ImageDraw.Draw(im)
    for i, y in enumerate((3, 7, 11)):
        c = [SAKURA, SKY, VIOLET][i]
        rect(d, 2, y, 4, y + 2, c)
        rect(d, 6, y, 13, y + 2, FG if i == 0 else DIM)
    save(im, "processes")


# ---- network: signal bars ----
def icon_network():
    im = canvas(); d = ImageDraw.Draw(im)
    heights = [3, 6, 9, 12]
    for i, hgt in enumerate(heights):
        x = 2 + i * 3
        rect(d, x, 13 - hgt, x + 2, 13, SKY)
    save(im, "network")


# ---- tailscale/link: chain link ----
def icon_link():
    im = canvas(); d = ImageDraw.Draw(im)
    d.ellipse([2, 5, 8, 11], outline=SKY, width=2)
    d.ellipse([7, 5, 13, 11], outline=VIOLET, width=2)
    save(im, "link")


# ---- bluetooth: the classic runic bt glyph (bold, hand-plotted) ----
def icon_bluetooth():
    im = canvas(); d = ImageDraw.Draw(im)
    pts = [
        (7, 2), (7, 14),           # 縦の芯棒
        (7, 2), (11, 5), (5, 9),   # 上の三角(右下がり)
        (5, 9), (11, 11), (7, 14), # 下の三角
    ]
    d.line(pts, fill=SKY, width=2, joint="curve")
    save(im, "bluetooth")


# ---- audio: speaker cone ----
def icon_audio():
    im = canvas(); d = ImageDraw.Draw(im)
    d.polygon([(2, 6), (5, 6), (9, 3), (9, 13), (5, 10), (2, 10)], fill=VIOLET)
    d.arc([9, 4, 14, 12], -60, 60, fill=VIOLET, width=1)
    d.arc([10, 2, 15, 14], -60, 60, fill=VIOLET, width=1)
    save(im, "audio")


# ---- media: a single clean eighth note (♪), not a cluttered double note ----
def icon_media():
    im = canvas(); d = ImageDraw.Draw(im)
    rect(d, 9, 2, 10, 11, SAKURA)                       # stem
    d.polygon([(9, 2), (13, 4), (13, 7), (9, 5)], fill=SAKURA)  # flag
    d.ellipse([3, 9, 9, 14], fill=SAKURA)                # notehead(大きめで視認性重視)
    save(im, "media")


# ---- location: map pin ----
def icon_location():
    im = canvas(); d = ImageDraw.Draw(im)
    d.ellipse([4, 2, 11, 9], fill=AMBER)
    d.polygon([(4, 7), (11, 7), (7, 14)], fill=AMBER)
    d.ellipse([6, 4, 9, 7], fill=(16, 18, 30, 255))
    save(im, "location")


# ---- daemons: gear ----
def icon_gear():
    im = canvas(); d = ImageDraw.Draw(im)
    d.ellipse([4, 4, 11, 11], fill=SKY)
    d.ellipse([6, 6, 9, 9], fill=(16, 18, 30, 255))
    for x, y in [(7, 1), (7, 13), (1, 7), (13, 7), (2, 2), (12, 2), (2, 12), (12, 12)]:
        rect(d, x, y, x + 1, y + 1, SKY)
    save(im, "gear")


# ---- weather: sun ----
def icon_sun():
    im = canvas(); d = ImageDraw.Draw(im)
    d.ellipse([5, 5, 10, 10], fill=AMBER)
    for dx, dy in [(-1, -1), (1, -1), (-1, 1), (1, 1)]:
        pass
    for x, y in [(7, 1), (7, 13), (1, 7), (13, 7)]:
        rect(d, x, y, x + 1, y + 1, AMBER)
    for x, y in [(3, 3), (11, 3), (3, 11), (11, 11)]:
        px(d, x, y, AMBER)
    save(im, "weather-sun")


# ---- weather: cloud ----
def icon_cloud():
    im = canvas(); d = ImageDraw.Draw(im)
    d.ellipse([2, 7, 8, 12], fill=FG)
    d.ellipse([6, 4, 13, 11], fill=FG)
    rect(d, 3, 10, 12, 12, FG)
    save(im, "weather-cloud")


# ---- weather: rain ----
def icon_rain():
    im = canvas(); d = ImageDraw.Draw(im)
    d.ellipse([2, 3, 8, 8], fill=FG)
    d.ellipse([6, 1, 13, 7], fill=FG)
    rect(d, 3, 6, 12, 8, FG)
    for x in (4, 7, 10):
        rect(d, x, 10, x, 13, SKY)
    save(im, "weather-rain")


# ---- weather: thunder ----
def icon_thunder():
    im = canvas(); d = ImageDraw.Draw(im)
    d.ellipse([2, 2, 8, 7], fill=FG)
    d.ellipse([6, 0, 13, 6], fill=FG)
    rect(d, 3, 5, 12, 7, FG)
    d.polygon([(8, 8), (6, 12), (8, 12), (6, 16)], fill=AMBER)
    save(im, "weather-thunder")


# ---- weather: fog ----
def icon_fog():
    im = canvas(); d = ImageDraw.Draw(im)
    for y in (4, 7, 10, 13):
        rect(d, 2, y, 13, y + 1, DIM)
    save(im, "weather-fog")


# ---- weather: unknown ----
def icon_weather_na():
    im = canvas(); d = ImageDraw.Draw(im)
    d.ellipse([3, 3, 12, 12], outline=DIM, width=2)
    px(d, 7, 7, DIM); px(d, 8, 7, DIM); px(d, 7, 8, DIM); px(d, 8, 8, DIM)
    save(im, "weather-na")


# ---- phone (location source note) ----
def icon_phone():
    im = canvas(); d = ImageDraw.Draw(im)
    rect(d, 5, 1, 10, 14, SKY)
    rect(d, 6, 2, 9, 11, (16, 18, 30, 255))
    rect(d, 7, 12, 8, 12, SKY)
    save(im, "phone")


# ---- globe (IP-based note) ----
def icon_globe():
    im = canvas(); d = ImageDraw.Draw(im)
    d.ellipse([2, 2, 13, 13], outline=SKY, width=1)
    d.line([(2, 7), (13, 7)], fill=SKY, width=1)
    d.line([(7, 2), (7, 13)], fill=SKY, width=1)
    d.arc([4, 2, 10, 13], 0, 360, fill=SKY, width=1)
    save(im, "globe")


for fn in [icon_system, icon_performance, icon_disk, icon_processes, icon_network,
           icon_link, icon_bluetooth, icon_audio, icon_media, icon_location,
           icon_gear, icon_sun, icon_cloud, icon_rain, icon_thunder, icon_fog,
           icon_weather_na, icon_phone, icon_globe]:
    fn()

print("done")
