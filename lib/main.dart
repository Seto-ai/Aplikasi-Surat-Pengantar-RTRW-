import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'theme.dart';
import 'utils/localization.dart';
import 'screens/auth_screen.dart';
import 'screens/biodata_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/warga_dashboard_screen.dart';
import 'screens/rt_rw_dashboard_screen.dart';
import 'screens/kelurahan_dashboard_screen.dart';
import 'screens/buat_surat_screen.dart';
import 'screens/rekrut_rtrw_screen.dart';
import 'screens/rekrut_kelurahan_screen.dart';
import 'screens/tambah_anggota_screen.dart';
import 'screens/detail_surat_screen.dart';
import 'screens/detail_akun_screen.dart';
import 'screens/ganti_password_screen.dart';
import 'screens/riwayat_surat_screen.dart';
import 'screens/lihat_data_warga_screen.dart';
import 'screens/daftar_keluarga_screen.dart';
import 'screens/riwayat_rtrw_screen.dart';
import 'screens/landing_page_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Supabase.initialize(
    url: 'https://kbkaqntbkulplmmwwmhw.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imtia2FxbnRia3VscGxtbXd3bWh3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk4MTk0MTYsImV4cCI6MjA3NTM5NTQxNn0.UL3MlABGTLyT4Nvaz8Zzh7Oh9gyI1RM13VEGZX-rAnQ',
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  static Future<String?> _getRoleFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('role');
  }

  static final GoRouter _router = GoRouter(
    redirect: (context, state) async {
      // Check if user is authenticated
      final isLoggedIn = FirebaseAuth.instance.currentUser != null;

      // Allow login and register pages even if authenticated (for logout flow)
      if (state.matchedLocation == '/login' ||
          state.matchedLocation == '/register') {
        return null;
      }

      if (isLoggedIn) {
        // User sudah login
        final role = await _getRoleFromPrefs();

        // Jika user akses landing page → redirect ke dashboard
        if (state.matchedLocation == '/') {
          if (role != null) {
            return '/dashboard/$role';
          }
          // Jika role tidak ada di prefs tapi user login, go to biodata
          return '/biodata';
        }
      } else {
        // User belum login
        // Jika akses protected routes (dashboard, dll) → redirect ke landing page
        if (state.matchedLocation.startsWith('/dashboard') ||
            state.matchedLocation.startsWith('/biodata') ||
            state.matchedLocation.startsWith('/buat-surat') ||
            state.matchedLocation.startsWith('/rekrut') ||
            state.matchedLocation.startsWith('/tambah-anggota') ||
            state.matchedLocation.startsWith('/detail-akun') ||
            state.matchedLocation.startsWith('/ganti-kata-sandi') ||
            state.matchedLocation.startsWith('/riwayat-surat') ||
            state.matchedLocation.startsWith('/daftar-keluarga') ||
            state.matchedLocation.startsWith('/riwayat-rtrw') ||
            state.matchedLocation.startsWith('/lihat-data-warga') ||
            state.matchedLocation.startsWith('/detail-surat')) {
          return '/';
        }
      }

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => LandingPageScreen()),
      GoRoute(
        path: '/login',
        builder: (context, state) => AuthScreen(isLoginMode: true),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => AuthScreen(isLoginMode: false),
      ),
      GoRoute(
        path: '/biodata',
        builder: (context, state) => BiodataScreen(
          isEditMode: state.uri.queryParameters['mode'] == 'edit',
        ),
      ),
      // Warga dashboard
      GoRoute(
        path: '/dashboard/warga',
        builder: (context, state) => WargaDashboardScreen(),
      ),
      // RT/RW dashboards (new version)
      GoRoute(
        path: '/dashboard/:role',
        builder: (context, state) {
          var role = state.pathParameters['role']!.toLowerCase().trim();
          print(
            'DEBUG: Dashboard route matched. Role value: "$role" (length: ${role.length})',
          );

          // Use new RTRWDashboardScreen for RT, RW, and RT_RW roles
          final isRTRW = role == 'rt' || role == 'rw' || role == 'rt_rw';
          print(
            'DEBUG: isRTRW=$isRTRW, showing: ${isRTRW
                ? "RTRWDashboardScreen"
                : role == "kelurahan"
                ? "KelurahanDashboardScreen"
                : "DashboardScreen"}',
          );

          if (isRTRW) {
            return RTRWDashboardScreen(role: role);
          } else if (role == 'kelurahan') {
            return KelurahanDashboardScreen();
          }
          return DashboardScreen(role: role); // fallback
        },
      ),
      GoRoute(
        path: '/buat-surat',
        builder: (context, state) => BuatSuratScreen(
          suratId: state.uri.queryParameters['id'],
          mode: state.uri.queryParameters['mode'] ?? 'create',
        ),
      ),
      GoRoute(
        path: '/rekrut-rtrw',
        builder: (context, state) => RekrutRTRWScreen(),
      ),
      GoRoute(
        path: '/rekrut-kelurahan',
        builder: (context, state) => RekrutKelurahanScreen(
          type: state.uri.queryParameters['type'],
          nomor: state.uri.queryParameters['nomor'],
        ),
      ),
      GoRoute(
        path: '/tambah-anggota',
        builder: (context, state) => TambahAnggotaScreen(),
      ),
      GoRoute(
        path: '/detail-akun',
        builder: (context, state) => DetailAkunScreen(
          isReadOnly: state.uri.queryParameters['readOnly'] == 'true',
          userId: state.uri.queryParameters['userId'],
        ),
      ),
      GoRoute(
        path: '/ganti-kata-sandi',
        builder: (context, state) => GantiPasswordScreen(),
      ),
      GoRoute(
        path: '/riwayat-surat',
        builder: (context, state) => RiwayatSuratScreen(),
      ),
      GoRoute(
        path: '/daftar-keluarga',
        builder: (context, state) => DaftarKeluargaScreen(),
      ),
      GoRoute(
        path: '/riwayat-rtrw',
        builder: (context, state) => RiwayatRTRWScreen(),
      ),
      GoRoute(
        path: '/lihat-data-warga',
        builder: (context, state) => LihatDataWargaScreen(),
      ),
      GoRoute(
        path: '/detail-surat/:id',
        builder: (context, state) =>
            DetailSuratScreen(id: state.pathParameters['id']!),
      ),
    ],
  );

  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocalizationProvider()),
      ],
      child: MaterialApp.router(
        routerConfig: _router,
        title: 'Surat Pengantar Sukorame',
        theme: getAppTheme(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
