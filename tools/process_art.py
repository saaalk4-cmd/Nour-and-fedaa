"""يعيد إنتاج assets/art/*.webp من الصور الأصلية في art_src/.

التشغيل من جذر المشروع:  python3 tools/process_art.py
يلزم: Pillow, numpy, scipy.
- JPG بخلفية بيضا: تُزال الخلفية (تغمر من الحواف) وتُنظَّف الحواف.
- PNG شفاف: يُنظَّف لون الهالة الملوّنة على الحواف.
- الملفات المسبوقة بـ unused_ غير مستخدمة (محفوظة فقط).
"""
import glob, os
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage as ndi
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT=os.path.join(ROOT,'assets','art')+os.sep
os.makedirs(OUT,exist_ok=True)
def src(n): return glob.glob(os.path.join(ROOT,'art_src',n+'.*'))[0]
def decontaminate(rgb, solid):
    # حواف شفافة تأخذ لون أقرب بكسل صلب: يزيل هالة الخلفية
    core=ndi.binary_erosion(solid,iterations=2)
    if core.sum()==0: core=solid
    idx=ndi.distance_transform_edt(~core,return_distances=False,return_indices=True)
    out=rgb.copy()
    out[~core]=rgb[idx[0][~core],idx[1][~core]]
    return out

def cutout_white(path, tol=24):
    im=Image.open(path).convert('RGB'); a=np.array(im).astype(int)
    near=(a.min(axis=2)>=255-tol)
    lab,n=ndi.label(near)
    border=set(np.unique(np.concatenate([lab[0],lab[-1],lab[:,0],lab[:,-1]])))-{0}
    bg=np.isin(lab,list(border))
    fg=~bg
    fg=ndi.binary_opening(fg,iterations=1) | ndi.binary_erosion(fg,iterations=1)
    fg=ndi.binary_fill_holes(fg) if False else fg
    # إزالة جزر صغيرة جدًا من الضجيج
    lab2,n2=ndi.label(fg)
    if n2>1:
        sizes=ndi.sum(fg,lab2,range(1,n2+1))
        keep=[i+1 for i,s in enumerate(sizes) if s>=max(40,0.0005*fg.size)]
        fg=np.isin(lab2,keep)
    solid=ndi.binary_erosion(fg,iterations=1)
    rgb=decontaminate(np.array(im),solid)
    alpha=Image.fromarray((fg*255).astype('uint8')).filter(ImageFilter.GaussianBlur(1.0))
    al=np.array(alpha).astype(float)
    al=np.clip((al-70)*255/(200-70),0,255).astype('uint8')
    out=np.dstack([rgb,al]).astype('uint8')
    return Image.fromarray(out,'RGBA')

def clean_png(path):
    im=Image.open(path).convert('RGBA'); a=np.array(im)
    al=a[:,:,3]; solid=al>=250
    rgb=decontaminate(a[:,:,:3],solid)
    al=np.where(al<40,0,al).astype('uint8')
    # أي جزر معزولة صغيرة (غبار) تُزال
    m=al>0; lab,n=ndi.label(ndi.binary_dilation(m,iterations=3))
    if n>1:
        sizes=ndi.sum(m,lab,range(1,n+1)); keep=1+int(np.argmax(sizes))
        al[lab!=keep]=0
    return Image.fromarray(np.dstack([rgb,al]).astype('uint8'),'RGBA')

def save(im,name,maxdim,q=86,crop=True):
    if crop and im.mode=='RGBA':
        bb=im.getbbox(); im=im.crop(bb)
    s=min(1,maxdim/max(im.size))
    if s<1: im=im.resize((round(im.width*s),round(im.height*s)),Image.LANCZOS)
    p=OUT+name+'.webp'; im.save(p,'WEBP',quality=q,method=6); 
    print(f'{name:16s}{im.size} {os.path.getsize(p)//1024}KB')

