/* العب مع لمعة — ألعاب وحكايات فداء ونور (أونلاين).
 * القواعد: الآيات بصوت الشيخ (المنشاوي) فقط، والكلام بمقاطع صوت التطبيق المسجّلة.
 * لا كلمة «خطأ»، لا خصم نجوم، كل حاجة صورة وصوت، ولا رسم لنبي أو صحابي. */
'use strict';

const $ = (html) => { const t = document.createElement('template'); t.innerHTML = html.trim(); return t.content.firstElementChild; };
const A = (n) => `art/${n}.webp`;
const rnd = (n) => Math.floor(Math.random() * n);
const pick = (a) => a[rnd(a.length)];
const shuffle = (a) => { a = a.slice(); for (let i = a.length - 1; i > 0; i--) { const j = rnd(i + 1); [a[i], a[j]] = [a[j], a[i]]; } return a; };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));

/* ---------------- الحالة ---------------- */
const KIDS = {
  fedaa: { name: 'فداء', art: 'fedaa_cheer', think: 'fedaa_think', color: '#ff6f9c' },
  nour: { name: 'نور', art: 'nour_cheer', think: 'nour_think', color: '#4caf50' },
};
const store = {
  get(k, d) { try { const v = localStorage.getItem(k); return v == null ? d : JSON.parse(v); } catch (_) { return d; } },
  set(k, v) { try { localStorage.setItem(k, JSON.stringify(v)); } catch (_) { /* وضع خاص */ } },
};
const S = { child: null, tab: 'games', shelf: 'all', data: null, voice: {}, videos: [] };
const kid = () => KIDS[S.child];
const starsKey = () => `stars_${S.child}`;
const gameKey = (id) => `g_${S.child}_${id}`;

/* ---------------- الصوت ---------------- */
const voiceEl = new Audio();
const ayahEl = new Audio();
let audioRun = 0;
function playOn(el, src) {
  return new Promise((res) => {
    el.onended = el.onerror = () => res();
    el.src = src;
    const p = el.play();
    if (p && p.catch) p.catch(() => res());
  });
}
function stopAll() { audioRun++; voiceEl.pause(); ayahEl.pause(); try { speechSynthesis.cancel(); } catch (_) { /* */ } }
/** جملة بصوت التطبيق؛ لو مش مسجّلة: صوت الجهاز (احتياط فقط). */
async function say(text) {
  const run = audioRun;
  const f = S.voice[text];
  if (f) { ayahEl.pause(); await playOn(voiceEl, `voice/${f}`); return run === audioRun; }
  if ('speechSynthesis' in window) {
    await new Promise((res) => {
      const u = new SpeechSynthesisUtterance(text); u.lang = 'ar'; u.rate = 0.9; u.onend = u.onerror = res;
      speechSynthesis.speak(u); setTimeout(res, 6000);
    });
  }
  return run === audioRun;
}
function globalAyah(s, a) { const c = S.data.counts; let n = 0; for (let i = 0; i < s - 1; i++) n += c[i]; return n + a; }
/** تلاوة الشيخ المنشاوي لآية واحدة. */
async function recite(s, a) {
  const run = audioRun; voiceEl.pause();
  await playOn(ayahEl, `https://cdn.islamic.network/quran/audio/128/ar.minshawi/${globalAyah(s, a)}.mp3`);
  return run === audioRun;
}
const praise = () => say(pick([`أحسنتِ يا ${kid().name}!`, `رائع يا ${kid().name}!`, `ممتاز يا ${kid().name}!`]));
const tryAgain = () => say(pick(['جرّبي مرة ثانية', 'قريب جدًا، جرّبي تاني']));

/* ---------------- القرآن ---------------- */
const DEFAULT_MEM = { fedaa: range(65, 114), nour: [103, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114] };
function range(a, b) { const r = []; for (let i = a; i <= b; i++) r.push(i); return r; }
const surah = (n) => S.data.surahs.find((s) => s.n === n);
const pool = (min = 3) => store.get(`mem_${S.child}`, DEFAULT_MEM[S.child]).map(surah).filter((s) => s && s.ayahs.length >= min);
const ref = (s, i) => ({ s: s.n, a: i + 1, text: s.ayahs[i], name: s.name });
const words = (t) => t.split(/\s+/).filter(Boolean);

/* ---------------- مؤثرات ---------------- */
function confetti(n = 60) {
  const box = document.getElementById('confetti');
  const colors = ['#ff6f9c', '#4fb3e8', '#ffd54f', '#4caf50', '#a463e8', '#ff9f43'];
  for (let i = 0; i < n; i++) {
    const c = document.createElement('i');
    c.style.left = `${Math.random() * 100}%`; c.style.background = pick(colors);
    c.style.animationDuration = `${1.6 + Math.random() * 1.6}s`; c.style.animationDelay = `${Math.random() * 0.4}s`;
    box.appendChild(c); setTimeout(() => c.remove(), 3800);
  }
}
function flash(art) {
  const f = $(`<div class="feedback"><img src="${A(art)}"></div>`);
  document.body.appendChild(f); setTimeout(() => f.remove(), 1400);
}
const cheer = () => { flash(kid().art); confetti(24); };
const hmm = () => flash('lamaa_think');

