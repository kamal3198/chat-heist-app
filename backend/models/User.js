const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const userSchema = new mongoose.Schema({
  username: {
    type: String,
    required: true,
    unique: true,
    trim: true,
    lowercase: true,
    minlength: 3
  },
  password: {
    type: String,
    required: true,
    minlength: 6
  },
  avatar: {
    type: String,
    default: 'https://ui-avatars.com/api/?background=random&name='
  },
  about: {
    type: String,
    default: 'Hey there! I am using ChatHeist.',
    maxlength: 140
  },
  socketId: {
    type: String,
    default: null
  },
  isOnline: {
    type: Boolean,
    default: false
  },
  lastSeen: {
    type: Date,
    default: Date.now
  },
  aiSettings: {
    enabled: { type: Boolean, default: false },
    mode: { type: String, enum: ['off', 'away', 'busy', 'custom'], default: 'off' },
    customReply: {
      type: String,
      default: 'Thanks for your message. I will get back to you soon.',
      maxlength: 500,
    },
  },
  createdAt: {
    type: Date,
    default: Date.now
  }
});

userSchema.pre('save', async function(next) {
  if (!this.isModified('password')) return next();

  try {
    const salt = await bcrypt.genSalt(10);
    this.password = await bcrypt.hash(this.password, salt);

    if (this.avatar === 'https://ui-avatars.com/api/?background=random&name=') {
      this.avatar = `https://ui-avatars.com/api/?background=random&name=${this.username}`;
    }

    next();
  } catch (error) {
    next(error);
  }
});

userSchema.methods.comparePassword = async function(candidatePassword) {
  return await bcrypt.compare(candidatePassword, this.password);
};

userSchema.methods.toJSON = function() {
  const user = this.toObject();
  delete user.password;
  delete user.__v;
  return user;
};

module.exports = mongoose.model('User', userSchema);

