// Run with: node --test "supabase/functions/delete-account/*.test.ts"
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { bearer, deleteAccount, type AccountDb } from './logic.ts';

const recorder = (failOn?: 'leave' | 'delete') => {
  const calls: string[] = [];
  const db: AccountDb = {
    async leaveAllPods(id) {
      calls.push(`leave:${id}`);
      if (failOn === 'leave') throw new Error('boom');
    },
    async deleteUser(id) {
      calls.push(`delete:${id}`);
      if (failOn === 'delete') throw new Error('boom');
    },
  };
  return { db, calls };
};

test('leaves every pod first, then deletes the user', async () => {
  const { db, calls } = recorder();
  await deleteAccount(db, 'u1');
  assert.deepEqual(calls, ['leave:u1', 'delete:u1']);
});

test('if leaving fails nothing is deleted, and the error reaches the caller to retry', async () => {
  const { db, calls } = recorder('leave');
  await assert.rejects(deleteAccount(db, 'u1'), /boom/);
  assert.deepEqual(calls, ['leave:u1']);
});

test('if deleting fails after leaving, the error still reaches the caller', async () => {
  const { db } = recorder('delete');
  await assert.rejects(deleteAccount(db, 'u1'), /boom/);
});

test('the bearer token is read from the Authorization header, nowhere else', () => {
  assert.equal(bearer('Bearer abc.def.ghi'), 'abc.def.ghi');
  assert.equal(bearer('bearer xyz'), 'xyz');
  assert.equal(bearer('Basic abc'), null);
  assert.equal(bearer(''), null);
  assert.equal(bearer(null), null);
});