/* ---------------- الألعاب ---------------- */
const SHELVES = [['all', 'الكل'], ['quran', 'قرآني'], ['letters', 'حروف وأرقام'], ['move', 'حركة'], ['memory', 'ذاكرة']];
const GAMES = [];
const game = (g) => GAMES.push(g);

/* 1) رتّبي الآيات */
game({
  id: 'order', title: 'رتّبي الآيات', desc: 'اضغطي الآيات بترتيبها الصحيح', shelf: 'quran', color: 'c-orange', art: 'pic_puzzle', who: ['fedaa'], rounds: 4,
  intro: 'رتّبي الآيات: اضغطي على الآية الأولى ثم التي بعدها',
  round(ui) {
    let list;
    for (let t = 0; t < 40; t++) {
      const s = pick(pool(3)); const n = Math.min(s.ayahs.length, 3 + rnd(2)); const st = rnd(s.ayahs.length - n + 1);
      list = range(st, st + n - 1).map((i) => ref(s, i));
      if (list.reduce((x, r) => x + r.text.length, 0) <= 240) break;
    }
    let mixed = shuffle(list); while (mixed.every((r, i) => r === list[i])) mixed = shuffle(list);
    return new Promise((done) => {
      ui.stage.append($(`<div class="label">سورة ${esc(list[0].name)}</div>`));
      const slots = $('<div class="slots"></div>');
      list.forEach((_, i) => slots.append($(`<div class="slot"><b>${i + 1}</b><span></span></div>`)));
      ui.stage.append(slots);
      let placed = 0; let slips = 0;
      mixed.forEach((r) => {
        const o = $(`<button class="opt"><span class="mini sb"><img src="${A('ic_sound')}"></span><span>${esc(r.text)}</span></button>`);
        o.querySelector('.sb').onclick = (e) => { e.stopPropagation(); stopAll(); recite(r.s, r.a); };
        o.onclick = async () => {
          if (o.disabled) return;
          if (r === list[placed]) {
            o.disabled = true; o.style.display = 'none'; slips = 0;
            const sl = slots.children[placed]; sl.classList.add('full'); sl.querySelector('span').textContent = r.text;
            placed++; stopAll(); recite(r.s, r.a);
            if (placed === list.length) { cheer(); await sleep(400); await praise(); done(); }
          } else {
            slips++; hmm(); stopAll(); tryAgain();
            if (slips >= 2) [...ui.stage.querySelectorAll('.opt')].forEach((b) => { if (b.querySelector('span:last-child').textContent === list[placed].text) b.classList.add('hint'); });
          }
        };
        ui.stage.append(o);
      });
    });
  },
});

/* 2) أكملي الآية */
game({
  id: 'next', title: 'أكملي الآية', desc: 'اسمعي الآية واختاري اللي بعدها', shelf: 'quran', color: 'c-sky', art: 'pic_headphones', who: ['fedaa'], rounds: 5,
  intro: 'اسمعي الآية، وبعدين اختاري الآية التي بعدها',
  round(ui) {
    const s = pick(pool(3)); const i = rnd(s.ayahs.length - 1); const heard = ref(s, i); const right = ref(s, i + 1);
    const others = shuffle(range(0, s.ayahs.length - 1).filter((k) => k !== i && k !== i + 1)).slice(0, 2).map((k) => ref(s, k));
    while (others.length < 2) { const o = pick(pool(3)); const r = ref(o, rnd(o.ayahs.length)); if (o.n !== s.n) others.push(r); }
    const opts = shuffle([right, ...others]);
    return askChoice(ui, {
      head: `<div class="label">سورة ${esc(s.name)}</div>`,
      prompt: heard.text, onPrompt: () => recite(heard.s, heard.a), autoPrompt: true,
      options: opts.map((r) => ({ html: esc(r.text), right: r === right, hear: () => recite(r.s, r.a) })),
    });
  },
});

