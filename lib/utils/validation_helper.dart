
class ValidationHelper {
  // Validasi nama (minimal 3 karakter, hanya huruf dan spasi)
  static String? validateNama(String? value) {
    if (value == null || value.isEmpty) {
      return 'Nama tidak boleh kosong';
    }
    if (value.length < 3) {
      return 'Nama minimal 3 karakter';
    }
    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value)) {
      return 'Nama hanya boleh berisi huruf dan spasi';
    }
    return null;
  }

  // Validasi NIK (16 digit)
  static String? validateNIK(String? value) {
    if (value == null || value.isEmpty) {
      return 'NIK tidak boleh kosong';
    }
    if (value.length != 16) {
      return 'NIK harus 16 digit';
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
      return 'NIK hanya boleh berisi angka';
    }
    return null;
  }

  // Validasi nomor HP (minimal 10 digit, dimulai dengan 0)
  static String? validateNoHp(String? value) {
    if (value == null || value.isEmpty) {
      return 'Nomor HP tidak boleh kosong';
    }
    if (!value.startsWith('0')) {
      return 'Nomor HP harus dimulai dengan 0';
    }
    if (value.length < 10 || value.length > 13) {
      return 'Nomor HP harus 10-13 digit';
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
      return 'Nomor HP hanya boleh berisi angka';
    }
    return null;
  }

  // Validasi email
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email tidak boleh kosong';
    }
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Format email tidak valid';
    }
    return null;
  }

  // Validasi password (minimal 6 karakter)
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password tidak boleh kosong';
    }
    if (value.length < 6) {
      return 'Password minimal 6 karakter';
    }
    return null;
  }

  // Validasi alamat
  static String? validateAlamat(String? value) {
    if (value == null || value.isEmpty) {
      return 'Alamat tidak boleh kosong';
    }
    if (value.length < 5) {
      return 'Alamat minimal 5 karakter';
    }
    return null;
  }

  // Validasi kota/provinsi
  static String? validateKota(String? value) {
    if (value == null || value.isEmpty) {
      return 'Tidak boleh kosong';
    }
    if (value.length < 3) {
      return 'Minimal 3 karakter';
    }
    return null;
  }

  // Validasi dropdown (tidak boleh null)
  static String? validateDropdown(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName harus dipilih';
    }
    return null;
  }

  // Check if string is network error
  static bool isNetworkError(Exception error) {
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('network') ||
        errorStr.contains('socket') ||
        errorStr.contains('timeout') ||
        errorStr.contains('connection refused');
  }

  // Check if string is permission error
  static bool isPermissionError(Exception error) {
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('permission') || errorStr.contains('unauthorized');
  }

  // Get user-friendly error message
  static String getErrorMessage(Exception error) {
    final errorStr = error.toString();

    if (isNetworkError(error)) {
      return 'Periksa koneksi internet Anda dan coba lagi';
    }
    if (isPermissionError(error)) {
      return 'Anda tidak memiliki izin untuk melakukan aksi ini';
    }
    if (errorStr.contains('FirebaseException')) {
      if (errorStr.contains('email-already-in-use')) {
        return 'Email sudah terdaftar';
      }
      if (errorStr.contains('weak-password')) {
        return 'Password terlalu lemah';
      }
      if (errorStr.contains('user-not-found')) {
        return 'Email tidak ditemukan';
      }
      if (errorStr.contains('wrong-password')) {
        return 'Password salah';
      }
      if (errorStr.contains('too-many-requests')) {
        return 'Terlalu banyak percobaan. Coba lagi nanti';
      }
    }
    if (errorStr.contains('PlatformException')) {
      return 'Terjadi kesalahan sistem. Coba lagi nanti';
    }

    return 'Terjadi kesalahan. Silakan coba lagi';
  }
}
