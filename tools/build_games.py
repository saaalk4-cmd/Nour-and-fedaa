#!/usr/bin/env python3
"""يولّد assets/content/games.json: كل ألعاب «نُور وفداء» من مكان واحد.

- لكل لعبة نسختان: فداء (5) ونور (3) بطريقة لعب وصعوبة مختلفة، ولكل نسخة 3 مستويات.
- نصوص الآيات تُؤخذ حرفيًا من assets/content/quran_surahs.json (Tanzil) ولا تُكتب يدويًا،
  والتلاوة بصوت الشيخ. لا نطق آلي لآية أو حديث: ما يُقال في ألعاب الأذكار عبارات تعليمية
  أو العبارتان المعتمدتان («بسم الله»، «السلام عليكم»).
- لإضافة لعبة: أضيفي قاموسًا إلى GAMES (أنواعها: choose / order / memory / sort / count / find / scenario).

الاستعمال: python3 tools/build_games.py
"""
import json
import os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets', 'content')


def load(name):
    with open(os.path.join(ROOT, name), encoding='utf-8') as f:
        return json.load(f)


SURAHS = {s['surahNumber']: s for s in load('quran_surahs.json')['surahs']}


def ayah(s, a):
    return SURAHS[s]['ayahs'][a - 1]['text']


def it(id_, emoji, label, **kw):
    d = {'id': id_, 'emoji': emoji, 'label': label}
    d.update({k: v for k, v in kw.items() if v is not None})
    return d


def lv(key, title, rounds, sub=None, **params):
    d = {'key': key, 'title': title, 'rounds': rounds}
    if sub:
        d['sub'] = sub
    d.update(params)
    return d


EASY, MID, ADV = 'سهل', 'متوسط', 'متقدم'
L1, L2, L3 = 'مستوى 1', 'مستوى 2', 'مستوى 3'

# ---------------- القرآن ----------------
# رمز يساعد الصغيرة على تذكّر السورة (من معنى السورة، بلا أي تجسيد).
SURAH_PICS = {1: '📖', 112: '☝️', 108: '🏞️', 113: '🌅', 114: '👨‍👩‍👧', 103: '⏳', 110: '🏆', 106: '🕋'}
FIRST = {1: 2}  # الفاتحة: الآية الثانية (الأولى البسملة)
surah_items = [
    it(str(n), SURAH_PICS[n], SURAHS[n]['name'], recite=[n, FIRST.get(n, 1)])
    for n in [1, 112, 108, 113, 114, 103, 110, 106]
]

quran_listen = {
    'id': 'quran_listen', 'section': 'quran', 'type': 'choose', 'respectful': True,
    'title': 'اسمعي واختاري', 'emoji': '🎧',
    'intro': 'الشيخ يقرأ أول السورة، وأنتِ تعرفين اسمها',
    'goal': 'تمييز السور القصيرة بالاستماع إلى تلاوتها.',
    'items': surah_items,
    'fedaa': {'show': 'emoji+label', 'prompt': 'اسمعي… أي سورة هذه؟', 'after': 'هذه سورة {label}', 'levels': [
        lv('easy', EASY, 5, 'سورتان في كل سؤال', pool=['1', '112', '108'], options=2),
        lv('mid', MID, 5, '3 اختيارات', pool=['1', '112', '108', '113', '114'], options=3),
        lv('adv', ADV, 6, '4 اختيارات وكل السور', pool=[i['id'] for i in surah_items], options=4),
    ]},
    'nour': {'show': 'emoji', 'prompt': 'اسمعي… أين صورتها؟', 'after': 'سورة {label}', 'levels': [
        lv('l1', L1, 4, 'صورتان', pool=['1', '112', '108'], options=2),
        lv('l2', L2, 5, 'صورتان وسور أكثر', pool=['1', '112', '108', '113', '114'], options=2),
        lv('l3', L3, 5, '3 صور', pool=['1', '112', '108', '113', '114', '103'], options=3),
    ]},
}


def surah_steps(n, upto=None):
    s = SURAHS[n]
    ayahs = s['ayahs'][:upto] if upto else s['ayahs']
    return [it('%d_%d' % (n, a['number']), '📖', a['text'], recite=[n, a['number']]) for a in ayahs]


