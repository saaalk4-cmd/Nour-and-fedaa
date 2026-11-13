#!/usr/bin/env python3
"""يولّد دروس التدريب من المحتوى الموثّق فقط (لا يضيف أي نص ديني جديد).

المدخلات: assets/content/quran_surahs.json و *_hadith.json
المخرجات: assets/content/quran_lessons.json و hadith_lessons.json
الأسئلة تُبنى من نفس النصوص المعتمدة (نص الآية/الحديث/عنوانه/معناه المبسّط).
"""
import json
import os

ROOT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'content')


def load(name):
    with open(os.path.join(ROOT, name), encoding='utf-8') as f:
        return json.load(f)


def save(name, lessons):
    with open(os.path.join(ROOT, name), 'w', encoding='utf-8') as f:
        json.dump({'schema': 1, 'lessons': lessons}, f, ensure_ascii=False, indent=2)


def question(prompt, correct, pool, idx, hint, emoji=None):
    """يرجع سؤالًا بثلاثة خيارات؛ مكان الصحيح يتبدّل حسب idx (حتى لا يكون ثابتًا)."""
    wrong = [p for p in pool if p != correct][:2]
    options = wrong[:]
    options.insert(idx % 3, correct)
    q = {'prompt': prompt, 'options': options, 'answerIndex': idx % 3, 'hint': hint}
    if emoji:
        q['emoji'] = emoji
    return q


# ---------------- القرآن ----------------
quran = load('quran_surahs.json')
surahs = quran['surahs']
names = [s['name'] for s in surahs]
# (difficulty, minAge)
LEVELS = {112: (1, 3), 114: (1, 3), 108: (1, 3), 113: (2, 4), 110: (2, 4),
          103: (2, 4), 106: (2, 4), 1: (3, 5)}
q_lessons = []
for i, s in enumerate(surahs):
    diff, min_age = LEVELS[s['surahNumber']]
    others = [n for n in names if n != s['name']]
    rot = others[i % len(others):] + others[:i % len(others)]
    first = s['ayahs'][0]['text']
    other_first = [t['ayahs'][0]['text'] for t in surahs if t is not s]
    other_first = other_first[i % len(other_first):] + other_first[:i % len(other_first)]
    questions = [
        question('من أي سورة هذه الآية؟\n' + first, 'سورة ' + s['name'],
                 ['سورة ' + n for n in rot], i, 'استمعي للآية مرة أخرى مع والديكِ', '📖'),
        question('ما أول آية في سورة ' + s['name'] + '؟', first, other_first, i + 1,
                 'أول آية في السورة', '🌟'),
    ]
    q_lessons.append({
        'id': 'quran_surah_%d' % s['surahNumber'],
        'title': 'سورة ' + s['name'],
        'emoji': '📖',
        'category': 'quran',
        'minAge': min_age,
        'maxAge': 6,
        'difficulty': diff,
        'source': {'type': 'quran',
                   'reference': '%s — سورة %s' % (quran['source']['name'], s['name'])},
        'steps': [{'emoji': '📖', 'text': a['text']} for a in s['ayahs']],
        'questions': questions,
    })
save('quran_lessons.json', q_lessons)

# ---------------- الأحاديث والأذكار ----------------
SECTIONS = [('akhlaq', 'akhlaq_hadith.json'), ('adhkar', 'adhkar_hadith.json'),
            ('prayer', 'prayer_hadith.json'), ('seerah', 'seerah_hadith.json')]
all_items = []
seen_texts = set()
for cat, f in SECTIONS:
    for h in load(f)['hadiths']:
        # الحديث المكرر في قسمين يُدرَّب مرة واحدة (حتى لا تتشابه الخيارات).
        if h['text'] in seen_texts:
            continue
        seen_texts.add(h['text'])
        all_items.append((cat, h))
titles = [h['title'] for _, h in all_items]
meanings = [h['kidMeaning'] for _, h in all_items]
h_lessons = []
for i, (cat, h) in enumerate(all_items):
    ot = [t for t in titles if t != h['title']]
    om = [m for m in meanings if m != h['kidMeaning']]
    ot = ot[i % len(ot):] + ot[:i % len(ot)]
    om = om[i % len(om):] + om[:i % len(om)]
    h_lessons.append({
        'id': h['id'] + '_lesson',
        'title': h['title'],
        'emoji': h['emoji'],
        'category': cat,
        'minAge': 3,
        'maxAge': 6,
        'difficulty': 1,
        'source': {'type': 'sahih_sunnah',
                   'reference': '%s (%s) — %s' % (h['book'], h['number'], h['grade'])},
        'steps': [{'emoji': h['emoji'], 'text': h['text']},
                  {'emoji': '💡', 'text': h['kidMeaning']}],
        'questions': [
            question('عن ماذا تتحدث هذه الجملة؟\n' + h['text'], h['title'], ot, i,
                     'فكّري في معنى الجملة', h['emoji']),
            question('ماذا نتعلّم؟', h['kidMeaning'], om, i + 1,
                     'تذكّري الخطوة الثانية', '💡'),
        ],
    })
save('hadith_lessons.json', h_lessons)
print(len(q_lessons), 'quran lessons;', len(h_lessons), 'hadith lessons')
