(function () {
    try {
        var stored = localStorage.getItem("theme");
        var dark = stored === "dark" || (stored !== "light" && window.matchMedia("(prefers-color-scheme: dark)").matches);
        var root = document.documentElement;
        root.classList.add(dark ? "dark-mode" : "light-mode");
        root.style.colorScheme = dark ? "dark" : "light";
    } catch (e) {
        /* storage can be blocked; React applies the theme after load */
    }
})();
