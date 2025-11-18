import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'firebase_options.dart';
import 'screens/auth_screen.dart';
import 'screens/biodata_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/buat_surat_screen.dart';
import 'screens/rekrut_rtrw_screen.dart';
import 'screens/tambah_anggota_screen.dart';
import 'screens/detail_surat_screen.dart';
import 'screens/detail_akun_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Supabase.initialize(
    url: 'https://kbkaqntbkulplmmwwmhw.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imtia2FxbnRia3VscGxtbXd3bWh3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk4MTk0MTYsImV4cCI6MjA3NTM5NTQxNn0.UL3MlABGTLyT4Nvaz8Zzh7Oh9gyI1RM13VEGZX-rAnQ',
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  static final GoRouter _router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => AuthScreen()),
      GoRoute(path: '/biodata', builder: (context, state) => BiodataScreen()),
      GoRoute(path: '/dashboard/:role', builder: (context, state) => DashboardScreen(role: state.pathParameters['role']!)),
      GoRoute(path: '/buat-surat', builder: (context, state) => BuatSuratScreen()),
      GoRoute(path: '/rekrut-rtrw', builder: (context, state) => RekrutRTRWScreen()),
      GoRoute(path: '/tambah-anggota', builder: (context, state) => TambahAnggotaScreen()),
  GoRoute(path: '/detail-akun', builder: (context, state) => DetailAkunScreen()),
      GoRoute(path: '/detail-surat/:id', builder: (context, state) => DetailSuratScreen(id: state.pathParameters['id']!)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: _router,
      title: 'Surat Pengantar Sukorame',
      theme: ThemeData(
        // Dominant green theme
        primarySwatch: Colors.green,
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.green).copyWith(
          secondary: Colors.greenAccent,
        ),
        scaffoldBackgroundColor: const Color(0xFFF3FBF5), // very light green background
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.green[700],
          foregroundColor: Colors.white,
          elevation: 2,
          titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[600],
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
            elevation: 2,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.green[700],
            side: BorderSide(color: Colors.green.shade300),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Colors.green[600],
          foregroundColor: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
          focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.green.shade400)),
        ),
        textTheme: TextTheme(
          titleLarge: TextStyle(color: Colors.green[900], fontWeight: FontWeight.w700),
          bodyMedium: TextStyle(color: Colors.grey[800]),
        ),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}