#!/usr/bin/env python3
"""ينزّل خطوط التطبيق (Tajawal للنص، Lalezar للعناوين — ترخيص OFL) أثناء البناء في CI.

الخطوط لا تُرفع إلى git. إن فشل التنزيل لأي سبب لا يفشل البناء: يعمل التطبيق بالخط الافتراضي.
عند النجاح يضيف قسم `fonts:` إلى pubspec.yaml داخل نسخة CI فقط.
"""
import json
import os
import sys
import urllib.request

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
FONT_DIR = os.path.join(ROOT, 'assets', 'fonts')
API = 'https://api.github.com/repos/google/fonts/contents/ofl/%s'

FAMILIES = {
    'Tajawal': ('tajawal', {'Regular': 400, 'Medium': 500, 'Bold': 700, 'ExtraBold': 800, 'Black': 900}),
    'Lalezar': ('lalezar', {'Regular': 400}),
}


def get(url):
    req = urllib.request.Request(url, headers={'User-Agent': 'nour-fedaa-build'})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read()


def main():
    os.makedirs(FONT_DIR, exist_ok=True)
    declared = []
    for family, (folder, weights) in FAMILIES.items():
        try:
            listing = json.loads(get(API % folder))
        except Exception as e:  # noqa: BLE001
            print('skip', family, ':', e)
            continue
        files = []
        for style, weight in weights.items():
            name = '%s-%s.ttf' % (family, style)
            item = next((x for x in listing if x['name'] == name), None)
            if not item:
                print('missing', name)
                continue
            try:
                data = get(item['download_url'])
                with open(os.path.join(FONT_DIR, name), 'wb') as f:
                    f.write(data)
                files.append((name, weight))
                print('ok', name, len(data))
            except Exception as e:  # noqa: BLE001
                print('fail', name, ':', e)
        if files:
            declared.append((family, files))
    if not declared:
        print('no fonts fetched; using default font')
        return 0
    block = '\n  fonts:\n'
    for family, files in declared:
        block += '    - family: %s\n      fonts:\n' % family
        for name, weight in files:
            block += '        - asset: assets/fonts/%s\n          weight: %d\n' % (name, weight)
    p = os.path.join(ROOT, 'pubspec.yaml')
    s = open(p, encoding='utf-8').read()
    if 'assets/fonts/' not in s:
        open(p, 'w', encoding='utf-8').write(s.rstrip('\n') + '\n' + block)
    return 0


if __name__ == '__main__':
    sys.exit(main())
