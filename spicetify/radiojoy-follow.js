// Recolours Spotify live when the desktop wallpaper changes (omarchy-radiojoy).
// radiojoy-sync writes radiojoy-colors.json next to the app; this polls it and sets the
// --spice-* variables, or removes them to fall back to the theme's own colours.
(function radiojoyFollow() {
  const root = document.documentElement;
  let last = null;
  let applied = [];

  const rgb = (hex) => [0, 2, 4].map((i) => parseInt(hex.slice(i, i + 2), 16)).join(",");

  async function check() {
    try {
      const res = await fetch("/radiojoy-colors.json?" + Date.now(), { cache: "no-store" });
      if (!res.ok) return;
      const text = await res.text();
      if (text === last) return;
      last = text;
      const { colors = {} } = JSON.parse(text);
      for (const name of applied) {
        root.style.removeProperty(`--spice-${name}`);
        root.style.removeProperty(`--spice-rgb-${name}`);
      }
      applied = Object.keys(colors);
      for (const [name, hex] of Object.entries(colors)) {
        root.style.setProperty(`--spice-${name}`, `#${hex}`);
        root.style.setProperty(`--spice-rgb-${name}`, rgb(hex));
      }
    } catch (e) {
      // file missing or mid-write: keep the current colours and try again
    }
  }

  check();
  setInterval(check, 1500);
})();