# ترتيب آيات سورة قصيرة كاملة (احترام: الآية كاملة، لا تقطيع ولا رمي، والشيخ يقرأ كل آية).
order_items = surah_steps(112) + surah_steps(108) + surah_steps(103)
quran_order = {
    'id': 'quran_order', 'section': 'quran', 'type': 'order', 'respectful': True, 'minAge': 5,
    'title': 'رتّبي آيات السورة', 'emoji': '🧩',
    'intro': 'اسمعي كل آية، ثم ضعيها في مكانها بالترتيب',
    'goal': 'حفظ ترتيب آيات السور القصيرة بالاستماع والترتيب.',
    'items': order_items,
    'fedaa': {'mode': 'drag', 'levels': [
        lv('easy', EASY + ': سورة العصر', 2, 'العصر', pool=['103_%d' % i for i in range(1, 4)], prompt='رتّبي آيات سورة العصر'),
        lv('mid', MID + ': سورة الكوثر', 2, 'الكوثر', pool=['108_%d' % i for i in range(1, 4)], prompt='رتّبي آيات سورة الكوثر'),
        lv('adv', ADV + ': سورة الإخلاص', 2, 'الإخلاص', pool=['112_%d' % i for i in range(1, 5)], prompt='رتّبي آيات سورة الإخلاص'),
    ]},
}

# ---------------- الوضوء والصلاة ----------------
wudu = [
    it('w1', '🤲', 'نقول بسم الله'),
    it('w2', '👐', 'نغسل الكفين'),
    it('w3', '👄', 'نتمضمض'),
    it('w4', '👃', 'نستنشق الماء'),
    it('w5', '😊', 'نغسل الوجه'),
    it('w6', '💪', 'نغسل اليدين إلى المرفقين'),
    it('w7', '💆', 'نمسح الرأس'),
    it('w8', '👂', 'نمسح الأذنين'),
    it('w9', '🦶', 'نغسل الرجلين'),
]
wudu_game = {
    'id': 'wudu_order', 'section': 'prayer', 'type': 'order', 'respectful': True,
    'title': 'خطوات الوضوء', 'emoji': '💧',
    'intro': 'نتوضأ قبل الصلاة. رتّبي خطوات الوضوء',
    'goal': 'معرفة ترتيب الوضوء بطريقة مبسطة.',
    'items': wudu,
    'fedaa': {'mode': 'drag', 'prompt': 'رتّبي خطوات الوضوء', 'levels': [
        lv('easy', EASY, 2, 'أول 4 خطوات', count=4),
        lv('mid', MID, 2, '6 خطوات', count=6),
        lv('adv', ADV, 2, 'الوضوء كاملًا', count=9),
    ]},
    'nour': {'mode': 'tap', 'prompt': 'اضغطي على الخطوة الأولى', 'levels': [
        lv('l1', L1, 3, 'خطوتان', count=2),
        lv('l2', L2, 3, '3 خطوات', count=3),
        lv('l3', L3, 3, '4 خطوات', count=4),
    ]},
}

salah = [
    it('s1', '🧍', 'نقف ونقول الله أكبر'),
    it('s2', '📖', 'نقرأ الفاتحة'),
    it('s3', '🙇', 'نركع'),
    it('s4', '🧍‍♀️', 'نقوم من الركوع'),
    it('s5', '🧎', 'نسجد'),
    it('s6', '🪑', 'نجلس'),
    it('s7', '🧎‍♀️', 'نسجد مرة ثانية'),
    it('s8', '👋', 'نسلّم في آخر الصلاة'),
]
salah_game = {
    'id': 'salah_order', 'section': 'prayer', 'type': 'order', 'respectful': True,
    'title': 'نتعلم الصلاة', 'emoji': '🕌',
    'intro': 'رتّبي حركات الصلاة بالترتيب',
    'goal': 'التعرف المبسّط على ترتيب بعض أفعال الصلاة.',
    'items': salah,
    'fedaa': {'mode': 'drag', 'prompt': 'رتّبي حركات الصلاة', 'levels': [
        lv('easy', EASY, 2, '4 حركات', pool=['s1', 's3', 's5', 's8']),
        lv('mid', MID, 2, '6 حركات', pool=['s1', 's2', 's3', 's4', 's5', 's8']),
        lv('adv', ADV, 2, 'ركعة كاملة', count=8),
    ]},
    'nour': {'mode': 'tap', 'prompt': 'اضغطي على الحركة الأولى', 'levels': [
        lv('l1', L1, 3, 'حركتان', pool=['s1', 's3']),
        lv('l2', L2, 3, '3 حركات', pool=['s1', 's3', 's5']),
        lv('l3', L3, 3, '4 حركات', pool=['s1', 's3', 's5', 's8']),
    ]},
}

# ---------------- الأذكار (متى نقول؟) ----------------
def sc(emoji, say, options, answer=0, text=None):
    d = {'emoji': emoji, 'say': say, 'options': [{'emoji': e, 'label': l} for e, l in options], 'answer': answer}
    if text:
        d['text'] = text
    return d