/* 3) الكلمة الناقصة */
game({
  id: 'missing', title: 'الكلمة الناقصة', desc: 'كلمة اختفت من الآية… لاقيها', shelf: 'quran', color: 'c-purple', art: 'pic_magnifier', who: ['fedaa'], rounds: 5,
  intro: 'اسمعي الآية واختاري الكلمة الناقصة',
  round(ui) {
    let s; let i; let ws;
    for (let t = 0; t < 50; t++) { s = pick(pool(2)); i = rnd(s.ayahs.length); ws = words(s.ayahs[i]); if (ws.length >= 3 && ws.length <= 12) break; }
    const k = 1 + rnd(ws.length - 1); const answer = ws[k];
    const bag = new Set();
    for (let t = 0; t < 60 && bag.size < 2; t++) { const o = pick(pool(2)); const w = pick(words(pick(o.ayahs))); if (w !== answer && w.length >= 2) bag.add(w); }
    const shown = ws.map((w, j) => (j === k ? '<span style="color:#ff6f9c">ـــــ</span>' : esc(w))).join(' ');
    return askChoice(ui, {
      head: `<div class="label">سورة ${esc(s.name)}</div>`,
      promptHtml: shown, onPrompt: () => recite(s.n, i + 1), autoPrompt: true,
      options: shuffle([answer, ...bag]).map((w) => ({ html: esc(w), right: w === answer })),
      after: () => { ui.stage.querySelector('.q').innerHTML = esc(ws.join(' ')); },
    });
  },
});

/* 4) فرقعة البالونات */
game({
  id: 'balloons', title: 'فرقعة البالونات', desc: 'فرقعي كلمات الآية بالترتيب', shelf: 'move', color: 'c-pink', art: 'pic_balloon', who: ['fedaa'], rounds: 3,
  intro: 'فرقعي البالونات بترتيب كلمات الآية',
  round(ui) {
    let s; let i; let ws;
    for (let t = 0; t < 60; t++) { s = pick(pool(2)); i = rnd(s.ayahs.length); ws = words(s.ayahs[i]); if (ws.length >= 3 && ws.length <= 6) break; }
    ws = ws.slice(0, 6);
    return new Promise((done) => {
      ui.stage.append($(`<div class="prompt-row"><button class="sound-btn"><img src="${A('ic_sound')}"></button><div class="q" id="built">…</div></div>`));
      ui.stage.querySelector('.sound-btn').onclick = () => { stopAll(); recite(s.n, i + 1); };
      recite(s.n, i + 1);
      const sky = $('<div class="sky"></div>'); ui.stage.append(sky);
      const colors = ['#ff6f9c', '#4fb3e8', '#ffb300', '#4caf50', '#a463e8', '#ff8f3a'];
      let next = 0; const built = [];
      const bs = shuffle(ws.map((w, j) => ({ w, j }))).map((b, n) => {
        const el = $(`<div class="balloon"><div class="ball" style="background:${colors[n % 6]}">${esc(b.w)}</div><div class="str"></div></div>`);
        b.el = el; b.x = 8 + (n % 3) * 30 + Math.random() * 6; b.y = 100 + n * 22 + Math.random() * 20; b.v = 0.12 + Math.random() * 0.08;
        el.onclick = async () => {
          if (b.gone) return;
          if (b.j === next) {
            b.gone = true; el.classList.add('pop'); built.push(b.w); next++;
            ui.stage.querySelector('#built').textContent = built.join(' ');
            if (next === ws.length) { cancelAnimationFrame(raf); cheer(); await praise(); done(); }
          } else { hmm(); el.animate([{ transform: 'rotate(-12deg)' }, { transform: 'rotate(12deg)' }, { transform: 'none' }], 300); tryAgain(); }
        };
        sky.append(el); return b;
      });
      let raf; let last = performance.now();
      const tick = (now) => {
        const dt = Math.min(50, now - last); last = now;
        bs.forEach((b) => { if (b.gone) return; b.y -= b.v * dt / 16 * 0.9; if (b.y < -40) b.y = 110; b.el.style.right = `${b.x}%`; b.el.style.top = `${b.y}%`; });
        raf = requestAnimationFrame(tick);
      };
      raf = requestAnimationFrame(tick);
      ui.onLeave(() => cancelAnimationFrame(raf));
    });
  },
});

/* 5) قطار الكلمات */
game({
  id: 'train', title: 'قطار الكلمات', desc: 'رتّبي كلمات الآية في عربات القطار', shelf: 'quran', color: 'c-teal', art: 'pic_firetruck', who: ['fedaa'], rounds: 4,
  intro: 'رتّبي كلمات الآية في عربات القطار',
  round(ui) {
    let s; let i; let ws;
    for (let t = 0; t < 60; t++) { s = pick(pool(2)); i = rnd(s.ayahs.length); ws = words(s.ayahs[i]); if (ws.length >= 3 && ws.length <= 7) break; }
    return new Promise((done) => {
      ui.stage.append($(`<div class="prompt-row"><button class="sound-btn pulse"><img src="${A('ic_sound')}"></button><div class="q">اسمعي ورتّبي</div></div>`));
      ui.stage.querySelector('.sound-btn').onclick = () => { stopAll(); recite(s.n, i + 1); };
      recite(s.n, i + 1);
      const train = $(`<div class="train"><div class="engine" style="font-size:58px">🚂</div></div>`); ui.stage.append(train);
      const box = $('<div class="words"></div>'); ui.stage.append(box);
      let next = 0;
      shuffle(ws.map((w, j) => ({ w, j }))).forEach((b) => {
        const el = $(`<button class="word">${esc(b.w)}</button>`);
        el.onclick = async () => {
          if (b.j === next) {
            el.classList.add('used'); train.append($(`<div class="car">${esc(b.w)}</div>`)); next++;
            if (next === ws.length) { stopAll(); recite(s.n, i + 1); cheer(); await praise(); done(); }
          } else { hmm(); tryAgain(); }
        };
        box.append(el);
      });
    });
  },
});

