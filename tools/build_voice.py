#!/usr/bin/env python3
"""يولّد مقاطع صوتية عالية الجودة للجمل المتكررة أثناء البناء في CI.

- المصدر: الجمل التعليمية المكتوبة في كود الشاشات (ما يُمرَّر إلى speak) مع أسماء
  البنتين، وعناوين الدروس والأقسام. لا يُولَّد صوت لأي آية أو حديث أبدًا.
- الصوت: edge-tts (أصوات Microsoft العصبية). القيمة الافتراضية ar-EG-SalmaNeural
  ويمكن تغييرها بـ VOICE_NAME.
- الناتج: assets/audio/voice/<key>.mp3 + index.json. المفتاح يطابق
  VoiceService.clipKey في Dart (أول 16 حرفًا من sha1 للنص بعد التنظيف).
- لا يفشل البناء أبدًا: لو تعذّر التوليد يعمل التطبيق بصوت الجهاز.

الاستعمال:
  python3 tools/build_voice.py            # توليد (يحتاج pip install edge-tts)
  python3 tools/build_voice.py --list     # طباعة الجمل فقط
  python3 tools/build_voice.py --catalog  # يكتب assets/content/voice_phrases.json (شاشة «صوتي» للأهل)
"""
import asyncio
import glob
import hashlib
import json
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
OUT = os.path.join(ROOT, 'assets', 'audio', 'voice')
VOICE = os.environ.get('VOICE_NAME', 'ar-EG-SalmaNeural')
RATE = os.environ.get('VOICE_RATE', '-8%')
PITCH = os.environ.get('VOICE_PITCH', '+4Hz')
NAMES = ['فداء', 'نور']
MAX_CLIPS = 4000

ARABIC = re.compile('[؀-ۿ]')
# يطابق VoiceService.clean
SYMBOLS = re.compile('[\U0001F000-\U0001FFFF☀-➿⬀-⯿️‍⃣]')
# يطابق spokenTitle
TITLE_SYMBOLS = re.compile('[\U0001F000-\U0001FFFF←-➿⬀-⯿️]')


def clean(raw):
    t = SYMBOLS.sub(' ', raw)
    t = re.sub(r'\s*\n\s*', '. ', t)
    t = re.sub(r'\s+', ' ', t)
    return t.strip()


def clip_key(cleaned):
    return hashlib.sha1(cleaned.encode('utf-8')).hexdigest()[:16]


def spoken_title(title):
    return TITLE_SYMBOLS.sub('', title).strip()


# --------- نصوص محمية: لا تُنطق آليًا أبدًا ---------

def protected_texts():
    """كل نص آية أو حديث في المحتوى (لن يُولَّد له صوت حتى لو ظهر في مكان آخر)."""
    out = set()

    def walk(x, religious):
        if isinstance(x, dict):
            for k, v in x.items():
                walk(v, religious or k in ('text', 'arabic', 'ayah', 'ayat', 'hadith', 'matn'))
        elif isinstance(x, list):
            for v in x:
                walk(v, religious)
        elif isinstance(x, str) and religious and ARABIC.search(x):
            out.add(clean(x))

    for f in glob.glob(os.path.join(ROOT, 'assets', 'content', '*.json')):
        name = os.path.basename(f)
        if 'quran' in name or 'hadith' in name or 'ayat' in name:
            with open(f, encoding='utf-8') as fh:
                walk(json.load(fh), True)
    return out


def looks_religious(t):
    return any(m in t for m in ('﴿', '﴾', 'قال رسول الله', 'قال الله تعالى', 'صلى الله عليه وسلم قال'))


# --------- جمع الجمل ---------

LIT = re.compile(r"'((?:[^'\\]|\\.)*)'")
SPEAK_LINE = re.compile(r"speak\(|sayAndWait\(|sayWait\(|Say\s*=|_say\(|_go\(|SpeakOnOpen|text:\s*'|praise|\?\s*'|:\s*'")
NAME_VARS = re.compile(r"\$\{(?:c|child|widget\.child|kid)\.name\}|\$\{widget\.childName\}|\$name\b|\$\{name\}")


def dart_phrases():
    out = set()
    files = glob.glob(os.path.join(ROOT, 'lib', 'features', '**', '*.dart'), recursive=True)
    files += glob.glob(os.path.join(ROOT, 'lib', 'core', 'widgets', '*.dart'))
    for f in files:
        if os.sep + 'parent' + os.sep in f:
            continue  # معاينة الصوت في لوحة الأهل يجب أن تسمع صوت الجهاز
        with open(f, encoding='utf-8') as fh:
            for line in fh:
                if not SPEAK_LINE.search(line):
                    continue
                for m in LIT.finditer(line):
                    s = m.group(1).replace("\\'", "'")
                    if not ARABIC.search(s):
                        continue
                    variants = [s]
                    if NAME_VARS.search(s):
                        variants = [NAME_VARS.sub(n, s) for n in NAMES]
                    for v in variants:
                        if '$' in v:
                            # استيفاء آخر: ثوابت k*Say المعروفة
                            v = expand_consts(v)
                        if v and '$' not in v:
                            out.add(v)
    return out


