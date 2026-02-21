const mongoose = require('mongoose');

const deviceSessionSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    deviceId: { type: String, required: true },
    deviceName: { type: String, default: 'Unknown device' },
    platform: { type: String, default: 'unknown' },
    appVersion: { type: String, default: '1.0.0' },
    isActive: { type: Boolean, default: true },
    lastActiveAt: { type: Date, default: Date.now },
  },
  { timestamps: true }
);

deviceSessionSchema.index({ user: 1, deviceId: 1 }, { unique: true });

module.exports = mongoose.model('DeviceSession', deviceSessionSchema);

