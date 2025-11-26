import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../utils/ux_helper.dart';

class RekrutKelurahanScreen extends StatefulWidget {
  final String? type; // 'rt' atau 'rw'
  final String? nomor; // nomor RT/RW

  const RekrutKelurahanScreen({this.type, this.nomor});

  @override
  State<RekrutKelurahanScreen> createState() => _RekrutKelurahanScreenState();
}

class _RekrutKelurahanScreenState extends State<RekrutKelurahanScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = true;
  List<Map<String, dynamic>> _wargaCandidates = [];
  Map<String, dynamic>? _currentHolder;
  String _mode = 'recruit'; // 'recruit' atau 'replace'

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);

      if (widget.type == null || widget.nomor == null) {
        // Show search/select mode
        setState(() => _mode = 'select');
      } else {
        // Check if already filled
        final existing = await _firestore
            .collection('users')
            .where(widget.type == 'rt' ? 'rt' : 'rw', isEqualTo: widget.nomor)
            .where('role', isEqualTo: widget.type)
            .limit(1)
            .get();

        if (existing.docs.isNotEmpty) {
          setState(() {
            _currentHolder = {'id': existing.docs[0].id, ...existing.docs[0].data()};
            _mode = 'replace';
          });
        } else {
          // Load candidates from this RT/RW
          await _loadCandidates();
          setState(() => _mode = 'recruit');
        }
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        UxHelper.showError(context, 'Error: $e');
      }
    }
  }

  Future<void> _loadCandidates() async {
    try {
      _wargaCandidates = [];

      // Get warga from this RT/RW who don't have role 'rt' or 'rw'
      final snapshot = await _firestore
          .collection('users')
          .where(widget.type == 'rt' ? 'rt' : 'rw', isEqualTo: widget.nomor)
          .where('role', isEqualTo: 'warga')
          .get();

      _wargaCandidates = snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      print('Error loading candidates: $e');
    }
  }

  Future<void> _recruitWarga(String uid, Map<String, dynamic> warga) async {
    try {
      // Show confirmation
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Konfirmasi Rekrut'),
          content: Text(
            'Rekrut ${warga['nama']} sebagai ${widget.type == 'rt' ? 'Ketua RT' : 'Ketua RW'} ${widget.nomor}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Rekrut'),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      final now = DateTime.now();
      final periodeAkhir = now.add(Duration(days: 365 * 5));

      // Update user: set role to rt/rw
      await _firestore.collection('users').doc(uid).update({
        'role': widget.type,
      });

      // Add to riwayatRTRW
      await _firestore.collection('riwayatRTRW').add({
        'uid': uid,
        'nama': warga['nama'],
        'nomor_rt': widget.type == 'rt' ? widget.nomor : null,
        'nomor_rw': widget.type == 'rw' ? widget.nomor : null,
        'periode_mulai': now.toString().split(' ')[0],
        'periode_akhir': periodeAkhir.toString().split(' ')[0],
        'created_at': now.toString(),
      });

      if (mounted) {
        UxHelper.showSuccess(context, 'Berhasil direkrut!');
        Future.delayed(Duration(milliseconds: 800), () {
          if (mounted) context.pop(true); // Return true to refresh parent
        });
      }
    } catch (e) {
      if (mounted) UxHelper.showError(context, 'Gagal merekrut: $e');
    }
  }

  Future<void> _copotJabatan(String uid, String nama) async {
    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Konfirmasi Copot Jabatan'),
          content: Text('Copot jabatan ${widget.type == 'rt' ? 'Ketua RT' : 'Ketua RW'} dari $nama?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: Text('Copot', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      // Revert role to 'warga'
      await _firestore.collection('users').doc(uid).update({
        'role': 'warga',
      });

      if (mounted) {
        UxHelper.showSuccess(context, 'Jabatan berhasil dicopotkan!');
        Future.delayed(Duration(milliseconds: 800), () {
          if (mounted) context.pop(true); // Return true to refresh parent
        });
      }
    } catch (e) {
      if (mounted) UxHelper.showError(context, 'Gagal copot jabatan: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_mode == 'select'
            ? 'Cari Posisi'
            : _mode == 'recruit'
                ? 'Rekrut ${widget.type == 'rt' ? 'Ketua RT' : 'Ketua RW'} ${widget.nomor}'
                : 'Ganti Jabatan'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _mode == 'select'
              ? _buildSelectMode()
              : _mode == 'recruit'
                  ? _buildRecruitMode()
                  : _buildReplaceMode(),
    );
  }

  // Mode 1: Select RT/RW
  Widget _buildSelectMode() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Pilih Posisi yang Ingin Diatur:',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          _buildRTRWSelector(),
        ],
      ),
    );
  }

  Widget _buildRTRWSelector() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('users').where('role', whereIn: ['rt', 'rw']).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allRTRW = snapshot.data!.docs.map((doc) => {...(doc.data() as Map<String, dynamic>)}).toList();

        // Group by RW first, then by RT
        final rwMap = <String, List<Map<String, dynamic>>>{};
        final rtOnly = <Map<String, dynamic>>[];

        for (var person in allRTRW) {
          if (person['role'] == 'rw') {
            final rw = person['rw'];
            rwMap.putIfAbsent(rw, () => []);
            rwMap[rw]!.add(person);
          } else if (person['role'] == 'rt') {
            rtOnly.add(person);
          }
        }

        return Column(
          children: [
            // RW section
            ...rwMap.entries.map((entry) {
              return _buildPositionCard(
                title: 'RW ${entry.key}',
                subtitle: entry.value.isNotEmpty ? 'Dipimpin: ${entry.value[0]['nama']}' : 'Kosong',
                onTap: () async {
                  final result = await context.push(
                    '/rekrut-kelurahan?type=rw&nomor=${entry.key}',
                  );
                  if (result == true) _loadData();
                },
              );
            }),
            // RT section
            ...rtOnly.map((rt) {
              return _buildPositionCard(
                title: 'RT ${rt['rt']}',
                subtitle: 'Dipimpin: ${rt['nama']}',
                onTap: () async {
                  final result = await context.push(
                    '/rekrut-kelurahan?type=rt&nomor=${rt['rt']}',
                  );
                  if (result == true) _loadData();
                },
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildPositionCard({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward),
        onTap: onTap,
      ),
    );
  }

  // Mode 2: Recruit new
  Widget _buildRecruitMode() {
    if (_wargaCandidates.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.people_outline, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                'Tidak ada warga yang tersedia',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _wargaCandidates.length,
      itemBuilder: (context, index) {
        final warga = _wargaCandidates[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.shade700,
              child: const Icon(Icons.person, color: Colors.white),
            ),
            title: Text(warga['nama'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(warga['email'] ?? 'N/A', style: const TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.arrow_forward),
            onTap: () => _showWargaDetail(warga),
          ),
        );
      },
    );
  }

  void _showWargaDetail(Map<String, dynamic> warga) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Text(
                warga['nama'] ?? 'N/A',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Email', warga['email'] ?? '-'),
            _buildDetailRow('No. HP', warga['noHp'] ?? '-'),
            _buildDetailRow('NIK', warga['nik'] ?? '-'),
            _buildDetailRow('RT/RW', 'RT ${warga['rt']} / RW ${warga['rw']}'),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  context.pop();
                  _recruitWarga(warga['id'], warga);
                },
                child: Text(
                  'Rekrut sebagai ${widget.type == 'rt' ? 'Ketua RT' : 'Ketua RW'} ${widget.nomor}',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // Mode 3: Replace existing
  Widget _buildReplaceMode() {
    if (_currentHolder == null) {
      return const Center(child: Text('Data tidak ditemukan'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.green.shade700,
                    child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 32),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${widget.type == 'rt' ? 'Ketua RT' : 'Ketua RW'} ${widget.nomor}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentHolder!['nama'] ?? 'N/A',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.info),
                      label: const Text('Lihat Detail'),
                      onPressed: () => _showDetailModal(_currentHolder!),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Ganti Jabatan:',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          _buildReplacementOptions(),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () => _copotJabatan(_currentHolder!['id'], _currentHolder!['nama']),
              child: const Text(
                'Copot Jabatan',
                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplacementOptions() {
    return FutureBuilder<QuerySnapshot>(
      future: _firestore
          .collection('users')
          .where(widget.type == 'rt' ? 'rt' : 'rw', isEqualTo: widget.nomor)
          .where('role', isEqualTo: 'warga')
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('Tidak ada warga tersedia untuk mengganti'),
          );
        }

        final candidates = snapshot.data!.docs
            .map((doc) => {'id': doc.id, ...(doc.data() as Map<String, dynamic>)})
            .toList();

        return Column(
          children: candidates
              .map((warga) => Card(
                    child: ListTile(
                      title: Text(warga['nama'] ?? 'N/A'),
                      subtitle: Text(warga['email'] ?? 'N/A', style: const TextStyle(fontSize: 11)),
                      trailing: const Icon(Icons.arrow_forward),
                      onTap: () {
                        context.pop();
                        _showWargaDetail(warga);
                      },
                    ),
                  ))
              .toList(),
        );
      },
    );
  }

  void _showDetailModal(Map<String, dynamic> person) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Text(
                  person['nama'] ?? 'N/A',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: 16),
              _buildDetailRow('Email', person['email'] ?? '-'),
              _buildDetailRow('No. HP', person['noHp'] ?? '-'),
              _buildDetailRow('NIK', person['nik'] ?? '-'),
              _buildDetailRow('RT/RW', 'RT ${person['rt']} / RW ${person['rw']}'),
              _buildDetailRow('Jenis Kelamin', person['jenisKelamin'] ?? '-'),
              _buildDetailRow('Pekerjaan', person['pekerjaan'] ?? '-'),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
