// KAVKAZ RP — меню игрока
const $ = (id) => document.getElementById(id);
const post = (name, body) => fetch(`https://${GetParentResourceName()}/${name}`, {
  method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(body || {}),
}).then((r) => r.json()).catch(() => ({}));
const rub = (n) => Math.round(Number(n) || 0).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ' ') + ' ₽';
const set = (id, v) => { $(id).textContent = (v === undefined || v === null || v === '') ? '—' : v; };

function tab(name) {
  document.querySelectorAll('nav button').forEach((b) => b.classList.toggle('on', b.dataset.tab === name));
  document.querySelectorAll('section').forEach((s) => s.classList.toggle('on', s.dataset.page === name));
}

function fill(d) {
  const p = d.profile, s = d.stats, sec = d.security;
  set('p-name', p.name); set('p-cid', p.cid); set('p-id', p.id);
  set('p-job', p.job + (p.onduty ? ' · на смене' : '')); set('p-gang', p.gang || 'нет');
  set('p-birth', (p.birth || '').replace(/^(\d{4})-(\d{2})-(\d{2})$/, '$3.$2.$1')); set('p-place', p.place); set('p-phone', p.phone); set('p-gender', p.gender);
  set('p-cash', rub(p.cash)); set('p-bank', rub(p.bank)); set('p-cars', p.cars);
  const lic = $('p-lic'); lic.innerHTML = '';
  (p.licences.length ? p.licences : [null]).forEach((l) => {
    const e = document.createElement('span');
    if (l) e.textContent = l; else { e.textContent = 'пока нет — права получают в автошколе'; e.className = 'none'; }
    lic.appendChild(e);
  });
  set('s-time', `${s.hours} ч ${s.minutes} мин`); set('s-first', s.first); set('s-days', s.days);
  set('s-fines', s.fines ? `${s.fines} на ${rub(s.finesSum)}` : 'нет');
  set('sec-last', sec.lastLogin || 'это первый вход'); set('sec-lic', sec.license);
  set('sec-discord', sec.discord ? 'привязан' : 'не привязан'); set('sec-steam', sec.steam ? 'привязан' : 'не привязан');
  set('ref-title', d.referral.title); set('ref-text', d.referral.text);
  $('set-hints').checked = !!d.settings.hints;
  $('set-sgu').value = d.settings.sguVolume; set('set-sgu-val', d.settings.sguVolume);
}

document.querySelectorAll('nav button').forEach((b) => b.addEventListener('click', () => tab(b.dataset.tab)));
document.querySelectorAll('[data-act]').forEach((b) => b.addEventListener('click', () => post('action', { id: b.dataset.act })));
$('set-hints').addEventListener('change', (e) => post('setting', { id: 'hints', value: e.target.checked }));
$('set-sgu').addEventListener('input', (e) => set('set-sgu-val', e.target.value));
$('set-sgu').addEventListener('change', (e) => post('setting', { id: 'sguVolume', value: Number(e.target.value) }));

async function promo() {
  const code = $('promo-code').value.trim();
  const msg = $('promo-msg');
  if (!code) { msg.textContent = 'введи код'; msg.className = 'msg bad'; return; }
  $('promo-go').disabled = true;
  const r = await post('promo', { code });
  $('promo-go').disabled = false;
  msg.textContent = r.msg || 'не получилось';
  msg.className = 'msg ' + (r.ok ? 'ok' : 'bad');
  if (r.ok) $('promo-code').value = '';
}
$('promo-go').addEventListener('click', promo);
$('promo-code').addEventListener('keydown', (e) => { if (e.key === 'Enter') promo(); });

window.addEventListener('message', (e) => {
  const d = e.data || {};
  if (d.action === 'open') { fill(d.data); tab(d.tab || 'profile'); $('menu').classList.remove('off'); $('promo-msg').textContent = ''; }
  if (d.action === 'close') $('menu').classList.add('off');
});
window.addEventListener('keydown', (e) => { if (e.key === 'Escape' || e.key === 'F4') post('close'); });
