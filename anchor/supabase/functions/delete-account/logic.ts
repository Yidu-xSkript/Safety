// Account deletion, as two ordered steps over a tiny interface (so the order is unit-tested without a database).
// Required by Apple App Review: deletion must be possible inside the app.

export interface AccountDb {
  /** Ends the person's membership in every pod and archives those pods, so the partner is told and keeps a read-only record. */
  leaveAllPods(userId: string): Promise<void>;

  /** Deletes the auth user; foreign keys cascade their profile, habits, ticks, check-ins, urges, replies and devices. */
  deleteUser(userId: string): Promise<void>;
}

export async function deleteAccount(db: AccountDb, userId: string): Promise<void> {
  // Leave first, so the pod is archived (and the partner notified) before the rows disappear. If this fails nothing
  // has been deleted yet, and the person can try again.
  await db.leaveAllPods(userId);
  await db.deleteUser(userId);
}

/** `Authorization: Bearer <jwt>` -> `<jwt>`. */
export function bearer(header: string | null): string | null {
  const m = /^Bearer\s+(.+)$/i.exec(header ?? '');
  return m ? m[1] : null;
}
