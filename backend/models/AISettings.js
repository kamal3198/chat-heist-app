const mongoose = require('mongoose');

const aiSettingsSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    unique: true,
  },
  enabled: {
    type: Boolean,
    default: false,
  },
  autoReplyEnabled: {
    type: Boolean,
    default: false,
  },
  // Keywords and corresponding auto-reply responses
  autoReplyRules: [{
    keyword: {
      type: String,
      required: true,
    },
    response: {
      type: String,
      required: true,
    },
    isCaseSensitive: {
      type: Boolean,
      default: false,
    },
  }],
  // Default AI responses for common scenarios
  defaultResponses: {
    away: {
      type: String,
      default: 'I am currently away. Will get back to you soon!',
    },
    busy: {
      type: String,
      default: 'I am busy right now. Will reply later!',
    },
    custom: {
      type: String,
      default: 'Thanks for your message! I will respond shortly.',
    },
  },
  // Quick replies for suggested responses
  quickReplies: [{
    type: String,
  }],
  createdAt: {
    type: Date,
    default: Date.now,
  },
  updatedAt: {
    type: Date,
    default: Date.now,
  },
});

// Pre-save middleware to update timestamps
aiSettingsSchema.pre('save', function(next) {
  this.updatedAt = new Date();
  next();
});

aiSettingsSchema.set('toJSON', { virtuals: true });
aiSettingsSchema.set('toObject', { virtuals: true });

module.exports = mongoose.model('AISettings', aiSettingsSchema);
