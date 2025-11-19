import 'package:firebase_auth/firebase_auth.dart';

class AuthErrorHelper {
  // Map Firebase error codes to user-friendly Indonesian messages
  static String getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Email tidak terdaftar. Silakan daftar terlebih dahulu.';
      case 'wrong-password':
        return 'Password salah. Silakan coba lagi.';
      case 'invalid-email':
        return 'Format email tidak valid.';
      case 'user-disabled':
        return 'Akun ini telah dinonaktifkan.';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan login gagal. Coba lagi nanti.';
      case 'operation-not-allowed':
        return 'Operasi login tidak diizinkan.';
      case 'email-already-in-use':
        return 'Email sudah terdaftar. Gunakan email lain atau login.';
      case 'weak-password':
        return 'Password terlalu lemah. Gunakan minimal 6 karakter.';
      case 'invalid-credential':
        return 'Email atau password salah.';
      case 'network-request-failed':
        return 'Koneksi internet gagal. Periksa koneksi Anda.';
      default:
        return 'Terjadi kesalahan. Silakan coba lagi.';
    }
  }

  static bool isAuthError(FirebaseAuthException e) {
    return !e.code.contains('network') && !e.code.contains('timeout');
  }
}
