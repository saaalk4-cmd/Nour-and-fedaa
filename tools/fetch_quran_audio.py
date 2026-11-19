#!/usr/bin/env python3
"""ينزّل تلاوة الآيات (آية آية) للسور الموجودة في التطبيق إلى assets/audio/quran/.

المصدر: Islamic Network CDN (قارئ: مشاري العفاسي). الترخيص حسب شروط alquran.cloud:
مجاني لإعادة التوزيع غير التجاري، وحقوق التلاوة تبقى للقارئ. التطبيق عائلي غير تجاري.
يُشغَّل في CI قبل بناء الـAPK (لا تُرفع الملفات إلى git). إن تعذّر التنزيل لا يفشل البناء:
التطبيق يعمل بدون تلاوة ويعرض رسالة لطيفة.
الاستخدام: python3 tools/fetch_quran_audio.py
"""
import json
import os
import sys
import time
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..')
OUT = os.path.join(ROOT, 'assets', 'audio', 'quran')
EDITION = 'ar.alafasy'
BITRATE = 64  # kbps: صغير الحجم ومناسب لتلاوة الأطفال
URL = 'https://cdn.islamic.network/quran/audio/%d/%s/%d.mp3'

counts = json.load(open(os.path.join(HERE, 'quran_verse_counts.json')))
surahs = json.load(open(os.path.join(ROOT, 'assets', 'content', 'quran_surahs.json'), encoding='utf-8'))['surahs']
os.makedirs(OUT, exist_ok=True)


def global_number(surah, ayah):
    return sum(counts[:surah - 1]) + ayah


def wanted():
    """كل آية لها نص في التطبيق: السور، وأي «recite» في الدروس، وآيات الأنبياء."""
    refs = set()
    for s in surahs:
        for a in s['ayahs']:
            refs.add((s['surahNumber'], a['number']))

    def walk(x):
        if isinstance(x, dict):
            r = x.get('recite')
            if isinstance(r, list) and len(r) in (2, 3):
                for a in range(r[1], (r[2] if len(r) == 3 else r[1]) + 1):
                    refs.add((r[0], a))
            for v in x.values():
                walk(v)
        elif isinstance(x, list):
            for v in x:
                walk(v)

    content = os.path.join(ROOT, 'assets', 'content')
    for f in sorted(os.listdir(content)):
        if f.endswith('.json'):
            doc = json.load(open(os.path.join(content, f), encoding='utf-8'))
            walk(doc)
            for v in (doc.get('verses', []) if isinstance(doc, dict) else []):
                for a in range(v['ayahFrom'], v['ayahTo'] + 1):
                    refs.add((v['surahNumber'], a))
    return sorted(refs)


ok = fail = 0
for n, i in wanted():
    path = os.path.join(OUT, '%d_%d.mp3' % (n, i))
    if os.path.exists(path) and os.path.getsize(path) > 1000:
        ok += 1
        continue
    url = URL % (BITRATE, EDITION, global_number(n, i))
    for attempt in range(3):
        try:
            data = urllib.request.urlopen(url, timeout=30).read()
            if len(data) < 1000:
                raise ValueError('too small')
            open(path, 'wb').write(data)
            ok += 1
            break
        except Exception as e:  # noqa: BLE001
            if attempt == 2:
                fail += 1
                print('FAILED %s: %s' % (url, e), file=sys.stderr)
            else:
                time.sleep(2)
print('quran audio: %d ok, %d failed' % (ok, fail))
if fail:
    print('::warning::Quran audio incomplete (%d failed); APK built without those recitations' % fail)
