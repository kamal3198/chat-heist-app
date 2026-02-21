const {
  createUser,
} = require('../services/firestore-chat-service');

async function createUserController(req, res) {
  const user = await createUser(req.body || {});
  res.status(201).json({ user });
}

module.exports = {
  createUserController,
};