adhkar_game = {
    'id': 'adhkar_when', 'section': 'adhkar', 'type': 'scenario', 'respectful': True,
    'title': 'متى نذكر الله؟', 'emoji': '🤲',
    'intro': 'لكل وقت ذكر جميل. اختاري ما نقوله',
    'goal': 'ربط الأذكار اليومية بأوقاتها.',
    'scenarios': [
        sc('🍽️', 'ماذا نقول قبل الأكل؟', [('🤲', 'بسم الله'), ('😴', 'تصبحين على خير'), ('🎈', 'هيا نلعب')]),
        sc('👧', 'قابلتِ صديقتك. ماذا نقول؟', [('👋', 'السلام عليكم'), ('🤐', 'لا شيء'), ('🙈', 'نختبئ')]),
        sc('🥛', 'انتهينا من الأكل. ماذا نفعل؟', [('🤲', 'نحمد الله'), ('😠', 'نتذمر'), ('🙈', 'لا شيء')]),
        sc('🌙', 'جاء وقت النوم. ماذا نفعل؟', [('🤲', 'نذكر الله قبل النوم'), ('📺', 'نشاهد التلفاز'), ('🍬', 'نأكل حلوى')]),
        sc('🚪', 'سندخل الحمّام. ماذا نفعل؟', [('🤲', 'ندعو دعاء دخول الحمّام'), ('🎵', 'نغني'), ('🏃', 'نجري')]),
        sc('🧼', 'خرجنا من الحمّام. ماذا نفعل؟', [('🤲', 'نستغفر الله'), ('😝', 'نضحك بصوت عالٍ'), ('🙈', 'لا شيء')]),
        sc('🌧️', 'نزل المطر. ماذا نفعل؟', [('🤲', 'ندعو الله'), ('😠', 'نغضب'), ('🙈', 'لا شيء')]),
        sc('🏠', 'دخلنا البيت. ماذا نقول؟', [('🤲', 'بسم الله'), ('📢', 'نصرخ'), ('🤐', 'لا شيء')]),
        sc('🕌', 'دخلنا المسجد. ماذا نفعل؟', [('🤲', 'ندعو بدعاء دخول المسجد'), ('🏃', 'نجري ونلعب'), ('📢', 'نتكلم بصوت عالٍ')]),
    ],
    'fedaa': {'levels': [
        lv('easy', EASY, 4, 'اختياران', options=2),
        lv('mid', MID, 5, '3 اختيارات', options=3),
        lv('adv', ADV, 7, 'كل الأوقات', options=3),
    ]},
    'nour': {'levels': [
        lv('l1', L1, 3, 'صورتان', options=2),
        lv('l2', L2, 4, 'صورتان', options=2),
        lv('l3', L3, 5, 'صورتان', options=2),
    ]},
}

# ---------------- الآداب ----------------
adab_game = {
    'id': 'adab_day', 'section': 'akhlaq', 'type': 'scenario',
    'title': 'يومي الجميل', 'emoji': '🌞',
    'intro': 'في كل موقف، اختاري التصرف الجميل',
    'goal': 'آداب يومية: السلام، بر الوالدين، النظافة، الطعام، الاستئذان، الصدق، مساعدة الآخرين.',
    'scenarios': [
        sc('👩', 'ماما تناديكِ. ماذا نفعل؟', [('🏃‍♀️', 'نذهب إليها فورًا'), ('🙉', 'نتجاهلها'), ('😠', 'نغضب')]),
        sc('🍽️', 'بأي يد نأكل؟', [('🫱', 'باليد اليمنى'), ('🫲', 'باليد اليسرى'), ('🦶', 'بالرجل')]),
        sc('🧼', 'رجعنا من اللعب. ماذا نفعل قبل الأكل؟', [('🧼', 'نغسل أيدينا'), ('🍫', 'نأكل فورًا'), ('🪨', 'نلعب بالطين')]),
        sc('🚪', 'نريد دخول غرفة بابا. ماذا نفعل؟', [('✊', 'نطرق الباب ونستأذن'), ('💥', 'ندخل بقوة'), ('📢', 'نصرخ')]),
        sc('🍼', 'كسرتِ الكوب بالخطأ. ماذا نقول لماما؟', [('💎', 'نقول الحقيقة'), ('🙈', 'نخفي الكوب'), ('🫵', 'نلوم أخانا')]),
        sc('👵', 'جدتي تحمل أكياسًا ثقيلة. ماذا نفعل؟', [('🤝', 'نساعدها'), ('🙈', 'نتركها'), ('😝', 'نضحك')]),
        sc('🧸', 'صديقتك تريد اللعب معك. ماذا نفعل؟', [('🤝', 'نشاركها اللعب'), ('😤', 'نأخذ اللعبة'), ('🙅', 'نرفض')]),
        sc('🎁', 'أعطتكِ خالتكِ هدية. ماذا نقول؟', [('😊', 'شكرًا جزيلًا'), ('🤐', 'لا شيء'), ('😒', 'لا أريدها')]),
        sc('🗑️', 'معكِ ورقة حلوى. أين نضعها؟', [('🗑️', 'في سلة المهملات'), ('🌳', 'على الأرض'), ('🛋️', 'تحت الكنبة')]),
        sc('🧹', 'انتهينا من اللعب. ماذا نفعل بالألعاب؟', [('🧺', 'نرتبها في مكانها'), ('🧸', 'نتركها على الأرض'), ('🦶', 'نرميها')]),
        sc('😢', 'صديقتك حزينة. ماذا نقول لها؟', [('💬', 'كلمة طيبة'), ('😝', 'نضحك عليها'), ('🙈', 'لا شيء')]),
        sc('🕌', 'نحن في المسجد. كيف نتكلم؟', [('🤫', 'بصوت هادئ'), ('📢', 'بصوت عالٍ'), ('🏃', 'نجري ونصرخ')]),
    ],
    'fedaa': {'levels': [
        lv('easy', EASY, 5, 'اختياران', options=2),
        lv('mid', MID, 6, '3 اختيارات', options=3),
        lv('adv', ADV, 8, 'مواقف أكثر', options=3),
    ]},
    'nour': {'levels': [
        lv('l1', L1, 3, 'صورتان', options=2),
        lv('l2', L2, 4, 'صورتان', options=2),
        lv('l3', L3, 5, 'صورتان', options=2),
    ]},
}

