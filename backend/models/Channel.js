const mongoose = require('mongoose');

const channelPostSchema = new mongoose.Schema(
  {
    author: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    text: { type: String, default: '', maxlength: 2000 },
    mediaUrl: { type: String, default: null },
    createdAt: { type: Date, default: Date.now },
  },
  { _id: true }
);

const channelSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true, minlength: 2, maxlength: 80 },
    description: { type: String, default: '', maxlength: 250 },
    avatar: { type: String, default: '' },
    kind: { type: String, enum: ['channel', 'community'], default: 'channel', index: true },
    creator: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    admins: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
    subscribers: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
    isPrivate: { type: Boolean, default: false },
    posts: [channelPostSchema],
  },
  { timestamps: true }
);

channelSchema.index({ name: 'text', description: 'text' });

module.exports = mongoose.model('Channel', channelSchema);

