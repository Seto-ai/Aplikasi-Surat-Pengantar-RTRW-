import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLocalization {
  static const String ID = 'id';
  static const String EN = 'en';

  static final Map<String, Map<String, String>> _translations = {
    ID: {
      // Auth Screen
      'welcome': 'Selamat Datang',
      'login_desc': 'Masuk dengan email dan password Anda',
      'register_desc': 'Daftar untuk membuat akun baru',
      'email': 'Email',
      'password': 'Password',
      'login_button': 'Masuk',
      'register_button': 'Daftar',
      'no_account': 'Belum punya akun? ',
      'have_account': 'Sudah punya akun? ',
      'register_here': 'Daftar di sini',
      'login_here': 'Masuk di sini',
      'email_not_found': 'Email tidak terdaftar. Silakan daftar terlebih dahulu.',
      'wrong_password': 'Password salah. Silakan coba lagi.',
      'invalid_email': 'Format email tidak valid.',
      'email_already_in_use': 'Email sudah terdaftar. Gunakan email lain atau login.',
      'weak_password': 'Password terlalu lemah. Gunakan minimal 6 karakter.',
      'network_error': 'Koneksi internet gagal. Periksa koneksi Anda.',
      'error_occurred': 'Terjadi kesalahan. Silakan coba lagi.',
      'email_verification_sent': 'Verifikasi email telah dikirim. Cek inbox Anda.',
      'email_password_required': 'Email dan password tidak boleh kosong',

      // Dashboard - Warga
      'good_morning': 'Selamat Pagi',
      'good_afternoon': 'Selamat Siang',
      'good_evening': 'Selamat Sore',
      'good_night': 'Selamat Malam',
      'home': 'Beranda',
      'account': 'Akun',
      'language': 'Bahasa',
      'select_language': 'Pilih Bahasa',
      'indonesian': 'Bahasa Indonesia',
      'english': 'English',
      'logout': 'Logout',
      'confirm_logout': 'Konfirmasi Logout',
      'logout_question': 'Apakah Anda yakin ingin keluar?',
      'cancel': 'Batal',
      'exit': 'Keluar',

      // Letters/Surat
      'search_letter': 'Cari kategori atau keperluan...',
      'status': 'Status',
      'all': 'Semua',
      'draft': 'Draft',
      'processing': 'Sedang Diproses',
      'approved_rt': 'Disetujui RT',
      'approved_rw': 'Disetujui RW',
      'approved_kelurahan': 'Disetujui Kelurahan',
      'completed': 'Selesai',
      'rejected': 'Ditolak',
      'category': 'Kategori',
      'no_letters_found': 'Tidak ada surat ditemukan',
      'start_new_letter': 'Mulai dengan membuat surat baru',
      'create_new_letter': 'Buat Surat Baru',
      'error': 'Terjadi kesalahan',

      // Account
      'view_profile': 'Lihat Profil',
      'change_password': 'Ganti Kata Sandi',
      'family_list': 'Daftar Keluarga',
      'rtrw_history': 'Riwayat RT/RW',
      'help_center': 'Pusat Bantuan',
      'about_app': 'Tentang Aplikasi',
      'version': 'Versi 1.0',

      // Common
      'applicant': 'Pemohon',
      'from_rt': 'Dari RT',
    },
    EN: {
      // Auth Screen
      'welcome': 'Welcome',
      'login_desc': 'Sign in with your email and password',
      'register_desc': 'Create a new account',
      'email': 'Email',
      'password': 'Password',
      'login_button': 'Sign In',
      'register_button': 'Sign Up',
      'no_account': 'Don\'t have an account? ',
      'have_account': 'Already have an account? ',
      'register_here': 'Sign up here',
      'login_here': 'Sign in here',
      'email_not_found': 'Email not registered. Please sign up first.',
      'wrong_password': 'Wrong password. Please try again.',
      'invalid_email': 'Invalid email format.',
      'email_already_in_use': 'Email already in use. Use another email or sign in.',
      'weak_password': 'Password is too weak. Use at least 6 characters.',
      'network_error': 'Internet connection failed. Check your connection.',
      'error_occurred': 'An error occurred. Please try again.',
      'email_verification_sent': 'Verification email sent. Check your inbox.',
      'email_password_required': 'Email and password are required',

      // Dashboard - Warga
      'good_morning': 'Good Morning',
      'good_afternoon': 'Good Afternoon',
      'good_evening': 'Good Evening',
      'good_night': 'Good Night',
      'home': 'Home',
      'account': 'Account',
      'language': 'Language',
      'select_language': 'Select Language',
      'indonesian': 'Bahasa Indonesia',
      'english': 'English',
      'logout': 'Logout',
      'confirm_logout': 'Confirm Logout',
      'logout_question': 'Are you sure you want to exit?',
      'cancel': 'Cancel',
      'exit': 'Exit',

      // Letters/Surat
      'search_letter': 'Search category or purpose...',
      'status': 'Status',
      'all': 'All',
      'draft': 'Draft',
      'processing': 'Processing',
      'approved_rt': 'Approved by RT',
      'approved_rw': 'Approved by RW',
      'approved_kelurahan': 'Approved by Kelurahan',
      'completed': 'Completed',
      'rejected': 'Rejected',
      'category': 'Category',
      'no_letters_found': 'No letters found',
      'start_new_letter': 'Start by creating a new letter',
      'create_new_letter': 'Create New Letter',
      'error': 'An error occurred',

      // Account
      'view_profile': 'View Profile',
      'change_password': 'Change Password',
      'family_list': 'Family List',
      'rtrw_history': 'RT/RW History',
      'help_center': 'Help Center',
      'about_app': 'About App',
      'version': 'Version 1.0',

      // Common
      'applicant': 'Applicant',
      'from_rt': 'From RT',
    }
  };

  static String get(String key, {String locale = ID}) {
    return _translations[locale]?[key] ?? key;
  }
}

class LocalizationProvider extends ChangeNotifier {
  String _currentLocale = AppLocalization.ID;

  String get currentLocale => _currentLocale;

  LocalizationProvider() {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    _currentLocale = prefs.getString('language') ?? AppLocalization.ID;
    notifyListeners();
  }

  Future<void> setLocale(String locale) async {
    _currentLocale = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', locale);
    notifyListeners();
  }

  String t(String key) {
    return AppLocalization.get(key, locale: _currentLocale);
  }
}
