#!/usr/bin/env python3
"""يولّد منهج سنة البراعم: ٧٠ حصة × درسان، وكتالوج مقاطع الصوت.

التشغيل من جذر المستودع: python3 tool/gen_buraem_year.py
- الدروس: assets/content/lessons/by_sNNN_q.json (القرآن) و by_sNNN_t.json (محور اليوم)
- الحصص: assets/content/sessions/buraem.json
- كتالوج الصوت: tool/buraem_year_clips.json و docs/audio/buraem-year-scripts.md
الصوت يُربط بالخطوة فقط إن وُجد ملفه، فيُعاد التشغيل بعد توليد مقاطع جديدة.
"""
import json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LESSONS = os.path.join(ROOT, 'assets/content/lessons')
AUDIO_DIR = 'assets/audio/by'
LIC = ("مولَّد بـ ElevenLabs (صوت «Abu Hassan»، الخطة المجانية) — نسخة تجريبية للاختبار فقط؛ "
       "الخطة المجانية لا تسمح بالاستخدام التجاري، فيُستبدل بتسجيل مرخّص قبل النشر.")
REVIEWED = "مبني على نصوص البراعم التي روجعت شرعيًا (٢٨ نوفمبر ٢٠٢٦)؛ أسئلة اللعبة وجمل الربط جديدة وتحتاج مراجعة."

clips = {}  # key -> (path, text)

def clip(key, text, path=None):
    clips[key] = (path or f'{AUDIO_DIR}/{key}.mp3', text)
    return key

def audio_of(key):
    path = clips[key][0]
    return path if os.path.exists(os.path.join(ROOT, path)) else None

# ---------- الحروف ----------
# (الحرف، الصوت، الكلمة مشكولة، الإيموجي، مقطع موجود إن وُجد)
LETTERS = {
 'م': ('مَ', 'مَوْزٌ', '🍌', 'assets/audio/t_letters_01.mp3'),
 'ب': ('بَ', 'بَطَّةٌ', '🦆', 'assets/audio/t_letters_02.mp3'),
 'د': ('دَ', 'دُبٌّ', '🐻', 'assets/audio/t_letters_03.mp3'),
 'ت': ('تَ', 'تُفَّاحٌ', '🍎', 'assets/audio/t_letters_04.mp3'),
 'ن': ('نَ', 'نَحْلَةٌ', '🐝', 'assets/audio/t_letters_05.mp3'),
 'ف': ('فَ', 'فَرَاشَةٌ', '🦋', 'assets/audio/t_letters_06.mp3'),
 'س': ('سَ', 'سَمَكَةٌ', '🐟', 'assets/audio/t_letters_07.mp3'),
 'ل': ('لَ', 'لَيْمُونٌ', '🍋', 'assets/audio/t_letters_08.mp3'),
 'ر': ('رَ', 'رِيشَةٌ', '🪶', None), 'ك': ('كَ', 'كُرَةٌ', '⚽', None),
 'هـ': ('هَ', 'هَدِيَّةٌ', '🎁', None), 'و': ('وَ', 'وَرْدَةٌ', '🌹', None),
 'ي': ('يَ', 'يَدٌ', '✋', None), 'ج': ('جَ', 'جَمَلٌ', '🐪', None),
 'ش': ('شَ', 'شَمْسٌ', '☀️', None), 'ز': ('زَ', 'زَرَافَةٌ', '🦒', None),
 'أ': ('أَ', 'أَرْنَبٌ', '🐇', None), 'ح': ('حَ', 'حِصَانٌ', '🐎', None),
 'خ': ('خَ', 'خَرُوفٌ', '🐑', None), 'ذ': ('ذَ', 'ذُرَةٌ', '🌽', None),
 'ص': ('صَ', 'صَارُوخٌ', '🚀', None), 'ض': ('ضَ', 'ضِفْدَعٌ', '🐸', None),
 'ط': ('طَ', 'طَائِرَةٌ', '✈️', None), 'ظ': ('ظَ', 'ظَرْفٌ', '✉️', None),
 'ع': ('عَ', 'عِنَبٌ', '🍇', None), 'غ': ('غَ', 'غَيْمَةٌ', '☁️', None),
 'ق': ('قَ', 'قَمَرٌ', '🌙', None), 'ث': ('ثَ', 'ثَعْلَبٌ', '🦊', None),
}
LETTER_KEYS = list(LETTERS)
for i, (l, (snd, word, emo, existing)) in enumerate(LETTERS.items()):
    clip(f'letter_{i:02d}', f'{word}... {snd}، {snd}، {snd}. {word}!', existing)
    clip(f'letterq_{i:02d}', f'أَيُّ صُورَةٍ تَبْدَأُ بِصَوْتِ {snd}؟ {snd}، {snd}.')

