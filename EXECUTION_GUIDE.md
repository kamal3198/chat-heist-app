# 🚀 EXECUTION GUIDE - WhatsApp Clone

## Step-by-Step Instructions to Run the App

### Prerequisites Check

Before starting, ensure you have:
- [ ] Node.js installed (v16+) - Check: `node --version`
- [ ] MongoDB installed - Check: `mongod --version`
- [ ] Flutter installed (v3.0+) - Check: `flutter --version`
- [ ] An Android emulator or iOS simulator running

---

## PART 1: Start the Backend

### Step 1: Open Terminal and Navigate to Backend
```bash
cd whatsapp_clone/backend
```

### Step 2: Install Dependencies
```bash
npm install
```

You should see packages installing. This takes 1-2 minutes.

### Step 3: Start MongoDB

**On macOS:**
```bash
brew services start mongodb-community
```

**On Linux:**
```bash
sudo systemctl start mongod
```

**On Windows:**
```bash
net start MongoDB
```

**Or use Docker:**
```bash
docker run -d -p 27017:27017 --name mongodb mongo
```

**Verify MongoDB is running:**
```bash
mongosh
# You should see: "Connected to MongoDB"
# Type: exit
```

### Step 4: Start the Backend Server
```bash
npm start
```

**Expected Output:**
```
Connected to MongoDB
Server running on port 3000
```

✅ **Backend is now running!** Keep this terminal open.

---

## PART 2: Configure Flutter App

### Step 5: Open a NEW Terminal

### Step 6: Navigate to Flutter App
```bash
cd whatsapp_clone/flutter_app
```

### Step 7: Configure API URL

**Important:** You need to edit the API configuration based on your setup.

Edit the file: `lib/config/api_config.dart`

**Choose your configuration:**

**A) For Android Emulator (Most Common):**
```dart
static const String baseUrl = 'http://10.0.2.2:3000';
static const String socketUrl = 'http://10.0.2.2:3000';
```

**B) For iOS Simulator:**
```dart
static const String baseUrl = 'http://localhost:3000';
static const String socketUrl = 'http://localhost:3000';
```

**C) For Physical Device:**
First, find your computer's IP address:

```bash
# macOS/Linux
ifconfig | grep "inet "
# Look for something like: inet 192.168.1.XXX

# Windows
ipconfig
# Look for IPv4 Address
```

Then use:
```dart
static const String baseUrl = 'http://192.168.1.XXX:3000';
static const String socketUrl = 'http://192.168.1.XXX:3000';
```
(Replace XXX with your actual IP)

### Step 8: Install Flutter Dependencies
```bash
flutter pub get
```

**Expected Output:**
```
Running "flutter pub get" in flutter_app...
Resolving dependencies...
Got dependencies!
```

---

## PART 3: Run the Flutter App

### Step 9: Check Available Devices
```bash
flutter devices
```

**Expected Output (example):**
```
2 connected devices:

sdk gphone64 arm64 (mobile) • emulator-5554 • android-arm64 • Android 13 (API 33)
macOS (desktop)              • macos          • darwin-arm64  • macOS 14.0
```

Choose your device from this list.

### Step 10: Run the App
```bash
flutter run
```

**Or specify a device:**
```bash
flutter run -d emulator-5554
# Replace 'emulator-5554' with your device ID
```

**Expected Output:**
```
Launching lib/main.dart on sdk gphone64 arm64 in debug mode...
Running Gradle task 'assembleDebug'...
✓ Built build/app/outputs/flutter-apk/app-debug.apk.
Installing build/app/outputs/flutter-apk/app.apk...
Syncing files to device sdk gphone64 arm64...
Flutter run key commands.
r Hot reload. 🔥🔥🔥
R Hot restart.
h List all available interactive commands.
d Detach (terminate "flutter run" but leave application running).
c Clear the screen
q Quit (terminate the application on the device).

💪 Running with sound null safety 💪

An Observatory debugger and profiler on sdk gphone64 arm64 is available at: http://127.0.0.1:xxxxx/
The Flutter DevTools debugger and profiler on sdk gphone64 arm64 is available at: http://127.0.0.1:xxxxx/
```

✅ **App is now running!**

---

## PART 4: Test the App

### What You Can Test Now:

1. **Splash Screen** 
   - You'll see the app logo and loading indicator
   - After 2 seconds, navigate to Login

2. **Registration**
   - Tap "Sign up"
   - Enter username: `alice`
   - Enter password: `password123`
   - Confirm password: `password123`
   - Tap "Sign Up"
   - Should navigate to Home screen

3. **Home Screen**
   - You'll see bottom navigation with: Chats, Contacts, Profile
   - Chats tab shows: "Chats Tab - To be implemented"
   - Contacts tab shows: "Contacts Tab - To be implemented"
   - Profile tab shows: Your username, avatar, and Logout button

4. **Logout**
   - Go to Profile tab
   - Tap "Logout" button
   - Should return to Login screen

5. **Login**
   - Enter username: `alice`
   - Enter password: `password123`
   - Tap "Login"
   - Should navigate back to Home screen

### What You CANNOT Test (Not Implemented Yet):
- ❌ Chatting
- ❌ Adding contacts
- ❌ Sending messages
- ❌ Viewing conversations

---

## TROUBLESHOOTING

### Problem: "Connection refused" or "Network error"

**Solution:**
1. Check backend is running (you should see "Server running on port 3000")
2. Check `api_config.dart` has correct URL
3. For Android emulator, MUST use `http://10.0.2.2:3000` not `localhost`

**Test backend manually:**
```bash
curl http://localhost:3000
# Should return: {"message":"WhatsApp Clone API","version":"1.0.0","status":"running"}
```

### Problem: "MongoDB connection error"

**Solution:**
```bash
# Check if MongoDB is running
brew services list  # macOS
sudo systemctl status mongod  # Linux

# Start MongoDB
brew services start mongodb-community  # macOS
sudo systemctl start mongod  # Linux
```

### Problem: "Port 3000 already in use"

**Solution:**
```bash
# Kill process on port 3000
lsof -ti:3000 | xargs kill -9  # macOS/Linux
```

### Problem: Flutter build fails

**Solution:**
```bash
flutter clean
flutter pub get
flutter run
```

### Problem: "Unable to load asset"

**Solution:**
```bash
# In flutter_app directory
flutter clean
flutter pub get
# Then run again
```

---

## VERIFICATION CHECKLIST

After running, you should have:

- [ ] Backend terminal shows: "Server running on port 3000"
- [ ] MongoDB is connected
- [ ] Flutter app launches on device/emulator
- [ ] Splash screen appears
- [ ] Can register a new user
- [ ] Can login with registered user
- [ ] Can see home screen with 3 tabs
- [ ] Can logout and return to login screen

---

## NEXT STEPS

Once everything is running, I can create the missing screens:
1. ChatScreen (most important)
2. ContactsScreen
3. ChatListScreen
4. SearchUsersScreen
5. RequestsScreen
6. All widgets

Would you like me to create these now so you can actually chat?

---

## TERMINAL LAYOUT

**Recommended setup - 2 terminals:**

```
Terminal 1 (Backend):          Terminal 2 (Flutter):
whatsapp_clone/backend/        whatsapp_clone/flutter_app/
$ npm start                    $ flutter run
[Server running...]            [App running...]
```

Keep both running while testing!
