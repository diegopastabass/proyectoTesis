import { initializeApp } from 'firebase/app'
import { connectAuthEmulator, getAuth, type Auth } from 'firebase/auth'
import { connectFirestoreEmulator, getFirestore, type Firestore } from 'firebase/firestore'

const env = import.meta.env

const config = {
  apiKey: env.VITE_FIREBASE_API_KEY,
  authDomain: env.VITE_FIREBASE_AUTH_DOMAIN,
  projectId: env.VITE_FIREBASE_PROJECT_ID,
  storageBucket: env.VITE_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: env.VITE_FIREBASE_MESSAGING_SENDER_ID,
  appId: env.VITE_FIREBASE_APP_ID,
}

export const isConfigured = Boolean(config.apiKey && config.projectId)
export const usingEmulators = env.VITE_USE_EMULATORS === 'true'

let auth: Auth | null = null
let db: Firestore | null = null

if (isConfigured) {
  const app = initializeApp(config)
  auth = getAuth(app)
  db = getFirestore(app)
  if (usingEmulators) {
    connectAuthEmulator(auth, 'http://127.0.0.1:9099', { disableWarnings: true })
    connectFirestoreEmulator(db, '127.0.0.1', 8080)
  }
}

export function getAuthInstance(): Auth {
  if (!auth) throw new Error('Firebase no está configurado (revisa .env.local)')
  return auth
}

export function getDb(): Firestore {
  if (!db) throw new Error('Firebase no está configurado (revisa .env.local)')
  return db
}
