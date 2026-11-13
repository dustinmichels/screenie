import { defineConfig } from "vitepress";

const base = "/screenie/";

export default defineConfig({
  title: "Screenie",
  description: "A lightweight macOS menu bar app for your recent screenshots.",
  base,
  cleanUrls: true,
  head: [["link", { rel: "icon", type: "image/png", href: `${base}favicon.png` }]],
  themeConfig: {
    logo: "/logo.png",
    nav: [
      { text: "Install", link: "/install" },
      { text: "How it works", link: "/how-it-works" },
      { text: "Developers", link: "/developers" },
    ],
    sidebar: [
      {
        text: "Guide",
        items: [
          { text: "Install", link: "/install" },
          { text: "How it works", link: "/how-it-works" },
        ],
      },
      {
        text: "Developers",
        items: [{ text: "Build from source", link: "/developers" }],
      },
    ],
    socialLinks: [{ icon: "github", link: "https://github.com/dustinmichels/screenie" }],
    outline: "deep",
    footer: {
      message:
        'Free and <a href="https://github.com/dustinmichels/screenie">open source</a>. Built by <a href="https://dustinmichels.com">Dustin M</a>.',
    },
  },
});