/* 6) البطاقات المقلوبة */
game({
  id: 'memory', title: 'البطاقات المقلوبة', desc: 'اقلبي بطاقتين: بداية الآية ونهايتها', shelf: 'memory', color: 'c-pink', art: 'pic_cards', who: ['fedaa'], rounds: 2,
  intro: 'اقلبي بطاقتين: بداية الآية ونهايتها',
  round(ui) {
    const pairs = []; const seen = new Set();
    for (let t = 0; t < 80 && pairs.length < 3; t++) {
      const s = pick(pool(2)); const i = rnd(s.ayahs.length); const ws = words(s.ayahs[i]);
      if (ws.length < 4 || ws.length > 10 || seen.has(`${s.n}:${i}`)) continue;
      seen.add(`${s.n}:${i}`); const h = Math.ceil(ws.length / 2);
      pairs.push({ id: pairs.length, s: s.n, a: i + 1, start: ws.slice(0, h).join(' ') + ' …', end: '… ' + ws.slice(h).join(' ') });
    }
    const cards = shuffle(pairs.flatMap((p) => [{ p, t: p.start }, { p, t: p.end }]));
    return new Promise((done) => {
      const grid = $('<div class="memory"></div>'); ui.stage.append(grid);
      let open = []; let matched = 0;
      cards.forEach((c) => {
        const el = $(`<div class="mcard"><div class="in"><div class="f"><img src="${A('star_on')}"></div><div class="b">${esc(c.t)}</div></div></div>`);
        c.el = el;
        el.onclick = async () => {
          if (el.classList.contains('flip') || open.length === 2) return;
          el.classList.add('flip'); open.push(c);
          if (open.length < 2) return;
          const [x, y] = open;
          if (x.p === y.p) {
            x.el.classList.add('done'); y.el.classList.add('done'); open = []; matched++;
            stopAll(); recite(x.p.s, x.p.a); cheer();
            if (matched === pairs.length) { await sleep(900); await praise(); done(); }
          } else { await sleep(900); x.el.classList.remove('flip'); y.el.classList.remove('flip'); open = []; }
        };
        grid.append(el);
      });
    });
  },
});

/* 7) خمّني السورة */
game({
  id: 'which', title: 'خمّني السورة', desc: 'اسمعي الشيخ واعرفي اسم السورة', shelf: 'quran', color: 'c-green', art: 'sec_quran', who: ['fedaa'], rounds: 5,
  intro: 'اسمعي الآية، من أي سورة هي؟',
  round(ui) {
    const ps = pool(1); const s = pick(ps); const i = rnd(s.ayahs.length);
    const names = shuffle([s, ...shuffle(ps.filter((x) => x.n !== s.n)).slice(0, 2)]);
    return askChoice(ui, {
      prompt: '🎧', onPrompt: () => recite(s.n, i + 1), autoPrompt: true,
      options: names.map((x) => ({ html: `سورة ${esc(x.name)}`, right: x === s })),
    });
  },
});

