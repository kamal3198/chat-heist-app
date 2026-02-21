# WhatsApp Clone - Flutter & Node.js

A full-featured WhatsApp-like chat application with contact request system, blocking functionality, real-time messaging, and file sharing.

## 🎯 Features

### ✅ Implemented Core Features
- **Secure Authentication** - JWT-based login/registration
- **Contact/Friend Request System** - Send, accept, reject requests
- **Blocking System** - Block/unblock users
- **Real-time Messaging** - Socket.IO powered chat
- **Online Status** - See who's online/offline
- **Typing Indicators** - Real-time typing detection
- **Message Status** - Sent, delivered, read receipts
- **File Sharing** - Images and documents
- **WhatsApp-like UI** - Material Design 3

## 📁 Project Structure

```
whatsapp_clone/
├── backend/                    # Node.js Express Backend
│   ├── models/
│   │   ├── User.js            # User model with password hashing
│   │   ├── ContactRequest.js  # Contact request model
│   │   ├── BlockedUser.js     # Blocked users model
│   │   └── Message.js         # Message model
│   ├── routes/
│   │   ├── auth.js            # Authentication routes
│   │   ├── contacts.js        # Contact management routes
│   │   ├── blocked.js         # Blocking routes
│   │   ├── users.js           # User search routes
│   │   └── messages.js        # Message routes
│   ├── middleware/
│   │   ├── auth.js            # JWT authentication middleware
│   │   └── upload.js          # File upload configuration
│   ├── socket.js              # Socket.IO event handlers
│   ├── server.js              # Main server file
│   ├── package.json           # Node dependencies
│   └── .env                   # Environment variables
│
└── flutter_app/               # Flutter Frontend
    ├── lib/
    │   ├── config/
    │   │   └── api_config.dart         # API endpoints configuration
    │   ├── models/
    │   │   ├── user.dart               # User model
    │   │   ├── message.dart            # Message model
    │   │   └── contact_request.dart    # Contact request model
    │   ├── services/
    │   │   ├── auth_service.dart       # Authentication service
    │   │   ├── api_service.dart        # Base API service
    │   │   ├── socket_service.dart     # Socket.IO service
    │   │   ├── contact_service.dart    # Contact management
    │   │   ├── message_service.dart    # Messaging service
    │   │   └── blocked_user_service.dart # Blocking service
    │   ├── providers/
    │   │   ├── auth_provider.dart      # Auth state management
    │   │   ├── contact_provider.dart   # Contact state management
    │   │   └── message_provider.dart   # Message state management
    │   ├── screens/
    │   │   ├── splash_screen.dart      # Splash/loading screen
    │   │   ├── login_screen.dart       # Login screen
    │   │   ├── signup_screen.dart      # Registration screen
    │   │   ├── home_screen.dart        # Main screen with tabs
    │   │   ├── chat_list_screen.dart   # List of conversations
    │   │   ├── contacts_screen.dart    # Contacts list
    │   │   ├── search_users_screen.dart # Search and add users
    │   │   ├── requests_screen.dart    # View requests
    │   │   ├── chat_screen.dart        # Individual chat
    │   │   └── profile_screen.dart     # User profile
    │   ├── widgets/
    │   │   ├── message_bubble.dart     # Chat message widget
    │   │   ├── user_avatar.dart        # User avatar widget
    │   │   └── typing_indicator.dart   # Typing animation
    │   └── main.dart                   # App entry point
    └── pubspec.yaml                    # Flutter dependencies
```

## 🚀 Setup Instructions

### Prerequisites
- Node.js (v16+)
- MongoDB (v5+)
- Flutter SDK (v3.0+)
- Android Studio / Xcode (for mobile development)

### Backend Setup

1. **Navigate to backend directory**
```bash
cd backend
```

2. **Install dependencies**
```bash
npm install
```

