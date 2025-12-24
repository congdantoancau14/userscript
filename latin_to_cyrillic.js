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

    translateTextNodes(el, vietnameseToCyrillic);
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
   VIETNAMESE → CYRILLIC
===================== */

// 1. Remove Vietnamese tone marks (but keep base letters like â, ê, ô, ă, ơ, ư)
function normalizeVietnamese(str) {
    return str
        .normalize("NFD")
        .replace(/[\u0300-\u036f]/g, "") // remove tone marks
        .replace(/đ/g, "d")
        .replace(/Đ/g, "D");
}

// 2. Latin → Cyrillic (Vietnamese phonetic)
function vietnameseToCyrillic_undiacritic(text) {
    text = normalizeVietnamese(text);

    const map = {
        // vowels
        'a': 'а', 'ă': 'а', 'â': 'ы',
        'e': 'е', 'ê': 'э',
        'i': 'и',
        'o': 'о', 'ô': 'о', 'ơ': 'ы',
        'u': 'у', 'ư': 'ы',
        'y': 'и',

        // consonants
        'b': 'б', 'c': 'к', 'd': 'д', 'đ': 'д',
        'g': 'г', 'h': 'х',
        'k': 'к', 'l': 'л', 'm': 'м', 'n': 'н',
        'p': 'п', 'q': 'к', 'r': 'р',
        's': 'с', 't': 'т', 'v': 'в',
        'x': 'с',

        // uppercase
        'A': 'А', 'Ă': 'А', 'Â': 'Ы',
        'E': 'Е', 'Ê': 'Э',
        'I': 'И',
        'O': 'О', 'Ô': 'О', 'Ơ': 'Ы',
        'U': 'У', 'Ư': 'Ы',
        'Y': 'И',

        'B': 'Б', 'C': 'К', 'D': 'Д', 'Đ': 'Д',
        'G': 'Г', 'H': 'Х',
        'K': 'К', 'L': 'Л', 'M': 'М', 'N': 'Н',
        'P': 'П', 'Q': 'К', 'R': 'Р',
        'S': 'С', 'T': 'Т', 'V': 'В',
        'X': 'С'
    };

    return text.split('').map(c => map[c] || c).join('');
}

function vietnameseToCyrillic(text) {
    // không xóa dấu nguyên âm
    const textNorm = text;

    return textNorm
        // xử lý âm ghép trước
        .replace(/ngh/gi, m => m[0] === m[0].toUpperCase() ? "НГ" : "нг")
        .replace(/ng/gi,  m => m[0] === m[0].toUpperCase() ? "НГ" : "нг")
        .replace(/nh/gi,  m => m[0] === m[0].toUpperCase() ? "НЬ" : "нь")
        .replace(/ch/gi,  m => m[0] === m[0].toUpperCase() ? "Ч" : "ч")
        .replace(/gi/gi,  m => m[0] === m[0].toUpperCase() ? "Ж" : "ж")
        .replace(/kh/gi,  m => m[0] === m[0].toUpperCase() ? "Х" : "х")
        .replace(/ph/gi,  m => m[0] === m[0].toUpperCase() ? "Ф" : "ф")
        .replace(/th/gi,  m => m[0] === m[0].toUpperCase() ? "ТХ" : "тх")
        .replace(/tr/gi,  m => m[0] === m[0].toUpperCase() ? "Ц" : "ц")
        .replace(/qu/gi,  m => m[0] === m[0].toUpperCase() ? "Кʷ" : "кʷ")

        // rồi đến từng ký tự riêng lẻ
        .split("")
        .map(c => latinToCyrillicMap[c] || c)
        .join("");
}

// Bảng đơn âm
const latinToCyrillicMap = {
    // nguyên âm (giữ dấu)
    "a": "а", "ă": "а", "â": "ы",
    "e": "е", "ê": "э",
    "i": "и",
    "o": "о", "ô": "о", "ơ": "ы",
    "u": "у", "ư": "ы",
    "y": "й",

    "A": "А", "Ă": "А", "Â": "Ы",
    "E": "Е", "Ê": "Э",
    "I": "И",
    "O": "О", "Ô": "О", "Ơ": "Ы",
    "U": "У", "Ư": "Ы",
    "Y": "Й",

    // phụ âm đơn
    "b": "б", "c": "к", "d": "з", "đ": "д",
    "g": "г", "h": "х", "k": "к", "l": "л",
    "m": "м", "n": "н", "p": "п", "q": "к",
    "r": "р", "s": "ш", "t": "т", "v": "в",
    "x": "с",

    "B": "Б", "C": "К", "D": "З", "Đ": "Д",
    "G": "Г", "H": "Х", "K": "К", "L": "Л",
    "M": "М", "N": "Н", "P": "П", "Q": "К",
    "R": "Р", "S": "Ш", "T": "Т", "V": "В",
    "X": "С"
};

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