good_bad = {
    'id': 'adab_sort', 'section': 'akhlaq', 'type': 'sort',
    'title': 'تصرف جميل', 'emoji': '💖',
    'intro': 'ضعي التصرف الجميل في سلة القلب، والتصرف الذي نتركه في السلة الأخرى',
    'goal': 'التمييز بين التصرفات الجميلة والتي نتجنبها.',
    'groups': [
        {'id': 'good', 'emoji': '💖', 'label': 'تصرف جميل', 'color': '#7ED36B'},
        {'id': 'leave', 'emoji': '🙅', 'label': 'نتركه', 'color': '#F4B942'},
    ],
    'items': [
        it('g1', '🤝', 'نساعد غيرنا', group='good'),
        it('g2', '😊', 'نبتسم', group='good'),
        it('g3', '🧹', 'نرتب غرفتنا', group='good'),
        it('g4', '🧼', 'نغسل أيدينا', group='good'),
        it('g5', '👋', 'نلقي السلام', group='good'),
        it('g6', '🎁', 'نشارك ألعابنا', group='good'),
        it('b1', '😠', 'نصرخ', group='leave'),
        it('b2', '🥊', 'نضرب غيرنا', group='leave'),
        it('b3', '🗑️', 'نرمي الورق على الأرض', group='leave'),
        it('b4', '😤', 'نأخذ ألعاب غيرنا', group='leave'),
        it('b5', '🙉', 'لا نسمع كلام ماما', group='leave'),
    ],
    'fedaa': {'mode': 'drag', 'levels': [
        lv('easy', EASY, 2, '4 بطاقات', perRound=4),
        lv('mid', MID, 2, '6 بطاقات', perRound=6),
        lv('adv', ADV, 3, '8 بطاقات', perRound=8),
    ]},
    'nour': {'mode': 'tap', 'levels': [
        lv('l1', L1, 2, '3 بطاقات', perRound=3),
        lv('l2', L2, 2, '4 بطاقات', perRound=4),
        lv('l3', L3, 3, '5 بطاقات', perRound=5),
    ]},
}

# ---------------- الحروف والكلمات ----------------
LETTERS = [
    ('أ', 'أرنب', '🐰'), ('ب', 'بطة', '🦆'), ('ت', 'تفاحة', '🍎'), ('ث', 'ثعلب', '🦊'),
    ('ج', 'جمل', '🐪'), ('ح', 'حصان', '🐴'), ('خ', 'خروف', '🐑'), ('د', 'دب', '🐻'),
    ('ذ', 'ذرة', '🌽'), ('ر', 'رمان', '🍎'), ('ز', 'زرافة', '🦒'), ('س', 'سمكة', '🐟'),
    ('ش', 'شمس', '☀️'), ('ص', 'صقر', '🦅'), ('ض', 'ضفدع', '🐸'), ('ط', 'طائرة', '✈️'),
    ('ظ', 'ظرف', '✉️'), ('ع', 'عصفور', '🐦'), ('غ', 'غزال', '🦌'), ('ف', 'فيل', '🐘'),
    ('ق', 'قمر', '🌙'), ('ك', 'كتاب', '📚'), ('ل', 'ليمون', '🍋'), ('م', 'موز', '🍌'),
    ('ن', 'نحلة', '🐝'), ('هـ', 'هدية', '🎁'), ('و', 'وردة', '🌹'), ('ي', 'يد', '✋'),
]
# الرمان والتفاحة لهما نفس الرمز تقريبًا: نستبدل الرمان.
LETTERS = [l if l[1] != 'رمان' else ('ر', 'رسالة', '📩') for l in LETTERS]
letter_items = [it('L%d' % i, e, w, letter=l, say='%s … %s' % (l if l != 'هـ' else 'هاء', w)) for i, (l, w, e) in enumerate(LETTERS)]
first7 = [i['id'] for i in letter_items[:7]]
first14 = [i['id'] for i in letter_items[:14]]

