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
            ('prayer', 'prayer_hadith.json'), ('seerah', 'seerah_hadith.json'),
            ('figures', 'figures_hadith.json')]
all_items = []
seen_texts = set()
for cat, f in SECTIONS:
    for h in load(f)['hadiths']:
        # الحديث المكرر في قسمين يُدرَّب مرة واحدة (حتى لا تتشابه الخيارات).
        if h['text'] in seen_texts:
            continue
        seen_texts.add(h['text'])
        all_items.append((cat, h))
# الأحاديث الستة عشر الأولى مستعملة في منهج الأسابيع: تُبنى أسئلتها من نفس المجموعة كما كانت
# (لا تتغير خياراتها بإضافة أحاديث جديدة). الجديدة تأتي بعدها.
ORIGINAL_HADITH = 16
originals = [x for x in all_items if 'verified' not in x[1]]
assert len(originals) == ORIGINAL_HADITH, len(originals)
all_items = originals + [x for x in all_items if 'verified' in x[1]]
titles = [h['title'] for _, h in all_items]
meanings = [h['kidMeaning'] for _, h in all_items]
h_lessons = []
for i, (cat, h) in enumerate(all_items):
    pool_t = titles[:ORIGINAL_HADITH] if i < ORIGINAL_HADITH else titles
    pool_m = meanings[:ORIGINAL_HADITH] if i < ORIGINAL_HADITH else meanings
    ot = [t for t in pool_t if t != h['title']]
    om = [m for m in pool_m if m != h['kidMeaning']]
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

# ---------------- واجهة الصغيرات (نور 3 سنوات) ----------------
# صورة + كلمة قصيرة + صوت + سؤال لمس واحد. الكلمات هنا «مفاهيم» تعليمية بلا نسبة للنبي ﷺ:
# النص الكامل والمصدر يبقيان في الدرس ويظهران للوالدين فقط. النطق الآلي لعبارتين فقط:
# «بسم الله» و«السلام عليكم».
def tq(say, emoji, good, other, hint):
    return {'prompt': say, 'say': say, 'emoji': emoji, 'options': [good, other], 'answerIndex': 0,
            'hint': hint, 'praise': 'أحسنتِ!'}