/* 8) ابني المسجد */
game({
  id: 'mosque', title: 'ابني المسجد', desc: 'كل إجابة صح تبني جزء من المسجد', shelf: 'quran', color: 'c-orange', art: 'sec_prayer', who: ['fedaa'], rounds: 6,
  intro: 'كل إجابة صحيحة تبني جزءًا من المسجد',
  setup(ui) {
    ui.mosque = $(`<div class="mosque"><svg viewBox="0 0 300 220" width="300" height="220">
      <g class="part"><rect x="20" y="190" width="260" height="22" rx="6" fill="#c98e4b"/></g>
      <g class="part"><rect x="70" y="110" width="160" height="82" rx="6" fill="#fffaf0" stroke="#e8a957" stroke-width="4"/></g>
      <g class="part"><path d="M135 192 v-38 a15 15 0 0 1 30 0 v38z" fill="#2a9d8f"/></g>
      <g class="part"><path d="M95 112 a55 55 0 0 1 110 0z" fill="#4caf50"/><circle cx="150" cy="52" r="5" fill="#ffd54f"/></g>
      <g class="part"><rect x="34" y="70" width="22" height="122" rx="4" fill="#fffaf0" stroke="#e8a957" stroke-width="3"/><path d="M30 72 l15 -26 l15 26z" fill="#4caf50"/></g>
      <g class="part"><rect x="244" y="70" width="22" height="122" rx="4" fill="#fffaf0" stroke="#e8a957" stroke-width="3"/><path d="M240 72 l15 -26 l15 26z" fill="#4caf50"/></g>
    </svg></div>`);
  },
  round(ui, n) {
    ui.stage.append(ui.mosque);
    const s = pick(pool(3)); const i = rnd(s.ayahs.length - 1); const heard = ref(s, i); const right = ref(s, i + 1);
    let other = ref(s, (i + 2) % s.ayahs.length); if (other.a === heard.a) other = ref(s, 0);
    return askChoice(ui, {
      prompt: heard.text, onPrompt: () => recite(heard.s, heard.a), autoPrompt: true, keep: true,
      options: shuffle([right, other]).map((r) => ({ html: esc(r.text), right: r === right, hear: () => recite(r.s, r.a) })),
    }).then(() => { ui.mosque.querySelectorAll('.part')[n].classList.add('on'); });
  },
  finishSay: 'بنيتِ المسجد كله! ما شاء الله',
});

/* 9) اسمعي واجمعي النجوم */
game({
  id: 'listen', title: 'اسمعي واجمعي النجوم', desc: 'اسمعي السورة من الشيخ وكل آية بنجمة', shelf: 'quran', color: 'c-sky', art: 'star_on', who: ['nour', 'fedaa'], rounds: 1,
  intro: 'اسمعي السورة واجمعي النجوم',
  round(ui) {
    const short = pool(1).filter((s) => s.ayahs.length <= 11);
    const s = pick(short.length ? short : pool(1));
    return new Promise((done) => {
      ui.stage.append($(`<div class="label">سورة ${esc(s.name)}</div>`));
      const box = $('<div class="listen-stars"></div>'); ui.stage.append(box);
      const stars = s.ayahs.map(() => { const im = $(`<img src="${A('star_on')}">`); box.append(im); return im; });
      ui.stage.append($(`<div class="prompt-row"><img src="${A('lamaa_point')}" style="width:80px"><div class="q">اضغطي على النجمة اللامعة</div></div>`));
      let k = 0;
      const step = async () => {
        if (k >= s.ayahs.length) { cheer(); await praise(); done(); return; }
        const ok = await recite(s.n, k + 1);
        if (!ok || !ui.alive()) return;
        const st = stars[k]; st.classList.add('on'); st.style.animation = 'pulse 1s infinite';
        st.onclick = () => { st.style.animation = ''; st.onclick = null; k++; confetti(10); step(); };
      };
      step();
    });
  },
});

/* 10) صيد الحروف */
game({
  id: 'letters', title: 'صيد الحروف', desc: 'اسمعي الكلمة واختاري صورتها', shelf: 'letters', color: 'c-green', art: 'let_01', who: ['nour', 'fedaa'], rounds: 6,
  intro: 'اسمعي الكلمة واختاري صورتها',
  round(ui) {
    const L = S.data.letters; const right = pick(L);
    const opts = shuffle([right, ...shuffle(L.filter((x) => x !== right)).slice(0, 3)]);
    return askPics(ui, { word: right.word, options: opts.map((x) => ({ art: x.art, right: x === right, badge: S.child === 'fedaa' ? x.letter : '' })) });
  },
});

/* 11) أين الصورة؟ */
game({
  id: 'where', title: 'أين الصورة؟', desc: 'اسمعي واضغطي على الصورة', shelf: 'letters', color: 'c-purple', art: 'pic_lion', who: ['nour', 'fedaa'], rounds: 6,
  intro: 'اسمعي واضغطي على الصورة',
  round(ui) {
    const P = S.data.pics; const right = pick(P);
    const opts = shuffle([right, ...shuffle(P.filter((x) => x !== right)).slice(0, 3)]);
    return askPics(ui, { word: right.word, options: opts.map((x) => ({ art: x.art, right: x === right })) });
  },
});

