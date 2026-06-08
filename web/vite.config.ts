import { cpSync, existsSync, mkdirSync, readdirSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { defineConfig, type Plugin } from 'vite'
import react from '@vitejs/plugin-react'

// GitHub Pages project site: https://grahamthetvi.github.io/Switch2GO_AAC_iPadOS/
const repoBase = '/Switch2GO_AAC_iPadOS/'
const rootDir = path.dirname(fileURLToPath(import.meta.url))

/** Piper defaults to cdnjs onnxruntime-web 1.18.0, which lacks files required by ort 1.26. */
function copyOrtWasmPlugin(): Plugin {
  return {
    name: 'copy-ort-wasm',
    buildStart() {
      const srcDir = path.resolve(rootDir, 'node_modules/onnxruntime-web/dist')
      const destDir = path.resolve(rootDir, 'public/ort')
      if (!existsSync(srcDir)) {
        this.warn('onnxruntime-web dist not found; Piper TTS may fail at runtime')
        return
      }
      mkdirSync(destDir, { recursive: true })
      for (const name of readdirSync(srcDir)) {
        if (name.startsWith('ort-wasm')) {
          cpSync(path.join(srcDir, name), path.join(destDir, name))
        }
      }
    },
  }
}

export default defineConfig({
  plugins: [copyOrtWasmPlugin(), react()],
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