def letter_question(l, salt):
    i = LETTER_KEYS.index(l)
    emo = LETTERS[l][2]
    # مشتّتان من حروف بعيدة في الترتيب، ثابتان لكل (حرف، ملح).
    d1 = LETTERS[LETTER_KEYS[(i + 9 + salt) % 28]][2]
    d2 = LETTERS[LETTER_KEYS[(i + 17 + 2 * salt) % 28]][2]
    opts = [d1, d2]
    pos = (i + salt) % 3
    opts.insert(pos, emo)
    step = {'type': 'choose', 'question': f'أيّ صورة تبدأ بصوت {LETTERS[l][0]}؟',
            'options': opts, 'answer': pos}
    a = audio_of(f'letterq_{i:02d}')
    if a: step['audio'] = a
    return step

# ---------- المحاور ----------
UP, DOWN = '👍', '👎'
# key: (عنوان، أيقونة، مقطع السماع (مفتاح كتالوج)، نوع المصدر، ملاحظة، أسئلة [(نص مشكول، خيارات، إجابة)])
TOPICS = {}
def topic(key, title, icon, listen_key, source, note, qs):
    TOPICS[key] = dict(title=title, icon=icon, listen=listen_key, source=source, note=note, qs=[])
    for j, (text, opts, ans) in enumerate(qs):
        k = clip(f'q_{key}_{j}', text)
        TOPICS[key]['qs'].append((k, text, opts, ans))

def ex(key, path, text):  # مقطع موجود
    return clip(key, text, path)

ex('greet', 'assets/audio/t_adab_greet.mp3', 'السلامُ عليكم. نُسلّمُ على مَن نعرفُ ومَن لا نعرف.')
ex('thanks', 'assets/audio/t_akhlaq_thanks.mp3', 'إذا أعطاني أحدٌ شيئًا أقول: شكرًا.')
ex('khalaq', 'assets/audio/t_know_1.mp3', 'اللهُ خلقني، وخلقَ الشمسَ والقمرَ والشجر.')
ex('food', 'assets/audio/t_adab_food.mp3', 'قبلَ الأكل نقول: بسمِ الله، ونأكلُ باليمين، ومما يلينا.')
ex('after_meal', 'assets/audio/t_adab_after_meal.mp3', 'بعدَ الأكل نقول: الحمدُ لله.')
ex('share', 'assets/audio/t_akhlaq_share.mp3', 'ألعبُ مع أصحابي، ونتشاركُ الألعاب.')
ex('wahid', 'assets/audio/t_know_2.mp3', 'اللهُ واحدٌ أحد.')
ex('sleep', 'assets/audio/t_adab_sleep.mp3', 'قبلَ النوم نقول: باسمِكَ اللهمَّ أموتُ وأحيا.')
ex('tidy', 'assets/audio/t_akhlaq_tidy.mp3', 'بعدَ اللعب أرتّبُ ألعابي في مكانها.')
ex('takbir', 'assets/audio/t_salah_1.mp3', 'نرفعُ أيديَنا ونقول: اللهُ أكبر.')
ex('ruku', 'assets/audio/t_salah_2.mp3', 'نركعُ ونقول: سُبحانَ ربّيَ العظيم.')
ex('sujud', 'assets/audio/t_salah_3.mp3', 'نسجدُ ونقول: سُبحانَ ربّيَ الأعلى.')
ex('kind_word', 'assets/audio/t_akhlaq_kind_word.mp3', 'أقولُ كلامًا طيبًا: من فضلك، وشكرًا.')
ex('sneeze', 'assets/audio/t_adab_sneeze.mp3', 'إذا عطسنا نقول: الحمدُ لله. ويقولُ لنا أخونا: يرحمُكَ الله. فنقول: يهديكمُ اللهُ ويُصلحُ بالَكم.')
ex('nabi', 'assets/audio/t_know_3.mp3', 'نبيُّنا محمدٌ، صلّى اللهُ عليه وسلّم، رسولُ الله.')
clip('wake', 'إِذَا اسْتَيْقَظْنَا نَقُولُ: الحَمْدُ لِلَّهِ الَّذِي أَحْيَانَا بَعْدَ مَا أَمَاتَنَا، وَإِلَيْهِ النُّشُورُ.')
clip('salah_all', 'نُصَلِّي: نَقُولُ اللَّهُ أَكْبَرُ، ثُمَّ نَرْكَعُ، ثُمَّ نَسْجُدُ.')
clip('mercy', 'نَرْحَمُ الحَيَوَانَاتِ: نُطْعِمُهَا، وَلَا نُؤْذِيهَا.')
clip('respect', 'نَحْتَرِمُ الكَبِيرَ: نُسَلِّمُ عَلَيْهِ، وَنُسَاعِدُهُ.')

