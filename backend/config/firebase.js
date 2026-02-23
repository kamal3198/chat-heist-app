const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');
const env = require('./env');

let app;

function parseServiceAccountFromEnv() {
  if (env.firebaseServiceAccountJson) {
    return JSON.parse(env.firebaseServiceAccountJson);
  }

  if (env.firebaseServiceAccountBase64) {
    const decoded = Buffer.from(env.firebaseServiceAccountBase64, 'base64').toString('utf8');
    return JSON.parse(decoded);
  }

  return null;
}

function loadServiceAccount() {
  const envAccount = parseServiceAccountFromEnv();
  if (envAccount) return envAccount;

  const providedPath = env.firebaseServiceAccountPath
    ? path.resolve(process.cwd(), env.firebaseServiceAccountPath)
    : null;
  const defaultPath = path.resolve(__dirname, 'serviceAccountKey.json');
  const filePath = providedPath || defaultPath;
  if (fs.existsSync(filePath)) {
    const raw = fs.readFileSync(filePath, 'utf8');
    return JSON.parse(raw);
  }

  if (env.firebaseProjectId && env.firebaseClientEmail && env.firebasePrivateKey) {
    return {
      project_id: env.firebaseProjectId,
      client_email: env.firebaseClientEmail,
      private_key: env.firebasePrivateKey,
    };
  }

  throw new Error(
    'Firebase service account not found. Set FIREBASE_SERVICE_ACCOUNT_JSON, FIREBASE_SERVICE_ACCOUNT_BASE64, FIREBASE_SERVICE_ACCOUNT_PATH, or add config/serviceAccountKey.json.'
  );
}

function normalizeServiceAccount(serviceAccount) {
  return {
    projectId: serviceAccount.projectId || serviceAccount.project_id,
    clientEmail: serviceAccount.clientEmail || serviceAccount.client_email,
    privateKey: serviceAccount.privateKey || serviceAccount.private_key,
  };
}

function getFirebaseApp() {
  if (app) return app;
  if (admin.apps.length) {
    app = admin.app();
    return app;
  }

  const serviceAccount = normalizeServiceAccount(loadServiceAccount());
  if (!serviceAccount.projectId || !serviceAccount.clientEmail || !serviceAccount.privateKey) {
    throw new Error('Invalid Firebase service account payload.');
  }

  console.info(`[firebase] Admin SDK projectId: ${serviceAccount.projectId}`);

  app = admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    ...(env.firebaseStorageBucket ? { storageBucket: env.firebaseStorageBucket } : {}),
  });

  return app;
}

function getFirestore() {
  return getFirebaseApp().firestore();
}

function getAuth() {
  return getFirebaseApp().auth();
}

module.exports = {
  admin,
  getFirebaseApp,
  getFirestore,
  getAuth,
};
