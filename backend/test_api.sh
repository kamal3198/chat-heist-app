#!/bin/bash

echo "Firebase backend smoke test"
BASE_URL="http://localhost:3000"

echo -n "Health check... "
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" $BASE_URL)
if [ $RESPONSE -eq 200 ]; then
  echo "PASS"
else
  echo "FAIL ($RESPONSE)"
fi

echo ""
echo "Auth note: /auth/register and /auth/login now use Firebase Authentication (email/password)."
echo "Provide Firebase credentials in backend/.env before running auth tests."