H = 'sahih_sunnah'; E = 'educational'; Q = 'quran'
topic('greet', 'إلقاء السلام', '👋', 'greet', H, 'صحيح البخاري ٦٢٣٦.', [
  ('نَقُولُ لِأَصْحَابِنَا: السَّلَامُ عَلَيْكُمْ؟', [UP, DOWN], 0),
  ('نَدْخُلُ البَيْتَ وَلَا نُسَلِّمُ؟', [UP, DOWN], 1)])
topic('thanks', 'الشكر', '🙏', 'thanks', E, 'محتوى تربوي عام.', [
  ('أَعْطَتْكَ أُمُّكَ هَدِيَّةً، تَقُولُ: شُكْرًا؟', [UP, DOWN], 0),
  ('نَأْخُذُ الهَدِيَّةَ وَلَا نَقُولُ شَيْئًا؟', [UP, DOWN], 1)])
topic('khalaq', 'الله خلقني', '🌍', 'khalaq', Q, 'مبني على سورة الزمر ٦٢ «الله خالق كل شيء».', [
  ('اللَّهُ خَلَقَ الشَّمْسَ. أَيْنَ الشَّمْسُ؟', ['🚗', '☀️', '⚽'], 1),
  ('اللَّهُ خَلَقَ الشَّجَرَ. أَيْنَ الشَّجَرَةُ؟', ['🌳', '🏠', '✏️'], 0)])
topic('food', 'قبل الأكل', '🍽️', 'food', H, 'صحيح البخاري ٥٣٧٦.', [
  ('نَأْكُلُ بِاليَدِ اليُمْنَى؟', [UP, DOWN], 0),
  ('نَأْكُلُ وَلَا نَقُولُ: بِسْمِ اللَّهِ؟', [UP, DOWN], 1)])
topic('after_meal', 'بعد الأكل', '🤲', 'after_meal', H, 'صحيح البخاري ٥٤٥٨.', [
  ('بَعْدَ الأَكْلِ نَقُولُ: الحَمْدُ لِلَّهِ؟', [UP, DOWN], 0),
  ('نَقُومُ مِنَ الأَكْلِ وَلَا نَحْمَدُ اللَّهَ؟', [UP, DOWN], 1)])
topic('share', 'مشاركة اللعب', '🧸', 'share', E, 'محتوى تربوي عام.', [
  ('نَلْعَبُ مَعَ أَصْحَابِنَا وَنَتَشَارَكُ الأَلْعَابَ؟', [UP, DOWN], 0),
  ('آخُذُ كُلَّ الأَلْعَابِ لِنَفْسِي؟', [UP, DOWN], 1)])
topic('wahid', 'الله واحد', '☝️', 'wahid', Q, 'مبني على سورة الإخلاص ١ «قل هو الله أحد».', [
  ('اللَّهُ وَاحِدٌ. المِسْ إِصْبَعًا وَاحِدًا.', ['✌️', '☝️', '🖐️'], 1)])
topic('sleep', 'قبل النوم', '😴', 'sleep', H, 'صحيح البخاري ٦٣٢٤.', [
  ('مَتَى نَقُولُ: بِاسْمِكَ اللَّهُمَّ أَمُوتُ وَأَحْيَا؟', ['🍽️', '⚽', '🛏️'], 2),
  ('قَبْلَ النَّوْمِ نَقُولُ: بِاسْمِكَ اللَّهُمَّ أَمُوتُ وَأَحْيَا؟', [UP, DOWN], 0)])
