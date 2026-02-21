const express = require('express');
const asyncHandler = require('../middleware/async-handler');
const {
  createChatController,
  listUserChatsController,
  sendMessageController,
  getChatMessagesController,
  deleteChatController,
} = require('../controllers/chatController');

const router = express.Router();

router.post('/', asyncHandler(createChatController));
router.get('/', asyncHandler(listUserChatsController));
router.post('/:chatId/messages', asyncHandler(sendMessageController));
router.get('/:chatId/messages', asyncHandler(getChatMessagesController));
router.delete('/:chatId', asyncHandler(deleteChatController));

module.exports = router;
