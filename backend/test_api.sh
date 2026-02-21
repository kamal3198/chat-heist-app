#!/bin/bash

echo "Firebase backend smoke test"
BASE_URL="https://chat-heist-app.onrender.com"

echo -n "Health check... "
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" $BASE_URL/health)

if [ "$RESPONSE" -eq 200 ]; then
  echo "PASS"
else
  echo "FAIL ($RESPONSE)"
fi

echo ""
echo "Auth note: /auth/register and /auth/login now use Firebase Authentication (email/password)."
echo "Make sure Firebase credentials are set in Render environment variables."
