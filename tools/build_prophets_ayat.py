#!/usr/bin/env python3
"""يبني assets/content/prophets_ayat.json بنص Tanzil الحرفي.
الاستخدام: python3 tools/build_prophets_ayat.py <مسار data/tanzil/uthmani.json> <chapters.json>
نختار المراجع (سورة:آية) فقط، والنص يُؤخذ برمجيًا دون أي تعديل."""
import json, os, sys

uthmani = json.load(open(sys.argv[1], encoding='utf-8'))
chapters = {c['id']: c['name'] for c in json.load(open(sys.argv[2], encoding='utf-8'))['chapters']}

# (id, النبي، عنوان، سورة، من، إلى، معنى مبسّط من مضمون الآية نفسها)
ITEMS = [
    ('prophet_ibrahim', 'إبراهيم عليه السلام', 'النار بردًا وسلامًا', 21, 69, 69,
     'قال الله للنار: كوني بردًا وسلامًا على إبراهيم.'),
    ('prophet_nuh', 'نوح عليه السلام', 'الاستغفار', 71, 10, 10,
     'قال نوح لقومه: اطلبوا المغفرة من ربكم، إنه كان غفّارًا.'),
    ('prophet_musa', 'موسى عليه السلام', 'دعاء موسى', 20, 25, 26,
     'دعا موسى ربه أن يشرح له صدره وأن ييسّر له أمره.'),
    ('prophet_yusuf', 'يوسف عليه السلام', 'رؤيا يوسف', 12, 4, 4,
     'قال يوسف لأبيه إنه رأى أحد عشر كوكبًا والشمس والقمر ساجدين له.'),
    ('prophet_isa', 'عيسى عليه السلام', 'عبد الله ونبيّه', 19, 30, 30,
     'قال عيسى: إني عبد الله، أعطاني الكتاب وجعلني نبيًا.'),
]
out = []
for pid, who, title, s, a, b, meaning in ITEMS:
    text = ' '.join(v['text'] for v in uthmani[str(s)] if a <= v['verse'] <= b)
    assert text
    out.append({'id': pid, 'prophet': who, 'title': title, 'emoji': '🌿',
                'surahNumber': s, 'surahName': chapters[s], 'ayahFrom': a, 'ayahTo': b,
                'text': text, 'kidMeaning': meaning})
doc = {'schema': 1,
       'source': {'type': 'quran', 'name': 'Tanzil Quran Text (Uthmani)',
                  'url': 'https://tanzil.net/docs/text_license',
                  'license': 'CC BY 3.0 — verbatim copying only'},
       'verses': out}
path = os.path.join(os.path.dirname(__file__), '..', 'assets', 'content', 'prophets_ayat.json')
json.dump(doc, open(path, 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
print(len(out), 'verses')
