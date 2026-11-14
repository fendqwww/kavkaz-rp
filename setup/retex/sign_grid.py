"""KAVKAZ RP: ПРОТОТИП (14.11, ждёт выбора основателя) — атлас вывесок → однотонные таблички с русскими словами.
атлас режется по прямым границам табличек (XY-cut по перепадам цвета), каждая табличка заливается своим основным цветом,
на крупной — русское слово цветом её прежних букв (гамма вывески сохраняется).
годится для атласов-сеток (im_signs*, *_shopsigns, *_gensigns); фото, витрины, дорожные знаки и плакаты ломает — их не подавать.
нужен numpy (python без -I: pip install --user numpy).
"""
import sys,os,re,zlib
import numpy as np
from PIL import Image,ImageDraw,ImageFont
FD=os.path.join(os.path.dirname(os.path.abspath(__file__)),'fonts')
WORDS=['ПРОДУКТЫ','ОДЕЖДА','ТКАНИ','РЕМОНТ','АПТЕКА','ОБУВЬ','ЦВЕТЫ','ХЛЕБ','ЧАСЫ','КЛЮЧИ','ОПТИКА','ФОТО','КНИГИ','ИГРУШКИ','МЕБЕЛЬ','ХИМЧИСТКА','СВЯЗЬ','ЛОМБАРД','ОБМЕН','АРЕНДА','ВХОД','ВЫХОД','ПАРКОВКА','СКЛАД','ОФИС','СКИДКИ','ОТКРЫТО','РАСПРОДАЖА']
def cuts(e,axis,lo,hi,a0,a1,minseg):
    # сила границы вдоль линии: доля пикселей с сильным перепадом по всей ширине участка
    sub=e[lo:hi,a0:a1] if axis==0 else e[a0:a1,lo:hi].T
    prof=sub.mean(axis=1)
    best=None
    for i in range(minseg,len(prof)-minseg):
        if prof[i]>0.55 and (best is None or prof[i]>prof[best]): best=i
    return None if best is None else lo+best
def segment(e,x0,y0,x1,y1,minseg,out,depth=0):
    if depth<12:
        r=cuts(e,0,y0,y1,x0,x1,minseg)
        c=cuts(e,1,x0,x1,y0,y1,minseg)
        if r is not None and (c is None or e[r,x0:x1].mean()>=e[y0:y1,c].mean()):
            segment(e,x0,y0,x1,r,minseg,out,depth+1); segment(e,x0,r+1,x1,y1,minseg,out,depth+1); return
        if c is not None:
            segment(e,x0,y0,c,y1,minseg,out,depth+1); segment(e,c+1,y0,x1,y1,minseg,out,depth+1); return
    out.append((x0,y0,x1,y1))
def two_colors(px):
    q=(px//32).astype(np.int32); key=q[:,0]*64+q[:,1]*8+q[:,2]
    vals,cnt=np.unique(key,return_counts=True); o=np.argsort(-cnt)
    def col(k): return tuple(int(v) for v in px[key==vals[k]].mean(axis=0))
    bg=col(o[0])
    fg=None
    for k in o[1:6]:
        c=col(k)
        if sum(abs(a-b) for a,b in zip(c,bg))>120: fg=c; break
    if fg is None: fg=(250,250,250) if sum(bg)<380 else (25,25,28)
    return bg,fg
def rebuild(im,name):
    w,h=im.size; s=max(1,max(w,h)//512)
    sm=im.convert('RGB').resize((w//s,h//s),Image.BOX); a=np.asarray(sm).astype(np.int16)
    g=np.zeros(a.shape[:2],bool)
    dy=np.abs(np.diff(a,axis=0)).sum(axis=2)>90; dx=np.abs(np.diff(a,axis=1)).sum(axis=2)>90
    e=np.zeros(a.shape[:2],float); e[1:,:]+=dy; e[:,1:]+=dx; e=np.clip(e,0,1)
    cells=[]; segment(e,0,0,a.shape[1],a.shape[0],max(6,min(a.shape[:2])//24),cells)
    K=2; W,H=a.shape[1]*K,a.shape[0]*K
    out=Image.new('RGB',(W,H)); d=ImageDraw.Draw(out)
    seed=zlib.crc32(name.encode())
    for n,(x0,y0,x1,y1) in enumerate(cells):
        bg,fg=two_colors(a[y0:y1,x0:x1].reshape(-1,3))
        d.rectangle((x0*K,y0*K,x1*K-1,y1*K-1),fill=bg)
        cw,ch=(x1-x0)*K,(y1-y0)*K
        if cw>=60 and ch>=24 and cw>=ch*1.3:
            word=WORDS[(seed+n)%len(WORDS)]
            size=int(ch*0.5)
            while size>8:
                f=ImageFont.truetype(os.path.join(FD,'Rubik-Black.ttf'),size)
                if d.textlength(word,font=f)<=cw*0.8: break
                size-=2
            if size>=12: d.text(((x0+x1)*K/2,(y0+y1)*K/2),word,font=f,fill=fg,anchor='mm')
    res=out.resize((w,h),Image.LANCZOS).convert('RGBA'); res.putalpha(im.getchannel('A'))
    return res,len(cells)
