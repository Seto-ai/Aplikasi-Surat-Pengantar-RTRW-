import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../utils/ux_helper.dart';

class RekrutRTRWScreen extends StatefulWidget {
  const RekrutRTRWScreen({super.key});

  @override
  _RekrutRTRWScreenState createState() => _RekrutRTRWScreenState();
}

class _RekrutRTRWScreenState extends State<RekrutRTRWScreen> {
  bool isRt = false, isRw = false;
  String selectedUid = '';
  String? selectedRw;
  String? selectedRwName;
  String? selectedRt;
  String? selectedRtName;
  bool _showAllRw = true; // Toggle between "Semua" and "Belum Ada Ketua"

  // Helper: count RT documents for an RW with fallbacks for different data shapes
  Future<int> _countRtForRw(String nomorRw) async {
    try {
      // try server-side where first
      final q = await FirebaseFirestore.instance
          .collection('rt')
          .where('nomor_rw', isEqualTo: nomorRw)
          .get();
      if (q.size > 0) return q.size;
      // fallback: fetch all RT and count client-side by matching id or field
      final all = await FirebaseFirestore.instance.collection('rt').get();
      final filtered = all.docs.where((d) {
        final data = d.data();
        final field = data['nomor_rw'];
        if (field != null && field.toString() == nomorRw) return true;
        if (d.id == nomorRw) return true;
        // try numeric compare
        try {
          if (field != null &&
              int.parse(field.toString()) == int.parse(nomorRw)) {
            return true;
          }
        } catch (e) {}
        return false;
      }).toList();
      return filtered.length;
    } catch (e) {
      return 0;
    }
  }

  // Helper: count warga for RW with fallback
  Future<int> _countWargaForRw(String nomorRw) async {
    try {
      final q = await FirebaseFirestore.instance
          .collection('users')
          .where('rw', isEqualTo: nomorRw)
          .get();
      if (q.size > 0) return q.size;
      final all = await FirebaseFirestore.instance.collection('users').get();
      final filtered = all.docs.where((d) {
        final data = d.data();
        final field = data['rw'];
        if (field != null && field.toString() == nomorRw) return true;
        if (d.id == nomorRw) return true;
        try {
          if (field != null &&
              int.parse(field.toString()) == int.parse(nomorRw)) {
            return true;
          }
        } catch (e) {}
        return false;
      }).toList();
      return filtered.length;
    } catch (e) {
      return 0;
    }
  }

  // Helper: count warga for RW+RT
  Future<int> _countWargaForRwRt(String nomorRw, String nomorRt) async {
    try {
      final q = await FirebaseFirestore.instance
          .collection('users')
          .where('rw', isEqualTo: nomorRw)
          .where('rt', isEqualTo: nomorRt)
          .get();
      if (q.size > 0) return q.size;
      final all = await FirebaseFirestore.instance.collection('users').get();
      final filtered = all.docs.where((d) {
        final data = d.data();
        final fieldRw = data['rw'];
        final fieldRt = data['rt'];
        bool matchRw = false, matchRt = false;
        if (fieldRw != null && fieldRw.toString() == nomorRw) matchRw = true;
        if (d.id == nomorRw) matchRw = true;
        try {
          if (fieldRw != null &&
              int.parse(fieldRw.toString()) == int.parse(nomorRw)) {
            matchRw = true;
          }
        } catch (e) {}
        if (fieldRt != null && fieldRt.toString() == nomorRt) matchRt = true;
        try {
          if (fieldRt != null &&
              int.parse(fieldRt.toString()) == int.parse(nomorRt)) {
            matchRt = true;
          }
        } catch (e) {}
        return matchRw && matchRt;
      }).toList();
      return filtered.length;
    } catch (e) {
      return 0;
    }
  }

