import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// GitHub Pages project site: https://grahamthetvi.github.io/Switch2GO_AAC_iPadOS/
const repoBase = '/Switch2GO_AAC_iPadOS/'

export default defineConfig({
  plugins: [react()],
  base: repoBase,
  build: {
    outDir: 'dist',
    sourcemap: true,
  },
  server: {
    port: 5173,
    host: true,
  },
})
