#!/usr/bin/env python3
"""حكايات فيديو للبنات من رسومات التطبيق نفسها (بدون كانفا وبدون أي رصيد).

  python3 tools/build_videos.py [--only ID] [--silent]

- القصص في tools/videos/stories.json: مشاهد بخلفية وشخصيات وصور وجملة راوٍ.
- الصوت: edge-tts بنفس صوت التطبيق (ar-EG-SalmaNeural)؛ لو مش متاح (أو --silent) فيديو صامت بمدة تقديرية.
- الصورة: 720×1280 (طولي للموبايل) 24 إطار/ث: تكبير بطيء للخلفية، الشخصيات تتمايل، والصور تظهر بحركة.
- الناتج: build/videos/<id>.mp4 + build/videos/<id>.jpg (غلاف) + build/videos/manifest.json (يرفعه CI أونلاين).
لا رسم لنبي أو صحابي، ولا آية أو حديث بصوت آلي: جمل الراوي تعليمية فقط.
"""
import asyncio
import json
import math
import os
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFont, features

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(ROOT, 'assets', 'art')
OUT = os.path.join(ROOT, 'build', 'videos')
W, H, FPS = 720, 1280, 24
VOICE = 'ar-EG-SalmaNeural'
FONT_DIRS = [os.path.join(ROOT, 'assets', 'fonts'), os.environ.get('FONTS', '')]

_cache = {}


def art(name):
    if name not in _cache:
        _cache[name] = Image.open(os.path.join(ART, name + '.webp')).convert('RGBA')
    return _cache[name]


def font(size):
    for d in FONT_DIRS:
        for n in ('Tajawal-ExtraBold.ttf', 'Tajawal-Bold.ttf'):
            p = os.path.join(d, n)
            if d and os.path.exists(p):
                return ImageFont.truetype(p, size, layout_engine=ImageFont.Layout.RAQM if features.check('raqm') else ImageFont.Layout.BASIC)
    return ImageFont.load_default()


def shape(text):
    """RAQM يشكّل العربي بنفسه؛ بدونه نشكّل يدويًا."""
    if features.check('raqm'):
        return text
    import arabic_reshaper
    from bidi.algorithm import get_display
    return get_display(arabic_reshaper.reshape(text))


def cover_bg(name):
    im = art(name).convert('RGB')
    s = max(W / im.width, H / im.height) * 1.08
    return im.resize((int(im.width * s), int(im.height * s)), Image.LANCZOS)


def wrap(draw, text, f, width):
    words, lines, cur = text.split(), [], ''
    for w in words:
        t = (cur + ' ' + w).strip()
        if draw.textlength(shape(t), font=f, direction='rtl' if features.check('raqm') else None) <= width:
            cur = t
        else:
            lines.append(cur)
            cur = w
    if cur:
        lines.append(cur)
    return lines


def ease(t):
    return 1 - (1 - min(max(t, 0), 1)) ** 3