  Future<void> _rekrut() async {
    if (selectedUid.isEmpty || (!isRt && !isRw)) {
      UxHelper.showWarning(context, 'Pilih warga dan jenis rekrut (RT/RW)');
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(selectedUid)
          .get();

      if (!doc.exists) {
        print(
          '[DEBUG] ✗ ERROR: User document tidak ditemukan untuk uid=$selectedUid',
        );
        UxHelper.showError(context, 'User tidak ditemukan');
        return;
      }

      final nama = doc['nama']; // Pastikan field 'nama' ada

      // Validasi nama
      if (nama == null || nama.toString().isEmpty) {
        print('[DEBUG] ✗ VALIDATION FAILED: nama kosong');
        UxHelper.showError(context, 'Nama user tidak boleh kosong');
        return;
      }

      // Use selectedRt/selectedRw if available, otherwise use from user document
      final rtToSave = selectedRt ?? doc['rt'];
      final rwToSave = selectedRw ?? doc['rw'];

      print('[DEBUG] ========== REKRUT START ==========');
      print('[DEBUG] uid=$selectedUid, nama=$nama');
      print('[DEBUG] selectedRt=$selectedRt, selectedRw=$selectedRw');
      print('[DEBUG] rtToSave=$rtToSave, rwToSave=$rwToSave');
      print('[DEBUG] isRt=$isRt, isRw=$isRw');

      // Validasi: pastikan minimal ada satu nomor yang akan disimpan
      if ((isRt && (rtToSave == null || rtToSave.toString().isEmpty)) ||
          (isRw && (rwToSave == null || rwToSave.toString().isEmpty))) {
        print('[DEBUG] ✗ VALIDATION FAILED: nomor kosong untuk yang dipilih');
        print('[DEBUG]   isRt=$isRt, rtToSave=$rtToSave');
        print('[DEBUG]   isRw=$isRw, rwToSave=$rwToSave');
        UxHelper.showError(context, 'Nomor RT/RW tidak boleh kosong');
        return;
      }

      // Format dates as YYYY-MM-DD
      final periodeMulai = DateTime.now().toString().split(' ')[0];
      final periodeAkhir = DateTime.now()
          .add(Duration(days: 365 * 5))
          .toString()
          .split(' ')[0];

      // Format timestamp as "YYYY-MM-DD HH:mm:ss"
      final now = DateTime.now();
      final updatedAt =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

      String newRole = isRt && isRw
          ? 'rt_rw'
          : isRt
          ? 'rt'
          : 'rw';

      print('[DEBUG] newRole=$newRole');

      // Update user role and RT/RW assignment
      final userUpdateData = {'role': newRole};
      if (isRt && rtToSave != null) {
        userUpdateData['rt'] = rtToSave;
      }
      if (isRw && rwToSave != null) {
        userUpdateData['rw'] = rwToSave;
      }

      print('[DEBUG] Updating user $selectedUid with: $userUpdateData');
      await FirebaseFirestore.instance
          .collection('users')
          .doc(selectedUid)
          .update(userUpdateData);
      print('[DEBUG] User updated successfully');

      // Save to collection 'rt'
      print('[DEBUG] About to save RT: isRt=$isRt, rtToSave=$rtToSave');
      if (isRt && rtToSave != null) {
        final rtData = {
          'uid': selectedUid,
          'nama': nama,
          'nomor_rt': int.tryParse(rtToSave.toString()) ?? 0,
          'periode_mulai': periodeMulai,
          'periode_akhir': periodeAkhir,
          'updated_at': updatedAt,
        };
        print('[DEBUG] Saving to RT collection: $rtData');
        try {
          final rtDocRef = await FirebaseFirestore.instance
              .collection('rt')
              .add(rtData);
          print('[DEBUG] ✓ RT saved successfully with ID: ${rtDocRef.id}');
        } catch (rtError) {
          print('[DEBUG] ✗ RT save FAILED: $rtError');
          print('[DEBUG]   Data: $rtData');
          rethrow;
        }
      } else {
        print('[DEBUG] ⊘ RT skipped (isRt=$isRt, rtToSave=$rtToSave)');
      }

      // Save to collection 'rw'
      print('[DEBUG] About to save RW: isRw=$isRw, rwToSave=$rwToSave');
      if (isRw && rwToSave != null) {
        final rwData = {
          'uid': selectedUid,
          'nama': nama,
          'nomor_rw': int.tryParse(rwToSave.toString()) ?? 0,
          'periode_mulai': periodeMulai,
          'periode_akhir': periodeAkhir,
          'updated_at': updatedAt,
        };
        print('[DEBUG] Saving to RW collection: $rwData');
        try {
          final rwDocRef = await FirebaseFirestore.instance
              .collection('rw')
              .add(rwData);
          print('[DEBUG] ✓ RW saved successfully with ID: ${rwDocRef.id}');
        } catch (rwError) {
          print('[DEBUG] ✗ RW save FAILED: $rwError');
          print('[DEBUG]   Data: $rwData');
          rethrow;
        }
      } else {
        print('[DEBUG] ⊘ RW skipped (isRw=$isRw, rwToSave=$rwToSave)');
      }

      // Save to history
      final historyData = {
        'uid': selectedUid,
        'nama': nama,
        'nomor_rw': isRw && rwToSave != null
            ? int.tryParse(rwToSave.toString()) ?? 0
            : null,
        'nomor_rt': isRt && rtToSave != null
            ? int.tryParse(rtToSave.toString()) ?? 0
            : null,
        'periode_mulai': periodeMulai,
        'periode_akhir': periodeAkhir,
        'updated_at': updatedAt,
      };
      print('[DEBUG] Saving to riwayatRTRW: $historyData');
      try {
        final historyDocRef = await FirebaseFirestore.instance
            .collection('riwayatRTRW')
            .add(historyData);
        print(
          '[DEBUG] ✓ History saved successfully with ID: ${historyDocRef.id}',
        );
      } catch (histError) {
        print('[DEBUG] ✗ History save FAILED: $histError');
        print('[DEBUG]   Data: $historyData');
        rethrow;
      }
      print('[DEBUG] ========== REKRUT END ==========');

      UxHelper.showSuccess(context, 'Rekrut berhasil!');
      Future.delayed(Duration(milliseconds: 800), () {
        if (mounted) context.go('/dashboard/kelurahan');
      });
    } catch (e, stackTrace) {
      print('[DEBUG] ✗ ERROR in _rekrut: $e');
      print('[DEBUG] Stack trace: $stackTrace');
      print('[DEBUG] ========== REKRUT END (ERROR) ==========');
      UxHelper.showError(context, 'Gagal merekrut: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Rekrut RT/RW'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard/kelurahan'),
        ),
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // header / breadcrumbs
            Row(
              children: [
                if (selectedRw != null)
                  IconButton(
                    icon: Icon(Icons.arrow_back),
                    onPressed: () => setState(() {
                      if (selectedRt != null) {
                        // Back from warga to RT
                        selectedRt = null;
                        selectedRtName = null;
                      } else {
                        // Back from RT to RW
                        selectedRw = null;
                        selectedRwName = null;
                      }
                    }),
                  ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Rekrut RT / RW',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    // show riwayat RTRW
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('Riwayat Rekrut RT/RW'),
                        content: SizedBox(
                          width: double.maxFinite,
                          child: StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('riwayatRTRW')
                                .orderBy('created_at', descending: true)
                                .snapshots(),
                            builder: (context, snap) {
                              if (snap.hasError) {
                                return Text(
                                  'Gagal memuat riwayat: ${snap.error}',
                                );
                              }
                              if (!snap.hasData) {
                                return Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                              final docs = snap.data!.docs;
                              if (docs.isEmpty) {
                                return Text('Belum ada riwayat rekrut.');
                              }
                              return ListView.separated(
                                shrinkWrap: true,
                                itemCount: docs.length,
                                separatorBuilder: (_, __) => Divider(),
                                itemBuilder: (context, i) {
                                  final d =
                                      docs[i].data() as Map<String, dynamic>? ??
                                      {};
                                  final nama = d['nama'] ?? '-';
                                  final nomor =
                                      d['nomor_rw'] ?? d['nomor_rt'] ?? '-';
                                  final periode =
                                      '${d['periode_mulai'] ?? '-'} → ${d['periode_akhir'] ?? '-'}';
                                  return ListTile(
                                    title: Text('$nama • $nomor'),
                                    subtitle: Text(periode),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('Tutup'),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: Icon(Icons.history),
                  label: Text('Riwayat'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),

            // Toggle between "Available to Recruit" and "All RW" when on RW list
            if (selectedRt == null && selectedRw == null)
              Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip(
                        'Semua',
                        _showAllRw,
                        () => setState(() => _showAllRw = true),
                      ),
                      SizedBox(width: 8),
                      _filterChip(
                        'Belum Ada Ketua',
                        !_showAllRw,
                        () => setState(() => _showAllRw = false),
                      ),
                    ],
                  ),
                ),
              ),

            // If no RW selected -> show RW list
            if (selectedRw == null)
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  // be permissive: just listen to 'rw' collection (documents may already exist with ids like '01')
                  stream: FirebaseFirestore.instance
                      .collection('rw')
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return Center(
                        child: Text('Gagal memuat RW: ${snap.error}'),
                      );
                    }
                    if (!snap.hasData) {
                      return Center(child: CircularProgressIndicator());
                    }
                    var docs = snap.data!.docs;

                    // Filter by leadership status if "Belum Ada Ketua" is selected
                    if (!_showAllRw) {
                      docs = docs.where((d) {
                        final data = d.data() as Map<String, dynamic>?;
                        final hasLeader =
                            data != null &&
                            data.containsKey('uid') &&
                            (data['uid'] != null &&
                                data['uid'].toString().isNotEmpty);
                        return !hasLeader; // Only show RW without leaders
                      }).toList();
                    }

                    if (docs.isEmpty) {
                      final emptyMsg = _showAllRw
                          ? 'Belum ada RW terdaftar.'
                          : 'Semua RW sudah memiliki ketua.';
                      return Center(child: Text(emptyMsg));
                    }

                    return ListView.separated(
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => SizedBox(height: 8),
                      itemBuilder: (context, idx) {
                        final doc = docs[idx];
                        final data = doc.data() as Map<String, dynamic>?;
                        final nomorRwField =
                            (data != null &&
                                data.containsKey('nomor_rw') &&
                                data['nomor_rw'] != null)
                            ? data['nomor_rw'].toString()
                            : null;
                        final nomorRw = nomorRwField ?? doc.id;
                        final nama =
                            (data != null &&
                                data.containsKey('nama') &&
                                data['nama'] != null)
                            ? data['nama'].toString()
                            : 'RW $nomorRw';
                        final assignedRw =
                            data != null &&
                            data.containsKey('uid') &&
                            (data['uid'] != null &&
                                data['uid'].toString().isNotEmpty);
                        return Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: InkWell(
                            onTap: () => setState(() {
                              selectedRw = nomorRw;
                              selectedRwName = nama;
                            }),
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: assignedRw
                                        ? Colors.green[600]
                                        : Colors.orange[600],
                                    child: Text(
                                      nomorRw.toString(),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'RW $nomorRw - $nama',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                          ),
                                        ),
                                        SizedBox(height: 6),
                                        FutureBuilder<int>(
                                          future: _countRtForRw(
                                            nomorRw.toString(),
                                          ),
                                          builder: (context, s2) {
                                            final rtCount = s2.data ?? 0;
                                            return FutureBuilder<int>(
                                              future: _countWargaForRw(
                                                nomorRw.toString(),
                                              ),
                                              builder: (context, s3) {
                                                final wargaCount = s3.data ?? 0;
                                                return Row(
                                                  children: [
                                                    // indicate whether RW already has a leader (uid)
                                                    _statusBadge(
                                                      !assignedRw
                                                          ? 'Belum Ada Ketua'
                                                          : 'Sudah Ada Ketua',
                                                      !assignedRw,
                                                    ),
                                                    SizedBox(width: 8),
                                                    _statusBadge(
                                                      rtCount == 0
                                                          ? 'Kosong'
                                                          : '$rtCount RT',
                                                      rtCount == 0,
                                                    ),
                                                    SizedBox(width: 8),
                                                    _statusBadge(
                                                      wargaCount == 0
                                                          ? 'Tidak Ada Warga'
                                                          : '$wargaCount Warga',
                                                      wargaCount == 0,
                                                    ),
                                                  ],
                                                );
                                              },
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.chevron_right),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              )
            else if (selectedRw != null && selectedRt == null) ...[
              // List RTs within selected RW
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'RW $selectedRw - ${selectedRwName ?? "Daftar RT"}',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  // fetch all RTs and filter client-side to be tolerant of existing doc formats
                  stream: FirebaseFirestore.instance
                      .collection('rt')
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return Center(
                        child: Text('Gagal memuat RT: ${snap.error}'),
                      );
                    }
                    if (!snap.hasData) {
                      return Center(child: CircularProgressIndicator());
                    }
                    final allDocs = snap.data!.docs;
                    final filtered = allDocs.where((d) {
                      final data = d.data() as Map<String, dynamic>?;
                      final field = data != null && data.containsKey('nomor_rw')
                          ? data['nomor_rw'].toString()
                          : null;
                      if (field != null && field == selectedRw) return true;
                      if (d.id == selectedRw) return true;
                      try {
                        if (field != null &&
                            int.parse(field) == int.parse(selectedRw!)) {
                          return true;
                        }
                      } catch (e) {}
                      return false;
                    }).toList();
                    if (filtered.isEmpty) {
                      return Center(
                        child: Text(
                          'Belum ada RT terdaftar di RW $selectedRw. Anda bisa merekrut dari warga.',
                        ),
                      );
                    }
                    // sort by nomor_rt if present
                    filtered.sort((a, b) {
                      final da = a.data() as Map<String, dynamic>?;
                      final db = b.data() as Map<String, dynamic>?;
                      final numa = da != null && da.containsKey('nomor_rt')
                          ? int.tryParse(da['nomor_rt'].toString()) ?? 999
                          : 999;
                      final numb = db != null && db.containsKey('nomor_rt')
                          ? int.tryParse(db['nomor_rt'].toString()) ?? 999
                          : 999;
                      return numa.compareTo(numb);
                    });
                    return ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => SizedBox(height: 8),
                      itemBuilder: (context, idx) {
                        final doc = filtered[idx];
                        final data = doc.data() as Map<String, dynamic>?;
                        final nomorRt =
                            (data != null &&
                                data.containsKey('nomor_rt') &&
                                data['nomor_rt'] != null)
                            ? data['nomor_rt'].toString()
                            : doc.id;
                        final nama =
                            (data != null &&
                                data.containsKey('nama') &&
                                data['nama'] != null)
                            ? data['nama'].toString()
                            : 'RT $nomorRt';
                        final assignedRt =
                            (data != null &&
                            data.containsKey('uid') &&
                            (data['uid'] != null &&
                                data['uid'].toString().isNotEmpty));
                        return Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: assignedRt
                                      ? Colors.green[600]
                                      : Colors.orange[600],
                                  child: Text(
                                    nomorRt.toString(),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'RT $nomorRt - $nama',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
                                      SizedBox(height: 6),
                                      FutureBuilder<int>(
                                        future: _countWargaForRwRt(
                                          selectedRw!,
                                          nomorRt,
                                        ),
                                        builder: (context, s) {
                                          final count = s.data ?? 0;
                                          return Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  count == 0
                                                      ? 'RT kosong'
                                                      : '$count warga',
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              _statusBadge(
                                                !assignedRt
                                                    ? 'Belum Ada Ketua'
                                                    : 'Sudah Ada Ketua',
                                                !assignedRt,
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () => setState(() {
                                    selectedRt = nomorRt;
                                    selectedRtName = nama;
                                  }),
                                  style: ElevatedButton.styleFrom(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  child: Text(
                                    'Lihat',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ] else if (selectedRt != null) ...[
              // List warga in selected RT
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'RW $selectedRw${selectedRwName != null ? " - $selectedRwName" : ""} • RT $selectedRt${selectedRtName != null ? " - $selectedRtName" : ""} - Warga',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  // fetch users and filter client-side to be flexible with RW/RT field formats
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return Center(
                        child: Text('Gagal memuat warga: ${snap.error}'),
                      );
                    }
                    if (!snap.hasData) {
                      return Center(child: CircularProgressIndicator());
                    }
                    final all = snap.data!.docs;
                    final filtered = all.where((d) {
                      final data = d.data() as Map<String, dynamic>?;
                      if (data == null) return false;
                      final fieldRw = data.containsKey('rw')
                          ? data['rw'].toString()
                          : null;
                      final fieldRt = data.containsKey('rt')
                          ? data['rt'].toString()
                          : null;
                      bool matchRw = false, matchRt = false;
                      if (fieldRw != null && fieldRw == selectedRw) {
                        matchRw = true;
                      }
                      if (fieldRt != null && fieldRt == selectedRt) {
                        matchRt = true;
                      }
                      try {
                        if (fieldRw != null &&
                            int.parse(fieldRw) == int.parse(selectedRw!)) {
                          matchRw = true;
                        }
                      } catch (e) {}
                      try {
                        if (fieldRt != null &&
                            int.parse(fieldRt) == int.parse(selectedRt!)) {
                          matchRt = true;
                        }
                      } catch (e) {}
                      return matchRw && matchRt;
                    }).toList();
                    if (filtered.isEmpty) {
                      return Center(
                        child: Text('Tidak ada warga di RT $selectedRt.'),
                      );
                    }
                    return ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => Divider(height: 1),
                      itemBuilder: (context, idx) {
                        final d = filtered[idx];
                        final data = d.data() as Map<String, dynamic>?;
                        return ListTile(
                          title: Text(data?['nama'] ?? '-'),
                          subtitle: Text('NIK: ${data?['nik'] ?? '-'}'),
                          trailing: Text(data?['noHp'] ?? '-'),
                          onTap: () => _showWargaActions(d.id, data ?? {}),
                        );
                      },
                    );
                  },
                ),
              ),
            ],

            SizedBox(height: 12),
            // existing recruit controls (kept at bottom)
            Divider(),
            SizedBox(height: 8),
            Text(
              'Rekrut dari warga',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    title: Text('RT'),
                    value: isRt,
                    onChanged: (val) => setState(() => isRt = val!),
                  ),
                ),
                Expanded(
                  child: CheckboxListTile(
                    title: Text('RW'),
                    value: isRw,
                    onChanged: (val) => setState(() => isRw = val!),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            SizedBox(
              height: 140,
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .where('role', isEqualTo: 'warga')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }
                  return ListView(
                    scrollDirection: Axis.horizontal,
                    children: snapshot.data!.docs.map((doc) {
                      return GestureDetector(
                        onTap: () => setState(() => selectedUid = doc.id),
                        child: Container(
                          width: 220,
                          margin: EdgeInsets.only(right: 12),
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: selectedUid == doc.id
                                ? Colors.green[50]
                                : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(color: Colors.black12, blurRadius: 4),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                doc['nama'] ?? '-',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'RT ${doc['rt']} / RW ${doc['rw']}',
                                style: TextStyle(color: Colors.grey[700]),
                              ),
                              Spacer(),
                              Text(doc['noHp'] ?? '-'),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
            SizedBox(height: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _rekrut,
              child: Text('Rekrut'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String text, bool isAlert) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isAlert ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isAlert ? Colors.red.shade200 : Colors.green.shade200,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isAlert ? Colors.red.shade800 : Colors.green.shade800,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _filterChip(String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.green[600] : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? Colors.green[600]! : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : Colors.grey[800],
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  void _showWargaActions(String id, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                title: Text(data['nama'] ?? '-'),
                subtitle: Text('NIK: ${data['nik'] ?? '-'}'),
              ),
              ListTile(
                leading: Icon(Icons.person),
                title: Text('Lihat Profil'),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/detail-warga/$id');
                },
              ),
              ListTile(
                leading: Icon(Icons.check),
                title: Text('Rekrut sebagai RT'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    selectedUid = id;
                    isRt = true;
                    isRw = false;
                  });
                },
              ),
              ListTile(
                leading: Icon(Icons.check),
                title: Text('Rekrut sebagai RW'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    selectedUid = id;
                    isRw = true;
                    isRt = false;
                  });
                },
              ),
              ListTile(
                leading: Icon(Icons.close),
                title: Text('Tutup'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }
}
