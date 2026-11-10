// KAVKAZ RP — HUD. данные шлёт client.lua через SendNUIMessage
const $ = (id) => document.getElementById(id);
const hud = $('hud');
const root = document.documentElement.style;
const money = (n) => Math.round(Number(n) || 0).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ' ');
const MAX_SPEED = 260; // шкала спидометра, км/ч

// деления шкалы скорости: 0 … 260 через 20, подписи через 40
(function ticks() {
  const g = $('ticks');
  const ns = 'http://www.w3.org/2000/svg';
  for (let v = 0; v <= MAX_SPEED; v += 20) {
    const a = (135 + 270 * v / MAX_SPEED) * Math.PI / 180;
    const big = v % 40 === 0;
    const r1 = 91, r2 = big ? 85 : 88;
    const line = document.createElementNS(ns, 'line');
    line.setAttribute('x1', 100 + r1 * Math.cos(a)); line.setAttribute('y1', 100 + r1 * Math.sin(a));
    line.setAttribute('x2', 100 + r2 * Math.cos(a)); line.setAttribute('y2', 100 + r2 * Math.sin(a));
    g.appendChild(line);
    if (big) {
      const t = document.createElementNS(ns, 'text');
      t.setAttribute('x', 100 + 58 * Math.cos(a)); t.setAttribute('y', 100 + 58 * Math.sin(a));
      t.textContent = v;
      g.appendChild(t);
    }
  }
})();

function setRing(id, value, opts = {}) {
  const el = $(id);
  const v = Math.max(0, Math.min(100, value));
  el.style.setProperty('--p', v);
  el.classList.toggle('low', v <= 20 && !opts.noLow);
  el.classList.toggle('hide', !!opts.hide);
}

function onStatus(d) {
  setRing('s-hp', d.hp);
  setRing('s-armor', d.armor, { hide: d.armor <= 0, noLow: true });
  setRing('s-hunger', d.hunger);
  setRing('s-thirst', d.thirst);
  setRing('s-stress', d.stress, { hide: d.stress < 5, noLow: true });
  setRing('s-oxygen', d.oxygen, { hide: d.oxygen < 0 });
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

function onVeh(d) {
  $('speed').textContent = Math.min(999, d.speed);
  $('spd-arc').style.strokeDasharray = `${Math.min(100, d.speed / MAX_SPEED * 100).toFixed(1)} 100`;
  const rpm = $('rpm');
  rpm.style.strokeDasharray = `${Math.round(d.rpm * 100)} 100`;
  rpm.classList.toggle('hot', d.rpm >= 0.88);

  const gear = $('gear');
  gear.textContent = d.gear;
  gear.className = 'gear' + (d.gear === '' ? ' hide' : d.gear === 'N' ? ' n' : d.gear === 'R' ? ' r' : '');

  const fuel = $('fuel');
  fuel.classList.toggle('hide', d.fuel < 0);
  fuel.classList.toggle('low', d.fuel >= 0 && d.fuel < 15);
  $('fuel-val').textContent = Math.max(0, d.fuel) + '%';

  $('v-belt').className = d.belt < 0 ? 'hide' : d.belt === 1 ? 'on' : (d.speed > 15 ? 'bad blink' : 'bad');
  $('v-engine').className = d.engine < 0 ? 'hide' : d.engine === 0 ? 'bad blink' : d.engine === 1 ? 'on' : '';
  $('v-lights').className = d.lights === 2 ? 'warn' : d.lights === 1 ? 'on' : '';
  $('v-lock').className = d.locked ? 'on' : '';
  $('v-lock-ico').setAttribute('href', d.locked ? '#i-lock' : '#i-unlock');
}

function onPop(d) {
  const el = document.createElement('div');
  el.className = 'pop ' + (d.minus ? 'minus' : 'plus');
  el.innerHTML = `${d.minus ? '−' : '+'} ${money(d.amount)} ₽<small>${d.kind === 'bank' ? 'карта' : 'наличные'}</small>`;
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
    row.innerHTML = `<kbd>${key}</kbd><span>${label}</span>`;
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
    case 'speedo': $('speedo').classList.toggle('off', !d.show); break;
    case 'moneyPop': onPop(d); break;
    case 'hints': onHints(d); break;
    case 'layout': onLayout(d); break;
  }
});
