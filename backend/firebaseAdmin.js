const { admin, getFirebaseApp, getAuth } = require('./config/firebase');

// Ensure Admin SDK is initialized exactly once on process startup.
getFirebaseApp();

module.exports = {
  admin,
  auth: getAuth(),
};

