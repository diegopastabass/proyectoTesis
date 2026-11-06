import type { BarcodeDetector as PonyfillDetector, BarcodeFormat } from 'barcode-detector/ponyfill'

export interface Detector {
  detect(source: HTMLVideoElement): Promise<{ rawValue: string }[]>
}

/** Códigos de productos de supermercado. */
const RETAIL_FORMATS: BarcodeFormat[] = ['ean_13', 'ean_8', 'upc_a', 'upc_e']

let cached: Promise<Detector> | null = null

/**
 * Usa el BarcodeDetector nativo si existe (Chrome en Android) y, si no, el de
 * zxing-wasm (iOS Safari, Firefox). Se carga bajo demanda para no inflar el bundle.
 */
export function getDetector(): Promise<Detector> {
  cached ??= createDetector().catch((err) => {
    cached = null
    throw err
  })
  return cached
}

async function createDetector(): Promise<Detector> {
  const Native = (globalThis as { BarcodeDetector?: typeof PonyfillDetector }).BarcodeDetector
  if (Native) {
    try {
      const supported = await Native.getSupportedFormats()
      const formats = RETAIL_FORMATS.filter((f) => supported.includes(f))
      if (formats.includes('ean_13')) return new Native({ formats })
    } catch {
      // Si el nativo falla se usa el de WebAssembly.
    }
  }
  const [{ BarcodeDetector, prepareZXingModule }, { default: wasmUrl }] = await Promise.all([
    import('barcode-detector/ponyfill'),
    import('zxing-wasm/reader/zxing_reader.wasm?url'),
  ])
  // Sirve el .wasm desde la propia app en vez del CDN por defecto.
  prepareZXingModule({
    overrides: { locateFile: (path: string, prefix: string) => (path.endsWith('.wasm') ? wasmUrl : prefix + path) },
  })
  return new BarcodeDetector({ formats: RETAIL_FORMATS })
}
