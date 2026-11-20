#!/usr/bin/env python3
"""حزم التنزيل (تُنزَّل داخل التطبيق مرة واحدة وتُحفظ للعمل بلا نت) — في CI بعد build_voice.py وقبل flutter build.

- voice: جمل الدروس الطويلة (فداء) التي ليست أساسية ولا لنور ولا للألعاب. الباقي يبقى داخل الـAPK.
- quran_28 / quran_29 / quran_30: تلاوة آيات الأجزاء (بصوت المنشاوي) عدا السور الثماني الأولى
  والآيات المستعملة داخل الدروس (تبقى داخل الـAPK).
الناتج: build/packs/<pack>.zip + build/packs/manifest.json، ويُعاد كتابة assets/audio/voice/index.json بالمضمَّن فقط.

  python3 tools/build_packs.py            # ينقل ملفات الحزم خارج assets ويصنع الملفات
  python3 tools/build_packs.py --restore  # بعد flutter build: يعيد مقاطع الصوت إلى assets/audio/voice
                                          # (فولدر الكاش في CI؛ وإلا يُعاد توليدها ويُصرف الرصيد)
"""
import hashlib
import json
import os
import shutil
import sys
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..')
VOICE = os.path.join(ROOT, 'assets', 'audio', 'voice')
QURAN = os.path.join(ROOT, 'assets', 'audio', 'quran')
CONTENT = os.path.join(ROOT, 'assets', 'content')
OUT = os.path.join(ROOT, 'build', 'packs')

# السور الأولى في التطبيق: تبقى داخل الـAPK
ORIGINAL_SURAHS = {1, 112, 113, 114, 108, 110, 103, 106}
JUZ = {28: range(58, 67), 29: range(67, 78), 30: range(78, 115)}


def juz_of(surah):
    for j, r in JUZ.items():
        if surah in r:
            return j
    return None


def bundled_voice_keys():
    sys.path.insert(0, HERE)
    import build_voice as bv  # noqa: PLC0415

    def keys(texts):
        return {bv.clip_key(bv.clean(t)) for t in texts if bv.clean(t)}

    return (keys(bv.dart_phrases()) | keys(bv.content_phrases()) | keys(bv.section_phrases())
            | keys(bv.cheer_phrases()) | keys(bv.game_phrases()) | keys(bv.nour_lesson_phrases())
            | set(bv.essential_keys()))


def lesson_ayah_refs():
    """آيات تُتلى داخل الدروس (recite وآيات الأنبياء والأقسام): تبقى داخل الـAPK."""
    refs = set()

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

    for f in sorted(os.listdir(CONTENT)):
        if f.endswith('.json') and f != 'quran_surahs.json':
            doc = json.load(open(os.path.join(CONTENT, f), encoding='utf-8'))
            walk(doc)
            for v in (doc.get('verses', []) if isinstance(doc, dict) else []):
                for a in range(v['ayahFrom'], v['ayahTo'] + 1):
                    refs.add((v['surahNumber'], a))
    return refs


def zip_dir(src, dest):
    files = sorted(f for f in os.listdir(src) if not f.startswith('.'))
    h = hashlib.sha1()
    with zipfile.ZipFile(dest, 'w', zipfile.ZIP_STORED) as z:
        for f in files:
            p = os.path.join(src, f)
            z.write(p, f)
            h.update(('%s:%d;' % (f, os.path.getsize(p))).encode())
    return h.hexdigest()[:16], len(files)


def build():
    shutil.rmtree(OUT, ignore_errors=True)
    os.makedirs(OUT)
    manifest = {'schema': 1, 'packs': []}

    # ---- الأصوات ----
    idx_path = os.path.join(VOICE, 'index.json')
    if os.path.exists(idx_path):
        idx = json.load(open(idx_path, encoding='utf-8'))
        keep = bundled_voice_keys()
        clips = idx.get('clips', [])
        pack = [k for k in clips if k not in keep and os.path.exists(os.path.join(VOICE, k + '.mp3'))]
        vdir = os.path.join(OUT, 'voice')
        os.makedirs(vdir)
        for k in pack:
            shutil.move(os.path.join(VOICE, k + '.mp3'), os.path.join(vdir, k + '.mp3'))
        bundled = [k for k in clips if k not in set(pack)]
        src = idx.get('sources', {})
        json.dump({'voice': idx.get('voice'), 'clips': sorted(bundled),
                   'sources': {k: src.get(k, 'edge') for k in bundled}},
                  open(idx_path, 'w', encoding='utf-8'))
        if pack:
            json.dump({'clips': sorted(pack)}, open(os.path.join(vdir, 'index.json'), 'w', encoding='utf-8'))
            ver, n = zip_dir(vdir, os.path.join(OUT, 'voice.zip'))
            manifest['packs'].append({'name': 'voice', 'file': 'voice.zip', 'version': ver, 'count': len(pack),
                                      'bytes': os.path.getsize(os.path.join(OUT, 'voice.zip'))})
        print('voice: %d bundled, %d in pack' % (len(bundled), len(pack)))

    # ---- التلاوة ----
    if os.path.isdir(QURAN):
        keep = lesson_ayah_refs()
        moved = {j: 0 for j in JUZ}
        for f in sorted(os.listdir(QURAN)):
            if not f.endswith('.mp3'):
                continue
            s, a = (int(x) for x in f[:-4].split('_'))
            j = juz_of(s)
            if j is None or s in ORIGINAL_SURAHS or (s, a) in keep:
                continue
            d = os.path.join(OUT, 'quran_%d' % j)
            os.makedirs(d, exist_ok=True)
            shutil.move(os.path.join(QURAN, f), os.path.join(d, f))
            moved[j] += 1
        for j, n in moved.items():
            if not n:
                continue
            name = 'quran_%d' % j
            ver, _ = zip_dir(os.path.join(OUT, name), os.path.join(OUT, name + '.zip'))
            manifest['packs'].append({'name': name, 'file': name + '.zip', 'version': ver, 'count': n,
                                      'bytes': os.path.getsize(os.path.join(OUT, name + '.zip'))})
        print('quran packs:', moved)

    json.dump(manifest, open(os.path.join(OUT, 'manifest.json'), 'w', encoding='utf-8'), indent=1)
    print(json.dumps(manifest))


def restore():
    """يعيد الملفات إلى فولدرات الكاش في CI (الأصوات والتلاوة) حتى لا يُعاد توليدها أو تنزيلها."""
    n = 0
    for name, dest in [('voice', VOICE)] + [('quran_%d' % j, QURAN) for j in JUZ]:
        d = os.path.join(OUT, name)
        if not os.path.isdir(d):
            continue
        for f in os.listdir(d):
            if f.endswith('.mp3'):
                shutil.copy2(os.path.join(d, f), os.path.join(dest, f))
                n += 1
    print('restored %d files to the cache folders' % n)


if __name__ == '__main__':
    restore() if '--restore' in sys.argv else build()
