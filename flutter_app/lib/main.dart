import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/call_provider.dart';
import 'providers/chat_settings_provider.dart';
import 'providers/contact_provider.dart';
import 'providers/group_provider.dart';
import 'providers/message_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String? firebaseInitError;
  try {
    await _initializeFirebase();
  } catch (e) {
    firebaseInitError = e.toString();
  }

  runApp(MyApp(firebaseInitError: firebaseInitError));
}

Future<void> _initializeFirebase() async {
  try {
    await Firebase.initializeApp();
    return;
  } catch (_) {
    const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
    const appId = String.fromEnvironment('FIREBASE_APP_ID');
    const messagingSenderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
    const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
    const storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');

    if (apiKey.isEmpty || appId.isEmpty || messagingSenderId.isEmpty || projectId.isEmpty) {
      throw Exception(
        'Firebase is not configured. Run "flutterfire configure" or pass '
        '--dart-define values for FIREBASE_API_KEY, FIREBASE_APP_ID, '
        'FIREBASE_MESSAGING_SENDER_ID, FIREBASE_PROJECT_ID.',
      );
    }

    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: messagingSenderId,
        projectId: projectId,
        storageBucket: storageBucket.isEmpty ? null : storageBucket,
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  final String? firebaseInitError;

  const MyApp({super.key, this.firebaseInitError});

  @override
  Widget build(BuildContext context) {
    if (firebaseInitError != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Firebase init failed:\n\n$firebaseInitError',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ContactProvider()),
        ChangeNotifierProvider(create: (_) => GroupProvider()),
        ChangeNotifierProvider(create: (_) => MessageProvider()),
        ChangeNotifierProvider(create: (_) => CallProvider()),
        ChangeNotifierProvider(
          create: (_) => ChatSettingsProvider()..load(),
        ),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) => MaterialApp(
          title: 'ChatHeist',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          home: const SplashScreen(),
        ),
      ),
    );
  }
}