def render_scene(scene, dur, pipe, first, last):
    bg = cover_bg(scene['bg'])
    f = font(44)
    n = max(1, int(dur * FPS))
    probe = ImageDraw.Draw(Image.new('RGB', (10, 10)))
    lines = wrap(probe, scene['say'], f, W - 120)
    for i in range(n):
        t = i / FPS
        z = 1 + 0.05 * (i / n)  # تكبير بطيء
        bw, bh = int(bg.width * z), int(bg.height * z)
        b = bg.resize((bw, bh), Image.BILINEAR)
        frame = b.crop(((bw - W) // 2, (bh - H) // 2, (bw - W) // 2 + W, (bh - H) // 2 + H)).convert('RGBA')
        # الشخصيات: تقف تحت وتتمايل
        chars = scene.get('chars', [])
        ch = int(H * (0.36 if len(chars) < 3 else 0.28))
        for k, (name, fx) in enumerate(chars):
            im = art(name)
            s = ch / im.height * (0.75 if name.startswith('lamaa') else 1)
            c = im.resize((int(im.width * s), int(im.height * s)), Image.LANCZOS)
            dy = int(abs(math.sin(t * 2.4 + k)) * 18)
            frame.alpha_composite(c, (int(W * fx - c.width / 2), int(H * 0.80 - c.height - dy)))
        # الصور: تظهر بحركة
        for k, (name, fx, fy, motion) in enumerate(scene.get('props', [])):
            im = art(name)
            p = ease((t - 0.25 * k) / 0.6)
            if p <= 0:
                continue
            size = int(W * (0.36 if name.startswith('pic_') else 0.22) * (0.4 + 0.6 * p))
            s = size / max(im.width, im.height)
            c = im.resize((max(1, int(im.width * s)), max(1, int(im.height * s))), Image.LANCZOS)
            y = H * fy
            if motion == 'fall':
                y = H * (fy - 0.25) + H * 0.25 * p
            y += math.sin(t * 2 + k) * 8
            frame.alpha_composite(c, (int(W * fx - c.width / 2), int(y - c.height / 2)))
        # جملة الراوي في صندوق أبيض تحت
        d = ImageDraw.Draw(frame)
        lh = 62
        boxh = lh * len(lines) + 40
        top = H - boxh - 40
        d.rounded_rectangle((30, top, W - 30, top + boxh), radius=34, fill=(255, 255, 255, 235), outline=(232, 169, 87, 255), width=5)
        for j, ln in enumerate(lines):
            txt = shape(ln)
            kw = {'direction': 'rtl'} if features.check('raqm') else {}
            tw = d.textlength(txt, font=f, **kw)
            d.text(((W - tw) / 2, top + 20 + j * lh), txt, font=f, fill=(74, 44, 18), **kw)
        # دخول/خروج ناعم
        a = 1.0
        if first:
            a = min(a, ease(i / (FPS * 0.5)))
        if last:
            a = min(a, ease((n - i) / (FPS * 0.6)))
        if a < 1:
            frame = Image.blend(Image.new('RGBA', (W, H), (255, 255, 255, 255)), frame, a)
        pipe.write(frame.convert('RGB').tobytes())


def title_card(story, dur, pipe):
    bg = cover_bg('bg_sky')
    f = font(64)
    frame0 = bg.crop(((bg.width - W) // 2, (bg.height - H) // 2, (bg.width - W) // 2 + W, (bg.height - H) // 2 + H)).convert('RGBA')
    cov = art(story.get('cover', 'lamaa_cheer'))
    n = int(dur * FPS)
    for i in range(n):
        t = i / FPS
        frame = frame0.copy()
        s = (H * 0.45) / cov.height * (0.85 + 0.15 * ease(t / 0.8))
        c = cov.resize((int(cov.width * s), int(cov.height * s)), Image.LANCZOS)
        frame.alpha_composite(c, (int(W / 2 - c.width / 2), int(H * 0.62 - c.height / 2)))
        d = ImageDraw.Draw(frame)
        kw = {'direction': 'rtl'} if features.check('raqm') else {}
        txt = shape(story['title'])
        tw = d.textlength(txt, font=f, **kw)
        d.rounded_rectangle(((W - tw) / 2 - 40, 150, (W + tw) / 2 + 40, 270), radius=40, fill=(255, 255, 255, 240), outline=(255, 143, 177, 255), width=6)
        d.text(((W - tw) / 2, 170), txt, font=f, fill=(184, 69, 122), **kw)
        a = ease(i / (FPS * 0.5))
        frame = Image.blend(Image.new('RGBA', (W, H), (255, 255, 255, 255)), frame, a)
        pipe.write(frame.convert('RGB').tobytes())
    return frame0


async def _tts(text, path):
    import edge_tts
    await edge_tts.Communicate(text, VOICE, rate='-8%').save(path)


def tts(text, path, silent):
    if silent:
        return False
    try:
        asyncio.run(_tts(text, path))
        return os.path.getsize(path) > 0
    except Exception as e:  # noqa: BLE001
        print('  tts unavailable:', type(e).__name__)
        return False


def duration(path):
    out = subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', path],
                         capture_output=True, text=True).stdout.strip()
    return float(out or 0)


def build(story, silent):
    os.makedirs(OUT, exist_ok=True)
    tmp = tempfile.mkdtemp()
    title = story['title']
    parts = [{'say': title, 'title': True}] + story['scenes']
    durs, audios = [], []
    for k, p in enumerate(parts):
        a = os.path.join(tmp, '%02d.mp3' % k)
        if tts(p['say'], a, silent):
            d = duration(a) + 0.9
            audios.append(a)
        else:
            d = 1.2 + len(p['say'].split()) * 0.45
            audios.append(None)
            silent = True  # صوت ناقص = فيديو صامت كله (لا نخلط)
        durs.append(max(2.5, d))
    video = os.path.join(tmp, 'v.mp4')
    enc = subprocess.Popen(['ffmpeg', '-y', '-loglevel', 'error', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', '%dx%d' % (W, H),
                            '-r', str(FPS), '-i', '-', '-c:v', 'libx264', '-preset', 'medium', '-crf', '26',
                            '-pix_fmt', 'yuv420p', video], stdin=subprocess.PIPE)
    title_card(story, durs[0], enc.stdin)
    for k, sc in enumerate(story['scenes']):
        render_scene(sc, durs[k + 1], enc.stdin, first=(k == 0), last=(k == len(story['scenes']) - 1))
    enc.stdin.close()
    enc.wait()
    out = os.path.join(OUT, story['id'] + '.mp4')
    if silent or any(a is None for a in audios):
        os.replace(video, out)
    else:
        # كل جملة في بداية مشهدها، والباقي سكوت.
        pads = []
        for k, (a, d) in enumerate(zip(audios, durs)):
            pa = os.path.join(tmp, 'p%02d.wav' % k)
            subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', a, '-af', 'adelay=300|300,apad', '-t', '%.3f' % d,
                            '-ar', '44100', '-ac', '1', pa], check=True)
            pads.append(pa)
        lst = os.path.join(tmp, 'a.txt')
        with open(lst, 'w') as fh:
            fh.writelines("file '%s'\n" % p for p in pads)
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', video, '-f', 'concat', '-safe', '0', '-i', lst,
                        '-c:v', 'copy', '-c:a', 'aac', '-b:a', '64k', '-shortest', out], check=True)
    # غلاف
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-ss', str(durs[0] * 0.9), '-i', out, '-frames:v', '1',
                    '-vf', 'scale=360:-1', os.path.join(OUT, story['id'] + '.jpg')], check=True)
    total = sum(durs)
    print('%s: %.1fs, %d KB%s' % (story['id'], total, os.path.getsize(out) // 1024, ' (silent)' if silent else ''))
    return {'id': story['id'], 'title': title, 'section': story.get('section', ''), 'seconds': round(total),
            'file': story['id'] + '.mp4', 'cover': story['id'] + '.jpg', 'voiced': not silent,
            'size': os.path.getsize(out)}


def main():
    doc = json.load(open(os.path.join(ROOT, 'tools', 'videos', 'stories.json'), encoding='utf-8'))
    only = sys.argv[sys.argv.index('--only') + 1] if '--only' in sys.argv else None
    silent = '--silent' in sys.argv
    items = [build(s, silent) for s in doc['stories'] if only in (None, s['id'])]
    with open(os.path.join(OUT, 'manifest.json'), 'w', encoding='utf-8') as fh:
        json.dump({'schema': 1, 'videos': items}, fh, ensure_ascii=False, indent=1)


if __name__ == '__main__':
    main()
