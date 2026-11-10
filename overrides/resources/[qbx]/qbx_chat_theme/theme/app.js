// KAVKAZ: дополнения к чату (тема qbx_chat_theme). заменяет стандартный app.js темы Qbox.
// 1) каждой строке ставим вид (data-cat): в роли / вне роли / рация / админ — для вкладок;
// 2) при вводе показываем вкладки «Всё / В роли / Вне роли / Рация / Админ», режим и счётчик символов.
(() => {
    const MAX = 300; // столько символов принимает сервер (kavkaz_rp)
    const TABS = [['all', 'Всё'], ['ic', 'В роли'], ['ooc', 'Вне роли'], ['radio', 'Рация'], ['adm', 'Админ']];
    const OOC = ['b', 'pm', 'rn', 'fn', 'ooc', 'report'];
    const RADIO = ['r', 'rn', 'd', 'f', 'fn', 'gov'];
    const ADM = ['a', 'admins', 'apanel', 'alogin', 'alogout'];
    const ADM_WORDS = /^(АДМИН|НАКАЗАНИЕ|А-ЧАТ|ОБЪЯВЛЕНИЕ|РЕПОРТ)/i;

    document.body.dataset.f = 'all';

    function category(msg) {
        const kv = msg.querySelector('.kv');
        if (kv) {
            const c = kv.classList;
            if (c.contains('kv-radio') || c.contains('kv-dep') || c.contains('kv-fam') || c.contains('kv-gov')) return 'radio';
            if (c.contains('kv-ooc') || c.contains('kv-pm')) return 'ooc';
            return 'ic';
        }
        const author = msg.querySelector('.author');
        if (author && ADM_WORDS.test(author.textContent.trim())) return 'adm';
        return 'sys';
    }

    function tag(node) {
        if (node.nodeType !== 1) return;
        const list = node.classList && node.classList.contains('msg') ? [node] : node.querySelectorAll ? node.querySelectorAll('.msg') : [];
        for (const m of list) if (!m.dataset.cat) m.dataset.cat = category(m);
    }

    // режим по первой команде в строке
    function mode(text) {
        const m = /^\/(\S+)/.exec(text || '');
        const cmd = m ? m[1].toLowerCase() : '';
        if (ADM.includes(cmd)) return ['adm', 'Админ'];
        if (RADIO.includes(cmd)) return [cmd === 'rn' || cmd === 'fn' ? 'ooc' : 'radio', cmd === 'rn' || cmd === 'fn' ? 'Рация вне роли' : 'Рация'];
        if (OOC.includes(cmd)) return ['ooc', 'Вне роли'];
        return ['ic', 'В роли'];
    }

    function decorateInput() {
        const box = document.querySelector('.chat-input');
        if (!box) return;
        const input = box.querySelector('div.input');
        const area = box.querySelector('textarea');
        if (!input || !area) return;
        if (!box.querySelector('.kv-tabs')) {
            const tabs = document.createElement('div');
            tabs.className = 'kv-tabs';
            for (const [id, label] of TABS) {
                const b = document.createElement('button');
                b.type = 'button';
                b.textContent = label;
                b.dataset.f = id;
                if (id === document.body.dataset.f) b.classList.add('on');
                b.addEventListener('mousedown', (e) => {
                    e.preventDefault(); // фокус остаётся в поле ввода
                    document.body.dataset.f = id;
                    tabs.querySelectorAll('button').forEach((x) => x.classList.toggle('on', x === b));
                });
                tabs.appendChild(b);
            }
            box.insertBefore(tabs, box.firstChild);
        }
        if (!input.querySelector('.kv-mode')) {
            const m = document.createElement('span');
            m.className = 'kv-mode';
            input.insertBefore(m, area);
            const c = document.createElement('span');
            c.className = 'kv-count';
            input.appendChild(c);
            update();
        }
    }

    function update() {
        const area = document.querySelector('.chat-input textarea');
        const m = document.querySelector('.kv-mode');
        const c = document.querySelector('.kv-count');
        if (!area || !m || !c) return;
        const [cls, label] = mode(area.value);
        const n = area.value.length;
        // меняем только то, что поменялось (меньше перерисовок)
        if (m.className !== 'kv-mode ' + cls) m.className = 'kv-mode ' + cls;
        if (m.textContent !== label) m.textContent = label;
        const count = `${n} / ${MAX}`;
        if (c.textContent !== count) c.textContent = count;
        c.classList.toggle('over', n > MAX);
    }

    document.addEventListener('input', (e) => { if (e.target && e.target.tagName === 'TEXTAREA') update(); }, true);
    document.addEventListener('keyup', (e) => { if (e.target && e.target.tagName === 'TEXTAREA') update(); }, true);

    // чат собирается Vue после загрузки — следим за изменениями
    // наши элементы (вкладки, режим, счётчик) не считаем — иначе наблюдатель сам себя будит без конца
    const ours = (n) => n.nodeType !== 1 ? (n.parentElement && n.parentElement.closest('.kv-tabs, .kv-mode, .kv-count'))
        : n.closest('.kv-tabs, .kv-mode, .kv-count');
    const obs = new MutationObserver((records) => {
        let other = false;
        for (const r of records) {
            if (ours(r.target)) continue;
            for (const n of r.addedNodes) { if (!ours(n)) { other = true; tag(n); } }
        }
        if (other) decorateInput();
    });
    const start = () => {
        obs.observe(document.body, { childList: true, subtree: true });
        tag(document.body);
        decorateInput();
    };
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start); else start();
})();
