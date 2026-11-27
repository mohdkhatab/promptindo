#!/usr/bin/env node
/**
 * Grant (or revoke) the `role: admin` custom claim on a Firebase Auth user.
 *
 * Usage:
 *   node scripts/make-admin.js <uid>            # promote
 *   node scripts/make-admin.js <uid> revoke     # demote
 *
 * Run INSIDE the functions directory with application-default credentials:
 *   gcloud auth application-default login
 * or with a service-account key kept strictly server-side:
 *   GOOGLE_APPLICATION_CREDENTIALS=/secrets/sa.json node scripts/make-admin.js UID
 *
 * The custom claim — not a Firestore field — is what firestore.rules'
 * isAdmin() and the Flutter admin UI check.
 */
const { initializeApp, applicationDefault, cert } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");

const [, , uid, mode = "grant"] = process.argv;

if (!uid) {
  console.error("Usage: node scripts/make-admin.js <uid> [grant|revoke]");
  process.exit(1);
}

initializeApp({ credential: applicationDefault(), projectId: "prompindo" });

(async () => {
  const user = await getAuth().getUser(uid);
  const claims = { ...(user.customClaims || {}) };

  if (mode === "revoke") {
    delete claims.role;
  } else {
    claims.role = "admin";
  }

  await getAuth().setCustomUserClaims(uid, claims);

  // Mirror into the profile doc so the admin screens can render without an
  // extra token refresh (authorization still uses the claim only).
  const { getFirestore } = require("firebase-admin/firestore");
  await getFirestore()
    .doc(`users/${uid}`)
    .set({ role: mode === "revoke" ? "user" : "admin" }, { merge: true });

  console.log(`OK: ${uid} → role=${claims.role ?? "user"}`);
  console.log("The user must sign out/in (or wait ~1h) for the claim to apply.");
  process.exit(0);
})().catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});
