import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DetailAkunScreen extends StatefulWidget {
  final bool isReadOnly;

  const DetailAkunScreen({super.key, this.isReadOnly = false});

  @override
  State<DetailAkunScreen> createState() => _DetailAkunScreenState();
}

class _DetailAkunScreenState extends State<DetailAkunScreen> {
  bool _loading = true;
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _loading = false;
      });
      return;
    }
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    setState(() {
      _user = doc.data();
      _loading = false;
    });
  }

  String _maskPhone(String? p) {
    if (p == null || p.isEmpty) return '-';
    if (p.length <= 4) return p;
    final visible = p.substring(p.length - 3);
    return '${'*' * (p.length - 3)}$visible';
  }

  Future<void> _updateField(
    String fieldKey,
    String label,
    String? initial,
  ) async {
    final controller = TextEditingController(text: initial ?? '');
    final formKey = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ubah $label'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(labelText: label),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Tidak boleh kosong' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false)
                Navigator.pop(context, true);
            },
            child: Text('Simpan'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        fieldKey: controller.text.trim(),
      });
      await _loadUser();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$label berhasil diubah')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal mengubah $label: $e')));
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus Akun'),
        content: Text(
          'Menghapus akun akan menghilangkan semua data Anda secara permanen. Lanjutkan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    // Show password dialog for re-authentication
    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PasswordDialog(),
    );
    if (password == null || password.isEmpty) return;

    // Perform deletion
    _performAccountDeletion(password);
  }

  Future<void> _performAccountDeletion(String password) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator()),
    );

    try {
      final user = FirebaseAuth.instance.currentUser;
      final email = user?.email;

      if (email == null) throw Exception('Email tidak ditemukan');

      // Re-authenticate
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await user!.reauthenticateWithCredential(credential);

      // Delete Firestore doc
      await FirebaseFirestore.instance.collection('users').doc(uid).delete();

      // Delete Supabase files (KK, KTP, TTD if exist)
      try {
        final supabase = Supabase.instance.client;
        final storage = supabase.storage.from('dokumen-warga');

        // List all files for this user
        final files = await storage.list(path: '');
        for (final file in files) {
          if (file.name.startsWith(uid)) {
            await storage.remove([file.name]);
          }
        }
      } catch (e) {
        // Ignore storage cleanup errors, proceed with auth deletion
        print('Supabase cleanup error: $e');
      }

      // Delete Auth user
      await user.delete();

      // Clear prefs and sign out
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('role');
      await FirebaseAuth.instance.signOut();

      Navigator.pop(context); // close progress dialog

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Akun berhasil dihapus'),
            backgroundColor: Colors.green,
          ),
        );
        await Future.delayed(Duration(seconds: 1));
        context.go('/');
      }
    } on FirebaseAuthException catch (e) {
      Navigator.pop(context);

      if (mounted) {
        String message = 'Gagal menghapus akun';
        if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
          message = 'Password tidak benar';
        } else if (e.code == 'requires-recent-login') {
          message = 'Silakan logout dan login kembali, lalu coba lagi';
        } else if (e.code == 'user-not-found') {
          message = 'Pengguna tidak ditemukan';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ $message'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Gagal menghapus akun: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildTopBoxes() {
    return Row(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Telepon',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Text(_maskPhone(_user?['noHp'])),
                  if (!widget.isReadOnly)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () =>
                            _updateField('noHp', 'Telepon', _user?['noHp']),
                        child: Text('Ubah'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Email', style: TextStyle(fontWeight: FontWeight.w600)),
                  SizedBox(height: 8),
                  Text(_user?['email'] ?? '-'),
                  if (!widget.isReadOnly)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () =>
                            _updateField('email', 'Email', _user?['email']),
                        child: Text('Ubah'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('NIK', style: TextStyle(fontWeight: FontWeight.w600)),
                  SizedBox(height: 8),
                  Text(_user?['nik'] ?? '-'),
                  if (!widget.isReadOnly)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () =>
                            _updateField('nik', 'NIK', _user?['nik']),
                        child: Text('Ubah'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailCard() {
    if (_user == null) return SizedBox.shrink();

    final fields = <String, String>{
      'Nama': (_user?['nama'] ?? '-').toString(),
      'Jenis Kelamin': (_user?['jenisKelamin'] ?? '-').toString(),
      'Tempat Lahir': (_user?['tempatLahir'] ?? '-').toString(),
      'Tanggal Lahir': (_user?['tanggalLahir'] ?? '-').toString(),
      'Pekerjaan': (_user?['pekerjaan'] ?? '-').toString(),
      'Status dalam Keluarga': (_user?['statusDiKeluarga'] ?? '-').toString(),
      'Status Perkawinan': (_user?['statusPerkawinan'] ?? '-').toString(),
      'Alamat': (_user?['alamat'] ?? '-').toString(),
      'RT/RW': 'RT ${_user?['rt'] ?? '-'} / RW ${_user?['rw'] ?? '-'}',
      'Kelurahan': (_user?['kelurahan'] ?? '-').toString(),
      'Kecamatan': (_user?['kecamatan'] ?? '-').toString(),
      'Kota': (_user?['kota'] ?? '-').toString(),
      'Provinsi': (_user?['provinsi'] ?? '-').toString(),
    };

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...fields.entries.map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        e.key,
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        e.value,
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 12),
            if (!widget.isReadOnly)
              ElevatedButton(
                onPressed: () => context.push('/biodata?mode=edit'),
                child: Text('Ubah'),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Detail Akun')),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : _user == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.shade300,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Gagal memuat data akun',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Silakan coba lagi',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      setState(() => _loading = true);
                      _loadUser();
                    },
                    child: Text('Muat Ulang'),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTopBoxes(),
                  SizedBox(height: 12),
                  _buildDetailCard(),
                  SizedBox(height: 20),
                  if (!widget.isReadOnly)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      onPressed: _deleteAccount,
                      child: Text('Hapus Akun'),
                    ),
                ],
              ),
            ),
    );
  }
}

class _PasswordDialog extends StatefulWidget {
  @override
  __PasswordDialogState createState() => __PasswordDialogState();
}

class __PasswordDialogState extends State<_PasswordDialog> {
  final _controller = TextEditingController();
  bool _showPassword = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Konfirmasi Penghapusan Akun'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Masukkan password Anda untuk mengkonfirmasi penghapusan akun.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          SizedBox(height: 16),
          TextField(
            controller: _controller,
            obscureText: !_showPassword,
            decoration: InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                  _showPassword ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () => setState(() => _showPassword = !_showPassword),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Batal'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: Text('Hapus Akun'),
        ),
      ],
    );
  }
}
