import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/locale/app_locale.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'screens/auth/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const NirapodClickApp());
}

class NirapodClickApp extends StatefulWidget {
  const NirapodClickApp({super.key});

  @override
  State<NirapodClickApp> createState() => _NirapodClickAppState();
}

class _NirapodClickAppState extends State<NirapodClickApp> {
  AppLocale _locale = AppLocale.english;

  void _setLocale(AppLocale next) {
    setState(() => _locale = next);
  }

  @override
  Widget build(BuildContext context) {
    return AppLocaleScope(
      locale: _locale,
      onChanged: _setLocale,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'NirapodClick',
        theme: AppTheme.lightTheme,
        // AuthGate listens to Firebase's auth state:
        //   - while the cached session rehydrates, shows a branded splash
        //   - resolves to HomePage when signed in (persistent login)
        //   - resolves to LoginPage when signed out
        home: const AuthGate(),
      ),
    );
  }
}