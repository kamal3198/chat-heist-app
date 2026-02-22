#!/bin/bash

echo "Starting WhatsApp Clone Backend (Firebase)"
echo "========================================="
echo ""

if ! command -v node &> /dev/null; then
    echo "Node.js is not installed"
    exit 1
fi

echo "Node.js version: $(node --version)"

if ! command -v npm &> /dev/null; then
    echo "npm is not installed"
    exit 1
fi

echo "npm version: $(npm --version)"
echo ""

if [ ! -d "node_modules" ]; then
    echo "Installing dependencies..."
    npm install
    echo ""
fi

if [ ! -f ".env" ]; then
    echo ".env file not found. Create backend/.env with Firebase credentials."
    exit 1
fi

echo "Starting server..."
echo "Backend URL: configured via PORT / deployment environment"
echo ""

npm start