_CONSTS = None


def expand_consts(s):
    global _CONSTS
    if _CONSTS is None:
        _CONSTS = {}
        for f in glob.glob(os.path.join(ROOT, 'lib', '**', '*.dart'), recursive=True):
            with open(f, encoding='utf-8') as fh:
                for m in re.finditer(r"const (k\w+Say)\s*=\s*'([^']*)'", fh.read()):
                    _CONSTS[m.group(1)] = m.group(2)
    return re.sub(r"\$(k\w+Say)\b", lambda m: _CONSTS.get(m.group(1), '$'), s)


def content_phrases():
    out = set()
    for f in sorted(glob.glob(os.path.join(ROOT, 'assets', 'content', '*lessons.json'))):
        with open(f, encoding='utf-8') as fh:
            d = json.load(fh)
        lessons = d if isinstance(d, list) else d.get('lessons', [])
        for l in lessons:
            t = spoken_title(l.get('title', ''))
            if t:
                out.add(t)
    return out


def section_phrases():
    out = set(NAMES)
    p = os.path.join(ROOT, 'lib', 'features', 'home', 'sections.dart')
    with open(p, encoding='utf-8') as fh:
        for m in re.finditer(r"AppSection\([^,]+,\s*'[^']*',\s*'([^']*)'", fh.read()):
            out.add(spoken_title(m.group(1)))
    return out


def game_phrases():
    """جمل الألعاب من assets/content/games.json (العناوين، التعليمات، الكلمات، المواقف).
    عناصر القرآن (التي لها تلاوة) لا يُولَّد لها صوت: يقرأها الشيخ."""
    out = set()
    p = os.path.join(ROOT, 'assets', 'content', 'games.json')
    if not os.path.exists(p):
        return out
    with open(p, encoding='utf-8') as fh:
        doc = json.load(fh)

    def fill(t, it):
        return (t.replace('{label}', it.get('label', '')).replace('{say}', it.get('say', it.get('label', '')))
                 .replace('{letter}', it.get('letter', '')).replace('{emoji}', ''))

    for g in doc['games']:
        out.add(g['title'])
        if g.get('intro'):
            out.add(g['intro'])
        items = [i for i in g.get('items', []) if not i.get('recite')]
        for i in items:
            out.add(i.get('say') or i['label'])
            if i.get('extra', {}).get('plural'):
                out.add(i['extra']['plural'])
        for grp in g.get('groups', []):
            out.add(grp['label'])
        for sc in g.get('scenarios', []):
            out.add(sc['say'])
            for o in sc['options']:
                out.add(o['label'])
        for track in (g.get('fedaa'), g.get('nour')):
            if not track:
                continue
            for lv in track['levels']:
                out.add(lv['title'])
            prompts = [track.get('prompt')] + [lv.get('prompt') for lv in track['levels']]
            afters = [track.get('after')] + [lv.get('after') for lv in track['levels']]
            for t in [x for x in prompts + afters if x]:
                if '{' in t:
                    for i in g.get('items', []):
                        out.add(fill(t, i))
                else:
                    out.add(t)
    return out


def cheer_phrases():
    """كل عبارات lib/core/audio/cheers.dart (مع اسم كل بنت) + عبارات ثابتة تُقال في الدروس والألعاب."""
    out = set()
    path = os.path.join(ROOT, 'lib', 'core', 'audio', 'cheers.dart')
    if os.path.exists(path):
        with open(path, encoding='utf-8') as fh:
            for m in LIT.finditer(fh.read()):
                s = m.group(1)
                if not ARABIC.search(s):
                    continue
                for n in NAMES:
                    out.add(s.replace('{n}', n))
    out |= {
        'ما شاء الله!', 'تذكّري الحديث الذي سمعناه', 'هذا كلام جميل، هيا نعرف معناه', 'ماذا تعلمتِ؟',
        'اختاري لعبة', 'اسمعي الآية التالية',
    } | {'الاختيار ' + o for o in ('الأول', 'الثاني', 'الثالث', 'الرابع', 'الخامس')}
    for n in NAMES:
        out.add('أحسنتِ يا %s!' % n)
    return out


def phrases():
    protected = protected_texts()
    raw = dart_phrases() | content_phrases() | section_phrases() | game_phrases() | cheer_phrases()
    result = {}
    for r in raw:
        t = clean(r)
        if not t or not ARABIC.search(t) or t in protected or looks_religious(t):
            continue
        result[clip_key(t)] = t
    return dict(sorted(result.items(), key=lambda kv: kv[1]))


# --------- التوليد ---------

