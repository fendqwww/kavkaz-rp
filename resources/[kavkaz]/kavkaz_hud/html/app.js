// KAVKAZ RP — HUD. данные шлёт client.lua через SendNUIMessage
const $ = (id) => document.getElementById(id);
const hud = $('hud');
const root = document.documentElement.style;
const money = (n) => Math.round(Number(n) || 0).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ' ');

/* ================= спидометр «А»: дуга 240°, цифры барабаном ================= */
const MAX_SPEED = 240;
const CX = 190, CY = 165, R = 150, A0 = 150, A1 = 390;
const pt = (a, r) => [CX + r * Math.cos(a * Math.PI / 180), CY + r * Math.sin(a * Math.PI / 180)];
const arc = (a0, a1, r) => {
  const [x0, y0] = pt(a0, r), [x1, y1] = pt(a1, r);
  return `M${x0.toFixed(1)} ${y0.toFixed(1)} A${r} ${r} 0 ${a1 - a0 > 180 ? 1 : 0} 1 ${x1.toFixed(1)} ${y1.toFixed(1)}`;
};
(function dial() {
  $('d-track').setAttribute('d', arc(A0, A1, R));
  $('d-red').setAttribute('d', arc(A0 + (A1 - A0) * 0.84, A1, R));
  $('d-fill').setAttribute('d', arc(A0, A1, R));
  $('d-rpm').setAttribute('d', arc(A0, A1, R - 13));
  const ns = 'http://www.w3.org/2000/svg';
  const g = $('d-ticks');
  for (let v = 0; v <= MAX_SPEED; v += 10) {
    const a = A0 + (A1 - A0) * v / MAX_SPEED, big = v % 40 === 0;
    const [x0, y0] = pt(a, R + 6), [x1, y1] = pt(a, R + (big ? 18 : 12));
    const l = document.createElementNS(ns, 'line');
    l.setAttribute('x1', x0); l.setAttribute('y1', y0); l.setAttribute('x2', x1); l.setAttribute('y2', y1);
    if (big) l.setAttribute('class', 'big');
    g.appendChild(l);
    if (big) {
      const [tx, ty] = pt(a, R + 32);
      const t = document.createElementNS(ns, 'text');
      t.setAttribute('x', tx); t.setAttribute('y', ty); t.textContent = v;
      g.appendChild(t);
    }
  }
})();

// барабан: 3 колонки, в каждой 0…9 и снова 0 — так переход 9 → 0 крутится вперёд, без отката
const cols = [];
(function reel() {
  for (let i = 0; i < 3; i++) {
    const col = document.createElement('div'); col.className = 'col';
    const strip = document.createElement('div'); strip.className = 'strip';
    strip.innerHTML = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0].map((d) => `<span>${d}</span>`).join('');
    col.appendChild(strip); $('reel').appendChild(col);
    cols.push({ col, strip });
  }
})();

let target = 0, shown = 0, targetRpm = 0, shownRpm = 0, lastT = 0, speedoOn = false, rafId = 0;

// положение колонки как у механического счётчика: единицы крутятся плавно,
// десятки и сотни поворачиваются только на последнем «километре» перед сменой
function wheel(v) {
  const u = v % 10;
  const carry = Math.max(0, u - 9);              // 0…1, пока единицы идут от 9 к 10
  const t = Math.floor(v / 10) % 10;
  const h = Math.floor(v / 100) % 10;
  return [h + (t === 9 ? carry : 0), t + carry, u];
}

function draw() {
  const v = Math.max(0, Math.min(999, shown));
  const pos = wheel(v);
  const h = cols[0].col.offsetHeight || 1;
  for (let i = 0; i < 3; i++) cols[i].strip.style.transform = `translate3d(0, ${(-pos[i] * h).toFixed(2)}px, 0)`;
  const r = Math.round(v);
  cols[0].col.classList.toggle('lead', r < 100);
  cols[1].col.classList.toggle('lead', r < 10);
  $('d-fill').setAttribute('stroke-dasharray', `${(Math.min(1, v / MAX_SPEED) * 1000).toFixed(1)} 1000`);
  $('d-rpm').setAttribute('stroke-dasharray', `${(shownRpm * 1000).toFixed(1)} 1000`);
}

// плавность: показываем не скачок к новому числу, а догоняем его с затуханием (~0,12 с)
function frame(t) {
  const dt = lastT ? Math.min(100, t - lastT) : 16;
  lastT = t;
  const k = 1 - Math.exp(-dt / 120);
  shown += (target - shown) * k;
  shownRpm += (targetRpm - shownRpm) * (1 - Math.exp(-dt / 70));
  if (Math.abs(target - shown) < 0.01) shown = target;
  draw();
  rafId = speedoOn ? requestAnimationFrame(frame) : 0;
}
function speedo(show) {
  speedoOn = show;
  $('speedo').classList.toggle('off', !show);
  if (show && !rafId) { lastT = 0; rafId = requestAnimationFrame(frame); }
  if (!show) { target = shown = 0; targetRpm = shownRpm = 0; draw(); }
}

