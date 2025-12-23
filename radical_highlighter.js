// ==UserScript==
// @name         Chinese Radical Highlighter
// @description  Auto-detect and highlight 214 Chinese radicals on any webpage
// @match        *://*/*
// @grant        none
// ==/UserScript==

(function () {
  'use strict';
  console.log("✅ Chinese Radical Highlighter loaded.");

  // 214 Chinese radicals (subset for brevity — you can expand)
  const radicals = "一丨丶丿乙亅二亠人儿入八冂冖冫几凵刀力勹匕匚十卜卩厂厶又口囗土士夂夊夕大女子宀寸小尢尸屮山川工己巾干幺广廴廾弋弓彐彡彳心戈戶手支攴文斗斤方无日曰月木欠止歹殳毋比毛氏气水火爪父爻爿片牙牛犬玄玉瓜瓦甘生用田疋疒癶白皮皿目矛矢石示禸禾穴立竹米糸缶网羊羽老而耒耳聿肉臣自至臼舌舛舟艮色艸虍虫血行衣西見角言谷豆豕豸貝赤走足身車辛辰酉釆里金長門阜隶隹雨青非面革韋韭音頁風飛食首香馬骨高髟鬥鬯鬲鬼魚鳥鹵鹿麥麻黃黍黑黹黽鼎鼓鼠鼻齊齒龍龜龠";

  // Helper: check if char is a radical
  const isRadical = c => radicals.includes(c);

  // Highlight function
  function highlightNode(node) {
    if (node.nodeType !== Node.TEXT_NODE) return;
    const parent = node.parentNode;
    if (!parent || parent.closest('input, textarea, script, style')) return;
    const text = node.nodeValue;
    if (!text) return;
    let hasRadical = false;
    const replaced = text.replace(/[\u4E00-\u9FFF]/g, ch => {
      if (isRadical(ch)) {
        hasRadical = true;
        return `<span class="radical-highlight" style="background:yellow;color:red;font-weight:bold;">${ch}</span>`;
      }
      return ch;
    });
    if (hasRadical) {
      const span = document.createElement('span');
      span.innerHTML = replaced;
      parent.replaceChild(span, node);
    }
  }

  /// === Highlight All Text Nodes ===
  function highlightAll() {
    const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, null);
    const textNodes = [];
    let node;
    while ((node = walker.nextNode())) textNodes.push(node);
    textNodes.forEach(highlightNode);
    console.log(`✨ Highlight done (${textNodes.length} text nodes checked).`);
  }

  // === Add Toggle Button (Draggable + Closable + Pin Save) ===
  function addToggleButton() {
    if (document.getElementById("radicalToggleBtn")) return;

    // Default pin position: bottom
    if (!localStorage.getItem("radicalBtnPinned")) {
      localStorage.setItem("radicalBtnPinned", "bottom");
    }

    // Create container
    const container = document.createElement("div");
    container.id = "radicalBtnContainer";
    Object.assign(container.style, {
      position: "fixed",
      top: localStorage.getItem("radicalBtnPinned") === "bottom" ? "unset" : "10px",
      bottom: localStorage.getItem("radicalBtnPinned") === "bottom" ? "10px" : "unset",
      right: "10px",
      zIndex: 999999,
      display: "flex",
      gap: "4px",
      alignItems: "center",
      background: "gold",
      border: "1px solid #333",
      borderRadius: "8px",
      padding: "5px 10px",
      boxShadow: "0 2px 6px rgba(0,0,0,0.2)",
      cursor: "move",
      userSelect: "none"
    });

    // Highlight toggle
    const toggleBtn = document.createElement("button");
    toggleBtn.id = "radicalToggleBtn";
    toggleBtn.textContent = "🈶 Highlight: ON";
    Object.assign(toggleBtn.style, {
      background: "transparent",
      border: "none",
      color: "black",
      fontSize: "14px",
      cursor: "pointer",
      fontWeight: "bold"
    });



    // Pin button
    const pinBtn = document.createElement("button");
    pinBtn.textContent =
      localStorage.getItem("radicalBtnPinned") === "bottom" ? "📍 Pin: Bottom" : "📍 Pin: Top";
    Object.assign(pinBtn.style, {
      background: "transparent",
      border: "none",
      cursor: "pointer",
      fontSize: "14px"
    });

    // Close button
    const closeBtn = document.createElement("button");
    closeBtn.textContent = "❌";
    Object.assign(closeBtn.style, {
      background: "transparent",
      border: "none",
      cursor: "pointer",
      fontSize: "14px"
    });

    container.append(toggleBtn, pinBtn, closeBtn);

    // === Event: Toggle highlight ===
    let enabled = true;
    toggleBtn.onclick = (e) => {
      e.stopPropagation();
      enabled = !enabled;
      toggleBtn.textContent = enabled ? "🈶 Highlight: ON" : "🈚️ Highlight: OFF";
      document.querySelectorAll(".radical-highlight").forEach((span) => {
        span.style.background = enabled ? "yellow" : "transparent";
        span.style.color = enabled ? "red" : "inherit";
        span.style.fontWeight = enabled ? "bold" : "normal";
      });
    };

    // === Event: Toggle pin (top/bottom) ===
    pinBtn.onclick = (e) => {
      e.stopPropagation();
      const pinned = localStorage.getItem("radicalBtnPinned") === "bottom" ? "top" : "bottom";
      localStorage.setItem("radicalBtnPinned", pinned);
      pinBtn.textContent = pinned === "bottom" ? "📍 Pin: Bottom" : "📍 Pin: Top";
      container.style.top = pinned === "bottom" ? "unset" : "10px";
      container.style.bottom = pinned === "bottom" ? "10px" : "unset";
    };

    // === Event: Close ===
    closeBtn.onclick = (e) => {
      e.stopPropagation();
      container.remove();
      console.log("❎ Toggle button closed.");
    };

    // === Make draggable ===
    let offsetX, offsetY, dragging = false;
    container.addEventListener("mousedown", (e) => {
      dragging = true;
      offsetX = e.clientX - container.getBoundingClientRect().left;
      offsetY = e.clientY - container.getBoundingClientRect().top;
      container.style.transition = "none";
    });
    document.addEventListener("mousemove", (e) => {
      if (!dragging) return;
      container.style.top = `${e.clientY - offsetY}px`;
      container.style.left = `${e.clientX - offsetX}px`;
      container.style.bottom = "unset";
      container.style.right = "unset";
    });
    document.addEventListener("mouseup", () => (dragging = false));

    function updateFullscreenVisibility() {
      if (document.fullscreenElement) {
        container.style.display = "none";
      } else {
        container.style.display = "flex";
      }
    }

    // Modern browsers
    document.addEventListener("fullscreenchange", updateFullscreenVisibility);

    // Safari fallback
    document.addEventListener("webkitfullscreenchange", updateFullscreenVisibility);

    // Initial check (important)
    updateFullscreenVisibility();


    // === Append safely ===
    const tryAppend = () => {
      if (document.body) {
        document.body.appendChild(container);
        console.log("✅ Toggle button added.");
      } else {
        setTimeout(tryAppend, 500);
      }
    };
    tryAppend();
  }


  // Main start logic (handles both before and after load)
  function start() {
    addToggleButton();
    setTimeout(() => {
      highlightAll();

      // Throttled observer
      // let pending = false;
      // const observer = new MutationObserver(() => {
      //   if (!pending) {
      //     pending = true;
      //     setTimeout(() => {
      //       highlightAll();
      //       pending = false;
      //     }, 2000);
      //   }
      // });

      const target = document.querySelector("main, #content, #app") || document.body;
      observer.observe(target, { childList: true, subtree: true });
      console.log("👀 Watching for new content (throttled)...");
    }, 3000);
  }

  if (document.readyState === "complete") {
    start();
  } else {
    window.addEventListener("load", start);
  }


})();
