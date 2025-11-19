import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class GantiPasswordScreen extends StatefulWidget {
  @override
  _GantiPasswordScreenState createState() => _GantiPasswordScreenState();
}

class _GantiPasswordScreenState extends State<GantiPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  
  bool _showOldPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _oldPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;
    
    final oldPassword = _oldPasswordCtrl.text;
    final newPassword = _newPasswordCtrl.text;
    final confirmPassword = _confirmPasswordCtrl.text;
    
    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password baru dan konfirmasi tidak cocok'), backgroundColor: Colors.red),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User tidak ditemukan');
      
      final email = user.email!;
      
      // Re-authenticate with old password
      final credential = EmailAuthProvider.credential(email: email, password: oldPassword);
      await user.reauthenticateWithCredential(credential);
      
      // Update password
      await user.updatePassword(newPassword);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✓ Password berhasil diubah'), backgroundColor: Colors.green),
        );
        await Future.delayed(Duration(seconds: 1));
        context.pop();
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String message = 'Gagal mengubah password';
        if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
          message = 'Password lama tidak benar';
        } else if (e.code == 'weak-password') {
          message = 'Password baru terlalu lemah (minimal 6 karakter)';
        } else if (e.code == 'requires-recent-login') {
          message = 'Anda perlu masuk ulang untuk mengubah password';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ $message'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Gagal: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Ganti Kata Sandi')),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Keamanan Akun',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.green.shade700),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Untuk keamanan akun Anda, gunakan password yang kuat dan jangan bagikan dengan siapapun.',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24),

                    // Old Password Field
                    Text('Kata Sandi Lama', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.green.shade700)),
                    SizedBox(height: 8),
                    TextFormField(
                      controller: _oldPasswordCtrl,
                      obscureText: !_showOldPassword,
                      decoration: InputDecoration(
                        labelText: 'Masukkan kata sandi lama',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(_showOldPassword ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _showOldPassword = !_showOldPassword),
                        ),
                      ),
                      validator: (val) => (val == null || val.isEmpty) ? 'Kata sandi lama wajib diisi' : null,
                    ),
                    SizedBox(height: 20),

                    // New Password Field
                    Text('Kata Sandi Baru', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.green.shade700)),
                    SizedBox(height: 8),
                    TextFormField(
                      controller: _newPasswordCtrl,
                      obscureText: !_showNewPassword,
                      decoration: InputDecoration(
                        labelText: 'Masukkan kata sandi baru (minimal 6 karakter)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(_showNewPassword ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _showNewPassword = !_showNewPassword),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Kata sandi baru wajib diisi';
                        if (val.length < 6) return 'Kata sandi minimal 6 karakter';
                        return null;
                      },
                    ),
                    SizedBox(height: 20),

                    // Confirm Password Field
                    Text('Konfirmasi Kata Sandi Baru', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.green.shade700)),
                    SizedBox(height: 8),
                    TextFormField(
                      controller: _confirmPasswordCtrl,
                      obscureText: !_showConfirmPassword,
                      decoration: InputDecoration(
                        labelText: 'Ulangi kata sandi baru',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(_showConfirmPassword ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _showConfirmPassword = !_showConfirmPassword),
                        ),
                      ),
                      validator: (val) => (val == null || val.isEmpty) ? 'Konfirmasi kata sandi wajib diisi' : null,
                    ),
                    SizedBox(height: 32),

                    // Submit Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 16)),
                      onPressed: _changePassword,
                      child: Text('Ubah Kata Sandi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                    SizedBox(height: 16),

                    // Cancel Button
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 14)),
                      onPressed: () => context.pop(),
                      child: Text('Batal'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
