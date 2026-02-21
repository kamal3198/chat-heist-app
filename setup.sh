#!/bin/bash

# WhatsApp Clone - Complete Setup Script
# This script will set up the entire project

set -e  # Exit on error

echo "🚀 WhatsApp Clone - Complete Setup"
echo "===================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BACKEND_DIR="$SCRIPT_DIR/backend"
FLUTTER_DIR="$SCRIPT_DIR/flutter_app"

# Check prerequisites
echo "📋 Checking prerequisites..."
echo ""

# Check Node.js
if ! command -v node &> /dev/null; then
    echo -e "${RED}❌ Node.js is not installed${NC}"
    echo "   Please install from https://nodejs.org"
    exit 1
fi
echo -e "${GREEN}✓${NC} Node.js $(node --version)"

# Check npm
if ! command -v npm &> /dev/null; then
    echo -e "${RED}❌ npm is not installed${NC}"
    exit 1
fi
echo -e "${GREEN}✓${NC} npm $(npm --version)"

# Check Flutter
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}❌ Flutter is not installed${NC}"
    echo "   Please install from https://flutter.dev"
    exit 1
fi
echo -e "${GREEN}✓${NC} Flutter $(flutter --version | head -n 1)"

# Check MongoDB
echo ""
echo "📡 Checking MongoDB..."
if ! mongosh --eval "db.version()" --quiet &> /dev/null; then
    echo -e "${YELLOW}⚠️  MongoDB is not running${NC}"
    echo ""
    echo "Please start MongoDB before continuing:"
    echo "  macOS:   brew services start mongodb-community"
    echo "  Linux:   sudo systemctl start mongod"
    echo "  Windows: net start MongoDB"
    echo "  Docker:  docker run -d -p 27017:27017 --name mongodb mongo"
    echo ""
    read -p "Press Enter once MongoDB is running (or Ctrl+C to cancel)..."
    
    # Check again
    if ! mongosh --eval "db.version()" --quiet &> /dev/null; then
        echo -e "${RED}❌ MongoDB is still not running${NC}"
        exit 1
    fi
fi
echo -e "${GREEN}✓${NC} MongoDB is running"

# Setup Backend
echo ""
echo "📦 Setting up backend..."
cd "$BACKEND_DIR"

if [ ! -d "node_modules" ]; then
    echo "Installing Node.js dependencies..."
    npm install
    echo -e "${GREEN}✓${NC} Backend dependencies installed"
else
    echo -e "${GREEN}✓${NC} Backend dependencies already installed"
fi

# Setup Flutter
echo ""
echo "📱 Setting up Flutter app..."
cd "$FLUTTER_DIR"

echo "Getting Flutter dependencies..."
flutter pub get
echo -e "${GREEN}✓${NC} Flutter dependencies installed"

# Configuration reminder
echo ""
echo "⚙️  Configuration Required"
echo "========================="
echo ""
echo "Before running the app, you need to configure the API URL:"
echo ""
echo "Edit: flutter_app/lib/config/api_config.dart"
echo ""
echo "For Android Emulator:"
echo "  baseUrl = 'http://10.0.2.2:3000'"
echo ""
echo "For iOS Simulator:"
echo "  baseUrl = 'http://localhost:3000'"
echo ""
echo "For Physical Device:"
echo "  1. Find your IP: ifconfig (Mac/Linux) or ipconfig (Windows)"
echo "  2. baseUrl = 'http://YOUR_IP:3000'"
echo ""

# Summary
echo ""
echo "✅ Setup Complete!"
echo "=================="
echo ""
echo "Next steps:"
echo ""
echo "1. Configure API URL (see above)"
echo ""
echo "2. Start the backend:"
echo "   cd backend"
echo "   npm start"
echo ""
echo "3. In a new terminal, run Flutter:"
echo "   cd flutter_app"
echo "   flutter run"
echo ""
echo "4. Create test accounts and start chatting!"
echo ""
echo "📚 For detailed instructions, see:"
echo "   - README.md"
echo "   - QUICKSTART.md"
echo "   - EXECUTION_GUIDE.md"
echo ""