letters_game = {
    'id': 'letters_house', 'section': 'letters', 'type': 'choose',
    'title': 'بيت الحروف', 'emoji': '🔤',
    'intro': 'كل حرف له صورة. هيا نتعرف عليها',
    'goal': 'ربط الحرف بصوته وبكلمة تبدأ به.',
    'items': letter_items,
    'fedaa': {'show': 'letter', 'promptShow': 'emoji', 'prompt': 'بأي حرف تبدأ كلمة {label}؟', 'after': '{label} تبدأ بحرف {letter}',
              'levels': [
                  lv('easy', EASY, 5, 'أول 7 حروف', pool=first7, options=3),
                  lv('mid', MID, 6, '14 حرفًا', pool=first14, options=3),
                  lv('adv', ADV, 8, 'كل الحروف', options=4),
              ]},
    'nour': {'show': 'emoji', 'prompt': 'اسمعي: {say}. أين صورتها؟', 'after': '{label}',
             'levels': [
                 lv('l1', L1, 4, 'صورتان', pool=first7[:4], options=2),
                 lv('l2', L2, 5, 'صورتان', pool=first7, options=2),
                 lv('l3', L3, 5, '3 صور', pool=first14, options=3),
             ]},
}

word_items = [
    it('m1', '🐰', 'أرنب'), it('m2', '🦆', 'بطة'), it('m3', '🍎', 'تفاحة'), it('m4', '🐪', 'جمل'),
    it('m5', '☀️', 'شمس'), it('m6', '🌙', 'قمر'), it('m7', '🐟', 'سمكة'), it('m8', '🌹', 'وردة'),
    it('m9', '🐘', 'فيل'), it('m10', '🍌', 'موز'), it('m11', '📚', 'كتاب'), it('m12', '🐝', 'نحلة'),
]
memory_words = {
    'id': 'memory_words', 'section': 'letters', 'type': 'memory',
    'title': 'كروت الكلمات', 'emoji': '🃏',
    'intro': 'اقلبي الكروت وابحثي عن الأزواج',
    'goal': 'الذاكرة، وقراءة كلمات بسيطة مع صورها (فداء).',
    'items': word_items,
    'fedaa': {'mode': 'words', 'levels': [
        lv('easy', EASY, 2, '4 أزواج: صورة وكلمة', pairs=4),
        lv('mid', MID, 2, '5 أزواج', pairs=5),
        lv('adv', ADV, 2, '6 أزواج', pairs=6),
    ]},
    'nour': {'mode': 'same', 'levels': [
        lv('l1', L1, 2, 'زوجان', pairs=2),
        lv('l2', L2, 2, '3 أزواج', pairs=3),
        lv('l3', L3, 2, '4 أزواج', pairs=4),
    ]},
}

islamic_words = {
    'id': 'islamic_words', 'section': 'letters', 'type': 'choose',
    'title': 'كلمات من ديني', 'emoji': '🕌',
    'intro': 'كلمات نحبها في ديننا، مع صورها',
    'goal': 'معاني كلمات إسلامية بسيطة بطريقة بصرية.',
    'items': [
        it('i1', '🕌', 'المسجد'), it('i2', '📖', 'المصحف'), it('i3', '🕋', 'الكعبة'),
        it('i4', '🌙', 'الهلال'), it('i5', '💧', 'الوضوء'), it('i6', '📿', 'المسبحة'),
        it('i7', '🤲', 'الدعاء'), it('i8', '🧎', 'السجود'),
    ],
    'fedaa': {'show': 'label', 'promptShow': 'emoji', 'prompt': 'ما اسم هذه الصورة؟', 'after': '{label}', 'levels': [
        lv('easy', EASY, 5, '3 كلمات', pool=['i1', 'i2', 'i3', 'i4'], options=3),
        lv('mid', MID, 6, 'كلمات أكثر', pool=['i1', 'i2', 'i3', 'i4', 'i5', 'i6'], options=3),
        lv('adv', ADV, 7, 'كل الكلمات', options=4),
    ]},
    'nour': {'show': 'emoji', 'prompt': 'أين {label}؟', 'after': '{label}', 'levels': [
        lv('l1', L1, 4, 'صورتان', pool=['i1', 'i2', 'i3'], options=2),
        lv('l2', L2, 5, 'صورتان', pool=['i1', 'i2', 'i3', 'i4', 'i5'], options=2),
        lv('l3', L3, 5, '3 صور', options=3),
    ]},
}

