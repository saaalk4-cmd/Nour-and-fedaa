#!/usr/bin/env python3
"""يضيف أحاديث موثّقة إلى ملفات الأقسام (*_hadith.json) بعد قراءتين:

1. موسوعة الأحاديث النبوية (HadeethEnc API): النص، الدرجة (صحيح فقط)، والتخريج
   الذي يجب أن يذكر الكتاب ورقم الحديث المطبوع.
2. نص الحديث نفسه موجود في نسخة الكتاب (hadith-json، مأخوذة من sunnah.com):
   تُطابَق عبارة مميزة من الحديث بعد حذف التشكيل.

لا يُكتب أي نص يدويًا: «text» مقطع حرفي من نص الموسوعة. ما لا يجتاز القراءتين لا يُضاف.

الاستخدام:
  python3 tools/build_verified_hadith.py <مجلد hadith-json/db/by_book/the_9_books>
(يحتاج curl ووصولًا إلى hadeethenc.com)
"""
import json
import os
import re
import subprocess
import sys
import time

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets', 'content')
API = 'https://hadeethenc.com/api/v1/hadeeths/one/?language=ar&id=%s'
PAGE = 'https://hadeethenc.com/ar/browse/hadith/%s'

# (الملف، المعرّف، العنوان، الرمز، رقم الموسوعة، بداية المقطع، نهاية المقطع، الراوي، الكتاب، الرقم،
#  ملف الكتاب للمطابقة، عبارة المطابقة، المعنى ببساطة)
# بداية/نهاية المقطع: أول وآخر كلمات المقطع كما في نص الموسوعة (بلا تشكيل)؛ None = ما بين « و ».
ITEMS = [
    ('adhkar_hadith.json', 'hadith_toilet_in', 'دخول الحمّام', '🚽', '3150', None, None,
     'أنس رضي الله عنه', 'صحيح البخاري', '142', 'bukhari', 'اللهم اني اعوذ بك من الخبث والخبائث',
     'قبل أن ندخل الحمّام ندعو الله أن يحمينا.'),
    ('adhkar_hadith.json', 'hadith_toilet_out', 'الخروج من الحمّام', '🚪', '10046', None, None,
     'عائشة رضي الله عنها', 'سنن أبي داود', '30', 'abudawud', 'غفرانك',
     'بعد أن نخرج من الحمّام نطلب من الله أن يغفر لنا.'),
    ('adhkar_hadith.json', 'hadith_home_in', 'دخول البيت', '🏠', '3037', 'إذا دخل الرجل بيته', 'ولا عشاء',
     'جابر بن عبد الله رضي الله عنهما', 'صحيح مسلم', '2018', 'muslim', 'لا مبيت لكم ولا عشاء',
     'إذا دخلنا البيت وذكرنا الله، لا يبقى الشيطان معنا في البيت.'),
    ('adhkar_hadith.json', 'hadith_mosque', 'دخول المسجد', '🕌', '65092', None, None,
     'أبو حميد أو أبو أسيد رضي الله عنهما', 'صحيح مسلم', '713', 'muslim', 'اللهم افتح لي ابواب رحمتك',
     'عند دخول المسجد نطلب من الله رحمته، وعند الخروج نطلب من فضله.'),
    ('adhkar_hadith.json', 'hadith_rain', 'عند نزول المطر', '🌧️', '65527', None, None,
     'عائشة رضي الله عنها', 'صحيح البخاري', '1032', 'bukhari', 'صيبا نافعا',
     'عندما ينزل المطر ندعو الله أن يجعله مطرًا نافعًا.'),
    ('seerah_hadith.json', 'hadith_serving_family', 'النبي ﷺ في بيته', '🏡', '6220', 'كان يكون في مهنة أهله', 'خرج إلى الصلاة',
     'عائشة رضي الله عنها', 'صحيح البخاري', '676', 'bukhari', 'مهنه اهله',
     'كان النبي ﷺ يساعد أهله في البيت، وإذا جاء وقت الصلاة ذهب إليها.'),
    ('seerah_hadith.json', 'hadith_mercy_children', 'رحمة النبي ﷺ بالأطفال', '🤗', '65991', 'قبل رسول الله', 'لا يرحم لا يرحم',
     'أبو هريرة رضي الله عنه', 'صحيح البخاري', '5997', 'bukhari', 'من لا يرحم لا يرحم',
     'كان النبي ﷺ يقبّل الأطفال ويرحمهم، ومن يرحم الناس يرحمه الله.'),
    ('figures_hadith.json', 'hadith_ali', 'علي بن أبي طالب', '💛', '65843', None, None,
     'سعد بن أبي وقاص رضي الله عنه', 'صحيح البخاري', '4416', 'bukhari', 'بمنزله هارون من موسي',
     'علي رضي الله عنه كان قريبًا من النبي ﷺ، كما كان هارون قريبًا من أخيه موسى.'),
    ('figures_hadith.json', 'hadith_bilal', 'بلال بن رباح', '🕌', '65849', None, None,
     'أبو هريرة رضي الله عنه', 'صحيح البخاري', '1149', 'bukhari', 'دف نعليك',
     'سمع النبي ﷺ صوت خطوات بلال في الجنة، لأن بلالًا كان يصلي كلما توضأ.'),
]