/* 12) عدّي معايا */
game({
  id: 'count', title: 'عدّي معايا', desc: 'عدّي الصور واختاري الرقم', shelf: 'letters', color: 'c-orange', art: 'pic_abacus', who: ['nour', 'fedaa'], rounds: 5,
  intro: 'عدّي الصور واختاري الرقم',
  round(ui) {
    const max = S.child === 'nour' ? 5 : 10; const n = 1 + rnd(max); const art = pick(['pic_strawberry', 'pic_orange', 'pic_balloon', 'pic_ball', 'pic_cookie', 'let_03', 'star_on']);
    const nums = new Set([n]); while (nums.size < 3) nums.add(1 + rnd(max));
    return new Promise((done) => {
      const row = $('<div class="count-row"></div>'); for (let i = 0; i < n; i++) row.append($(`<img src="${A(art)}">`)); ui.stage.append(row);
      const grid = $('<div class="nums"></div>'); ui.stage.append(grid);
      let tries = 0;
      [...nums].sort((a, b) => a - b).forEach((x) => {
        const b = $(`<button class="num">${x.toLocaleString('ar-EG')}</button>`);
        b.onclick = async () => {
          if (b.classList.contains('tried')) return;
          stopAll(); await say(String(x));
          if (x === n) { b.classList.add('right'); cheer(); await praise(); done(); } else { b.classList.add('tried'); tries++; hmm(); tryAgain(); }
        };
        grid.append(b);
      });
    });
  },
});

/* ---------------- أدوات الجولات ---------------- */
/** سؤال باختيارات نصية: صح → مديح، غيره → «جرّبي مرة ثانية» (بلا خصم)، وبعد محاولتين يلمع الصح. */
function askChoice(ui, o) {
  return new Promise((done) => {
    if (o.head) ui.stage.append($(o.head));
    const row = $(`<div class="prompt-row"><button class="sound-btn pulse"><img src="${A('ic_sound')}"></button><div class="q">${o.promptHtml || esc(o.prompt)}</div></div>`);
    row.querySelector('.sound-btn').onclick = () => { stopAll(); o.onPrompt(); };
    ui.stage.append(row);
    if (o.autoPrompt) o.onPrompt();
    let tries = 0; const btns = [];
    o.options.forEach((op) => {
      const b = $(`<button class="opt">${op.hear ? `<span class="mini sb"><img src="${A('ic_sound')}"></span>` : ''}<span>${op.html}</span></button>`);
      if (op.hear) b.querySelector('.sb').onclick = (e) => { e.stopPropagation(); stopAll(); op.hear(); };
      b.onclick = async () => {
        if (b.classList.contains('tried') || b.classList.contains('right')) return;
        if (op.right) {
          b.classList.add('right'); btns.forEach((x) => { x.disabled = true; }); if (o.after) o.after();
          cheer(); stopAll(); await praise(); await sleep(300); done();
        } else {
          b.classList.add('tried'); tries++; hmm(); stopAll(); tryAgain();
          if (tries >= 2) btns.forEach((x, k) => { if (o.options[k].right) x.classList.add('hint'); });
        }
      };
      btns.push(b); ui.stage.append(b);
    });
  });
}
/** سؤال بالصور: تسمع الكلمة وتضغط صورتها. */
function askPics(ui, o) {
  return new Promise((done) => {
    const row = $(`<div class="prompt-row"><button class="sound-btn pulse"><img src="${A('ic_sound')}"></button><div class="q">${S.child === 'fedaa' ? esc(o.word) : '👂'}</div></div>`);
    row.querySelector('.sound-btn').onclick = () => { stopAll(); say(o.word); };
    ui.stage.append(row); say(o.word);
    const grid = $('<div class="pics"></div>'); ui.stage.append(grid);
    let tries = 0; const btns = [];
    o.options.forEach((op) => {
      const b = $(`<button class="pic"><img src="${A(op.art)}">${op.badge ? `<span class="big" style="position:absolute;font-size:34px;color:#1c5fa8;margin-top:-70%">${esc(op.badge)}</span>` : ''}</button>`);
      b.style.position = 'relative';
      b.onclick = async () => {
        if (b.classList.contains('tried') || b.classList.contains('right')) return;
        if (op.right) { b.classList.add('right'); cheer(); stopAll(); await praise(); done(); } else {
          b.classList.add('tried'); tries++; hmm(); stopAll(); await tryAgain(); say(o.word);
          if (tries >= 2) btns.forEach((x, k) => { if (o.options[k].right) x.classList.add('hint'); });
        }
      };
      btns.push(b); grid.append(b);
    });
  });
}