# شخصيات
save(cutout_white(src('fedaa_welcome')),'fedaa_welcome',780)
save(cutout_white(src('fedaa_think'),tol=22),'fedaa_think',900)
save(clean_png(src('fedaa_cheer')),'fedaa_cheer',900)
save(clean_png(src('nour_welcome')),'nour_welcome',900)
save(clean_png(src('nour_think')),'nour_think',900)
save(clean_png(src('nour_cheer')),'nour_cheer',900)
# لمعة
for n,f in [('lamaa_calm','lamaa_calm'),('lamaa_point','lamaa_point'),('lamaa_cheer','lamaa_cheer'),('lamaa_think','lamaa_think'),('lamaa_welcome','lamaa_welcome')]:
    save(cutout_white(src(f)),n,440)
# أيقونات
for n,f in [(x, x) for x in ['ic_gift','ic_sound','ic_back','ic_home','ic_lock','ic_play','ic_mic','ic_repeat','ic_done','ic_next']]:
    save(cutout_white(src(f)),n,220)
star=cutout_white(src('star_on')); star=star.crop(star.getbbox()); star=star.resize((220,round(220*star.height/star.width)),Image.LANCZOS)
star.save(OUT+'star_on.webp','WEBP',quality=86,method=6,exact=True); print('star_on',star.size)
a=np.array(star).astype(float)
g=np.clip(a[:,:,:3].mean(axis=2,keepdims=True)*0.75+70,120,235)
a[:,:,:3]=np.repeat(g,3,axis=2); Image.fromarray(a.astype('uint8'),'RGBA').save(OUT+'star_off.webp','WEBP',quality=86,method=6,exact=True)
# بوابة وميدالية
save(cutout_white(src('gate')),'gate',420)
save(cutout_white(src('medal')),'medal',420)
# خلفيات
for n,f in [('bg_sky','bg_sky'),('bg_river','bg_river'),('bg_forest','bg_forest'),('bg_house','bg_house'),('bg_castle','bg_castle'),('bg_path','bg_path')]:
    im=Image.open(src(f)).convert('RGB'); p=OUT+n+'.webp'; im.save(p,'WEBP',quality=74,method=6); print(n,im.size,os.path.getsize(p)//1024,'KB')
# ورقة الطبيعة
sheet=cutout_white(src('nature_sheet'),tol=20); arr=np.array(sheet); a=arr[:,:,3]>20
lab,n=ndi.label(ndi.binary_dilation(a,iterations=4)); objs=ndi.find_objects(lab)
items=[]
for i,sl in enumerate(objs):
    y,x=sl
    if (x.stop-x.start)*(y.stop-y.start)>3000: items.append((y.start,x.start,i+1,sl))
top=sorted([t for t in items if t[0]<250],key=lambda t:t[1]); bot=sorted([t for t in items if t[0]>=250],key=lambda t:t[1])
names=['tree1','tree2','tree3','tree4','bush','flowers1','flowers2','rock','signpost']
print(len(top),len(bot))
for nm,(y0,x0,lid,sl) in zip(names,top+bot):
    m=ndi.binary_dilation(lab==lid,iterations=1)
    c=arr.copy(); c[~m,3]=0
    save(Image.fromarray(c,'RGBA').crop((sl[1].start,sl[0].start,sl[1].stop,sl[0].stop)),'decor_'+nm,300)
# أيقونات الأقسام (Canva، بنفس أسلوب واحد)
for n in ['quran', 'prayer', 'adhkar', 'akhlaq', 'seerah', 'figures', 'prophets', 'learn', 'achievements']:
    save(cutout_white(src('sec_' + n)), 'sec_' + n, 200)
# كروت حروف نور (Canva): صورة أول كلمة لكل حرف
for i in range(1, 29):
    save(cutout_white(src('let_%02d' % i)), 'let_%02d' % i, 200)

# مكتبة الصور (Canva، نفس الأسلوب): كل art_src/pic_*.png
for f in sorted(glob.glob(os.path.join(ROOT, 'art_src', 'pic_*.png'))):
    n = os.path.basename(f)[:-4]
    save(cutout_white(f), n, 200)
