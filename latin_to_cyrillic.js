console.log('latinToCyrillic script loaded');

/* =====================
   GLOBAL TOGGLE STATE
===================== */
let cyrillicEnabled = localStorage.getItem('cyrillicEnabled') !== 'false';

/* =====================
   DEBOUNCE
===================== */
function debounce(func, delay) {
    let timeoutId;
    return function (...args) {
        clearTimeout(timeoutId);
        timeoutId = setTimeout(() => func.apply(this, args), delay);
    };
}

/* =====================
   FORBIDDEN STRINGS
===================== */
const forbiddenStrings = ['密码', '@', '#', '/'];

function shouldSkip(element) {
    const text = element.textContent;
    return forbiddenStrings.some(s => text.includes(s));
}

/* =====================
   TRANSLATE / RESTORE
===================== */
function translateTextNodes(element, translateFn, reverse = false) {
    if (element.classList && element.classList.contains('CodeBlock')) return;

    for (let node of element.childNodes) {
        if (node.nodeType === Node.TEXT_NODE) {
            if (!reverse) {
                if (!node.__latinOriginal) {
                    node.__latinOriginal = node.textContent;
                }
                node.textContent = translateFn(node.textContent);
            } else {
                if (node.__latinOriginal) {
                    node.textContent = node.__latinOriginal;
                }
            }
        } else if (node.nodeType === Node.ELEMENT_NODE) {
            translateTextNodes(node, translateFn, reverse);
        }
    }
}

function restoreLatin(el) {
    translateTextNodes(el, null, true);
    el.removeAttribute('data-translated');
}

/* =====================
   PROCESS MESSAGE
===================== */
function processMessageContent(el) {
    if (!cyrillicEnabled) return;
    if (el.getAttribute('data-translated') === 'true') return;
    if (shouldSkip(el)) return;

    translateTextNodes(el, latinToCyrillic);
    el.setAttribute('data-translated', 'true');
}

/* =====================
   LATIN → CYRILLIC MAP
===================== */
function latinToCyrillic(text) {
    const map = {
        'a': 'а', 'b': 'б', 'c': 'ц', 'd': 'д', 'e': 'е',
        'f': 'ф', 'g': 'г', 'h': 'х', 'i': 'и', 'j': 'й',
        'k': 'к', 'l': 'л', 'm': 'м', 'n': 'н', 'o': 'о',
        'p': 'п', 'q': 'к', 'r': 'р', 's': 'с', 't': 'т',
        'u': 'у', 'v': 'в', 'w': 'в', 'x': 'кс', 'y': 'й',
        'z': 'з',
        'A': 'А', 'B': 'Б', 'C': 'Ц', 'D': 'Д', 'E': 'Е',
        'F': 'Ф', 'G': 'Г', 'H': 'Х', 'I': 'И', 'J': 'Й',
        'K': 'К', 'L': 'Л', 'M': 'М', 'N': 'Н', 'O': 'О',
        'P': 'П', 'Q': 'К', 'R': 'Р', 'S': 'С', 'T': 'Т',
        'U': 'У', 'V': 'В', 'W': 'В', 'X': 'КС', 'Y': 'Й',
        'Z': 'З'
    };
    return text.split('').map(c => map[c] || c).join('');
}

/* =====================
   INITIAL RUN
===================== */
document.addEventListener('DOMContentLoaded', () => {
    console.log('Processing existing messages');
    if (cyrillicEnabled) {
        document
            .querySelectorAll('.message-content, .message')
            .forEach(processMessageContent);
    }
});

/* =====================
   MUTATION OBSERVER
===================== */
const debouncedConvert = debounce(() => {
    if (!cyrillicEnabled) return;
    document.querySelectorAll('div').forEach(processMessageContent);
}, 500);

const observer = new MutationObserver(mutations => {
    for (const mutation of mutations) {
        if (mutation.type === 'childList') {
            for (const node of mutation.addedNodes) {
                if (node.nodeType === Node.ELEMENT_NODE) {
                    if (node.matches('.message-content, .message')) {
                        processMessageContent(node);
                    } else {
                        node
                            .querySelectorAll?.('.message-content, .message')
                            .forEach(processMessageContent);
                    }
                }
            }
            debouncedConvert();
        }
    }
});

document.addEventListener('DOMContentLoaded', () => {
    observer.observe(document.body, { childList: true, subtree: true });
});

/* =====================
   TOGGLE BUTTON
===================== */
document.addEventListener('DOMContentLoaded', () => {
    const btn = document.createElement('button');
    btn.textContent = cyrillicEnabled ? '🅻 Latin' : '🅲 Cyrillic';

    Object.assign(btn.style, {
        position: 'fixed',
        bottom: '16px',
        right: '16px',
        zIndex: 99999,
        padding: '8px 12px',
        background: '#222',
        color: '#fff',
        border: 'none',
        borderRadius: '6px',
        cursor: 'pointer',
        fontSize: '13px'
    });

    btn.onclick = () => {
        cyrillicEnabled = !cyrillicEnabled;
        localStorage.setItem('cyrillicEnabled', cyrillicEnabled);

        if (!cyrillicEnabled) {
            btn.textContent = '🅲 Cyrillic';
            document
                .querySelectorAll('[data-translated="true"]')
                .forEach(restoreLatin);
        } else {
            btn.textContent = '🅻 Latin';
            document
                .querySelectorAll('.message-content, .message')
                .forEach(processMessageContent);
        }
    };

    document.body.appendChild(btn);
});

/* =====================
   KEYBOARD SHORTCUT
   Alt + L
===================== */
document.addEventListener('keydown', e => {
    if (e.altKey && e.code === 'KeyL') {
        e.preventDefault();
        document.querySelector('button')?.click();
    }
});