topic('wake', 'إذا استيقظنا', '🌅', 'wake', H, 'صحيح البخاري ٦٣٢٤.', [
  ('مَتَى نَقُولُ: الحَمْدُ لِلَّهِ الَّذِي أَحْيَانَا؟', ['🌅', '🍽️', '🛏️'], 0)])
topic('tidy', 'ترتيب ألعابي', '🧺', 'tidy', E, 'محتوى تربوي عام.', [
  ('بَعْدَ اللَّعِبِ نُرَتِّبُ أَلْعَابَنَا؟', [UP, DOWN], 0),
  ('نَتْرُكُ الأَلْعَابَ عَلَى الأَرْضِ؟', [UP, DOWN], 1)])
topic('takbir', 'الله أكبر', '🙌', 'takbir', H, 'صحيح البخاري ٧٨٩.', [
  ('أَيْنَ: اللَّهُ أَكْبَرُ؟', ['🙌', '🙇', '🧎'], 0)])
topic('ruku', 'الركوع', '🙇', 'ruku', H, 'صحيح مسلم ٧٧٢.', [
  ('أَيْنَ الرُّكُوعُ؟', ['🧎', '🙇', '🙌'], 1)])
topic('sujud', 'السجود', '🧎', 'sujud', H, 'صحيح مسلم ٧٧٢.', [
  ('أَيْنَ السُّجُودُ؟', ['🙌', '🙇', '🧎'], 2)])
topic('salah_all', 'نصلّي معًا', '🕌', 'salah_all', H, 'صحيح البخاري ٧٨٩ وصحيح مسلم ٧٧٢.', [])
topic('kind_word', 'الكلمة الطيبة', '💬', 'kind_word', E, 'محتوى تربوي عام.', [
  ('نَقُولُ: مِنْ فَضْلِكَ، وَشُكْرًا؟', [UP, DOWN], 0),
  ('نَصْرُخُ عَلَى أَصْحَابِنَا؟', [UP, DOWN], 1)])
topic('sneeze', 'بعد العطاس', '🤧', 'sneeze', H, 'صحيح البخاري ٦٢٢٤.', [
  ('إِذَا عَطَسْنَا نَقُولُ: الحَمْدُ لِلَّهِ؟', [UP, DOWN], 0),
  ('مَتَى نَقُولُ: يَرْحَمُكَ اللَّهُ؟', ['🛏️', '🤧', '🍽️'], 1)])
topic('mercy', 'الرحمة بالحيوان', '🐱', 'mercy', E, 'محتوى تربوي عام.', [
  ('نُطْعِمُ القِطَّةَ الجَائِعَةَ؟', [UP, DOWN], 0),
  ('نَضْرِبُ العُصْفُورَ؟', [UP, DOWN], 1)])
topic('respect', 'احترام الكبير', '🤝', 'respect', E, 'محتوى تربوي عام.', [
  ('جَدَّتِي تَحْمِلُ حَقِيبَةً ثَقِيلَةً، أُسَاعِدُهَا؟', [UP, DOWN], 0),
  ('أُقَاطِعُ جَدِّي وَهُوَ يَتَكَلَّمُ؟', [UP, DOWN], 1)])
topic('nabi', 'نبيّنا محمد ﷺ', '🌙', 'nabi', Q, 'مبني على سورة الفتح ٢٩ «محمد رسول الله».', [
  ('نُحِبُّ نَبِيَّنَا مُحَمَّدًا، صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ؟', [UP, DOWN], 0)])

def topic_questions(key):
    out = []
    for k, text, opts, ans in TOPICS[key]['qs']:
        s = {'type': 'choose', 'question': text, 'options': opts, 'answer': ans}
        a = audio_of(k)
        if a: s['audio'] = a
        out.append(s)
    return out

POSTURES = ['takbir', 'ruku', 'sujud']

def listen(key, prompt=None):
    s = {'type': 'listen'}
    if prompt: s['prompt'] = prompt
    a = audio_of(key)
    if a: s['audio'] = a
    return s

