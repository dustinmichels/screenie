import { defineConfig } from 'vitepress'

export default defineConfig({
  title: 'Screenie',
  description: 'A lightweight macOS menu bar app for your recent screenshots.',
  base: '/screenie/',
  cleanUrls: true,
  themeConfig: {
    nav: [
      { text: 'Install', link: '/install' },
      { text: 'How it works', link: '/how-it-works' },
    ],
    sidebar: [
      {
        text: 'Guide',
        items: [
          { text: 'Install', link: '/install' },
          { text: 'How it works', link: '/how-it-works' },
        ],
      },
    ],
    outline: 'deep',
  },
})
