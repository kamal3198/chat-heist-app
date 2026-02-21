const {
  createChat,
  listUserChats,
  sendMessage,
  getChatMessages,
  deleteChat,
} = require('../services/firestore-chat-service');

async function createChatController(req, res) {
  const chat = await createChat(req.body || {});
  res.status(201).json({ chat });
}

async function sendMessageController(req, res) {
  const { chatId } = req.params;
  const chatMessage = await sendMessage(chatId, req.body || {});
  res.status(201).json({ message: chatMessage });
}

async function listUserChatsController(req, res) {
  const { userId, limit } = req.query;
  const chats = await listUserChats(userId, limit);
  res.status(200).json({ chats });
}

async function getChatMessagesController(req, res) {
  const { chatId } = req.params;
  const { limit } = req.query;
  const messages = await getChatMessages(chatId, limit);
  res.status(200).json({ messages });
}

async function deleteChatController(req, res) {
  const { chatId } = req.params;
  await deleteChat(chatId);
  res.status(200).json({ success: true, deleted: chatId });
}

module.exports = {
  createChatController,
  listUserChatsController,
  sendMessageController,
  getChatMessagesController,
  deleteChatController,
};
