# Quick Start Guide - WhatsApp Clone

## 🚀 Get Started in 5 Minutes

### Step 1: Start MongoDB
```bash
# macOS
brew services start mongodb-community

# Linux
sudo systemctl start mongod

# Windows
net start MongoDB

# Or use Docker
docker run -d -p 27017:27017 --name mongodb mongo
```

### Step 2: Start the Backend
```bash
cd backend
npm install
npm start
```

You should see:
```
Connected to MongoDB
Server running on port 3000
```

### Step 3: Configure Flutter App
Edit `flutter_app/lib/config/api_config.dart`:

**For Android Emulator:**
```dart
static const String baseUrl = 'http://10.0.2.2:3000';
static const String socketUrl = 'http://10.0.2.2:3000';
```

**For iOS Simulator:**
```dart
static const String baseUrl = 'http://localhost:3000';
static const String socketUrl = 'http://localhost:3000';
```

**For Physical Device:**
1. Find your computer's IP address:
   ```bash
   # macOS/Linux
   ifconfig | grep "inet "
   
   # Windows
   ipconfig
   ```

2. Update config (replace YOUR_IP with your actual IP):
   ```dart
   static const String baseUrl = 'http://YOUR_IP:3000';
   static const String socketUrl = 'http://YOUR_IP:3000';
   ```

### Step 4: Run Flutter App
```bash
cd flutter_app
flutter pub get
flutter run
```

### Step 5: Test the App

1. **Create First Account**
   - Tap "Sign up"
   - Username: `alice`
   - Password: `password123`
   - Tap "Sign Up"

2. **Create Second Account** (on another device/emulator)
   - Tap "Sign up"
   - Username: `bob`
   - Password: `password123`
   - Tap "Sign Up"

3. **Add Contact**
   - Go to Contacts tab
   - Tap "+" button
   - Search for the other user
   - Send contact request

4. **Accept Request** (on other device)
   - Tap bell icon
   - Accept the request

5. **Start Chatting!**
   - Tap on the contact
   - Start messaging

## 🔧 Troubleshooting

### Backend won't start
```bash
# Check if port 3000 is already in use
lsof -ti:3000 | xargs kill -9  # macOS/Linux
netstat -ano | findstr :3000   # Windows

# Check MongoDB is running
mongosh  # Should connect successfully
```

### Flutter app can't connect
```bash
# Test backend is accessible
curl http://10.0.2.2:3000  # From Android Emulator
curl http://localhost:3000  # From iOS Simulator

# Check API config is correct
cat flutter_app/lib/config/api_config.dart
```

### Dependencies issue
```bash
# Backend
cd backend
rm -rf node_modules package-lock.json
npm install

# Flutter
cd flutter_app
flutter clean
flutter pub get
```

## 📱 Development Tips

### Hot Reload (Flutter)
- Press `r` in terminal for hot reload
- Press `R` for hot restart
- Press `q` to quit

### Backend Auto-Reload
```bash
npm install -g nodemon
npm run dev  # Uses nodemon for auto-restart
```

### View MongoDB Data
```bash
mongosh
use whatsapp_clone
db.users.find().pretty()
db.messages.find().pretty()
db.contactrequests.find().pretty()
```

### Test API Endpoints
```bash
# Register user
curl -X POST http://localhost:3000/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"test123"}'

# Login
curl -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"test123"}'
```

## 🎯 Next Steps

To complete the full implementation, you need to create:

1. **Contact Provider** - Manages contact state
2. **Message Provider** - Manages message state
3. **Chat List Screen** - Shows recent conversations
4. **Contacts Screen** - Shows contact list
5. **Search Users Screen** - Search and add contacts
6. **Requests Screen** - Manage contact requests
7. **Chat Screen** - Individual chat interface
8. **Message Widgets** - Message bubbles, typing indicators

The core infrastructure is ready:
- ✅ Backend API with all endpoints
- ✅ Socket.IO for real-time communication
- ✅ Authentication system
- ✅ Database models
- ✅ Flutter services (API, Socket, Auth)
- ✅ Basic screens (Splash, Login, Signup, Home)

## 🐛 Common Issues

### Issue: "Connection refused"
**Solution:** Make sure backend is running and API URL is correct

### Issue: "CORS error"
**Solution:** Backend already has CORS enabled, check URL format

### Issue: "JWT token invalid"
**Solution:** Logout and login again, or clear app data

### Issue: "Socket not connecting"
**Solution:** Check Socket URL matches API URL

### Issue: "File upload fails"
**Solution:** Ensure `uploads/` directory exists in backend

## 📚 Additional Resources

- [Flutter Documentation](https://docs.flutter.dev)
- [Socket.IO Documentation](https://socket.io/docs)
- [MongoDB Documentation](https://www.mongodb.com/docs)
- [Express.js Guide](https://expressjs.com/en/guide)

---

Need help? Check the main README.md for detailed documentation!
