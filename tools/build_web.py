#!/usr/bin/env python3
"""يجمّع صفحة «العب مع لمعة» (games_web/) في build/site/ للرفع على GitHub Pages.

  python3 tools/build_web.py [fonts_dir]

- games_web/: الصفحة نفسها (index.html, style.css, app.js, phrases.json).
- art/: رسومات التطبيق (assets/art/*.webp).
- fonts/: Tajawal + Lalezar (assets/fonts، أو المجلد المعطى).
- data/quran.json: نص الأجزاء 28–30 (نفس نص التطبيق المطابق لـ Tanzil) + عدد آيات كل سورة (لرقم الآية في تلاوة الشيخ).
- voice/: مقاطع صوت التطبيق لجمل الصفحة فقط (games_web/phrases.json) + index.json (الجملة ← الملف).
- videos/: الحكايات (build/videos) إن وُجدت.
"""
import json
import os
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SITE = os.path.join(ROOT, 'build', 'site')
sys.path.insert(0, os.path.join(ROOT, 'tools'))


def main():
    fonts = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, 'assets', 'fonts')
    shutil.rmtree(SITE, ignore_errors=True)
    shutil.copytree(os.path.join(ROOT, 'games_web'), SITE)
    shutil.copytree(os.path.join(ROOT, 'assets', 'art'), os.path.join(SITE, 'art'))
    os.makedirs(os.path.join(SITE, 'fonts'))
    for n in ('Tajawal-Medium.ttf', 'Tajawal-ExtraBold.ttf', 'Lalezar-Regular.ttf'):
        p = os.path.join(fonts, n)
        if os.path.exists(p):
            shutil.copy(p, os.path.join(SITE, 'fonts', n))

    q = json.load(open(os.path.join(ROOT, 'assets', 'content', 'quran_surahs.json'), encoding='utf-8'))
    surahs = q['surahs'] if isinstance(q, dict) else q
    data = {
        'counts': json.load(open(os.path.join(ROOT, 'tools', 'quran_verse_counts.json'))),
        'surahs': [{'n': s['surahNumber'], 'name': s['name'], 'ayahs': [a['text'] for a in s['ayahs']]}
                   for s in surahs if s['surahNumber'] >= 58],
    }
    os.makedirs(os.path.join(SITE, 'data'))
    with open(os.path.join(SITE, 'data', 'quran.json'), 'w', encoding='utf-8') as fh:
        json.dump(data, fh, ensure_ascii=False, separators=(',', ':'))

    # صوت التطبيق لجمل الصفحة (نفس مفتاح tools/build_voice.py).
    import build_voice as bv
    phrases = json.load(open(os.path.join(ROOT, 'games_web', 'phrases.json'), encoding='utf-8'))['phrases']
    vdir = os.path.join(SITE, 'voice')
    os.makedirs(vdir)
    index = {}
    for t in phrases:
        k = bv.clip_key(bv.clean(t))
        src = os.path.join(bv.OUT, k + '.mp3')
        if os.path.exists(src):
            shutil.copy(src, os.path.join(vdir, k + '.mp3'))
            index[t] = k + '.mp3'
    with open(os.path.join(vdir, 'index.json'), 'w', encoding='utf-8') as fh:
        json.dump(index, fh, ensure_ascii=False)

    vids = os.path.join(ROOT, 'build', 'videos')
    if os.path.isdir(vids):
        shutil.copytree(vids, os.path.join(SITE, 'videos'))
    open(os.path.join(SITE, '.nojekyll'), 'w').close()
    size = sum(os.path.getsize(os.path.join(d, f)) for d, _, fs in os.walk(SITE) for f in fs)
    print('site: %d phrases with voice of %d, %.1f MB' % (len(index), len(phrases), size / 1e6))


if __name__ == '__main__':
    main()