TODDLER = {
    'hadith_eating_manners': ([('🍽️', 'بسم الله', 'بسم الله')],
                              tq('ماذا نقول قبل الأكل؟', '🍽️', '🍽️ بسم الله', '🤐 لا شيء', 'قبل الأكل')),
    'hadith_good_word': ([('💬', 'كلمة طيبة', 'كلمة طيبة')],
                         tq('صديقتك حزينة. ماذا نقول لها؟', '😢', '💬 كلمة طيبة', '🙊 لا شيء', 'كلمة طيبة')),
    'hadith_every_good_is_charity': ([('🤝', 'المعروف', 'نفعل المعروف')],
                                     tq('صديقتك تحتاج مساعدة. ماذا نفعل؟', '🧸', '🤝 نساعدها', '🙈 نتركها', 'نساعد')),
    'hadith_sleep_dhikr': ([('😴', 'قبل النوم', 'قبل النوم')],
                           tq('ماذا نفعل قبل النوم؟', '😴', '🤲 نذكر الله', '📱 نلعب', 'قبل النوم')),
    'hadith_prayer_on_time': ([('🕌', 'الصلاة', 'الصلاة')],
                              tq('متى نصلي؟', '🕌', '⏰ في وقتها', '😴 نؤخرها', 'في وقتها')),
    'hadith_best_manners': ([('😊', 'أخلاق جميلة', 'أخلاق جميلة')],
                            tq('صديقتك أخذت لعبتك. ماذا نفعل؟', '🧸', '😊 نتكلم بلطف', '😠 نصرخ', 'بلطف')),
    'hadith_abubakr_umar': ([('💛', 'نحب الصالحين', 'نحب الصالحين')], None),
    'hadith_hasan_husayn': ([('💛', 'الحسن والحسين', 'الحسن والحسين')], None),
    'hadith_anas_service': ([('🤝', 'نخدم بحب', 'نخدم بحب')],
                            tq('ماما تحتاج مساعدة. ماذا نفعل؟', '🛍️', '🤝 نساعدها', '🙈 نتجاهل', 'نساعد')),
    'hadith_truthfulness': ([('💎', 'الصدق', 'الصدق')],
                            tq('ماذا نقول دائمًا؟', '💎', '💎 الحقيقة', '🙈 غير الحقيقة', 'الحقيقة')),
    'hadith_salam': ([('👋', 'السلام عليكم', 'السلام عليكم')],
                     tq('نرى جارتنا. ماذا نقول؟', '👩', '👋 السلام عليكم', '🤐 لا شيء', 'السلام')),
    'hadith_purity': ([('🧼', 'النظافة', 'النظافة')],
                      tq('قبل الأكل. ماذا نفعل؟', '🍽️', '🧼 نغسل أيدينا', '🪨 نلعب بالطين', 'نغسل')),
    'hadith_gratitude_food': ([('🥛', 'نشكر الله', 'نشكر الله')],
                              tq('بعد الأكل. ماذا نفعل؟', '🍽️', '🤲 نشكر الله', '🙈 لا شيء', 'نشكر')),
    'hadith_wudu_prayer': ([('💧', 'الوضوء', 'نتوضأ')],
                           tq('قبل الصلاة. ماذا نفعل؟', '🕌', '💧 نتوضأ', '🙈 لا شيء', 'نتوضأ')),
    'hadith_remove_harm': ([('🪨', 'نبعد الأذى', 'نبعد الأذى عن الطريق')],
                           tq('حجر في الطريق. ماذا نفعل؟', '🪨', '🤝 نبعده', '🙈 نتركه', 'نبعده')),
    'hadith_parents': ([('👩‍👧', 'ماما وبابا', 'نحب ماما وبابا')],
                       tq('من نحب ونحسن إليهما؟', '👩‍👧', '👩‍👧 ماما وبابا', '🙈 لا أحد', 'ماما وبابا')),
    # إضافات الجلسة الثالثة (أذكار، سيرة، شخصيات). العبارات تعليمية قصيرة لا تقتبس الحديث.
    'hadith_toilet_in': ([('🚽', 'قبل الحمّام', 'قبل الحمّام ندعو الله')],
                         tq('قبل دخول الحمّام. ماذا نفعل؟', '🚽', '🤲 ندعو الله', '🏃 نجري', 'ندعو')),
    'hadith_toilet_out': ([('🚪', 'بعد الحمّام', 'بعد الحمّام نستغفر الله')],
                          tq('خرجنا من الحمّام. ماذا نفعل؟', '🚪', '🤲 نستغفر الله', '🙈 لا شيء', 'نستغفر')),
    'hadith_home_in': ([('🏠', 'ندخل البيت', 'ندخل البيت ونذكر الله')],
                       tq('ندخل البيت. ماذا نقول؟', '🏠', '🤲 بسم الله', '🤐 لا شيء', 'بسم الله')),
    'hadith_mosque': ([('🕌', 'المسجد', 'ندخل المسجد وندعو الله')], None),
    'hadith_rain': ([('🌧️', 'المطر', 'المطر نعمة من الله')],
                    tq('نزل المطر. ماذا نفعل؟', '🌧️', '🤲 ندعو الله', '😠 نغضب', 'ندعو')),
    'hadith_serving_family': ([('🏡', 'نساعد في البيت', 'النبي كان يساعد أهله')],
                              tq('ماما ترتّب البيت. ماذا نفعل؟', '🧺', '🤝 نساعدها', '🙈 نتركها', 'نساعد')),
    'hadith_mercy_children': ([('🤗', 'الرحمة', 'النبي يحب الأطفال')],
                              tq('أخوك الصغير يبكي. ماذا نفعل؟', '😢', '🤗 نحضنه', '🙈 نتركه', 'نحضنه')),
    'hadith_ali': ([('💛', 'علي', 'نحب علي بن أبي طالب')], None),
    'hadith_bilal': ([('🕌', 'بلال', 'بلال يحب الصلاة')],
                     tq('توضأنا. ماذا نفعل؟', '💧', '🕌 نصلي', '📺 نتفرج', 'نصلي')),
}
for l in h_lessons:
    base = l['id'][:-len('_lesson')]
    cards, q = TODDLER[base]
    l['toddler'] = {'cards': [{'emoji': e, 'word': w, 'say': sy} for e, w, sy in cards]}
    if q:
        l['toddler']['question'] = q
save('hadith_lessons.json', h_lessons)
print(len(q_lessons), 'quran lessons;', len(h_lessons), 'hadith lessons')