/* ---------------- شاشة اللعبة ---------------- */
async function openGame(g) {
  stopAll();
  const bg = pick(['bg_sky', 'bg_forest', 'bg_river', 'bg_path', 'bg_castle']);
  const scr = $(`<div class="screen" style="background-image:url(${A(bg)})">
    <div class="bar"><button class="round-btn back"><img src="${A('ic_home')}"></button><h2>${esc(g.title)}</h2><span style="width:54px"></span></div>
    <div class="progress"></div><div class="stage"></div></div>`);
  document.body.appendChild(scr);
  let alive = true; const leave = [];
  const ui = { stage: scr.querySelector('.stage'), alive: () => alive, onLeave: (f) => leave.push(f) };
  const close = () => { alive = false; leave.forEach((f) => f()); stopAll(); scr.remove(); render(); };
  scr.querySelector('.back').onclick = close;
  const prog = scr.querySelector('.progress');
  for (let i = 0; i < g.rounds; i++) prog.append($(`<img class="off" src="${A('star_on')}">`));
  if (g.setup) g.setup(ui);
  await say(g.intro);
  for (let n = 0; n < g.rounds; n++) {
    if (!alive) return;
    ui.stage.innerHTML = '';
    await g.round(ui, n);
    if (!alive) return;
    const st = prog.children[n]; st.classList.remove('off'); st.animate([{ transform: 'scale(1.6)' }, { transform: 'none' }], 400);
    await sleep(500);
  }
  if (!alive) return;
  store.set(starsKey(), store.get(starsKey(), 0) + g.rounds);
  store.set(gameKey(g.id), Math.min(3, store.get(gameKey(g.id), 0) + 1));
  ui.stage.innerHTML = '';
  const box = $(`<div class="done-box"><img class="m" src="${A('lamaa_cheer')}"><h2>أحسنتِ يا ${esc(kid().name)}!</h2>
    <div class="progress" style="padding:0">${`<img src="${A('star_on')}">`.repeat(g.rounds)}</div>
    <div class="row"><button class="again"><img src="${A('ic_repeat')}"></button><button class="home"><img src="${A('ic_done')}"></button></div></div>`);
  if (g.id === 'mosque') box.prepend(ui.mosque);
  ui.stage.append(box); confetti(90);
  box.querySelector('.again').onclick = () => { close(); openGame(g); };
  box.querySelector('.home').onclick = close;
  await say(g.finishSay || 'أحسنتِ! جمعتِ كل النجوم');
}

/* ---------------- الحكايات ---------------- */
function openVideo(v) {
  stopAll();
  const p = $(`<div class="player"><div class="bar"><button class="round-btn back"><img src="${A('ic_home')}"></button><h2>${esc(v.title)}</h2><span style="width:54px"></span></div>
    <video src="videos/${esc(v.file)}" poster="videos/${esc(v.cover)}" controls autoplay playsinline></video></div>`);
  document.body.appendChild(p);
  p.querySelector('.back').onclick = () => { p.querySelector('video').pause(); p.remove(); };
}

/* ---------------- الواجهة الرئيسية ---------------- */
function render() {
  const app = document.getElementById('app');
  const k = kid();
  const stars = store.get(starsKey(), 0);
  app.innerHTML = '';
  const hero = $(`<header class="hero">
    <div class="topbar">
      <div class="logo"><img src="${A('lamaa_cheer')}"></div>
      <div class="brand"><h1>العب مع لمعة</h1><small>عالم نور وفداء</small></div>
      <span class="spacer"></span>
      <div class="stars-chip"><img src="${A('star_on')}"><span>${stars.toLocaleString('ar-EG')}</span></div>
      <button class="kid-btn" style="border-color:${k.color}"><img src="${A(k.art)}"></button>
    </div>
    <div class="hero-body">
      <div style="flex:1"><h2>العبي واحفظي<br>مع <span>لمعة</span></h2><p>ألعاب وحكايات من محفوظك ومن عالم نور وفداء</p></div>
      <img class="hero-mascot" src="${A('lamaa_welcome')}">
    </div>
    <div class="tabs">
      <button class="tab ${S.tab === 'games' ? 'on' : ''}" data-t="games"><img src="${A('pic_gamepad')}">الألعاب</button>
      <button class="tab ${S.tab === 'videos' ? 'on' : ''}" data-t="videos"><img src="${A('ic_play')}">الحكايات</button>
    </div></header>`);
  hero.querySelector('.kid-btn').onclick = () => chooseKid(true);
  hero.querySelectorAll('.tab').forEach((t) => { t.onclick = () => { S.tab = t.dataset.t; render(); say(S.tab === 'games' ? 'اختاري لعبة' : 'حكايات نور وفداء'); }; });
  app.append(hero);
  if (S.tab === 'games') renderGames(app); else renderVideos(app);
  buddy();
}

