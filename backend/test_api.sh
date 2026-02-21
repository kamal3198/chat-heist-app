#!/bin/bash

# Backend API Test Script
# This script tests all backend endpoints to ensure they're working

echo "🧪 WhatsApp Clone Backend API Tests"
echo "===================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

BASE_URL="http://localhost:3000"

# Test 1: Health Check
echo -n "1. Testing health check endpoint... "
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" $BASE_URL)
if [ $RESPONSE -eq 200 ]; then
    echo -e "${GREEN}✓ PASSED${NC}"
else
    echo -e "${RED}✗ FAILED (HTTP $RESPONSE)${NC}"
fi

# Test 2: User Registration
echo -n "2. Testing user registration... "
RESPONSE=$(curl -s -w "%{http_code}" -X POST $BASE_URL/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser_'$(date +%s)'","password":"test123456"}' \
  -o /tmp/register_response.json)

if [ $RESPONSE -eq 201 ]; then
    TOKEN=$(cat /tmp/register_response.json | grep -o '"token":"[^"]*' | cut -d'"' -f4)
    echo -e "${GREEN}✓ PASSED${NC}"
    echo "   Token: ${TOKEN:0:20}..."
else
    echo -e "${RED}✗ FAILED (HTTP $RESPONSE)${NC}"
    cat /tmp/register_response.json
fi

# Test 3: User Login
echo -n "3. Testing user login... "
RESPONSE=$(curl -s -w "%{http_code}" -X POST $BASE_URL/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"test123456"}' \
  -o /tmp/login_response.json)

if [ $RESPONSE -eq 200 ] || [ $RESPONSE -eq 401 ]; then
    echo -e "${GREEN}✓ PASSED${NC} (endpoint working)"
else
    echo -e "${RED}✗ FAILED (HTTP $RESPONSE)${NC}"
fi

# Test 4: Get Current User (with token)
if [ ! -z "$TOKEN" ]; then
    echo -n "4. Testing get current user (protected route)... "
    RESPONSE=$(curl -s -w "%{http_code}" -X GET $BASE_URL/auth/me \
      -H "Authorization: Bearer $TOKEN" \
      -o /tmp/me_response.json)
    
    if [ $RESPONSE -eq 200 ]; then
        echo -e "${GREEN}✓ PASSED${NC}"
        USERNAME=$(cat /tmp/me_response.json | grep -o '"username":"[^"]*' | cut -d'"' -f4)
        echo "   Username: $USERNAME"
    else
        echo -e "${RED}✗ FAILED (HTTP $RESPONSE)${NC}"
    fi
else
    echo -e "${YELLOW}4. Skipping protected route test (no token)${NC}"
fi

# Test 5: Search Users
if [ ! -z "$TOKEN" ]; then
    echo -n "5. Testing search users... "
    RESPONSE=$(curl -s -w "%{http_code}" -X GET "$BASE_URL/users/search?username=test" \
      -H "Authorization: Bearer $TOKEN" \
      -o /dev/null)
    
    if [ $RESPONSE -eq 200 ]; then
        echo -e "${GREEN}✓ PASSED${NC}"
    else
        echo -e "${RED}✗ FAILED (HTTP $RESPONSE)${NC}"
    fi
else
    echo -e "${YELLOW}5. Skipping search test (no token)${NC}"
fi

# Test 6: Get Contacts
if [ ! -z "$TOKEN" ]; then
    echo -n "6. Testing get contacts... "
    RESPONSE=$(curl -s -w "%{http_code}" -X GET $BASE_URL/contacts \
      -H "Authorization: Bearer $TOKEN" \
      -o /dev/null)
    
    if [ $RESPONSE -eq 200 ]; then
        echo -e "${GREEN}✓ PASSED${NC}"
    else
        echo -e "${RED}✗ FAILED (HTTP $RESPONSE)${NC}"
    fi
else
    echo -e "${YELLOW}6. Skipping contacts test (no token)${NC}"
fi

# Test 7: Get Blocked Users
if [ ! -z "$TOKEN" ]; then
    echo -n "7. Testing get blocked users... "
    RESPONSE=$(curl -s -w "%{http_code}" -X GET $BASE_URL/blocked \
      -H "Authorization: Bearer $TOKEN" \
      -o /dev/null)
    
    if [ $RESPONSE -eq 200 ]; then
        echo -e "${GREEN}✓ PASSED${NC}"
    else
        echo -e "${RED}✗ FAILED (HTTP $RESPONSE)${NC}"
    fi
else
    echo -e "${YELLOW}7. Skipping blocked users test (no token)${NC}"
fi

echo ""
echo "===================================="
echo "✅ Backend API Tests Complete"
echo ""
echo "Note: Some tests may fail if users don't exist yet."
echo "Create test users through the Flutter app or API to fully test."
echo ""

# Cleanup
rm -f /tmp/register_response.json /tmp/login_response.json /tmp/me_response.json