# ---------- القرآن ----------
SURAHS = [(1, 'الفاتحة', 'الفَاتِحَةِ'), (112, 'الإخلاص', 'الإِخْلَاصِ'), (113, 'الفلق', 'الفَلَقِ'),
          (114, 'الناس', 'النَّاسِ'), (108, 'الكوثر', 'الكَوْثَرِ'), (103, 'العصر', 'العَصْرِ'),
          (110, 'النصر', 'النَّصْرِ')]
for n, _, voc in SURAHS:
    clip(f'surah_listen_{n}', f'هَيَّا نَسْمَعُ سُورَةَ {voc}.')
    clip(f'surah_repeat_{n}', f'هَيَّا نُرَدِّدُ سُورَةَ {voc}.')

UNITS = [
 ('أنا وربي', ['م', 'ب', 'د', 'ت'], ['greet', 'thanks', 'khalaq', ('mix', ['greet', 'thanks', 'khalaq'])]),
 ('طعامي', ['ن', 'ف', 'س', 'ل'], ['food', 'after_meal', 'wahid', 'share']),
 ('يومي ونومي', ['ر', 'ك', 'هـ', 'و'], ['sleep', 'wake', ('mix', ['khalaq', 'wahid']), 'tidy']),
 ('صلاتي', ['ي', 'ج', 'ش', 'ز'], ['takbir', 'ruku', 'sujud', 'salah_all']),
 ('أخلاقي', ['أ', 'ح', 'خ', 'ذ'], ['kind_word', 'sneeze', ('mix', ['wahid', 'nabi']), 'mercy']),
 ('نبيي', ['ص', 'ض', 'ط', 'ظ'], ['respect', ('mix', ['greet', 'thanks']), 'nabi', ('mix', ['food', 'sleep', 'sneeze'])]),
 ('مراجعة السنة', ['ع', 'غ', 'ق', 'ث'], [('mix', ['food', 'after_meal', 'sleep', 'sneeze']),
                                       ('mix', ['khalaq', 'wahid', 'nabi']),
                                       ('mix', POSTURES),
                                       ('mix', ['thanks', 'share', 'tidy', 'kind_word'])]),
]

def lesson(id_, title, icon, source, note, steps):
    d = {'id': id_, 'title': title, 'icon': icon, 'section': 'course', 'band': 'buraem',
         'source_type': source, 'source_note': note, 'content_verified': False,
         'steps': steps + [{'type': 'reward', 'stars': 2}]}
    if any('audio' in s for s in steps):
        d['audio_license'] = LIC
    return d

def quran_lesson(sid, unit_i, k):
    n, name, _ = SURAHS[unit_i]
    full = k >= 8
    first = k == 1 or full
    steps = [listen(f'surah_listen_{n}' if first else f'surah_repeat_{n}', '📖'),
             {'type': 'surah', 'surah': n, 'repeat_each': 1 if first else 3}]
    if k == 9:
        steps.append({'type': 'surah', 'surah': n, 'repeat_each': 3})
    if k == 10 and unit_i > 0:
        pn = SURAHS[unit_i - 1][0]
        steps += [listen(f'surah_listen_{pn}', '📖'), {'type': 'surah', 'surah': pn, 'repeat_each': 1}]
    note = ('النص من مشروع تنزيل عبر AlQuran Cloud، والتلاوة للشيخ محمد أيوب (مجمع الملك فهد) أونلاين. '
            'ترخيص التلاوة مؤكَّد بقرار صاحب المشروع (٢٧ نوفمبر ٢٠٢٦). جملة التحية جديدة وتحتاج مراجعة.')
    return lesson(f'{sid}_q', f'سورة {name}', '📖', 'quran', note, steps)

