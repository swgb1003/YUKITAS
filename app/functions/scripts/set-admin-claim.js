#!/usr/bin/env node
/**
 * Grants (or revokes) the `admin` custom claim used by `resolveDispute`
 * (see ../src/disputes.ts) to gate who may settle a disputed request.
 *
 * There is no UI for this on purpose - it is rare, high-trust, and running
 * it requires already having gcloud/Firebase credentials for the project,
 * which is a reasonable bar for "can decide who gets paid in a dispute".
 *
 * Setup (once per machine):
 *   gcloud auth application-default login
 *
 * Usage (run from the functions/ directory):
 *   node scripts/set-admin-claim.js <email>              grant
 *   node scripts/set-admin-claim.js <email> --revoke      revoke
 *   node scripts/set-admin-claim.js --list                list current admins
 *
 * Custom claims are cached in the user's ID token. The account must sign
 * out and back in (or otherwise force a token refresh) before
 * `request.auth.token.admin` reflects the change.
 */

const admin = require("firebase-admin");

const PROJECT_ID = process.env.GOOGLE_CLOUD_PROJECT || "yukitas-app";

function usageAndExit() {
  console.error(
    "Usage:\n" +
      "  node scripts/set-admin-claim.js <email>          grant admin\n" +
      "  node scripts/set-admin-claim.js <email> --revoke  revoke admin\n" +
      "  node scripts/set-admin-claim.js --list            list current admins",
  );
  process.exit(1);
}

async function main() {
  const args = process.argv.slice(2);
  if (args.length === 0) usageAndExit();

  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: PROJECT_ID,
  });

  if (args[0] === "--list") {
    await listAdmins();
    return;
  }

  const email = args[0];
  const revoke = args.includes("--revoke");
  if (!email || email.startsWith("--")) usageAndExit();

  const user = await admin.auth().getUserByEmail(email);
  const nextClaims = { ...(user.customClaims || {}) };
  if (revoke) {
    delete nextClaims.admin;
  } else {
    nextClaims.admin = true;
  }
  await admin.auth().setCustomUserClaims(user.uid, nextClaims);

  console.log(
    `${revoke ? "Revoked" : "Granted"} admin claim for ${email} (${user.uid}).`,
  );
  console.log(
    "This account must sign out and back in before the change takes effect.",
  );
}

async function listAdmins() {
  const admins = [];
  let pageToken;
  do {
    const page = await admin.auth().listUsers(1000, pageToken);
    for (const user of page.users) {
      if (user.customClaims && user.customClaims.admin === true) {
        admins.push(user.email || user.uid);
      }
    }
    pageToken = page.pageToken;
  } while (pageToken);

  if (admins.length === 0) {
    console.log("No accounts currently hold the admin claim.");
    return;
  }
  console.log("Accounts with the admin claim:");
  for (const identifier of admins) console.log(`  - ${identifier}`);
}

main().catch((error) => {
  console.error("Failed:", error.message || error);
  process.exit(1);
});
