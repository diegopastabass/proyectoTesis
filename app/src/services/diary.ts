import {
  collection,
  deleteDoc,
  doc,
  onSnapshot,
  orderBy,
  query,
  serverTimestamp,
  writeBatch,
  type Timestamp,
} from 'firebase/firestore'
import { normalizeMacros } from '../core/macros'
import type { DiaryEntry, Macros, MealSlot, NewDiaryEntry } from '../core/types'
import { getDb } from './firebase'

const entriesCol = (uid: string, date: string) => collection(getDb(), 'users', uid, 'days', date, 'entries')

export function watchDay(
  uid: string,
  date: string,
  cb: (entries: DiaryEntry[]) => void,
  onError: (e: Error) => void,
) {
  return onSnapshot(
    query(entriesCol(uid, date), orderBy('createdAt')),
    (snap) =>
      cb(
        snap.docs
          .map((d) => {
            const data = d.data({ serverTimestamps: 'estimate' })
            return {
              id: d.id,
              kind: data.kind,
              refId: data.refId,
              name: data.name,
              grams: data.grams,
              servings: data.servings ?? null,
              macros: normalizeMacros(data.macros as Partial<Macros> | undefined),
              meal: data.meal as MealSlot,
              rawInput: data.rawInput ?? null,
              createdAt: (data.createdAt as Timestamp | null)?.toMillis() ?? Date.now(),
              position: (data.position as number | undefined) ?? 0,
            }
          })
          .sort((a, b) => a.createdAt - b.createdAt || a.position - b.position)
          .map(({ position: _position, ...entry }) => entry),
      ),
    onError,
  )
}

export async function addEntries(uid: string, date: string, entries: NewDiaryEntry[]) {
  const batch = writeBatch(getDb())
  // Las entradas de un mismo lote comparten createdAt; `position` conserva el orden de la lista.
  entries.forEach((e, position) => {
    batch.set(doc(entriesCol(uid, date)), { ...e, position, createdAt: serverTimestamp() })
  })
  await batch.commit()
}

export function deleteEntry(uid: string, date: string, id: string) {
  return deleteDoc(doc(entriesCol(uid, date), id))
}
