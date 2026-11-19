#!/usr/bin/env python3
"""يبني assets/content/section_ayat.json: دروس السيرة والشخصيات والأذكار التي مصدرها آية.

الاستخدام:
  python3 tools/build_section_ayat.py <tanzil_uthmani.txt> <surahs.json>
(نفس ملفي build_prophets_ayat.py). النص من Tanzil حرفيًا، و«المعنى ببساطة» من مضمون الآية فقط
ولا يقتبس كلمات الآية (حتى لا ينطقها الصوت الآلي).
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_prophets_ayat import load_tanzil, skeleton, surah_name  # noqa: E402

# (المعرّف، القسم، العنوان، الرمز، سورة، من، إلى، المعنى ببساطة، كلمة نور، جملة نور، كلمة يجب أن تكون في الآية)
ITEMS = [
    # سيرة النبي ﷺ بالترتيب
    ('seerah_orphan', 'seerah', 'النبي ﷺ اليتيم', '🤲', 93, 6, 6,
     'كان النبي ﷺ يتيمًا، فرعاه الله وآواه.', 'يتيم', 'الله رعى النبي', 'يتيما'),
    ('seerah_first_revelation', 'seerah', 'أول الوحي', '📖', 96, 1, 1,
     'أول ما نزل من القرآن على النبي ﷺ: أن يقرأ باسم الله الذي خلق.', 'أول الوحي', 'أول وحي نزل على النبي', 'اقرا'),
    ('seerah_isra', 'seerah', 'رحلة الإسراء', '🌙', 17, 1, 1,
     'أسرى الله بنبيه ﷺ ليلًا من المسجد الحرام في مكة إلى المسجد الأقصى.', 'الإسراء', 'رحلة إلى المسجد الأقصى', 'الاقصا'),
    ('seerah_victory', 'seerah', 'فتح مكة', '🕋', 110, 1, 1,
     'نصر الله نبيه ﷺ، وفتح له مكة.', 'فتح مكة', 'الله نصر النبي', 'الفتح'),
    ('seerah_great_manners', 'seerah', 'خُلق عظيم', '😊', 68, 4, 4,
     'أخلاق النبي ﷺ عظيمة وجميلة.', 'أخلاق جميلة', 'النبي أخلاقه جميلة', 'خلق'),
    ('seerah_mercy', 'seerah', 'رحمة للعالمين', '💞', 21, 107, 107,
     'أرسل الله النبي ﷺ رحمة للناس جميعًا.', 'رحمة', 'النبي رحمة للناس', 'رحمه'),
    ('seerah_cares', 'seerah', 'النبي ﷺ يحبنا', '❤️', 9, 128, 128,
     'النبي ﷺ يحزن إذا تعبنا، ويحب لنا الخير، وهو رحيم بالمؤمنين.', 'يحبنا', 'النبي يحبنا', 'رءوف'),
    ('seerah_role_model', 'seerah', 'قدوتنا', '🌟', 33, 21, 21,
     'النبي ﷺ قدوتنا الحسنة، نتعلم منه ونفعل مثله.', 'قدوتنا', 'النبي قدوتنا', 'اسوه'),
    # شخصيات أحبها (من القرآن)
    ('figure_maryam', 'figures', 'مريم عليها السلام', '🌸', 3, 42, 42,
     'اختار الله مريم وطهّرها، وفضّلها على نساء العالمين.', 'مريم', 'مريم أم عيسى', 'مريم'),
    ('figure_asiya', 'figures', 'امرأة فرعون', '🏡', 66, 11, 11,
     'آمنت امرأة فرعون بالله، ودعت ربها أن يبني لها بيتًا في الجنة.', 'بيت في الجنة', 'آمنت بالله', 'فرعون'),
    ('figure_umm_musa', 'figures', 'أم موسى', '🌊', 28, 7, 7,
     'طمأن الله أم موسى: ترضعه، وإذا خافت عليه تضعه في الماء ولا تحزن، وسيرجعه الله إليها.', 'أم موسى',
     'أم موسى وثقت بالله', 'موسي'),
    ('figure_luqman', 'figures', 'لقمان', '👨‍👦', 31, 13, 13,
     'نصح لقمان ابنه: لا تعبد مع الله أحدًا.', 'لقمان', 'لقمان ينصح ابنه', 'لقمن'),
    # أذكاري
    ('adhkar_ride', 'adhkar', 'ذكر الركوب', '🚗', 43, 13, 14,
     'عندما نركب السيارة أو أي مركب، نتذكر نعمة الله ونسبّحه ونشكره.', 'نركب', 'نركب ونشكر الله', 'سخر'),
]


def main():
    q = load_tanzil(sys.argv[1])
    names = {c['number']: c['name'] for c in json.load(open(sys.argv[2], encoding='utf-8'))['data']}
    out = []
    for (iid, cat, title, emoji, s, a, b, meaning, word, say, must) in ITEMS:
        text = ' '.join(q[(s, v)] for v in range(a, b + 1))
        assert skeleton(must) in skeleton(text).replace('ى', 'ي').replace('ة', 'ه'), (iid, text)
        # جملة نور لا تكون جزءًا من نص الآية أو المعنى (لا اقتباس بالصوت الآلي)
        assert len(say.split()) < 4 or (say not in text and say not in meaning), iid
        out.append({'id': iid, 'category': cat, 'title': title, 'emoji': emoji,
                    'surahNumber': s, 'surahName': surah_name(names[s]), 'ayahFrom': a, 'ayahTo': b,
                    'text': text, 'kidMeaning': meaning, 'toddlerWord': word, 'toddlerSay': say})
    doc = {'schema': 1,
           'source': {'type': 'quran', 'name': 'Tanzil Quran Text (Uthmani)',
                      'url': 'https://tanzil.net/docs/text_license',
                      'license': 'CC BY 3.0 — verbatim copying only'},
           'verses': out}
    path = os.path.join(os.path.dirname(__file__), '..', 'assets', 'content', 'section_ayat.json')
    with open(path, 'w', encoding='utf-8') as fh:
        json.dump(doc, fh, ensure_ascii=False, indent=2)
    print(len(out), 'section ayat')


if __name__ == '__main__':
    main()
