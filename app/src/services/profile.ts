import { doc, onSnapshot, serverTimestamp, setDoc } from 'firebase/firestore'
import { DEFAULT_GOALS } from '../core/score'
import type { Goals } from '../core/types'
import { getDb } from './firebase'

const userDoc = (uid: string) => doc(getDb(), 'users', uid)

export function watchGoals(uid: string, cb: (goals: Goals) => void, onError: (e: Error) => void) {
  return onSnapshot(
    userDoc(uid),
    (snap) => {
      const goals = snap.data()?.goals as Goals | undefined
      cb(goals ? { ranges: { ...DEFAULT_GOALS.ranges, ...goals.ranges }, weights: { ...DEFAULT_GOALS.weights, ...goals.weights } } : DEFAULT_GOALS)
    },
    onError,
  )
}

export function saveGoals(uid: string, goals: Goals) {
  return setDoc(userDoc(uid), { goals, updatedAt: serverTimestamp() }, { merge: true })
}
