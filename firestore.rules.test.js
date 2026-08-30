/**
 * Firestore rules unit tests.
 *
 * These exercise `firestore.rules` against the Firebase emulator using
 * @firebase/rules-unit-testing. They verify the security model from the
 * server's perspective (the Dart tests verify it from the client's).
 *
 * Run locally with:
 *   firebase emulators:exec --only firestore \
 *     "node firestore.rules.test.js"
 *
 * Requires Node 18+ and the firebase-tools CLI.
 */

const { initializeTestEnvironment, assertFails, assertSucceeds } =
  require('@firebase/rules-unit-testing');
const { setLogLevel } = require('firebase/firestore');

// Minimal env stub: the rules don't import from the client; we just need
// them to compile. The test harness authenticates as fake users.

let env;

beforeAll(async () => {
  setLogLevel('error');
  env = await initializeTestEnvironment({
    projectId: 'demo-nirapodclick',
    firestore: { rules: require('fs').readFileSync('firestore.rules', 'utf8') },
  });
});

afterAll(async () => {
  await env.cleanup();
});

async function aliceDb() {
  return env.authenticatedContext('alice').firestore();
}
async function bobDb() {
  return env.authenticatedContext('bob').firestore();
}
async function anonDb() {
  return env.unauthenticatedContext().firestore();
}

const validCheck = {
  originalText: 'hello',
  score: 0,
  level: 'low',
  category: 'General',
  confidence: 0.5,
  reasons: [],
  createdAt: { '.sv': 'timestamp' },
};

describe('firestore.rules', () => {
  test('alice can write her own check', async () => {
    const db = await aliceDb();
    await assertSucceeds(
      db.collection('users/alice/checks').add(validCheck),
    );
  });

  test('alice cannot read bob\'s checks', async () => {
    const db = await bobDb();
    await db.collection('users/bob/checks').add(validCheck);
    const alice = await aliceDb();
    await assertFails(alice.collection('users/bob/checks').get());
  });

  test('bob cannot write into alice\'s path', async () => {
    const db = await bobDb();
    await assertFails(
      db.collection('users/alice/checks').add(validCheck),
    );
  });

  test('anonymous user cannot write anywhere', async () => {
    const db = await anonDb();
    await assertFails(
      db.collection('users/anyone/checks').add(validCheck),
    );
  });

  test('overly long originalText is rejected', async () => {
    const db = await aliceDb();
    const tooLong = { ...validCheck, originalText: 'x'.repeat(5001) };
    await assertFails(
      db.collection('users/alice/checks').add(tooLong),
    );
  });

  test('invalid level is rejected', async () => {
    const db = await aliceDb();
    const bad = { ...validCheck, level: 'catastrophic' };
    await assertFails(
      db.collection('users/alice/checks').add(bad),
    );
  });

  test('all five valid levels are accepted', async () => {
    const db = await aliceDb();
    for (const level of ['safe', 'low', 'medium', 'high', 'critical']) {
      const ok = { ...validCheck, level };
      await assertSucceeds(
        db.collection('users/alice/checks').add(ok),
      );
    }
  });

  test('all four scan types are accepted on create', async () => {
    const db = await aliceDb();
    for (const type of ['message', 'url', 'screenshot', 'phone', 'qr']) {
      const ok = { ...validCheck, type };
      await assertSucceeds(
        db.collection('users/alice/checks').add(ok),
      );
    }
  });

  test('unknown scan type is rejected', async () => {
    const db = await aliceDb();
    const bad = { ...validCheck, type: 'email' };
    await assertFails(
      db.collection('users/alice/checks').add(bad),
    );
  });

  test('missing category is rejected', async () => {
    const db = await aliceDb();
    const { category, ...bad } = validCheck;
    await assertFails(
      db.collection('users/alice/checks').add(bad),
    );
  });

  test('unknown top-level collection is denied', async () => {
    const db = await aliceDb();
    await assertFails(
      db.collection('secrets/abc').doc('x').set({ value: 1 }),
    );
  });

  test('update is denied but delete is allowed (owner can clear history)', async () => {
    const db = await aliceDb();
    const ref = db.collection('users/alice/checks').doc('doc1');
    await assertFails(ref.update({ score: 99 }));
    await assertSucceeds(ref.set({ ...validCheck }));
    await assertSucceeds(ref.delete());
  });

  // ---- url_scam_rules (URL checker rule engine data layer) ----
  //
  // Public read / write-deny from the client. Mirrors the
  // scam_patterns posture so a signed-in user can't poison the
  // rule set that every other user's app runs.
  describe('url_scam_rules', () => {
    test('anonymous user can read', async () => {
      const db = await anonDb();
      await assertSucceeds(
        db.collection('url_scam_rules/test_xyz').get(),
      );
    });

    test('signed-in user can read', async () => {
      const db = await aliceDb();
      await assertSucceeds(
        db.collection('url_scam_rules/test_xyz').get(),
      );
    });

    test('signed-in user cannot write', async () => {
      const db = await aliceDb();
      await assertFails(
        db.collection('url_scam_rules/test_xyz').set({
          type: 'keyword',
          category: 'Phishing',
          pattern: 'login',
          score: 15,
          active: true,
          version: 1,
        }),
      );
    });

    test('signed-in user cannot update or delete', async () => {
      const db = await aliceDb();
      const ref = db.collection('url_scam_rules/test_xyz');
      await assertFails(ref.doc('test_xyz').update({ active: false }));
      await assertFails(ref.doc('test_xyz').delete());
    });
  });
});