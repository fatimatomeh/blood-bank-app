import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:device_preview/device_preview.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/welcome_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── تهيئة Firebase ──
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("✅ Firebase Connected Successfully!");
  } catch (e) {
    print("❌ Firebase Connection Error: $e");
  }

  // ── تهيئة Supabase ──
  await Supabase.initialize(
    url: 'https://omulileqreycycorebgx.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9tdWxpbGVxcmV5Y3ljb3JlYmd4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYzNTkxMzgsImV4cCI6MjA5MTkzNTEzOH0.tjpy_vW7mO8tNlcdXOb1G_6z6_tYYK0hbYpWcNwbNK8',
  );
  print("✅ Supabase Connected Successfully!");

  runApp(
    DevicePreview(
      enabled: true,
      builder: (context) => const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      useInheritedMediaQuery: true,
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,

      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        textTheme: GoogleFonts.marheyTextTheme(Theme.of(context).textTheme),

        primaryColor: const Color(0xFFE57373),
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),

        inputDecorationTheme: const InputDecorationTheme(
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.red, width: 2),
          ),
          border: OutlineInputBorder(),
        ),
      ),

      home: const WelcomePage(),
    );
  }
}