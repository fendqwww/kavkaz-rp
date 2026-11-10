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
  const [first, ...rest] = (p.name || '').trim().split(' ');
  const last = rest.join(' ');
  set('pp-last', last); set('pp-first', first); set('pp-gender', p.gender === 'женский' ? 'жен.' : 'муж.');
  const birth = (p.birth || '').replace(/^(\d{4})-(\d{2})-(\d{2})$/, '$3.$2.$1');
  set('pp-birth', birth); set('pp-place', p.place); set('pp-issued', d.stats.first);
  set('pp-sign', last ? last.charAt(0).toUpperCase() + last.slice(1).toLowerCase() : '—');
  // серия и номер из номера персонажа: 95 (регион) + 2 цифры + 6 цифр
  let h = 0; for (const c of String(p.cid)) h = (h * 31 + c.charCodeAt(0)) % 100000000;
  const num = String(h).padStart(8, '0');
  set('pp-num', `95 ${num.slice(0, 2)} ${num.slice(2)}`);
  const tr = (t) => t.toUpperCase().replace(/[^A-ZА-ЯЁ]/g, '');
  const lat = (t) => { const m = { А:'A',Б:'B',В:'V',Г:'G',Д:'D',Е:'E',Ё:'E',Ж:'ZH',З:'Z',И:'I',Й:'I',К:'K',Л:'L',М:'M',Н:'N',О:'O',П:'P',Р:'R',С:'S',Т:'T',У:'U',Ф:'F',Х:'KH',Ц:'TS',Ч:'CH',Ш:'SH',Щ:'SHCH',Ы:'Y',Э:'E',Ю:'IU',Я:'IA',Ь:'',Ъ:'' }; return tr(t).split('').map((c) => m[c] ?? c).join(''); };
  const line1 = ('PNNAG' + lat(last) + '<<' + lat(first)).padEnd(44, '<').slice(0, 44);
  const line2 = (num + '<' + '9NAG' + birth.replace(/\./g, '').slice(4) + birth.slice(3, 5) + birth.slice(0, 2)).padEnd(44, '<').slice(0, 44);
  $('pp-mrz').textContent = line1 + '\n' + line2;
  const img = $('pp-photo');
  if (p.photo) { img.src = p.photo; img.classList.add('on'); } else { img.removeAttribute('src'); img.classList.remove('on'); }
  set('p-id', p.id);
  set('p-job', p.job + (p.onduty ? ' · на смене' : '')); set('p-gang', p.gang || 'нет'); set('p-phone', p.phone);
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
