import { defineConfig } from 'vitepress'

export default defineConfig({
  title: 'Kyzen Docs',
  description: 'Developer reference documentation for the Kyzen Flutter application.',
  lang: 'en-US',

  appearance: 'dark',

  head: [
    ['link', { rel: 'icon', href: '/logo.png' }],
    ['meta', { name: 'theme-color', content: '#3eaf7c' }],
  ],

  themeConfig: {
    logo: '/logo.png',
    siteTitle: 'Kyzen',

    nav: [
      { text: 'Home', link: '/' },
      { text: 'Getting Started', link: '/getting-started/overview' },
      { text: 'API Reference', link: '/api/playfab-client' },
    ],

    sidebar: [
      {
        text: 'Getting Started',
        collapsed: false,
        items: [
          { text: 'Architecture Overview', link: '/getting-started/overview' },
          { text: 'Core Workflow', link: '/getting-started/workflow' },
          { text: 'Environment Setup (.env.json)', link: '/getting-started/environment-setup' },
          { text: 'Publishing with FastForge', link: '/getting-started/fastforge' },
          { text: 'Localization (l10n)', link: '/getting-started/localization' },
        ],
      },
      {
        text: 'Authentication Layer',
        collapsed: false,
        items: [
          { text: 'LiveConnectAuth', link: '/auth/live-connect' },
          { text: 'XboxAuthService', link: '/auth/xbox-auth' },
          { text: 'Platform Deep Links', link: '/auth/deep-linking' },
        ],
      },
      {
        text: 'APIs',
        collapsed: false,
        items: [
          { text: 'PlayFabClient', link: '/api/playfab-client' },
          { text: 'MinecraftApi', link: '/api/minecraft-api' },
        ],
      },
      {
        text: 'Decryption',
        collapsed: false,
        items: [
          { text: 'openssl/decrypt.c (Native)', link: '/decryption/native-library' },
          { text: 'Decryptor / aes_256_cfb8', link: '/decryption/decryptor-worker' },
          { text: 'Entitlement Decryption', link: '/decryption/entitlement' },
          { text: 'ReceiptProcessor', link: '/decryption/receipt-processor' },
        ],
      },
      {
        text: 'Download',
        collapsed: false,
        items: [
          { text: 'DownloadService', link: '/download/download-service' },
          { text: 'ForegroundDownloadService', link: '/download/foreground-service' },
        ],
      },
      {
        text: 'Utilities & Stores',
        collapsed: false,
        items: [
          { text: 'SettingsService', link: '/utilities/settings-service' },
          { text: 'KeysService', link: '/utilities/keys-service' },
          { text: 'UploadKeysService', link: '/utilities/upload-keys' },
          { text: 'SocialLinksService', link: '/utilities/social-links' },
          { text: 'AnnouncementsService', link: '/utilities/announcements-service' },
          { text: 'AppUpdateService', link: '/utilities/app-update-service' },
        ],
      },
    ],

    search: {
      provider: 'local',
    },

    editLink: undefined,
  },
})