# ---------------- قصص الأنبياء (آيات) ----------------
# فداء (5): الآية بصوت الشيخ + المعنى ببساطة + سؤالان.
# نور (3): بطاقة الاسم (يُنطق) + بطاقة الآية (الشيخ يقرأ) + بطاقة معنى قصيرة. لا نطق آلي للآية.
pv = load('prophets_ayat.json')
verses = pv['verses']
# الدروس الخمسة الأولى مستعملة في منهج الأسابيع (لا تُمس): نفس الرمز ونفس الأسئلة كما كانت،
# ويُضاف فقط صوت الشيخ وبطاقات نور.
ORIGINAL = ['prophet_ibrahim', 'prophet_nuh', 'prophet_musa', 'prophet_yusuf', 'prophet_isa']
p_lessons = []
for i, v in enumerate(verses):
    if v['id'] in ORIGINAL:
        k = ORIGINAL.index(v['id'])
        orig = [o for o in verses if o['id'] in ORIGINAL]
        orig.sort(key=lambda o: ORIGINAL.index(o['id']))
        ow = [o['prophet'] for o in orig if o['id'] != v['id']]
        om = [o['kidMeaning'] for o in orig if o['id'] != v['id']]
        ow = ow[k % len(ow):] + ow[:k % len(ow)]
        om = om[k % len(om):] + om[:k % len(om)]
        v = dict(v, emoji='🌿')
        qi = k
    else:
        qi = i
    others = [o for o in verses if o['id'] != v['id']]
    others = others[i % len(others):] + others[:i % len(others)]
    if v['id'] not in ORIGINAL:
        ow = [o['prophet'] for o in others]
        # خيارات المعنى الخاطئة من آيات بمعنى مختلف فقط (لا «ألا تتقون» مقابل «ألا تتقون»).
        om = [o['kidMeaning'] for o in others if o['meaningGroup'] != v['meaningGroup']]
    ref = 'سورة %s، آية %d' % (v['surahName'], v['ayahFrom']) if v['ayahFrom'] == v['ayahTo'] \
        else 'سورة %s، الآيات %d-%d' % (v['surahName'], v['ayahFrom'], v['ayahTo'])
    recite = [v['surahNumber'], v['ayahFrom']] if v['ayahFrom'] == v['ayahTo'] \
        else [v['surahNumber'], v['ayahFrom'], v['ayahTo']]
    name = v['prophet'].split(' عليه')[0].replace(' ﷺ', '')
    assert v['toddlerSay'] not in v['kidMeaning'] or len(v['toddlerSay'].split()) < 4, v['id']
    p_lessons.append({
        'id': v['id'] + '_lesson', 'title': v['prophet'], 'emoji': v['emoji'],
        'category': 'prophets', 'minAge': 3, 'maxAge': 6, 'difficulty': 1,
        'source': {'type': 'quran', 'reference': '%s — %s' % (pv['source']['name'], ref)},
        'steps': [{'emoji': '📖', 'text': v['text'], 'recite': recite},
                  {'emoji': '💡', 'text': v['kidMeaning']}],
        'questions': [
            question('عن أي نبي تتحدث هذه الآية؟\n' + v['text'], v['prophet'], ow, qi,
                     'استمعي لاسم النبي في الآية', v['emoji']),
            question('ماذا تقول الآية؟', v['kidMeaning'], om, qi + 1,
                     'تذكّري الخطوة الثانية', '💡'),
        ],
        'toddler': {'cards': [
            {'emoji': v['emoji'], 'word': name, 'say': name},
            {'emoji': '📖', 'word': '', 'recite': recite},
            {'emoji': '💡', 'word': v['toddlerWord'], 'say': v['toddlerSay']},
        ]},
    })
save('prophets_lessons.json', p_lessons)
print(len(p_lessons), 'prophet lessons')

# ---------------- سيرة وشخصيات وأذكار من القرآن ----------------
sv = load('section_ayat.json')
s_lessons = []
for i, v in enumerate(sv['verses']):
    same = [o for o in sv['verses'] if o['category'] == v['category'] and o['id'] != v['id']]
    pool = same if len(same) >= 2 else [o for o in sv['verses'] if o['id'] != v['id']]
    pool = pool[i % len(pool):] + pool[:i % len(pool)]
    ref = 'سورة %s، آية %d' % (v['surahName'], v['ayahFrom']) if v['ayahFrom'] == v['ayahTo'] \
        else 'سورة %s، الآيات %d-%d' % (v['surahName'], v['ayahFrom'], v['ayahTo'])
    recite = [v['surahNumber'], v['ayahFrom']] if v['ayahFrom'] == v['ayahTo'] \
        else [v['surahNumber'], v['ayahFrom'], v['ayahTo']]
    s_lessons.append({
        'id': v['id'] + '_lesson', 'title': v['title'], 'emoji': v['emoji'],
        'category': v['category'], 'minAge': 3, 'maxAge': 6, 'difficulty': 1,
        'source': {'type': 'quran', 'reference': '%s — %s' % (sv['source']['name'], ref)},
        'steps': [{'emoji': '📖', 'text': v['text'], 'recite': recite},
                  {'emoji': '💡', 'text': v['kidMeaning']}],
        'questions': [
            question('عن ماذا تتحدث هذه الآية؟\n' + v['text'], v['title'], [o['title'] for o in pool], i,
                     'استمعي للآية جيدًا', v['emoji']),
            question('ماذا نتعلّم؟', v['kidMeaning'], [o['kidMeaning'] for o in pool], i + 1,
                     'تذكّري الخطوة الثانية', '💡'),
        ],
        'toddler': {'cards': [
            {'emoji': v['emoji'], 'word': v['toddlerWord'], 'say': v['toddlerSay']},
            {'emoji': '📖', 'word': '', 'recite': recite},
        ]},
    })
save('section_ayat_lessons.json', s_lessons)
print(len(s_lessons), 'section ayah lessons')