def topic_lesson(sid, unit_i, k, letters, topics):
    if k in (1, 3, 5, 7):
        li = (k - 1) // 2
        l = letters[li]
        idx = LETTER_KEYS.index(l)
        emo = LETTERS[l][2]
        prev = letters[li - 1] if li > 0 else (UNITS[unit_i - 1][1][-1] if unit_i > 0 else l)
        steps = [listen(f'letter_{idx:02d}', emo), {'type': 'repeat', 'times': 3, 'prompt': emo},
                 letter_question(l, 0), letter_question(prev, 1), letter_question(l, 2)]
        return lesson(f'{sid}_t', f'صوت {l}', emo, 'educational', 'محتوى لغوي: صوت الحرف وكلمة تبدأ به.', steps)
    if k == 9:
        steps = [letter_question(l, j) for j, l in enumerate(letters)]
        return lesson(f'{sid}_t', 'مراجعة الحروف', '🔤', 'educational', 'مراجعة حروف الوحدة.', steps)
    if k == 10:
        t0 = topics[0] if isinstance(topics[0], str) else topics[0][1][0]
        steps = [letter_question(letters[0], 1), letter_question(letters[2], 2)] + topic_questions(t0)[:1]
        t2 = topics[2] if isinstance(topics[2], str) else topics[2][1][0]
        steps += topic_questions(t2)[:1]
        return lesson(f'{sid}_t', f'احتفال وحدة «{UNITS[unit_i][0]}»', '🎉', 'educational',
                      REVIEWED, steps)
    t = topics[(k - 2) // 2]
    if isinstance(t, tuple):
        keys = t[1]
        steps = []
        for key in keys:
            steps += (topic_questions(key)[:1] if key not in POSTURES else topic_questions(key))
        if keys == POSTURES:
            steps = [listen('salah_all', '🕌')] + steps
        srcs = {TOPICS[x]['source'] for x in keys}
        src = 'sahih_sunnah' if 'sahih_sunnah' in srcs else ('quran' if 'quran' in srcs else 'educational')
        return lesson(f'{sid}_t', 'مراجعة', '🔁', src, REVIEWED, steps)
    T = TOPICS[t]
    qs = topic_questions(t)
    if t == 'salah_all':
        qs = [q for p in POSTURES for q in topic_questions(p)]
    steps = [listen(T['listen'], T['icon']), {'type': 'repeat', 'times': 3, 'prompt': T['icon']}] + qs
    return lesson(f'{sid}_t', T['title'], T['icon'], T['source'], f"{T['note']} {REVIEWED}", steps)

def main():
    sessions = []
    n = 0
    for ui, (utitle, letters, topics) in enumerate(UNITS):
        for k in range(1, 11):
            n += 1
            sid = f'by_s{n:03d}'
            a = quran_lesson(sid, ui, k)
            b = topic_lesson(sid, ui, k, letters, topics)
            for d in (a, b):
                with open(os.path.join(LESSONS, d['id'] + '.json'), 'w') as f:
                    f.write(json.dumps(d, ensure_ascii=False, indent=2) + '\n')
            sessions.append({'n': n, 'unit': ui + 1, 'unit_title': utitle, 'lessons': [a['id'], b['id']]})
    with open(os.path.join(ROOT, 'assets/content/sessions/buraem.json'), 'w') as f:
        f.write(json.dumps({'band': 'buraem', 'sessions': sessions}, ensure_ascii=False, indent=1) + '\n')
    cat = {k: {'path': p, 'text': t, 'exists': os.path.exists(os.path.join(ROOT, p))} for k, (p, t) in clips.items()}
    with open(os.path.join(ROOT, 'tool/buraem_year_clips.json'), 'w') as f:
        f.write(json.dumps(cat, ensure_ascii=False, indent=1) + '\n')
    missing = [(k, v) for k, v in cat.items() if not v['exists']]
    md = ['# مقاطع صوت منهج سنة البراعم', '',
          f'> مولَّد آليًا من tool/gen_buraem_year.py. المقاطع: {len(cat)}، الموجود منها: {len(cat) - len(missing)}، الناقص: {len(missing)} (≈ {sum(len(v["text"]) for _, v in missing)} حرفًا).', '',
          '| المفتاح | الملف | النص | موجود؟ |', '|---|---|---|---|']
    for k, v in cat.items():
        md.append(f"| `{k}` | `{v['path']}` | {v['text']} | {'✅' if v['exists'] else '—'} |")
    with open(os.path.join(ROOT, 'docs/audio/buraem-year-scripts.md'), 'w') as f:
        f.write('\n'.join(md) + '\n')
    print(f'{len(sessions)} sessions, {2*len(sessions)} lessons, clips {len(cat)}, missing {len(missing)} '
          f'({sum(len(v["text"]) for _, v in missing)} chars)')

if __name__ == '__main__':
    main()
