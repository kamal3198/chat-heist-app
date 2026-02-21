#!/bin/bash

echo "🚀 Starting WhatsApp Clone Backend"
echo "=================================="
echo ""

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed!"
    echo "   Please install Node.js from https://nodejs.org"
    exit 1
fi

echo "✓ Node.js version: $(node --version)"

# Check if npm is installed
if ! command -v npm &> /dev/null; then
    echo "❌ npm is not installed!"
    exit 1
fi

echo "✓ npm version: $(npm --version)"

# Check if MongoDB is running
echo ""
echo "Checking MongoDB connection..."
if ! mongosh --eval "db.version()" --quiet &> /dev/null; then
    echo "⚠️  MongoDB is not running!"
    echo ""
    echo "Please start MongoDB:"
    echo "  macOS:   brew services start mongodb-community"
    echo "  Linux:   sudo systemctl start mongod"
    echo "  Windows: net start MongoDB"
    echo "  Docker:  docker run -d -p 27017:27017 --name mongodb mongo"
    echo ""
    read -p "Press Enter once MongoDB is running..."
fi

echo "✓ MongoDB is running"
echo ""

# Check if node_modules exists
if [ ! -d "node_modules" ]; then
    echo "📦 Installing dependencies..."
    npm install
    echo ""
fi

# Check if .env exists
if [ ! -f ".env" ]; then
    echo "⚠️  .env file not found, using defaults"
fi

# Start the server
echo "🚀 Starting server..."
echo ""
echo "Backend will be available at: http://localhost:3000"
echo ""
echo "Press Ctrl+C to stop the server"
echo "=================================="
echo ""

npm start
