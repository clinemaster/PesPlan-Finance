/* Dashboard behaviour: hover/focus tooltips, table-view toggles, theme choice.
 *
 * The page is fully readable with JavaScript disabled: every value a tooltip
 * shows is also in that chart's table view, and the filter row submits as a
 * plain GET form.
 */
(function () {
  "use strict";

  // --- tooltips ---------------------------------------------------------
  // Marks carry their text in data-* attributes and it is inserted with
  // textContent, never innerHTML: descriptions and category names originate
  // in CSV files and are untrusted.

  var tip = document.getElementById("tooltip");

  function fill(el) {
    tip.textContent = "";
    var value = document.createElement("span");
    value.className = "tip-value";
    value.textContent = el.getAttribute("data-value") || "";
    var label = document.createElement("span");
    label.className = "tip-label";
    label.textContent = el.getAttribute("data-label") || "";
    tip.appendChild(value);
    tip.appendChild(label);
    var extra = el.getAttribute("data-extra");
    if (extra) {
      var more = document.createElement("span");
      more.className = "tip-extra";
      more.textContent = extra;
      tip.appendChild(more);
    }
  }

  function place(x, y) {
    tip.hidden = false;
    var box = tip.getBoundingClientRect();
    var left = Math.min(x + 14, window.innerWidth - box.width - 8);
    var top = y - box.height - 12;
    if (top < 8) {
      top = y + 18;
    }
    tip.style.left = Math.max(8, left) + "px";
    tip.style.top = top + "px";
  }

  function hide() {
    tip.hidden = true;
  }

  function show(el, x, y) {
    fill(el);
    place(x, y);
  }

  // --- crosshair --------------------------------------------------------
  // Line charts get a hairline that snaps to the hovered month, plus a dot on
  // each series. It is driven by the same full-height hit bands that carry the
  // tooltip, so pointer and keyboard both land on it and nobody has to aim at
  // a 2px line.

  function moveCrosshair(mark) {
    var chart = mark.ownerSVGElement;
    if (!chart || mark.getAttribute("data-cx") === null) {
      return;
    }
    var x = mark.getAttribute("data-cx");
    var line = chart.querySelector(".crosshair-line");
    if (line) {
      line.setAttribute("x1", x);
      line.setAttribute("x2", x);
    }
    chart.querySelectorAll(".crosshair-dot").forEach(function (dot) {
      var y = mark.getAttribute("data-cy-" + dot.getAttribute("data-dot"));
      dot.setAttribute("cx", x);
      dot.setAttribute("cy", y === null ? "0" : y);
      // A month with no value for that series gets no dot.
      dot.setAttribute("r", y === null ? "0" : "4.5");
    });
    chart.classList.add("crosshair-on");
  }

  function clearCrosshairs() {
    document.querySelectorAll(".chart.crosshair-on").forEach(function (chart) {
      chart.classList.remove("crosshair-on");
    });
  }

  var SELECTOR = "[data-label]";

  document.addEventListener("pointermove", function (event) {
    var mark = event.target.closest ? event.target.closest(SELECTOR) : null;
    if (mark) {
      show(mark, event.clientX, event.clientY);
      moveCrosshair(mark);
    } else {
      hide();
      clearCrosshairs();
    }
  });

  document.addEventListener("pointerleave", function () {
    hide();
    clearCrosshairs();
  });
  window.addEventListener("scroll", hide, { passive: true });

  // Keyboard focus gets the same readout as hover.
  document.addEventListener(
    "focus",
    function (event) {
      var mark = event.target.closest ? event.target.closest(SELECTOR) : null;
      if (!mark) {
        return;
      }
      var box = mark.getBoundingClientRect();
      show(mark, box.left + box.width / 2, box.top);
      moveCrosshair(mark);
    },
    true
  );

  document.addEventListener("blur", function () {
    hide();
    clearCrosshairs();
  }, true);
  document.addEventListener("keydown", function (event) {
    if (event.key === "Escape") {
      hide();
      clearCrosshairs();
    }
  });

  // --- table views ------------------------------------------------------

  document.addEventListener("click", function (event) {
    var button = event.target.closest("[data-table-toggle]");
    if (!button) {
      return;
    }
    var table = document.getElementById(button.getAttribute("data-table-toggle"));
    if (!table) {
      return;
    }
    var opening = table.hidden;
    table.hidden = !opening;
    button.setAttribute("aria-expanded", String(opening));
    button.textContent = opening ? "Hide table" : "Table";
  });

  // --- filter row -------------------------------------------------------
  // Progressive enhancement: the Apply button already works without this.

  document.querySelectorAll("[data-autosubmit]").forEach(function (select) {
    select.addEventListener("change", function () {
      select.form.submit();
    });
  });

  // --- theme ------------------------------------------------------------
  // Three states: stored "light"/"dark" win over the OS setting; no stored
  // value means follow the OS.

  var KEY = "lifepilot-theme";
  var root = document.documentElement;

  function stored() {
    try {
      return localStorage.getItem(KEY);
    } catch (err) {
      return null;
    }
  }

  function apply(theme) {
    if (theme === "light" || theme === "dark") {
      root.setAttribute("data-theme", theme);
    } else {
      root.removeAttribute("data-theme");
    }
  }

  apply(stored());

  var toggle = document.getElementById("theme-toggle");
  if (toggle) {
    toggle.addEventListener("click", function () {
      var dark = getComputedStyle(root).colorScheme === "dark";
      var next = dark ? "light" : "dark";
      apply(next);
      try {
        localStorage.setItem(KEY, next);
      } catch (err) {
        /* private window: the choice just won't persist */
      }
      toggle.textContent = next === "dark" ? "Light" : "Dark";
    });
    toggle.textContent =
      getComputedStyle(root).colorScheme === "dark" ? "Light" : "Dark";
  }
})();
