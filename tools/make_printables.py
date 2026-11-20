#!/usr/bin/env python3
"""أوراق للطباعة (A4) بنفس رسومات التطبيق: شهادة تقدير، وجدول نجوم الأسبوع، ولوحة الحفظ.

  python3 tools/make_printables.py <fonts_dir> <out_dir>

يكتب HTML لكل ورقة ثم يحوّله PDF بمتصفح Chromium (Playwright عبر node)، لأن المتصفح يشكّل الحروف العربية صح.
الخطوط: Tajawal و Lalezar (tools/fetch_fonts.py). الصور: assets/art (شفافة).
لا آيات ولا أحاديث في الأوراق: أسماء السور فقط.
"""
import base64
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def b64(path, mime):
    with open(path, 'rb') as fh:
        return 'data:%s;base64,%s' % (mime, base64.b64encode(fh.read()).decode())


def art(name):
    return b64(os.path.join(ROOT, 'assets', 'art', name + '.webp'), 'image/webp')


def style(fonts, landscape=False):
    return """
@font-face{font-family:Tajawal;font-weight:400;src:url(%s)}
@font-face{font-family:Tajawal;font-weight:800;src:url(%s)}
@font-face{font-family:Lalezar;src:url(%s)}
@page{size:A4 %s;margin:0}
*{box-sizing:border-box}
body{margin:0;font-family:Tajawal;color:#4a2c12;direction:rtl}
.page{width:%s;height:%s;position:relative;overflow:hidden;padding:14mm;page-break-after:always}
h1,.big{font-family:Lalezar;font-weight:400;margin:0}
""" % (b64(os.path.join(fonts, 'Tajawal-Regular.ttf'), 'font/ttf'),
       b64(os.path.join(fonts, 'Tajawal-ExtraBold.ttf'), 'font/ttf'),
       b64(os.path.join(fonts, 'Lalezar-Regular.ttf'), 'font/ttf'),
       'landscape' if landscape else 'portrait',
       '297mm' if landscape else '210mm', '210mm' if landscape else '297mm')


def certificate(name, girl, color, fonts):
    return """<html><head><meta charset="utf-8"><style>%s
.frame{position:absolute;inset:9mm;border:5mm solid %s;border-radius:12mm;background:#fffaf0}
.inner{position:absolute;inset:16mm;border:1.2mm dashed #e8a957;border-radius:8mm}
.c{position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center}
h1{font-size:30mm;color:%s;text-shadow:0 1mm 0 #fff}
.name{font-family:Lalezar;font-size:24mm;margin:2mm 0;color:#4a2c12}
.line{font-size:8mm;font-weight:800;margin:2mm}
.blank{display:inline-block;min-width:110mm;border-bottom:.8mm dotted #9a5b22;height:9mm}
.girl{position:absolute;bottom:14mm;right:16mm;height:78mm}
.lamaa{position:absolute;bottom:16mm;left:20mm;height:50mm}
.medal{position:absolute;top:18mm;left:24mm;height:38mm}
.stars{position:absolute;top:20mm;right:26mm}
.stars img{height:14mm;margin:0 1mm}
.sign{font-size:6mm;margin-top:6mm}
</style></head><body><div class="page">
<div class="frame"></div><div class="inner"></div>
<img class="medal" src="%s"><div class="stars"><img src="%s"><img src="%s"><img src="%s"></div>
<div class="c">
 <h1>شهادة تقدير</h1>
 <div class="line">تُمنح هذه الشهادة للبطلة</div>
 <div class="name">%s</div>
 <div class="line">لأنها <span class="blank"></span></div>
 <div class="line">نفخر بكِ ونحبكِ كثيرًا</div>
 <div class="sign">التاريخ: <span class="blank" style="min-width:50mm"></span>&nbsp;&nbsp;&nbsp; ماما وبابا: <span class="blank" style="min-width:50mm"></span></div>
</div>
<img class="girl" src="%s"><img class="lamaa" src="%s">
</div></body></html>""" % (style(fonts, landscape=True), color, color, art('medal'), art('star_on'), art('star_on'),
                           art('star_on'), name, art(girl), art('lamaa_cheer'))


DAYS = ['السبت', 'الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة']


def star_chart(name, girl, color, rows, fonts):
    head = ''.join('<th>%s</th>' % d for d in DAYS)
    body = ''.join(
        '<tr><td class="lab"><img src="%s"><div>%s</div></td>%s</tr>' % (art(a), t, '<td><div class="dot"></div></td>' * 7)
        for a, t in rows)
    return """<html><head><meta charset="utf-8"><style>%s
.top{display:flex;align-items:center;gap:6mm;margin-bottom:6mm}
.top img{height:46mm}
h1{font-size:17mm;color:%s}
.sub{font-size:6.5mm;font-weight:800}
table{width:100%%;border-collapse:separate;border-spacing:2mm}
th{font-size:5.2mm;font-weight:800;background:%s;color:#fff;border-radius:4mm;padding:2.5mm 0}
td{background:#fff7e6;border-radius:5mm;text-align:center;height:30mm}
td.lab{width:34mm;font-weight:800;font-size:4.8mm}
td.lab img{height:15mm;display:block;margin:0 auto 1mm}
.dot{width:16mm;height:16mm;border:1mm dashed #e8a957;border-radius:50%%;margin:auto}
.foot{display:flex;align-items:center;justify-content:center;gap:4mm;margin-top:5mm;font-size:6mm;font-weight:800}
.foot img{height:12mm}
</style></head><body><div class="page">
<div class="top"><img src="%s"><div><h1>نجوم %s</h1><div class="sub">لوّني الدائرة أو الزقي نجمة كل ما تخلّصي</div></div></div>
<table><tr><th></th>%s</tr>%s</table>
<div class="foot"><img src="%s"> كل أسبوع فيه نجوم كتير = هدية حلوة من ماما وبابا <img src="%s"></div>
</div></body></html>""" % (style(fonts), color, color, art(girl), name, head, body, art('star_on'), art('star_on'))