function renderGames(app) {
  const mine = GAMES.filter((g) => g.who.includes(S.child));
  const shelves = SHELVES.filter(([id]) => id === 'all' || mine.some((g) => g.shelf === id));
  const list = mine.filter((g) => S.shelf === 'all' || g.shelf === S.shelf);
  app.append($(`<div class="section-title"><h2>كل الألعاب</h2><span>${mine.length.toLocaleString('ar-EG')} لعبة</span></div>`));
  const chips = $('<div class="chips"></div>');
  shelves.forEach(([id, label]) => {
    const c = $(`<button class="chip ${S.shelf === id ? 'on' : ''}">${label}</button>`);
    c.onclick = () => { S.shelf = id; render(); say(label); }; chips.append(c);
  });
  app.append(chips);
  const grid = $('<div class="grid"></div>');
  list.forEach((g) => {
    const best = store.get(gameKey(g.id), 0);
    const tag = SHELVES.find(([id]) => id === g.shelf)[1];
    const c = $(`<button class="card"><div class="art ${g.color}"><span class="tag">${tag}</span>${best ? '' : '<span class="new">جديدة</span>'}
      <img src="${A(g.art)}"><span class="stars">${`<img src="${A('star_on')}">`.repeat(best)}</span></div>
      <div class="txt"><h3>${esc(g.title)}</h3><p>${esc(g.desc)}</p></div></button>`);
    c.onclick = () => openGame(g);
    grid.append(c);
  });
  app.append(grid);
}

function renderVideos(app) {
  app.append($(`<div class="section-title"><h2>الحكايات</h2><span>${S.videos.length.toLocaleString('ar-EG')} حكاية</span></div>`));
  if (!S.videos.length) {
    app.append($(`<div class="empty"><img src="${A('lamaa_think')}">الحكايات الجديدة في الطريق إن شاء الله</div>`));
    return;
  }
  const grid = $('<div class="vgrid"></div>');
  S.videos.forEach((v) => {
    const c = $(`<button class="vcard"><div class="cover" style="background-image:url(videos/${esc(v.cover)})"></div><h3>${esc(v.title)}</h3></button>`);
    c.onclick = () => openVideo(v); grid.append(c);
  });
  app.append(grid);
}

/* لمعة العائمة: تتسحب لأي مكان، وبالضغط تقول جملة. */
function buddy() {
  if (document.querySelector('.buddy')) return;
  const b = $(`<img class="buddy" src="${A('lamaa_point')}">`);
  const pos = store.get('buddy', { x: 14, y: window.innerHeight - 140 });
  b.style.left = `${pos.x}px`; b.style.top = `${pos.y}px`;
  document.body.appendChild(b);
  let drag = null; let moved = false;
  b.addEventListener('pointerdown', (e) => { drag = { dx: e.clientX - b.offsetLeft, dy: e.clientY - b.offsetTop }; moved = false; b.setPointerCapture(e.pointerId); });
  b.addEventListener('pointermove', (e) => {
    if (!drag) return; moved = true;
    const x = Math.max(0, Math.min(window.innerWidth - 86, e.clientX - drag.dx)); const y = Math.max(0, Math.min(window.innerHeight - 100, e.clientY - drag.dy));
    b.style.left = `${x}px`; b.style.top = `${y}px`;
  });
  b.addEventListener('pointerup', () => {
    if (drag && moved) store.set('buddy', { x: b.offsetLeft, y: b.offsetTop });
    if (drag && !moved) { stopAll(); say(S.tab === 'games' ? 'اختاري لعبة' : 'اختاري حكاية'); }
    drag = null;
  });
}

function chooseKid(force) {
  const w = $(`<div class="who"><img src="${A('lamaa_welcome')}" style="width:130px"><h1>من ستلعب اليوم؟</h1>
    <div class="kids"><button class="kid f" data-k="fedaa"><img src="${A('fedaa_cheer')}"><h2>فداء</h2></button>
    <button class="kid n" data-k="nour"><img src="${A('nour_cheer')}"><h2>نور</h2></button></div></div>`);
  w.querySelectorAll('.kid').forEach((b) => {
    b.onclick = () => { S.child = b.dataset.k; store.set('child', S.child); S.shelf = 'all'; w.remove(); render(); say(`أهلًا يا ${kid().name}! هيا نلعب`); };
  });
  document.body.appendChild(w);
  if (force) say('من ستلعب اليوم؟');
}

/* ---------------- البداية ---------------- */
async function boot() {
  const j = (u, d) => fetch(u, { cache: 'no-cache' }).then((r) => (r.ok ? r.json() : d)).catch(() => d);
  const [quran, phrases, voice, vids] = await Promise.all([
    j('data/quran.json', null), j('phrases.json', { letters: [], pics: [] }), j('voice/index.json', {}), j('videos/manifest.json', { videos: [] }),
  ]);
  if (!quran) { document.getElementById('app').innerHTML = `<div class="empty"><img src="${A('lamaa_think')}">لا يوجد إنترنت الآن</div>`; return; }
  S.data = { ...quran, letters: phrases.letters, pics: phrases.pics };
  S.voice = voice; S.videos = vids.videos || [];
  const q = new URLSearchParams(location.search).get('child');
  S.child = KIDS[q] ? q : store.get('child', null);
  if (KIDS[q]) store.set('child', q);
  if (!S.child) { S.child = 'fedaa'; render(); chooseKid(true); return; }
  render();
}
window.addEventListener('DOMContentLoaded', boot);
