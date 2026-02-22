import React, { createContext, useContext, useMemo, useState } from 'react';

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [idToken, setIdToken] = useState(null);
  const [firebaseUser, setFirebaseUser] = useState(null);

  const value = useMemo(
    () => ({
      idToken,
      firebaseUser,
      setSession: ({ token, user }) => {
        setIdToken(token);
        setFirebaseUser(user);
      },
      clearSession: () => {
        setIdToken(null);
        setFirebaseUser(null);
      },
    }),
    [idToken, firebaseUser]
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) {
    throw new Error('useAuth must be used inside AuthProvider');
  }
  return ctx;
}

