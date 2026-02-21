# ⚡ QUICK RUN GUIDE

## Copy-Paste Commands to Execute

### Terminal 1 - Start Backend

```bash
# Navigate to backend directory
cd whatsapp_clone/backend

# Install dependencies (first time only)
npm install

# Start MongoDB (choose your OS)
brew services start mongodb-community  # macOS
# OR
sudo systemctl start mongod  # Linux
# OR
docker run -d -p 27017:27017 --name mongodb mongo  # Docker

# Start the backend server
npm start
```

**✅ Success looks like:**
```
Connected to MongoDB
Server running on port 3000
```

---

### Terminal 2 - Run Flutter App

```bash
# Navigate to flutter app directory
cd whatsapp_clone/flutter_app

# Install dependencies (first time only)
flutter pub get

# Run the app
flutter run
```

**Choose device when prompted**

---

## Before Running Flutter

### ⚠️ IMPORTANT: Configure API URL

Edit: `flutter_app/lib/config/api_config.dart`

**For Android Emulator (most common):**
```dart
static const String baseUrl = 'http://10.0.2.2:3000';
static const String socketUrl = 'http://10.0.2.2:3000';
```

**For iOS Simulator:**
```dart
static const String baseUrl = 'http://localhost:3000';
static const String socketUrl = 'http://localhost:3000';
```

---

## Test the Setup

### Option 1: Test Backend API
```bash
cd whatsapp_clone/backend
./test_api.sh
```

### Option 2: Manual Test
```bash
# Test if backend is running
curl http://localhost:3000

# Should return:
# {"message":"WhatsApp Clone API","version":"1.0.0","status":"running"}
```

---

## What You Can Test in the App

### ✅ Working Now:
1. **Register Account**
   - Tap "Sign up"
   - Enter username & password
   - Tap "Sign Up"

2. **Login**
   - Enter credentials
   - Tap "Login"

3. **View Profile**
   - See your username
   - See avatar
   - Logout button works

### ❌ Not Working Yet (Screens Not Built):
- Chatting with users
- Adding contacts
- Viewing conversations
- Sending messages

---

## If Something Goes Wrong

### Backend won't start?
```bash
# Check if port 3000 is busy
lsof -ti:3000 | xargs kill -9

# Reinstall dependencies
rm -rf node_modules
npm install
npm start
```

### Flutter won't connect?
1. Make sure backend is running (see Terminal 1)
2. Check `api_config.dart` has correct URL
3. For Android, MUST use `10.0.2.2` not `localhost`

### MongoDB error?
```bash
# Check if MongoDB is running
mongosh

# If not running, start it
brew services start mongodb-community  # macOS
```

---

## Quick Commands Reference

| Task | Command |
|------|---------|
| Start backend | `cd backend && npm start` |
| Run Flutter | `cd flutter_app && flutter run` |
| Test API | `cd backend && ./test_api.sh` |
| Kill port 3000 | `lsof -ti:3000 \| xargs kill -9` |
| Flutter hot reload | Press `r` in terminal |
| Flutter restart | Press `R` in terminal |
| Stop app | Press `q` in terminal |

---

## Next Steps

Once you've successfully run the app and tested registration/login, let me know and I can:

1. ✨ Complete all missing screens (ChatScreen, ContactsScreen, etc.)
2. 🎨 Add all missing widgets (MessageBubble, UserAvatar, etc.)
3. 🔧 Create the remaining providers (ContactProvider, MessageProvider)

Then you'll have a **fully functional WhatsApp clone** that can actually send messages!

---

## Expected File Structure After Download

```
whatsapp_clone/
├── backend/
│   ├── models/
│   ├── routes/
│   ├── middleware/
│   ├── server.js
│   ├── socket.js
│   ├── package.json
│   ├── .env
│   ├── start.sh ← Run this!
│   └── test_api.sh ← Test with this!
│
├── flutter_app/
│   ├── lib/
│   │   ├── config/
│   │   │   └── api_config.dart ← Edit this first!
│   │   ├── models/
│   │   ├── services/
│   │   ├── providers/
│   │   ├── screens/
│   │   └── main.dart
│   └── pubspec.yaml
│
├── README.md
├── QUICKSTART.md
├── EXECUTION_GUIDE.md
└── This file
```
