/// <reference types="vitest/config" />
import tailwindcss from '@tailwindcss/vite'
import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react(), tailwindcss()],
  build: {
    // Dos páginas: la web del prototipo y el panel de administración (pantalla de diseño).
    rollupOptions: { input: ['index.html', 'admin.html'] },
  },
  test: {
    include: ['src/**/*.test.ts'],
  },
})
