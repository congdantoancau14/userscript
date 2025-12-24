console.log('latinToCyrillic script loaded');

// Debounce utility
function debounce(func, delay) {
    let timeoutId;
    return function(...args) {
        clearTimeout(timeoutId);
        timeoutId = setTimeout(() => func.apply(this, args), delay);
    };
}

// Translate only text nodes, keeping HTML tags intact
function translateTextNodes(element, translateFn) {
    if (element.classList && element.classList.contains('CodeBlock')) return;

    for (let node of element.childNodes) {
        if (node.nodeType === Node.TEXT_NODE) {
            node.textContent = translateFn(node.textContent);
        } else if (node.nodeType === Node.ELEMENT_NODE) {
            translateTextNodes(node, translateFn);
        }
    }
}

// List of forbidden words/characters to skip translation
const forbiddenStrings = ['密码', '@', '#', '/'];

// Check if element should be skipped
function shouldSkip(element) {
    const text = element.textContent;
    return forbiddenStrings.some(s => text.includes(s));
}

// Process a message block if it meets conditions
function processMessageContent(el) {
    if (el.getAttribute('data-translated') === 'true') return; // Already translated
    if (shouldSkip(el)) return;

    translateTextNodes(el, latinToCyrillic);
    el.setAttribute('data-translated', 'true');
}

// Latin → Cyrillic map
function latinToCyrillic(text) {
    const latinCyrillicMap = {
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
    return text.split('').map(char => latinCyrillicMap[char] || char).join('');
}

// Run on existing messages
document.addEventListener('DOMContentLoaded', () => {
    console.log('Processing existing messages');
    document.querySelectorAll('.message-content, .message').forEach(processMessageContent);
});

// Watch for dynamically added messages
const debouncedConvert = debounce(() => {
    document.querySelectorAll('div').forEach(processMessageContent);
    console.log('latinToCyrillic conversion run');
}, 500);

const observer = new MutationObserver(mutations => {
    for (const mutation of mutations) {
        if (mutation.type === 'childList') {
            for (const node of mutation.addedNodes) {
                if (node.nodeType === Node.ELEMENT_NODE) {
                    if (node.matches('.message-content, .message')) {
                        processMessageContent(node);
                    } else {
                        node.querySelectorAll?.('.message-content, .message').forEach(processMessageContent);
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
