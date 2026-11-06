import { mapOffProduct, type OffDraft } from '../core/openFoodFacts'

const FIELDS = 'code,product_name,product_name_es,generic_name,brands,nutriments,serving_quantity'
const TIMEOUT_MS = 8000

/**
 * Busca un producto por código en Open Food Facts (datos ODbL). Devuelve null si
 * no existe. La API limita a ~15 lecturas por minuto por IP.
 */
export async function lookupBarcode(code: string): Promise<OffDraft | null> {
  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS)
  let res: Response
  try {
    res = await fetch(`https://world.openfoodfacts.org/api/v2/product/${encodeURIComponent(code)}.json?fields=${FIELDS}`, {
      // Los navegadores no permiten cambiar User-Agent; la API acepta X-User-Agent para identificar la app.
      headers: { 'X-User-Agent': 'NutriPrototipo/0.1 (proyecto de titulo)' },
      signal: controller.signal,
    })
  } catch {
    throw new Error('No se pudo contactar a Open Food Facts. Revisa tu conexión.')
  } finally {
    clearTimeout(timer)
  }

  // Bajo carga o al superar el límite, la API responde HTML en vez de JSON.
  const isJson = res.headers.get('content-type')?.includes('json')
  if (!isJson) throw new Error('Open Food Facts no está disponible ahora. Intenta en un minuto.')
  const data = (await res.json()) as { status?: number; product?: Record<string, unknown> }
  if (data.status !== 1 || !data.product) return null
  return mapOffProduct(code, data.product)
}
