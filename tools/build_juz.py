#!/usr/bin/env python3
"""يضيف الأجزاء 28 و29 و30 (من المجادلة إلى الناس) إلى assets/content/quran_surahs.json بنص Tanzil الحرفي.

الاستخدام:
  python3 tools/build_juz.py <tanzil_uthmani.txt> <surahs_meta.json>
- tanzil_uthmani.txt: https://tanzil.net/pub/download/index.php?pauseMarks=false&sajdah=false&rub=false&tatweel=true&quranType=uthmani&outType=txt-2&agree=true
  (sha256 المستعمل: b38cf5d71a02056632350c72ef1f490cca4baccc68988d34346b5eadcf8b7006)
- surahs_meta.json: https://api.alquran.cloud/v1/surah (أسماء السور فقط).
القراءة بنفس load_tanzil في build_prophets_ayat.py: يُحذف التطويل الاختياري (ـ) والبسملة المضافة قبل الآية الأولى فقط.
السور الموجودة من قبل تبقى كما هي (ويُتحقق أنها مطابقة للمصدر حرفًا بحرف).
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_prophets_ayat import load_tanzil, surah_name  # noqa: E402

JUZ = {28: range(58, 67), 29: range(67, 78), 30: range(78, 115)}
PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets', 'content', 'quran_surahs.json')


def juz_of(n):
    for j, r in JUZ.items():
        if n in r:
            return j
    return None


def main():
    q = load_tanzil(sys.argv[1])
    names = {c['number']: surah_name(c['name'].replace('سُورَةُ ', '')) for c in json.load(open(sys.argv[2], encoding='utf-8'))['data']}
    names[78] = 'النبأ'  # بالكتابة المألوفة للبنات (الاسم فقط، لا نص الآيات)
    doc = json.load(open(PATH, encoding='utf-8'))
    have = {s['surahNumber']: s for s in doc['surahs']}
    for s in doc['surahs']:
        for a in s['ayahs']:
            assert q[(s['surahNumber'], a['number'])] == a['text'], (s['surahNumber'], a['number'])
        j = juz_of(s['surahNumber'])
        if j:
            s['juz'] = j
    counts = {}
    for (s, a) in q:
        counts[s] = max(counts.get(s, 0), a)
    for j, r in JUZ.items():
        for n in r:
            if n in have:
                continue
            doc['surahs'].append({
                'id': 'surah_%d' % n, 'surahNumber': n, 'name': names[n], 'ayahCount': counts[n], 'juz': j,
                'ayahs': [{'number': a, 'text': q[(n, a)]} for a in range(1, counts[n] + 1)],
            })
    doc['source']['note'] = (doc['source'].get('note', '') + ' الأجزاء 28–30 أُضيفت بـ tools/build_juz.py من نفس المصدر.').strip()
    with open(PATH, 'w', encoding='utf-8') as fh:
        json.dump(doc, fh, ensure_ascii=False, indent=2)
    print(len(doc['surahs']), 'surahs,', sum(len(s['ayahs']) for s in doc['surahs']), 'ayahs')


if __name__ == '__main__':
    main()