# ---------------- الأرقام ----------------
count_items = [
    it('c1', '⭐', 'نجمة', extra={'plural': 'نجوم'}),
    it('c2', '🍎', 'تفاحة', extra={'plural': 'تفاحات'}),
    it('c3', '🎈', 'بالونة', extra={'plural': 'بالونات'}),
    it('c4', '🐟', 'سمكة', extra={'plural': 'سمكات'}),
    it('c5', '🌸', 'وردة', extra={'plural': 'ورود'}),
    it('c6', '🦋', 'فراشة', extra={'plural': 'فراشات'}),
]
numbers_game = {
    'id': 'numbers_market', 'section': 'numbers', 'type': 'count',
    'title': 'سوق الأرقام', 'emoji': '🔢',
    'intro': 'هيا نعدّ معًا',
    'goal': 'العد من 1 إلى 10 وربط الكمية بالرقم.',
    'items': count_items,
    'fedaa': {'mode': 'choose', 'levels': [
        lv('easy', EASY, 5, 'من 1 إلى 5', min=1, max=5),
        lv('mid', MID, 6, 'من 3 إلى 8', min=3, max=8),
        lv('adv', ADV, 6, 'حتى 10', min=5, max=10),
    ]},
    'nour': {'mode': 'tap', 'levels': [
        lv('l1', L1, 4, 'حتى 2', min=1, max=2, extra=1),
        lv('l2', L2, 4, 'حتى 3', min=1, max=3, extra=2),
        lv('l3', L3, 5, 'حتى 5', min=2, max=5, extra=2),
    ]},
}

# ---------------- الألوان والأشكال ----------------
colors_sort = {
    'id': 'colors_garden', 'section': 'colors', 'type': 'sort',
    'title': 'حديقة الألوان', 'emoji': '🌈',
    'intro': 'كل شيء يذهب إلى سلة لونه',
    'goal': 'التعرف على الألوان والفرز.',
    'groups': [
        {'id': 'red', 'emoji': '🔴', 'label': 'أحمر', 'color': '#F06262'},
        {'id': 'yellow', 'emoji': '🟡', 'label': 'أصفر', 'color': '#FFD54A'},
        {'id': 'green', 'emoji': '🟢', 'label': 'أخضر', 'color': '#6CCB5F'},
        {'id': 'blue', 'emoji': '🔵', 'label': 'أزرق', 'color': '#5AA9F0'},
    ],
    'items': [
        it('r1', '🍎', 'تفاحة', group='red'), it('r2', '🍓', 'فراولة', group='red'), it('r3', '🚒', 'سيارة إطفاء', group='red'),
        it('r4', '🌹', 'وردة', group='red'),
        it('y1', '🍌', 'موزة', group='yellow'), it('y2', '🌻', 'زهرة', group='yellow'), it('y3', '🍋', 'ليمونة', group='yellow'),
        it('y4', '🐥', 'كتكوت', group='yellow'),
        it('g1', '🥒', 'خيارة', group='green'), it('g2', '🐸', 'ضفدع', group='green'), it('g3', '🍀', 'ورقة شجر', group='green'),
        it('g4', '🥦', 'بروكلي', group='green'),
        it('b1', '💧', 'نقطة ماء', group='blue'), it('b2', '🫐', 'توت', group='blue'), it('b3', '🐳', 'حوت', group='blue'),
        it('b4', '🧊', 'مكعب ثلج', group='blue'),
    ],
    'fedaa': {'mode': 'drag', 'levels': [
        lv('easy', EASY, 2, 'لونان', groups=['red', 'yellow'], perRound=6),
        lv('mid', MID, 2, '3 ألوان', groups=['red', 'yellow', 'green'], perRound=7),
        lv('adv', ADV, 2, '4 ألوان', groups=['red', 'yellow', 'green', 'blue'], perRound=8),
    ]},
    'nour': {'mode': 'tap', 'levels': [
        lv('l1', L1, 2, 'لونان', groups=['red', 'yellow'], perRound=3),
        lv('l2', L2, 2, 'لونان', groups=['green', 'blue'], perRound=4),
        lv('l3', L3, 3, 'لونان', groups=['red', 'green'], perRound=5),
    ]},
}

