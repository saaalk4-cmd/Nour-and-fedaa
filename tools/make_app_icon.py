# يولّد أيقونة التطبيق من اللوجو: python3 tools/make_app_icon.py art_src/app_logo.jpg assets/icon
# (يحفظ أيضًا preview.png في نفس المجلد للمعاينة فقط؛ لا تضيفه للمستودع)
import sys
from PIL import Image, ImageDraw, ImageFilter
src, outdir = sys.argv[1], sys.argv[2]
im = Image.open(src).convert('RGB')
inner = im.crop((346, 119, 678, 452)).resize((1024, 1024), Image.LANCZOS)
inner = inner.filter(ImageFilter.UnsharpMask(radius=2, percent=60, threshold=2))

def rmask(size, r, feather):
    m = Image.new('L', (size, size), 0)
    d = ImageDraw.Draw(m)
    p = feather
    d.rounded_rectangle((p, p, size - p, size - p), r, fill=255)
    return m.filter(ImageFilter.GaussianBlur(feather / 2))

# خلفية: نفس ألوان اللوجو مموّهة، بلا نجوم الأركان
core = inner.crop((140, 140, 884, 884)).resize((1024, 1024), Image.LANCZOS)
bg = core.filter(ImageFilter.GaussianBlur(90))

# الأيقونة العادية: اللوجو يملأ المربع والأركان ناعمة
legacy = bg.copy()
legacy.paste(inner, (0, 0), rmask(1024, 150, 24))
legacy.save(f'{outdir}/icon.png')

# الأيقونة المتكيّفة: Android يقص الدائرة الوسطى (حوالي 66%)، فنصغّر المحتوى
s = int(1024 * 0.74)
small = inner.resize((s, s), Image.LANCZOS)
fg = bg.copy()
o = (1024 - s) // 2
fg.paste(small, (o, o), rmask(s, 120, 40))
fg.convert('RGBA').save(f'{outdir}/icon_fg.png')

# معاينة: كيف تبدو في دائرة ومربع مدوّر
prev = Image.new('RGB', (1100, 560), (240, 240, 240))
for i, shape in enumerate(['circle', 'squircle']):
    t = fg.resize((432, 432), Image.LANCZOS)
    m = Image.new('L', (432, 432), 0); d = ImageDraw.Draw(m)
    vis = (432 - 288) // 2  # 72dp من 108dp
    box = (vis - 30, vis - 30, 432 - vis + 30, 432 - vis + 30)
    (d.ellipse if shape == 'circle' else lambda b, fill: d.rounded_rectangle(b, 70, fill=fill))(box, fill=255)
    prev.paste(t, (40 + i * 520, 60), m)
prev.paste(legacy.resize((200, 200)), (450, 340))
prev.save(f'{outdir}/preview.png')
