const express = require('express');
const asyncHandler = require('../middleware/async-handler');
const {
  createUserController,
} = require('../controllers/userController');

const router = express.Router();

router.post('/', asyncHandler(createUserController));

module.exports = router;
