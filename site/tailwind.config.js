/** @type {import('tailwindcss').Config} */
// WIREX design system — see .stitch/DESIGN.md
// Объединённый конфиг для index.html и admin.html. Раньше каждая страница
// держала свой inline tailwind.config + грузила cdn.tailwindcss.com — это
// блокировалось TSPU в РФ (ERR_CONNECTION_RESET). Теперь сборка статическая.
module.exports = {
  content: ["./index.html", "./admin.html"],
  darkMode: "class",
  theme: {
    extend: {
      colors: {
        // Primary surfaces (dark to darker by elevation)
        background:                 "#000000",
        surface:                    "#000000",
        "surface-container-lowest": "#000000",
        "surface-container-low":    "#070707",
        "surface-container":        "#0A0A0A",
        "surface-container-high":   "#111111",
        "surface-container-highest":"#161616",
        "surface-bright":           "#1C1C1C",
        "surface-dim":              "#000000",
        "surface-variant":          "#0A0A0A",

        // Borders
        outline:           "#2A2A2A",
        "outline-variant": "#1A1A1A",

        // Text
        "on-background":      "#F0F0F0",
        "on-surface":         "#F0F0F0",
        "on-surface-variant": "#8A8A8A",
        "inverse-on-surface": "#4A4A4A",
        "inverse-surface":    "#F0F0F0",

        // Accent (primary action) — monochrome off-white
        primary:                    "#F5F5F5",
        "primary-dim":              "#CCCCCC",
        "primary-fixed":            "#F5F5F5",
        "primary-fixed-dim":        "#CCCCCC",
        "primary-container":        "#F5F5F5",
        "on-primary":               "#000000",
        "on-primary-container":     "#000000",
        "on-primary-fixed":         "#000000",
        "on-primary-fixed-variant": "#1A1A1A",
        "surface-tint":             "#F5F5F5",
        "inverse-primary":          "#CCCCCC",

        // Status
        success:              "#00E78B",
        warning:              "#FFB020",
        error:                "#FF4757",
        "error-dim":          "#CC2D3C",
        "on-error":           "#FFFFFF",
        "on-error-container": "#FFB7BD",
        "error-container":    "#3A0008",

        // Legacy hooks kept for compatibility (mapped to neutral surfaces)
        "on-secondary":               "#8A8A8A",
        "on-tertiary-container":      "#F0F0F0",
        "on-secondary-container":     "#F0F0F0",
        "secondary-fixed":            "#1A1A1A",
        "tertiary-fixed-dim":         "#F5F5F5",
        "tertiary-dim":               "#CCCCCC",
        "secondary-dim":              "#1A1A1A",
        secondary:                    "#1A1A1A",
        "secondary-container":        "#1A1A1A",
        "on-tertiary":                "#000000",
        "on-secondary-fixed":         "#8A8A8A",
        "tertiary-fixed":             "#F5F5F5",
        "secondary-fixed-dim":        "#1A1A1A",
        "tertiary-container":         "#F5F5F5",
        "on-tertiary-fixed":          "#000000",
        "on-tertiary-fixed-variant":  "#1A1A1A",
        "on-secondary-fixed-variant": "#8A8A8A",
        tertiary:                     "#F5F5F5",
      },
      borderRadius: {
        DEFAULT: "0.25rem",
        lg:    "0.5rem",
        xl:    "0.75rem",
        "2xl": "1rem",
        full:  "9999px",
      },
      fontFamily: {
        headline: ["Space Grotesk", "system-ui", "sans-serif"],
        body:     ["Inter",         "system-ui", "sans-serif"],
        label:    ["Inter",         "system-ui", "sans-serif"],
        mono:     ["JetBrains Mono", "ui-monospace", "monospace"],
      },
    },
  },
  plugins: [
    require("@tailwindcss/forms"),
    require("@tailwindcss/container-queries"),
  ],
};
