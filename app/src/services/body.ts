import { collection, deleteDoc, doc, onSnapshot, serverTimestamp, setDoc } from 'firebase/firestore'
import { sortByDate, type BodyGoal, type WeightEntry } from '../core/progress'
import { getDb } from './firebase'

const weightsCol = (uid: string) => collection(getDb(), 'users', uid, 'weights')
const userDoc = (uid: string) => doc(getDb(), 'users', uid)

export function watchWeights(uid: string, cb: (entries: WeightEntry[]) => void, onError: (e: Error) => void) {
  return onSnapshot(
    weightsCol(uid),
    (snap) => cb(sortByDate(snap.docs.map((d) => ({ date: d.id, kg: d.data().kg as number })))),
    onError,
  )
}

/** Un registro por día: guardar dos veces el mismo día lo reemplaza. */
export function saveWeight(uid: string, entry: WeightEntry) {
  return setDoc(doc(weightsCol(uid), entry.date), { kg: entry.kg, updatedAt: serverTimestamp() })
}

export function deleteWeight(uid: string, date: string) {
  return deleteDoc(doc(weightsCol(uid), date))
}

export function watchBodyGoal(uid: string, cb: (goal: BodyGoal | null) => void, onError: (e: Error) => void) {
  return onSnapshot(userDoc(uid), (snap) => cb((snap.data()?.bodyGoal as BodyGoal | undefined) ?? null), onError)
}

export function saveBodyGoal(uid: string, goal: BodyGoal) {
  return setDoc(userDoc(uid), { bodyGoal: goal, updatedAt: serverTimestamp() }, { merge: true })
}