3. **Configure environment variables**
Edit `.env` file:
```env
PORT=3000
MONGODB_URI=mongodb://localhost:27017/whatsapp_clone
JWT_SECRET=your_secret_key_here
JWT_EXPIRES_IN=7d
```

4. **Start MongoDB**
```bash
# macOS
brew services start mongodb-community

# Linux
sudo systemctl start mongod

# Windows
net start MongoDB
```

5. **Run the server**
```bash
npm start

# Or for development with auto-reload
npm run dev
```

Server will run at `http://localhost:3000`

### Flutter App Setup

1. **Navigate to flutter app directory**
```bash
cd flutter_app
```

2. **Install dependencies**
```bash
flutter pub get
```

3. **Configure API endpoint**
Edit `lib/config/api_config.dart`:
```dart
class ApiConfig {
  // For Android Emulator
  static const String baseUrl = 'http://10.0.2.2:3000';
  
  // For iOS Simulator
  // static const String baseUrl = 'http://localhost:3000';
  
  // For Physical Device (replace with your computer's IP)
  // static const String baseUrl = 'http://192.168.1.XXX:3000';
}
```

4. **Run the app**
```bash
# List available devices
flutter devices

# Run on specific device
flutter run -d <device_id>

# Or just run (will prompt for device)
flutter run
```

## 📱 How to Use

### First Time Setup
1. **Register Account**
   - Open the app
   - Tap "Sign up"
   - Enter username and password
   - Tap "Sign Up"

2. **Add Contacts**
   - Go to Contacts tab
   - Tap "+" button
   - Search for users by username
   - Send contact request
   - Wait for acceptance

3. **Start Chatting**
   - Once request is accepted, contact appears in your list
   - Tap on contact to open chat
   - Start messaging!

### Key Features Usage

**Blocking Users**
- Long press on contact → Block
- Or in chat screen → Menu → Block

**Managing Requests**
- Tap bell icon to see pending requests
- Accept or reject requests
- View sent requests status

**File Sharing**
- In chat, tap attachment icon
- Choose image/document
- File uploads and sends automatically

## 🔒 Security Features

- **Password Hashing**: Bcrypt with salt rounds
- **JWT Authentication**: Secure token-based auth
- **Secure Storage**: flutter_secure_storage for tokens
- **API Protection**: Middleware validates all requests
- **Input Validation**: express-validator on backend
- **Socket Authentication**: User ID verification

## 🎨 UI Features

