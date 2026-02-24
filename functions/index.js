const {setGlobalOptions} = require("firebase-functions");

setGlobalOptions({maxInstances: 10});

// Keep this file intentionally minimal so lint/deploy passes even when
// function triggers are added incrementally.
module.exports = {};