def hifz_chart(name, girl, color, juz_list, done, title, sub, fonts):
    q = json.load(open(os.path.join(ROOT, 'assets', 'content', 'quran_surahs.json'), encoding='utf-8'))
    surahs = {s['surahNumber']: s['name'] for s in (q['surahs'] if isinstance(q, dict) else q)}
    ranges = {28: range(58, 67), 29: range(67, 78), 30: range(78, 115)}
    juz_name = {28: 'جزء قد سمع', 29: 'جزء تبارك', 30: 'جزء عمّ'}
    blocks = ''
    for j in juz_list:
        cells = ''
        for n in ranges[j]:
            got = n in done
            cells += '<div class="s%s"><span class="st">%s</span>%s</div>' % (
                ' got' if got else '', '<img src="%s">' % art('star_on') if got else '', surahs.get(n, str(n)))
        blocks += '<h2>%s</h2><div class="grid">%s</div>' % (juz_name[j], cells)
    return """<html><head><meta charset="utf-8"><style>%s
.top{display:flex;align-items:center;gap:6mm;margin-bottom:3mm}
.top img{height:38mm}
h1{font-size:15mm;color:%s}
.sub{font-size:5.5mm;font-weight:800}
h2{font-family:Lalezar;font-weight:400;font-size:8mm;margin:3mm 0 1.5mm;color:%s}
.grid{display:grid;grid-template-columns:repeat(5,1fr);gap:1.6mm}
.grid div{background:#fff7e6;border:.6mm solid #f1d3a3;border-radius:3mm;padding:1.4mm .5mm;text-align:center;font-weight:800;font-size:3.9mm;display:flex;align-items:center;justify-content:center;gap:1mm}
.grid div.got{background:#e5f7df;border-color:#7ed36b}
.st{width:6mm;height:6mm;border:.6mm dashed #e8a957;border-radius:50%%;display:inline-flex;flex:none}
.got .st{border:none}
.st img{width:6mm;height:6mm}
</style></head><body><div class="page">
<div class="top"><img src="%s"><div><h1>%s</h1><div class="sub">%s</div></div></div>
%s
</div></body></html>""" % (style(fonts), color, color, art(girl), title, sub, blocks)


def main():
    fonts, out = sys.argv[1], sys.argv[2]
    os.makedirs(out, exist_ok=True)
    pink, green = '#ff6f9c', '#4caf50'
    fedaa_rows = [('sec_learn', 'درس اليوم'), ('sec_quran', 'ورد القرآن'), ('sec_prayer', 'صلاتي'),
                  ('sec_adhkar', 'أذكاري'), ('sec_akhlaq', 'خُلق جميل')]
    nour_rows = [('sec_learn', 'درس اليوم'), ('sec_quran', 'سمعت القرآن'), ('sec_adhkar', 'أذكاري'),
                 ('sec_akhlaq', 'خُلق جميل')]
    pages = {
        'certificate_fedaa': certificate('فداء', 'fedaa_cheer', pink, fonts),
        'certificate_nour': certificate('نور', 'nour_cheer', green, fonts),
        'stars_fedaa': star_chart('فداء', 'fedaa_cheer', pink, fedaa_rows, fonts),
        'stars_nour': star_chart('نور', 'nour_cheer', green, nour_rows, fonts),
        # فداء: محفوظ من الطلاق للناس بنجمة، والجديد (58–64) تلوّنه وهي بتحفظ.
        'hifz_fedaa': hifz_chart('فداء', 'fedaa_cheer', pink, [28, 29, 30], set(range(65, 115)),
                                 'لوحة حفظ فداء', 'كل سورة تحفظيها لوّني دائرتها أو الزقي نجمة', fonts),
        'listen_nour': hifz_chart('نور', 'nour_cheer', green, [30, 29], set(),
                                  'سور سمعتها نور', 'كل سورة تسمعيها للآخر لوّني دائرتها', fonts),
    }
    for name, html in pages.items():
        with open(os.path.join(out, name + '.html'), 'w', encoding='utf-8') as fh:
            fh.write(html)
    js = """const {chromium}=require('playwright');(async()=>{const b=await chromium.launch();const p=await b.newPage();
for(const n of %s){await p.goto('file://%s/'+n+'.html');await p.waitForTimeout(400);
await p.pdf({path:'%s/'+n+'.pdf',preferCSSPageSize:true,printBackground:true});}
await b.close();})();""" % (json.dumps(list(pages)), os.path.abspath(out), os.path.abspath(out))
    subprocess.run(['node', '-e', js], check=True)
    for name in pages:
        os.remove(os.path.join(out, name + '.html'))
        print(name + '.pdf', os.path.getsize(os.path.join(out, name + '.pdf')) // 1024, 'KB')


if __name__ == '__main__':
    main()