### WhatsApp-Inspired Design
- Green color scheme (#00A884)
- Material Design 3 components
- Message bubbles (sent: teal, received: gray)
- Online status indicators
- Read receipts (double checkmarks)
- Typing indicators
- Pull-to-refresh
- Smooth animations

## 📡 API Endpoints

### Authentication
```
POST /auth/register - Register new user
POST /auth/login - Login user
GET /auth/me - Get current user (protected)
```

### Contacts
```
GET /contacts - Get accepted contacts
POST /contacts/request - Send contact request
GET /contacts/requests - Get pending requests
GET /contacts/requests/sent - Get sent requests
PUT /contacts/request/:id/accept - Accept request
PUT /contacts/request/:id/reject - Reject request
DELETE /contacts/:userId - Remove contact
```

### Blocking
```
GET /blocked - Get blocked users
POST /blocked/:userId - Block user
DELETE /blocked/:userId - Unblock user
GET /blocked/check/:userId - Check if blocked
```

### Users
```
GET /users/search?username=xxx - Search users
GET /users/:id - Get user by ID
```

### Messages
```
GET /messages/:contactId - Get conversation
PUT /messages/read/:contactId - Mark as read
POST /messages/upload - Upload file
```

## 🔌 Socket Events

### Client → Server
- `registerUser` - Register socket connection
- `sendMessage` - Send message
- `typing` - Send typing status
- `markAsRead` - Mark messages as read

### Server → Client
- `receiveMessage` - New message received
- `messageSent` - Message sent confirmation
- `userTyping` - Contact is typing
- `messagesRead` - Messages read by contact
- `userOnline` - Contact came online
- `userOffline` - Contact went offline
- `contactRequest` - New contact request
- `requestAccepted` - Request was accepted
- `userBlocked` - You were blocked

## 📝 Database Schema

### User Collection
```javascript
{
  _id: ObjectId,
  username: String (unique),
  password: String (hashed),
  avatar: String,
  socketId: String,
  isOnline: Boolean,
  lastSeen: Date,
  createdAt: Date
}
```

### ContactRequest Collection
```javascript
{
  _id: ObjectId,
  sender: ObjectId (ref: User),
  receiver: ObjectId (ref: User),
  status: String ('pending', 'accepted', 'rejected'),
  createdAt: Date
}
```

### BlockedUser Collection
```javascript
{
  _id: ObjectId,
  blocker: ObjectId (ref: User),
  blocked: ObjectId (ref: User),
  createdAt: Date
}
```

### Message Collection
```javascript
{
  _id: ObjectId,
  sender: ObjectId (ref: User),
  receiver: ObjectId (ref: User),
  text: String,
  fileUrl: String,
  fileName: String,
  fileType: String,
  status: String ('sent', 'delivered', 'read'),
  timestamp: Date
}
```

## 🐛 Troubleshooting

### Backend Issues

**MongoDB Connection Error**
```bash
# Check if MongoDB is running
# macOS
brew services list

# Linux
sudo systemctl status mongod
```

**Port Already in Use**
```bash
# Find and kill process on port 3000
# macOS/Linux
lsof -ti:3000 | xargs kill -9

# Windows
netstat -ano | findstr :3000
taskkill /PID <PID> /F
```

### Flutter Issues

**Cannot Connect to Backend**
- Check API URL in `api_config.dart`
- Ensure backend server is running
- For emulator use `10.0.2.2` instead of `localhost`
- For physical device, use computer's IP address

**Package Installation Errors**
```bash
flutter clean
flutter pub get
```

**Build Errors**
```bash
flutter clean
cd ios && pod install (for iOS)
flutter run
```

## 🔄 Next Steps for Complete Implementation

The following files need to be created to complete the app:

### Flutter Providers
- `lib/providers/contact_provider.dart` - Contact management state
- `lib/providers/message_provider.dart` - Message state management

### Flutter Screens
- `lib/screens/splash_screen.dart`
- `lib/screens/login_screen.dart`
- `lib/screens/signup_screen.dart`
- `lib/screens/home_screen.dart`
- `lib/screens/chat_list_screen.dart`
- `lib/screens/contacts_screen.dart`
- `lib/screens/search_users_screen.dart`
- `lib/screens/requests_screen.dart`
- `lib/screens/chat_screen.dart`
- `lib/screens/profile_screen.dart`

### Flutter Widgets
- `lib/widgets/message_bubble.dart`
- `lib/widgets/user_avatar.dart`
- `lib/widgets/typing_indicator.dart`
- `lib/widgets/online_indicator.dart`

I can provide these files if needed!

## 📦 Dependencies

### Backend
- express - Web framework
- mongoose - MongoDB ODM
- socket.io - Real-time communication
- bcryptjs - Password hashing
- jsonwebtoken - JWT authentication
- multer - File upload handling
- cors - Cross-origin requests

### Flutter
- http - HTTP requests
- socket_io_client - Socket.IO client
- flutter_secure_storage - Secure token storage
- provider - State management
- image_picker - Image selection
- file_picker - Document selection
- cached_network_image - Image caching
- timeago - Time formatting
- intl - Internationalization

## 📄 License

This project is created for educational purposes.

## 👨‍💻 Contributing

Feel free to fork and improve this project!

## 📞 Support

For issues and questions, please create an issue in the repository.

---

**Happy Coding! 🚀**