shapes_sort = {
    'id': 'shapes_box', 'section': 'colors', 'type': 'sort',
    'title': 'صندوق الأشكال', 'emoji': '🔷',
    'intro': 'دائرة، مربع، أم مثلث؟',
    'goal': 'التعرف على الأشكال في الأشياء من حولنا.',
    'groups': [
        {'id': 'circle', 'emoji': '⚪', 'label': 'دائرة', 'color': '#5AA9F0'},
        {'id': 'square', 'emoji': '🟧', 'label': 'مربع', 'color': '#F2A93B'},
        {'id': 'triangle', 'emoji': '🔺', 'label': 'مثلث', 'color': '#E76F8B'},
    ],
    'items': [
        it('c1', '⚽', 'كرة', group='circle'), it('c2', '🍩', 'كعكة', group='circle'), it('c3', '🕐', 'ساعة', group='circle'),
        it('c4', '🌕', 'بدر', group='circle'), it('c5', '🍪', 'بسكويتة', group='circle'),
        it('s1', '🎁', 'هدية', group='square'), it('s2', '📦', 'صندوق', group='square'), it('s3', '🧇', 'وافل', group='square'),
        it('s4', '🖼️', 'لوحة', group='square'),
        it('t1', '🍕', 'قطعة بيتزا', group='triangle'), it('t2', '⛺', 'خيمة', group='triangle'), it('t3', '🔺', 'مثلث أحمر', group='triangle'),
        it('t4', '🧀', 'قطعة جبن', group='triangle'),
    ],
    'fedaa': {'mode': 'drag', 'levels': [
        lv('easy', EASY, 2, 'شكلان', groups=['circle', 'square'], perRound=6),
        lv('mid', MID, 2, '3 أشكال', groups=['circle', 'square', 'triangle'], perRound=7),
        lv('adv', ADV, 2, '3 أشكال وأكثر', groups=['circle', 'square', 'triangle'], perRound=9),
    ]},
    'nour': {'mode': 'tap', 'levels': [
        lv('l1', L1, 2, 'شكلان', groups=['circle', 'square'], perRound=3),
        lv('l2', L2, 2, 'شكلان', groups=['circle', 'triangle'], perRound=4),
        lv('l3', L3, 3, 'شكلان', groups=['square', 'triangle'], perRound=4),
    ]},
}

color_names = {
    'id': 'color_names', 'section': 'colors', 'type': 'choose',
    'title': 'اختاري اللون', 'emoji': '🎨',
    'intro': 'هيا نعرف أسماء الألوان',
    'goal': 'أسماء الألوان (نور: الصورة، فداء: الكلمة).',
    'items': [
        it('red', '🔴', 'أحمر'), it('yellow', '🟡', 'أصفر'), it('green', '🟢', 'أخضر'), it('blue', '🔵', 'أزرق'),
        it('orange', '🟠', 'برتقالي'), it('purple', '🟣', 'بنفسجي'), it('brown', '🟤', 'بني'), it('black', '⚫', 'أسود'),
    ],
    'fedaa': {'show': 'label', 'promptShow': 'emoji', 'prompt': 'ما اسم هذا اللون؟', 'after': '{label}', 'levels': [
        lv('easy', EASY, 5, '4 ألوان', pool=['red', 'yellow', 'green', 'blue'], options=3),
        lv('mid', MID, 6, '6 ألوان', pool=['red', 'yellow', 'green', 'blue', 'orange', 'purple'], options=3),
        lv('adv', ADV, 7, 'كل الألوان', options=4),
    ]},
    'nour': {'show': 'emoji', 'prompt': 'أين اللون {label}؟', 'after': '{label}', 'levels': [
        lv('l1', L1, 4, 'لونان', pool=['red', 'yellow', 'blue'], options=2),
        lv('l2', L2, 5, 'لونان', pool=['red', 'yellow', 'green', 'blue'], options=2),
        lv('l3', L3, 5, '3 ألوان', pool=['red', 'yellow', 'green', 'blue', 'orange'], options=3),
    ]},
}

# ---------------- الذاكرة والملاحظة ----------------
SCENE = ['🌳', '🌷', '🍄', '🪨', '🌿', '🐞', '🌼', '🍂', '🌵', '🐌', '🌲', '🦔']
find_game = {
    'id': 'find_hidden', 'section': 'focus', 'type': 'find',
    'title': 'فين المستخبي؟', 'emoji': '🔍',
    'intro': 'انظري جيدًا وابحثي في الحديقة',
    'goal': 'الملاحظة والتركيز.',
    'items': [
        it('star', '⭐', 'النجمة'), it('moon', '🌙', 'القمر'), it('sun', '☀️', 'الشمس'),
        it('bunny', '🐰', 'الأرنب'), it('bird', '🐦', 'العصفور'), it('fish', '🐟', 'السمكة'),
    ],
    'fedaa': {'levels': [
        lv('easy', EASY, 4, 'شيئان بين 12', cells=12, targets=2, distractors=SCENE),
        lv('mid', MID, 4, '3 أشياء بين 16', cells=16, targets=3, distractors=SCENE),
        lv('adv', ADV, 5, '3 أشياء بين 20', cells=20, targets=3, distractors=SCENE),
    ]},
    'nour': {'levels': [
        lv('l1', L1, 4, 'بين 4', cells=4, targets=1, distractors=SCENE[:4]),
        lv('l2', L2, 4, 'بين 6', cells=6, targets=1, distractors=SCENE[:6]),
        lv('l3', L3, 5, 'بين 9', cells=9, targets=1, distractors=SCENE),
    ]},
}

