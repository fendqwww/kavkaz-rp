// KAVKAZ RP — отрисовка госномеров в SVG.
// пропорции по ГОСТ Р 50577-2018, тип 1: 520×112 мм, цифры 76 мм, буквы 58 мм, справа поле региона «95 / RUS + флаг».
// символы — шрифт с открытой лицензией (html/fonts), каждый в ячейке фиксированного размера.
// использование: Plate.svg({ style: 'ru', plate: 'K013PA95', frame: { text: 'ФСО РОССИИ' } })
(function () {
  const LAT2CYR = { A: 'А', B: 'В', E: 'Е', K: 'К', M: 'М', H: 'Н', O: 'О', P: 'Р', C: 'С', T: 'Т', Y: 'У', X: 'Х' };

  // ---------- символы ----------
  // символы — обычный шрифт (файл в html/fonts), но каждый ставится в ячейку фиксированного размера:
  // все буквы одной высоты и ширины, все цифры одной высоты и ширины — как на штампованном знаке.
  // cap — высота заглавной буквы в долях кегля (из метрик шрифта), по ней считаем кегль под нужную высоту в мм.
  const FONT = { family: 'Plate Font', fallback: '"Roboto Condensed", "Arial Narrow", Arial', weight: 600, cap: 0.711 };

  function cell(it, x, base, color, cyr) {
    const ch = cyr ? (LAT2CYR[it.ch] || it.ch) : it.ch;
    if (ch === '-') {
      const t = it.h * 0.14;
      return `<rect x="${(x + it.w * 0.15).toFixed(1)}" y="${(base - it.h * 0.5 - t / 2).toFixed(1)}" width="${(it.w * 0.7).toFixed(1)}" height="${t.toFixed(1)}" fill="${color}"/>`;
    }
    const size = it.h / FONT.cap;
    return `<text x="${x.toFixed(1)}" y="${base.toFixed(1)}" font-family="${FONT.family}, ${FONT.fallback}" font-weight="${FONT.weight}" font-size="${size.toFixed(1)}"`
      + ` textLength="${it.w.toFixed(1)}" lengthAdjust="spacingAndGlyphs" fill="${color}">${ch}</text>`;
  }

  // ряд символов: каждый элемент { ch, w, h }, все стоят на одной базовой линии
  function row(items, x0, base, _sw, gap, color, cyr) {
    let x = x0, out = '';
    for (const it of items) {
      if (it.ch !== ' ') out += cell(it, x, base, color, cyr);
      x += it.w + (it.gap ?? gap);
    }
    return out;
  }
  const rowWidth = (items, gap) => items.reduce((a, it, i) => a + it.w + (i < items.length - 1 ? (it.gap ?? gap) : 0), 0);
  const isDigit = (c) => c >= '0' && c <= '9';
  const D = (ch) => ({ ch, w: 45, h: 80 });           // цифра (76 мм по ГОСТ, почти вся высота поля)
  const Lt = (ch) => ({ ch, w: 45, h: 60 });          // буква (58 мм), ширина как у цифры
  const sp = (w) => ({ ch: ' ', w, h: 0, gap: 0 });

  // ---------- флаги ----------
  const FLAGS = {
    ru: (x, y, w, h) => `<rect x="${x}" y="${y}" width="${w}" height="${h / 3}" fill="#fff"/><rect x="${x}" y="${y + h / 3}" width="${w}" height="${h / 3}" fill="#0039a6"/><rect x="${x}" y="${y + 2 * h / 3}" width="${w}" height="${h / 3}" fill="#d52b1e"/><rect x="${x}" y="${y}" width="${w}" height="${h}" fill="none" stroke="#111" stroke-width="2"/>`,
    kz: (x, y, w, h) => `<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="#00afca"/><circle cx="${x + w * 0.55}" cy="${y + h * 0.42}" r="${h * 0.2}" fill="#fec50c"/><path d="M${x + w * 0.35} ${y + h * 0.72} Q${x + w * 0.55} ${y + h * 0.55} ${x + w * 0.75} ${y + h * 0.72}" stroke="#fec50c" stroke-width="${h * 0.08}" fill="none"/><rect x="${x + w * 0.05}" y="${y}" width="${w * 0.08}" height="${h}" fill="#fec50c" opacity=".85"/>`,
    by: (x, y, w, h) => `<rect x="${x}" y="${y}" width="${w}" height="${h * 2 / 3}" fill="#c8313e"/><rect x="${x}" y="${y + h * 2 / 3}" width="${w}" height="${h / 3}" fill="#4aa657"/><rect x="${x}" y="${y}" width="${w * 0.16}" height="${h}" fill="#fff"/><path d="M${x + w * 0.08} ${y + h * 0.1} l${w * 0.05} ${h * 0.15} l-${w * 0.05} ${h * 0.15} l-${w * 0.05} -${h * 0.15}z M${x + w * 0.08} ${y + h * 0.55} l${w * 0.05} ${h * 0.15} l-${w * 0.05} ${h * 0.15} l-${w * 0.05} -${h * 0.15}z" fill="#c8313e"/>`,
    am: (x, y, w, h) => `<rect x="${x}" y="${y}" width="${w}" height="${h / 3}" fill="#d90012"/><rect x="${x}" y="${y + h / 3}" width="${w}" height="${h / 3}" fill="#0033a0"/><rect x="${x}" y="${y + 2 * h / 3}" width="${w}" height="${h / 3}" fill="#f2a800"/>`,
    ge: (x, y, w, h) => {
      const t = h * 0.14, sc = (cx, cy) => `<rect x="${cx - t * 0.25}" y="${cy - t * 0.9}" width="${t * 0.5}" height="${t * 1.8}" fill="#e8112d"/><rect x="${cx - t * 0.9}" y="${cy - t * 0.25}" width="${t * 1.8}" height="${t * 0.5}" fill="#e8112d"/>`;
      return `<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="#fff" stroke="#111" stroke-width="1"/><rect x="${x + w / 2 - t / 2}" y="${y}" width="${t}" height="${h}" fill="#e8112d"/><rect x="${x}" y="${y + h / 2 - t / 2}" width="${w}" height="${t}" fill="#e8112d"/>`
        + sc(x + w * 0.25, y + h * 0.25) + sc(x + w * 0.75, y + h * 0.25) + sc(x + w * 0.25, y + h * 0.75) + sc(x + w * 0.75, y + h * 0.75);
    },
    az: (x, y, w, h) => `<rect x="${x}" y="${y}" width="${w}" height="${h / 3}" fill="#00b5e2"/><rect x="${x}" y="${y + h / 3}" width="${w}" height="${h / 3}" fill="#ef3340"/><rect x="${x}" y="${y + 2 * h / 3}" width="${w}" height="${h / 3}" fill="#509e2f"/><circle cx="${x + w * 0.46}" cy="${y + h / 2}" r="${h * 0.12}" fill="#fff"/><circle cx="${x + w * 0.49}" cy="${y + h / 2}" r="${h * 0.1}" fill="#ef3340"/><circle cx="${x + w * 0.6}" cy="${y + h / 2}" r="${h * 0.05}" fill="#fff"/>`,
  };

  // ---------- стили номеров ----------
  // parse(plate) -> { main: [...символы], region } ; рисуем по одной схеме: основная часть + поле справа или полоса слева
  const STYLES = {
    ru:       { bg: '#fff', fg: '#111', re: /^([ABEKMHOPCTYX])(\d{3})([ABEKMHOPCTYX]{2})(\d{2,3})$/, main: (m) => [Lt(m[1]), sp(6), D(m[2][0]), D(m[2][1]), D(m[2][2]), sp(6), Lt(m[3][0]), Lt(m[3][1])], region: (m) => m[4], rus: true },
    ru_taxi:  { bg: '#f5c400', fg: '#111', re: /^([ABEKMHOPCTYX]{2})(\d{3})(\d{2,3})$/, main: (m) => [Lt(m[1][0]), Lt(m[1][1]), sp(10), D(m[2][0]), D(m[2][1]), D(m[2][2])], region: (m) => m[3], rus: true },
    ru_police:{ bg: '#1f4aa8', fg: '#fff', edge: '#f2f4f8', re: /^([ABEKMHOPCTYX])(\d{4})(\d{2,3})$/, main: (m) => [Lt(m[1]), sp(10), ...m[2].split('').map(D)], region: (m) => m[3], rus: true },
    ru_army:  { bg: '#121212', fg: '#fff', edge: '#e8e8e8', re: /^(\d{4})([ABEKMHOPCTYX]{2})(\d{2,3})$/, main: (m) => [...m[1].split('').map(D), sp(10), Lt(m[2][0]), Lt(m[2][1])], region: (m) => m[3], rus: true },
    kz:       { bg: '#fff', fg: '#111', re: /^(\d{3})([ABEKMHOPCTYX]{3})(\d{2})$/, main: (m) => [...m[1].split('').map(D), sp(10), ...m[2].split('').map(Lt)], region: (m) => m[3], left: { flag: 'kz', code: 'KZ' } },
    by:       { bg: '#fff', fg: '#111', re: /^(\d{4})([ABEKMHOPCTYX]{2})(\d)$/, main: (m) => [...m[1].split('').map(D), sp(10), Lt(m[2][0]), Lt(m[2][1]), { ch: '-', w: 22, h: 60 }, D(m[3])], left: { flag: 'by', code: 'BY' } },
    am:       { bg: '#fff', fg: '#111', re: /^(\d{2})([ABEKMHOPCTYX]{2})(\d{3})$/, main: (m) => [D(m[1][0]), D(m[1][1]), sp(10), Lt(m[2][0]), Lt(m[2][1]), sp(10), ...m[3].split('').map(D)], left: { flag: 'am', code: 'AM', band: true } },
    ge:       { bg: '#fff', fg: '#111', re: /^([ABEKMHOPCTYX]{2})(\d{3})([ABEKMHOPCTYX]{2})$/, main: (m) => [Lt(m[1][0]), Lt(m[1][1]), { ch: '-', w: 22, h: 60 }, ...m[2].split('').map(D), { ch: '-', w: 22, h: 60 }, Lt(m[3][0]), Lt(m[3][1])], left: { flag: 'ge', code: 'GE', band: true } },
    az:       { bg: '#fff', fg: '#111', re: /^(\d{2})([ABEKMHOPCTYX]{2})(\d{3})$/, main: (m) => [D(m[1][0]), D(m[1][1]), { ch: '-', w: 22, h: 60 }, Lt(m[2][0]), Lt(m[2][1]), { ch: '-', w: 22, h: 60 }, ...m[3].split('').map(D)], left: { flag: 'az', code: 'AZ' } },
  };

  function fit(items, maxW, gap) {
    // если символов много (полиция, военные, Беларусь) — сжимаем по ширине, высота остаётся по ГОСТ
    const w = rowWidth(items, gap);
    if (w <= maxW) return items;
    const k = (maxW - gap * (items.length - 1)) / (w - gap * (items.length - 1));
    return items.map((it) => ({ ...it, w: it.w * k }));
  }

  // геометрия (viewBox 520×112): толстая окантовка, два отдельных поля со скруглёнными углами — как на настоящем знаке
  const MAIN = { x: 7, y: 7, w: 364, h: 98 }, REG = { x: 377, y: 7, w: 136, h: 98 }, FULL = { x: 7, y: 7, w: 506, h: 98 };
  const field = (f, fill) => `<rect x="${f.x}" y="${f.y}" width="${f.w}" height="${f.h}" rx="7" fill="${fill}"/>`;
  const edgeRect = (color) => `<rect x="0" y="0" width="520" height="112" rx="11" fill="${color}"/>`;

  function transit(plate) {
    return edgeRect('#111') + field(FULL, '#fffdf3')
      + `<text x="260" y="32" text-anchor="middle" font-family="${FONT.family}, ${FONT.fallback}" font-weight="${FONT.weight}" font-size="18" fill="#c0262d" letter-spacing="6">ТРАНЗИТ</text>
      <text x="260" y="90" text-anchor="middle" font-family="${FONT.family}, ${FONT.fallback}" font-weight="${FONT.weight}" font-size="50" fill="#111" letter-spacing="4">${plate}</text>`;
  }

  function body(styleId, plate) {
    const st = STYLES[styleId] || STYLES.ru;
    const m = st.re.exec(plate || '');
    if (!m) return transit(plate || '');
    const gap = 5, sw = 10.5, fg = st.fg;
    const region = st.region && st.region(m);
    const main = region ? MAIN : FULL;
    let out = edgeRect(st.edge || '#111') + field(main, st.bg) + (region ? field(REG, st.bg) : '');

    let x0 = main.x + 8, x1 = main.x + main.w - 8;
    if (st.left) {
      // флаг и код страны слева (номера СНГ и Европы)
      const bw = 60;
      if (st.left.band) out += `<path d="M${main.x} ${main.y + 7} a7 7 0 0 1 7 -7 h${bw - 7} v${main.h} h-${bw - 7} a7 7 0 0 1 -7 -7z" fill="#1d4fb8"/>`;
      out += FLAGS[st.left.flag](main.x + 9, main.y + 12, 42, 28);
      out += `<text x="${main.x + bw / 2}" y="${main.y + 86}" text-anchor="middle" font-family="${FONT.family}, ${FONT.fallback}" font-weight="${FONT.weight}" font-size="24" fill="${st.left.band ? '#fff' : fg}">${st.left.code}</text>`;
      x0 = main.x + bw + 6;
    }

    if (region) {
      // поле региона: крупные цифры сверху, внизу RUS вразрядку и флаг в чёрной рамке
      const cx = REG.x + REG.w / 2;
      const rd = region.split('').map((c) => ({ ch: c, w: region.length === 3 ? 31 : 40, h: 52 }));
      const rw = rowWidth(rd, 5);
      out += row(rd, cx - rw / 2, REG.y + 60, 0, 5, fg);
      if (st.rus) {
        out += `<text x="${REG.x + 44}" y="${REG.y + 89}" text-anchor="middle" font-family="${FONT.family}, ${FONT.fallback}" font-weight="${FONT.weight}" font-size="21" letter-spacing="5" fill="${fg}">RUS</text>`;
        out += FLAGS.ru(REG.x + 82, REG.y + 72, 40, 21);
      } else if (styleId === 'kz') {
        out += `<text x="${cx}" y="${REG.y + 89}" text-anchor="middle" font-family="${FONT.family}, ${FONT.fallback}" font-weight="${FONT.weight}" font-size="17" letter-spacing="2" fill="${fg}">KZ</text>`;
      }
    }

    const items = fit(st.main(m), x1 - x0, gap);
    const w = rowWidth(items, gap);
    out += row(items, x0 + (x1 - x0 - w) / 2, main.y + main.h - 8, sw, gap, fg, styleId.startsWith('ru'));
    return out;
  }

  // рамка номера: пластик вокруг знака и надпись снизу («ФСО РОССИИ», дилер, семья)
  function svg(opts) {
    const o = opts || {};
    const plateSvg = body(o.style || 'ru', o.plate);
    if (!o.frame || !o.frame.text) {
      return `<svg class="plate-svg" viewBox="0 0 520 112" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="${o.pretty || o.plate || ''}">${plateSvg}</svg>`;
    }
    const color = o.frame.color || '#141414', textColor = o.frame.textColor || '#f2f2f2';
    return `<svg class="plate-svg framed" viewBox="0 0 548 150" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="${o.pretty || o.plate || ''}">
      <rect x="0" y="0" width="548" height="150" rx="12" fill="${color}"/>
      <rect x="4" y="4" width="540" height="142" rx="10" fill="none" stroke="rgba(255,255,255,.08)" stroke-width="2"/>
      <g transform="translate(14 8)">${plateSvg}</g>
      <text x="274" y="140" text-anchor="middle" font-family="Golos Text, Arial" font-weight="600" font-size="17" letter-spacing="1.5" fill="${textColor}">${o.frame.text}</text>
    </svg>`;
  }

  // «A777AA95» -> «А 777 АА 95» (для подписей)
  function pretty(style, plate) {
    const st = STYLES[style || 'ru'];
    const m = st && st.re.exec(plate || '');
    if (!m) return plate;
    const cyr = (s) => (style || 'ru').startsWith('ru') ? s.replace(/[ABEKMHOPCTYX]/g, (c) => LAT2CYR[c]) : s;
    return cyr(m.slice(1).join(' '));
  }

  window.Plate = { svg, pretty, styles: Object.keys(STYLES), font: FONT };
})();
