#!/usr/bin/env python3
"""يولّد مقاطع صوتية عالية الجودة للجمل المتكررة أثناء البناء في CI.

- المصدر: الجمل التعليمية المكتوبة في كود الشاشات (ما يُمرَّر إلى speak) مع أسماء
  البنتين، وعناوين الدروس والأقسام. لا يُولَّد صوت لأي آية أو حديث أبدًا.
- الصوت: **ElevenLabs بصوت «وئام»** إن وُجد المتغير ELEVENLABS_API_KEY (في CI من secret باسم
  ELEVENLABS_API_KEY)؛ وإلا edge-tts (أصوات Microsoft العصبية، الافتراضي ar-EG-SalmaNeural).
  - يبدأ بالجمل الأساسية ثم الباقي، ولا يتجاوز حد الأحرف في البناء الواحد (ELEVENLABS_MAX_CHARS، الافتراضي 9000)،
    ولا يتجاوز الرصيد المتبقي في الحساب؛ وما لا يتسع يكمله صوت edge-tts (VOICE_FALLBACK=edge) أو يُترك لصوت الجهاز (none)،
    ثم يُستبدل بصوت ElevenLabs في أول بناء يتسع له الرصيد. كل جملة تُحسب مرة واحدة فقط (يُحفظ ما وُلِّد).
  - متغيرات: ELEVENLABS_VOICE_ID (الافتراضي وئام R5kMoWNNTn84ezIJA53m)، ELEVENLABS_MODEL (eleven_multilingual_v2)،
    ELEVENLABS_SPEED (0.9).
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
import time
import urllib.error
import urllib.request

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
OUT = os.environ.get('VOICE_OUT_DIR') or os.path.join(ROOT, 'assets', 'audio', 'voice')
VOICE = os.environ.get('VOICE_NAME', 'ar-EG-SalmaNeural')
RATE = os.environ.get('VOICE_RATE', '-8%')
PITCH = os.environ.get('VOICE_PITCH', '+4Hz')
NAMES = ['فداء', 'نور']
MAX_CLIPS = 4000

EL_KEY = os.environ.get('ELEVENLABS_API_KEY', '').strip()
EL_VOICE = os.environ.get('ELEVENLABS_VOICE_ID', '').strip() or 'R5kMoWNNTn84ezIJA53m'  # وئام
EL_MODEL = os.environ.get('ELEVENLABS_MODEL', '').strip() or 'eleven_multilingual_v2'
EL_BASE = os.environ.get('ELEVENLABS_BASE', 'https://api.elevenlabs.io').rstrip('/')
EL_FORMAT = os.environ.get('ELEVENLABS_FORMAT', 'mp3_44100_64')
EL_SPEED = float(os.environ.get('ELEVENLABS_SPEED', '0.9') or 0.9)
EL_MAX_CHARS = int(os.environ.get('ELEVENLABS_MAX_CHARS', '9000') or 9000)
FALLBACK = os.environ.get('VOICE_FALLBACK', 'edge')  # edge | none

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

SOURCES = os.path.join(OUT, '_sources.json')  # مفتاح الجملة ← مصدر صوتها (eleven | edge)


def essential_keys():
    """مفاتيح الجمل الأساسية (ترحيب وتشجيع وأسماء الأقسام): تُولَّد أولًا."""
    texts = []
    texts += NAMES
    texts += sorted(cheer_phrases())
    texts += [x.replace('{n}', n) for x in ESSENTIAL_EXTRA for n in (NAMES if '{n}' in x else [''])]
    texts += sorted(section_phrases())
    out, seen = [], set()
    for t in texts:
        c = clean(t)
        if c and c not in seen and ARABIC.search(c):
            seen.add(c)
            out.append(clip_key(c))
    return out


def ordered_items():
    """كل الجمل: الأساسية أولًا (بترتيبها) ثم الباقي بالترتيب الأبجدي."""
    allp = phrases()
    first = [k for k in essential_keys() if k in allp]
    seen = set(first)
    return [(k, allp[k]) for k in first] + [(k, t) for k, t in allp.items() if k not in seen]


def load_sources():
    try:
        with open(SOURCES, encoding='utf-8') as fh:
            return json.load(fh)
    except Exception:  # noqa: BLE001
        return {}


def save_sources(src):
    with open(SOURCES, 'w', encoding='utf-8') as fh:
        json.dump(src, fh, ensure_ascii=False, sort_keys=True)


class ElevenLabs:
    """عميل ElevenLabs بسيط (urllib، بلا اعتماديات). يتعطّل نفسه عند خطأ دائم (مفتاح/خطة)."""

    def __init__(self):
        self.enabled = bool(EL_KEY)
        self.reason = ''

    def _req(self, path, body=None, timeout=60):
        data = None if body is None else json.dumps(body).encode('utf-8')
        req = urllib.request.Request(
            EL_BASE + path, data=data, method='POST' if body is not None else 'GET',
            headers={'xi-api-key': EL_KEY, 'Content-Type': 'application/json', 'Accept': 'audio/mpeg, application/json'})
        return urllib.request.urlopen(req, timeout=timeout)

    def remaining_chars(self):
        """الرصيد المتبقي في الحساب (None لو تعذّرت القراءة)."""
        try:
            with self._req('/v1/user/subscription', timeout=20) as r:
                d = json.load(r)
            return int(d['character_limit']) - int(d['character_count'])
        except Exception:  # noqa: BLE001
            return None

    def speak(self, text, path):
        """يولّد الجملة إلى path. يرجع True عند النجاح. يعطّل نفسه عند 401/402/403."""
        body = {
            'text': text,
            'model_id': EL_MODEL,
            'voice_settings': {'stability': 0.55, 'similarity_boost': 0.75, 'style': 0.0,
                               'use_speaker_boost': True, 'speed': EL_SPEED},
        }
        for attempt in range(4):
            try:
                with self._req('/v1/text-to-speech/%s?output_format=%s' % (EL_VOICE, EL_FORMAT), body) as r:
                    audio = r.read()
                if len(audio) < 800:
                    raise ValueError('audio too small')
                with open(path, 'wb') as fh:
                    fh.write(audio)
                return True
            except urllib.error.HTTPError as e:
                if e.code in (401, 402, 403):
                    detail = ''
                    try:
                        detail = e.read().decode('utf-8', 'ignore')[:160]
                    except Exception:  # noqa: BLE001
                        pass
                    self.enabled = False
                    self.reason = 'HTTP %d %s' % (e.code, detail)
                    return False
                if e.code in (429, 500, 502, 503, 504) and attempt < 3:
                    time.sleep(2 + attempt * 3)
                    continue
                print('eleven fail', text[:30], 'HTTP', e.code)
                return False
            except Exception as e:  # noqa: BLE001
                if attempt == 3:
                    print('eleven fail', text[:30], ':', e)
                    return False
                time.sleep(1 + attempt * 2)
        return False


def edge_speak(text, path):
    try:
        import edge_tts  # noqa: PLC0415
    except Exception:  # noqa: BLE001
        return False

    async def run():
        await edge_tts.Communicate(text, VOICE, rate=RATE, pitch=PITCH).save(path)

    for attempt in range(3):
        try:
            asyncio.run(run())
            if os.path.getsize(path) > 0:
                return True
        except Exception as e:  # noqa: BLE001
            if attempt == 2:
                print('edge fail', text[:30], ':', e)
            time.sleep(1 + attempt * 2)
    if os.path.exists(path):
        os.remove(path)
    return False


def generate(items):
    """يولّد المقاطع الناقصة. يرجع (مفاتيح الجاهز، المصادر، ملخص)."""
    os.makedirs(OUT, exist_ok=True)
    src = load_sources()
    eleven = ElevenLabs()
    budget = EL_MAX_CHARS
    summary = {'eleven': 0, 'edge': 0, 'reused': 0, 'skipped': 0}
    if eleven.enabled:
        rem = eleven.remaining_chars()
        if rem is not None:
            budget = min(budget, max(0, rem - 300))  # هامش أمان
        print('ElevenLabs: voice %s, model %s, budget %d chars' % (EL_VOICE, EL_MODEL, budget))

    # صوت ElevenLabs/ الصوت المختار تغيّر؟ لا نخلط مقاطع صوت قديم.
    want = 'eleven:%s:%s' % (EL_VOICE, EL_MODEL) if eleven.enabled else 'edge:%s' % VOICE
    meta_path = os.path.join(OUT, '_voice.txt')
    try:
        old = open(meta_path, encoding='utf-8').read().strip()
    except Exception:  # noqa: BLE001
        old = ''
    if old and old != want:
        for f in os.listdir(OUT):
            if f.endswith('.mp3'):
                os.remove(os.path.join(OUT, f))
        src = {}
        print('voice changed (%s -> %s): regenerating all clips' % (old, want))
    with open(meta_path, 'w', encoding='utf-8') as fh:
        fh.write(want)

    ready = []
    todo = []
    for k, t in items:
        path = os.path.join(OUT, k + '.mp3')
        have = os.path.exists(path) and os.path.getsize(path) > 0
        kind = src.get(k)
        if have and (kind == 'eleven' or not eleven.enabled):
            ready.append(k)
            summary['reused'] += 1
        else:
            todo.append((k, t, have))

    # ElevenLabs أولًا بالترتيب (الأساسي ثم الباقي)، ضمن الميزانية
    pending = []
    if eleven.enabled:
        for k, t, have in todo:
            path = os.path.join(OUT, k + '.mp3')
            if not eleven.enabled:
                pending.append((k, t, have))
                continue
            if len(t) > budget:
                pending.append((k, t, have))
                summary['skipped'] += 1
                continue
            tmp = path + '.part'
            if eleven.speak(t, tmp):
                os.replace(tmp, path)
                budget -= len(t)
                src[k] = 'eleven'
                ready.append(k)
                summary['eleven'] += 1
            else:
                if os.path.exists(tmp):
                    os.remove(tmp)
                pending.append((k, t, have))
        if not eleven.enabled and eleven.reason:
            print('ElevenLabs disabled for this run:', eleven.reason)
    else:
        pending = todo

    # ما لم يتسع له الرصيد: صوت edge-tts (إن سُمح) وإلا يبقى لصوت الجهاز
    for k, t, have in pending:
        path = os.path.join(OUT, k + '.mp3')
        if have and src.get(k) == 'edge':
            ready.append(k)
            continue
        if FALLBACK == 'edge' and edge_speak(t, path):
            src[k] = 'edge'
            ready.append(k)
            summary['edge'] += 1
    save_sources(src)
    return ready, src, summary


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
    items = ordered_items()[:MAX_CLIPS]
    if '--list' in sys.argv:
        for k, t in items:
            print(k, t)
        print(len(items), 'phrases')
        return 0
    try:
        ok, src, summary = generate(ordered_items()[:MAX_CLIPS])
    except Exception as e:  # noqa: BLE001
        print('voice clips skipped:', e)
        return 0
    voice = ('eleven:' + EL_VOICE) if (EL_KEY and any(v == 'eleven' for v in src.values())) else VOICE
    with open(os.path.join(OUT, 'index.json'), 'w', encoding='utf-8') as fh:
        json.dump({'voice': voice, 'clips': sorted(ok), 'sources': {k: src.get(k, 'edge') for k in ok}}, fh)
    size = sum(os.path.getsize(os.path.join(OUT, k + '.mp3')) for k in ok)
    print('voice clips: %d ready, %.1f MB | ElevenLabs new %d, edge new %d, reused %d, over budget %d' % (
        len(ok), size / 1e6, summary['eleven'], summary['edge'], summary['reused'], summary['skipped']))
    return 0


if __name__ == '__main__':
    sys.exit(main())