_MARKS = re.compile('[ً-ٰٟـ‌]')


def plain(s):
    return _MARKS.sub('', s)


def norm(s):
    s = plain(s)
    s = re.sub('[أإآٱ]', 'ا', s).replace('ى', 'ي').replace('ة', 'ه')
    return re.sub(r'\s+', ' ', re.sub('[^ء-ي ]', ' ', s)).strip()


def fetch(hid):
    for i in range(3):
        try:
            out = subprocess.run(['curl', '-s', '-m', '40', '--fail', API % hid],
                                 capture_output=True, check=True).stdout
            return json.loads(out)
        except Exception:  # noqa: BLE001
            time.sleep(2)
    raise SystemExit('HadeethEnc unreachable for %s' % hid)


def cut(full, start, end):
    """مقطع حرفي من [full] يبدأ بـ[start] وينتهي بـ[end] (المقارنة بلا تشكيل)."""
    if start is None:
        a, b = full.index('«') + 1, full.index('»')
        return full[a:b].strip()
    # نبني خريطة من النص بلا تشكيل إلى مواضعه في النص الأصلي.
    idx = [i for i, ch in enumerate(full) if not _MARKS.match(ch)]
    bare = ''.join(full[i] for i in idx)
    s = bare.index(start)
    e = bare.index(end, s) + len(end)
    a, b = idx[s], (idx[e] if e < len(idx) else len(full))
    t = full[a:b]
    if full[b:b + 1] == '»' and t.count('«') > t.count('»'):
        t += '»'  # نُغلق الاقتباس الذي فتحه المقطع
    return t.strip(' ،.')


def main():
    books_dir = sys.argv[1]
    books = {}
    added = {}
    for (fname, hid, title, emoji, henc, start, end, narrator, book, number, bfile, phrase, meaning) in ITEMS:
        d = fetch(henc)
        assert d['grade'].strip() == 'صحيح', (hid, d['grade'])
        assert '(%s)' % number in d['reference'], (hid, d['reference'])
        text = cut(d['hadeeth'], start, end)
        assert text and text in d['hadeeth'], hid
        if bfile not in books:
            with open(os.path.join(books_dir, bfile + '.json'), encoding='utf-8') as fh:
                books[bfile] = [norm(h['arabic']) for h in json.load(fh)['hadiths']]
        p = norm(phrase)
        assert any(p in h for h in books[bfile]), (hid, 'not found in', bfile)
        assert p in norm(text) or p in norm(d['hadeeth']), hid
        body = d['hadeeth']
        quote = body[body.find('«') + 1:body.find('»')].strip()
        after = body[body.find('»') + 1:].strip(' .\n')
        whole = text == quote and not after  # لا شيء من الحديث محذوف
        added.setdefault(fname, []).append({
            'id': hid, 'title': title, 'emoji': emoji, 'text': text,
            'narrator': narrator, 'book': book, 'number': number, 'grade': 'صحيح',
            'url': PAGE % henc, 'kidMeaning': meaning, 'excerpt': not whole,
            'verified': ['HadeethEnc #%s (%s)' % (henc, d['attribution'].strip()),
                         'نص مطابق في %s (hadith-json / sunnah.com)' % book],
        })
        print('ok', hid, book, number)
    for fname, items in added.items():
        path = os.path.join(ROOT, fname)
        with open(path, encoding='utf-8') as fh:
            doc = json.load(fh)
        ids = {h['id'] for h in items}
        doc['hadiths'] = [h for h in doc['hadiths'] if h['id'] not in ids] + items
        with open(path, 'w', encoding='utf-8') as fh:
            json.dump(doc, fh, ensure_ascii=False, indent=2)
            fh.write('\n')


if __name__ == '__main__':
    main()
