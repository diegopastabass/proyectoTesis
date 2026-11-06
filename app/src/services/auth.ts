import { GoogleAuthProvider, onAuthStateChanged, signInWithPopup, signOut, type User } from 'firebase/auth'
import { getAuthInstance } from './firebase'

export type { User }

export function signInWithGoogle() {
  return signInWithPopup(getAuthInstance(), new GoogleAuthProvider())
}

export function signOutUser() {
  return signOut(getAuthInstance())
}

export function watchAuth(cb: (user: User | null) => void) {
  return onAuthStateChanged(getAuthInstance(), cb)
}