memory_pics = {
    'id': 'memory_garden', 'section': 'focus', 'type': 'memory',
    'title': 'كروت الحديقة', 'emoji': '🧠',
    'intro': 'تذكّري مكان كل صورة',
    'goal': 'الذاكرة البصرية والتركيز.',
    'items': [
        it('a', '🦋', 'فراشة'), it('b', '🐞', 'دعسوقة'), it('c', '🌻', 'زهرة'), it('d', '🍓', 'فراولة'),
        it('e', '🐢', 'سلحفاة'), it('f', '🐳', 'حوت'), it('g', '🦁', 'أسد'), it('h', '🐧', 'بطريق'),
    ],
    'fedaa': {'mode': 'same', 'levels': [
        lv('easy', EASY, 2, '4 أزواج', pairs=4),
        lv('mid', MID, 2, '6 أزواج', pairs=6),
        lv('adv', ADV, 2, '8 أزواج', pairs=8),
    ]},
    'nour': {'mode': 'same', 'levels': [
        lv('l1', L1, 2, 'زوجان', pairs=2),
        lv('l2', L2, 2, '3 أزواج', pairs=3),
        lv('l3', L3, 2, '4 أزواج', pairs=4),
    ]},
}

animals = {
    'id': 'animal_homes', 'section': 'focus', 'type': 'sort',
    'title': 'بيوت الحيوانات', 'emoji': '🏡',
    'intro': 'من يعيش في البحر، ومن يعيش على الأرض، ومن يطير في السماء؟',
    'goal': 'التصنيف والتفكير.',
    'groups': [
        {'id': 'sea', 'emoji': '🌊', 'label': 'البحر', 'color': '#5AA9F0'},
        {'id': 'land', 'emoji': '🌳', 'label': 'الأرض', 'color': '#6CCB5F'},
        {'id': 'sky', 'emoji': '☁️', 'label': 'السماء', 'color': '#B98CFF'},
    ],
    'items': [
        it('s1', '🐟', 'سمكة', group='sea'), it('s2', '🐙', 'أخطبوط', group='sea'), it('s3', '🐬', 'دلفين', group='sea'),
        it('s4', '🦀', 'سلطعون', group='sea'),
        it('l1', '🐄', 'بقرة', group='land'), it('l2', '🐪', 'جمل', group='land'), it('l3', '🐘', 'فيل', group='land'),
        it('l4', '🐇', 'أرنب', group='land'),
        it('k1', '🐦', 'عصفور', group='sky'), it('k2', '🦅', 'نسر', group='sky'), it('k3', '🦋', 'فراشة', group='sky'),
        it('k4', '🦉', 'بومة', group='sky'),
    ],
    'fedaa': {'mode': 'drag', 'levels': [
        lv('easy', EASY, 2, 'مكانان', groups=['sea', 'land'], perRound=6),
        lv('mid', MID, 2, '3 أماكن', groups=['sea', 'land', 'sky'], perRound=7),
        lv('adv', ADV, 2, '3 أماكن وأكثر', groups=['sea', 'land', 'sky'], perRound=10),
    ]},
    'nour': {'mode': 'tap', 'levels': [
        lv('l1', L1, 2, 'مكانان', groups=['sea', 'land'], perRound=3),
        lv('l2', L2, 2, 'مكانان', groups=['land', 'sky'], perRound=4),
        lv('l3', L3, 3, 'مكانان', groups=['sea', 'sky'], perRound=4),
    ]},
}

GAMES = [
    quran_listen, quran_order, wudu_game, salah_game, adhkar_game, adab_game, good_bad,
    letters_game, memory_words, islamic_words, numbers_game, colors_sort, shapes_sort, color_names,
    find_game, memory_pics, animals,
]


def main():
    ids = [g['id'] for g in GAMES]
    assert len(ids) == len(set(ids))
    out = os.path.join(ROOT, 'games.json')
    with open(out, 'w', encoding='utf-8') as fh:
        json.dump({'schema': 1, 'games': GAMES}, fh, ensure_ascii=False, indent=1)
        fh.write('\n')
    print(len(GAMES), 'games')


if __name__ == '__main__':
    main()