function onVeh(d) {
  target = Math.min(999, Math.max(0, d.speed));
  targetRpm = Math.max(0, Math.min(1, d.rpm));
  $('d-rpm').classList.toggle('hot', d.rpm >= 0.88);

  const gear = $('gear');
  gear.textContent = d.gear === '' ? 'N' : d.gear;
  gear.className = 'gear' + (d.gear === '' ? ' hide' : d.gear === 'N' ? ' n' : d.gear === 'R' ? ' r' : '');

  const fuel = $('fuel');
  fuel.classList.toggle('hide', d.fuel < 0);
  fuel.classList.toggle('low', d.fuel >= 0 && d.fuel < 15);
  $('fuel-bar').style.width = Math.max(0, Math.min(100, d.fuel)) + '%';
  $('fuel-val').textContent = Math.max(0, d.fuel) + '%';

  $('v-belt').className = d.belt < 0 ? 'hide' : d.belt === 1 ? 'on' : (d.speed > 15 ? 'bad blink' : 'bad');
  $('v-engine').className = d.engine < 0 ? 'hide' : d.engine === 0 ? 'bad blink' : d.engine === 1 ? 'on' : '';
  $('v-lights').className = d.lights === 2 ? 'warn' : d.lights === 1 ? 'on' : '';
  $('v-lock').className = d.locked ? 'on' : '';
  $('v-lock-ico').setAttribute('href', d.locked ? '#i-lock' : '#i-unlock');
}

/* ================= состояние, время, деньги ================= */
function setStat(id, value, opts = {}) {
  const el = $(id);
  const v = Math.max(0, Math.min(100, Math.round(value)));
  el.querySelector('b').textContent = v;
  el.classList.toggle('low', v <= 20 && !opts.noLow);
  el.classList.toggle('hide', !!opts.hide);
}

function onStatus(d) {
  setStat('s-hp', d.hp);
  setStat('s-armor', d.armor, { hide: d.armor <= 0, noLow: true });
  setStat('s-hunger', d.hunger);
  setStat('s-thirst', d.thirst);
  setStat('s-stress', d.stress, { hide: d.stress < 5, noLow: true });
  setStat('s-oxygen', d.oxygen, { hide: d.oxygen < 0 });
  const v = $('voice');
  v.classList.toggle('talk', !!d.talking);
  v.dataset.r = d.voice || 2;
  $('radio').classList.toggle('hide', !d.radio);
  $('radio-ch').textContent = d.radio ? String(d.radio) : '';
}

function onInfo(d) {
  $('pid').textContent = d.id;
  $('online').textContent = d.online;
  $('slots').textContent = d.slots;
  $('clock').textContent = d.time;
  $('date').textContent = d.date || '';
  $('weekday').textContent = d.weekday || '';
  $('weather').textContent = d.weather || '';
  $('cash').textContent = money(d.cash);
  $('bank').textContent = money(d.bank);
  $('dir').textContent = d.dir;
  $('zone').textContent = d.zone || '';
}

function onPop(d) {
  const el = document.createElement('div');
  el.className = 'pop ' + (d.minus ? 'minus' : 'plus');
  el.innerHTML = `${d.minus ? '−' : '+'}${money(d.amount)}<small>₽ · ${d.kind === 'bank' ? 'карта' : 'наличные'}</small>`;
  $('pops').prepend(el);
  setTimeout(() => el.remove(), 3300);
  const list = $('pops').children;
  while (list.length > 4) list[list.length - 1].remove();
}

function onHints(d) {
  const box = $('hints');
  box.classList.toggle('off', !d.show);
  if (!d.list) return;
  box.innerHTML = '';
  for (const [key, label] of d.list) {
    const row = document.createElement('div');
    row.className = 'h';
    const k = document.createElement('kbd'); k.textContent = key;
    const s = document.createElement('span'); s.textContent = label;
    row.append(k, s);
    box.appendChild(row);
  }
}

function onLayout(d) {
  root.setProperty('--mm-left', d.left * 100 + 'vw');
  root.setProperty('--mm-bottom', d.bottom * 100 + 'vh');
  root.setProperty('--mm-w', d.width * 100 + 'vw');
  root.setProperty('--mm-h', d.height * 100 + 'vh');
}

window.addEventListener('message', (e) => {
  const d = e.data || {};
  switch (d.action) {
    case 'visible': hud.classList.toggle('off', !d.show); break;
    case 'status': onStatus(d); break;
    case 'info': onInfo(d); break;
    case 'veh': onVeh(d); break;
    case 'speedo': speedo(!!d.show); break;
    case 'moneyPop': onPop(d); break;
    case 'hints': onHints(d); break;
    case 'layout': onLayout(d); break;
  }
});

draw();
