// Vite configuration of the Script Application.
// Based on the react-ts template of @hcl-software/create-dx-script-app (Apache-2.0, HCL America Inc.).
import { readFileSync } from 'node:fs'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

const pkg = JSON.parse(readFileSync(new URL('./package.json', import.meta.url), 'utf8'))

// "npm run dev" only: DX URL for the local proxy (e.g. https://dx.example.com). The app calls DX
// with relative URLs (/wps/...), as it does once deployed; the proxy forwards them to DX.
const dxTarget = process.env.DX_TARGET ? new URL(process.env.DX_TARGET).origin : 'https://localhost'

export default defineConfig({
  plugins: [react()],
  // Relative asset URLs: DXClient stores every file in WCM and rewrites the references
  base: '',
  define: { __APP_VERSION__: JSON.stringify(pkg.version) },
  build: { outDir: 'dist', emptyOutDir: true },
  server: {
    port: 3000,
    proxy: {
      '/wps': { target: dxTarget, changeOrigin: true, secure: false, cookieDomainRewrite: 'localhost' },
      '/dx': { target: dxTarget, changeOrigin: true, secure: false, cookieDomainRewrite: 'localhost' },
    },
  },
})