async def _generate(items):
    import edge_tts  # noqa: PLC0415

    os.makedirs(OUT, exist_ok=True)
    sem = asyncio.Semaphore(6)
    ok = []

    async def one(key, text):
        path = os.path.join(OUT, key + '.mp3')
        if os.path.exists(path) and os.path.getsize(path) > 0:
            ok.append(key)
            return
        async with sem:
            for attempt in range(3):
                try:
                    await edge_tts.Communicate(text, VOICE, rate=RATE, pitch=PITCH).save(path)
                    if os.path.getsize(path) > 0:
                        ok.append(key)
                        return
                except Exception as e:  # noqa: BLE001
                    if attempt == 2:
                        print('fail', text, ':', e)
                    await asyncio.sleep(1 + attempt * 2)
            if os.path.exists(path):
                os.remove(path)

    await asyncio.gather(*(one(k, t) for k, t in items))
    return ok


# جمل يُنصح الأهل بتسجيلها أولًا (ترحيب وتشجيع وأسماء الأقسام)
ESSENTIAL_EXTRA = [
    'من سيتعلم اليوم؟', 'أهلًا يا {n}! هيا نبدأ مهمتنا', 'أحسنتِ يا {n}! هيا نكمل', 'أحسنتِ يا {n}! أكملتِ اليوم',
    'هديتك تنتظرك بعد مهمات اليوم', 'أنتِ مستكشفة صغيرة', 'مغامرة جديدة تنتظرك', 'أكملي المغامرة السابقة أولًا',
    'وقت استراحة! اشربي ماء وتحركي قليلًا ثم نكمل', 'خريطة الأسبوع', 'الألعاب', 'اسمعي', 'يلا نلعب',
]


def hadith_catalog():
    """كل نص حديث موثّق في التطبيق (لتسجّله الأم/الأب بصوتهما). النص كما في الدرس بالضبط."""
    out = []
    seen = set()
    for f in sorted(glob.glob(os.path.join(ROOT, 'assets', 'content', '*_hadith.json'))):
        with open(f, encoding='utf-8') as fh:
            doc = json.load(fh)
        for h in doc['hadiths']:
            t = clean(h['text'])
            if t in seen:
                continue
            seen.add(t)
            out.append({'key': clip_key(t), 'text': h['text'], 'title': h['title'],
                        'source': '%s (%s) — %s' % (h['book'], h['number'], h['grade']),
                        'narrator': h['narrator']})
    return out


def write_catalog():
    """assets/content/voice_phrases.json: ما يسجّله الأهل بصوتهم (الأساسي، الأحاديث، الباقي)."""
    allp = phrases()  # key -> text (بلا آيات ولا أحاديث)
    ess_texts = []
    for n in NAMES:
        ess_texts.append(n)
    for t in sorted(cheer_phrases()) + [x.replace('{n}', n) for x in ESSENTIAL_EXTRA for n in (NAMES if '{n}' in x else [''])]:
        ess_texts.append(t)
    for t in sorted(section_phrases()):
        ess_texts.append(t)
    ess, seen = [], set()
    for t in ess_texts:
        c = clean(t)
        if c and c not in seen and ARABIC.search(c):
            seen.add(c)
            ess.append({'key': clip_key(c), 'text': c})
    ess_keys = {e['key'] for e in ess}
    other = [{'key': k, 'text': t} for k, t in allp.items() if k not in ess_keys]
    doc = {'schema': 1, 'groups': [
        {'id': 'essential', 'title': 'الأساسية', 'phrases': ess},
        {'id': 'hadith', 'title': 'الأحاديث', 'phrases': hadith_catalog()},
        {'id': 'other', 'title': 'باقي الجمل', 'phrases': other},
    ]}
    path = os.path.join(ROOT, 'assets', 'content', 'voice_phrases.json')
    with open(path, 'w', encoding='utf-8') as fh:
        json.dump(doc, fh, ensure_ascii=False, indent=1)
        fh.write('\n')
    print('catalog: %d essential, %d hadith, %d other' % (len(ess), len(doc['groups'][1]['phrases']), len(other)))


def main():
    if '--catalog' in sys.argv:
        write_catalog()
        return 0
    items = list(phrases().items())[:MAX_CLIPS]
    if '--list' in sys.argv:
        for k, t in items:
            print(k, t)
        print(len(items), 'phrases')
        return 0
    try:
        ok = asyncio.run(_generate(items))
    except Exception as e:  # noqa: BLE001
        print('voice clips skipped:', e)
        return 0
    with open(os.path.join(OUT, 'index.json'), 'w', encoding='utf-8') as fh:
        json.dump({'voice': VOICE, 'clips': sorted(ok)}, fh)
    size = sum(os.path.getsize(os.path.join(OUT, k + '.mp3')) for k in ok)
    print('voice clips: %d ok of %d, %.1f MB, voice %s' % (len(ok), len(items), size / 1e6, VOICE))
    return 0


if __name__ == '__main__':
    sys.exit(main())
