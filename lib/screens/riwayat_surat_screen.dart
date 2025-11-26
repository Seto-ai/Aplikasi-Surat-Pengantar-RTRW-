import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class RiwayatSuratScreen extends StatefulWidget {
  const RiwayatSuratScreen({super.key});

  @override
  _RiwayatSuratScreenState createState() => _RiwayatSuratScreenState();
}

class _RiwayatSuratScreenState extends State<RiwayatSuratScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _searchCtrl = TextEditingController();
  
  String? _selectedStatusFilter;
  String? _selectedKategoriFilter;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'draft':
        return Colors.grey.shade200;
      case 'diajukan':
        return Colors.orange.shade200;
      case 'acc_rt':
        return Colors.blue.shade200;
      case 'acc_rw':
        return Colors.purple.shade200;
      case 'acc_kelurahan':
        return Colors.green.shade200;
      case 'selesai':
        return Colors.green.shade300;
      case 'ditolak':
        return Colors.red.shade200;
      default:
        return Colors.grey.shade100;
    }
  }

  String _getStatusLabel(String status) {
    const labels = {
      'draft': 'Draft',
      'diajukan': 'Sedang Diproses',
      'acc_rt': 'Disetujui RT',
      'acc_rw': 'Disetujui RW',
      'acc_kelurahan': 'Disetujui Kelurahan',
      'selesai': 'Selesai',
      'ditolak': 'Ditolak',
    };
    return labels[status] ?? status;
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Riwayat Surat')),
        body: Center(child: Text('User tidak ditemukan')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Riwayat Surat')),
      body: Column(
        children: [
          // === FILTERS ===
          Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              children: [
                // Search
                TextFormField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    labelText: 'Cari kategori atau keperluan...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                ),
                SizedBox(height: 8),
                // Filter dropdowns
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedStatusFilter,
                        decoration: InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          DropdownMenuItem(value: null, child: Text('Semua Status')),
                          DropdownMenuItem(value: 'draft', child: Text('Draft')),
                          DropdownMenuItem(value: 'diajukan', child: Text('Sedang Diproses')),
                          DropdownMenuItem(value: 'acc_rt', child: Text('Disetujui RT')),
                          DropdownMenuItem(value: 'acc_rw', child: Text('Disetujui RW')),
                          DropdownMenuItem(value: 'acc_kelurahan', child: Text('Disetujui Kelurahan')),
                          DropdownMenuItem(value: 'selesai', child: Text('Selesai')),
                          DropdownMenuItem(value: 'ditolak', child: Text('Ditolak')),
                        ],
                        onChanged: (val) => setState(() => _selectedStatusFilter = val),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: _firestore.collection('surat').where('pembuatId', isEqualTo: uid).snapshots(),
                        builder: (context, snapshot) {
                          final categories = <String>{};
                          if (snapshot.hasData) {
                            for (final doc in snapshot.data!.docs) {
                              final kategori = doc['kategori']?.toString();
                              if (kategori != null) categories.add(kategori);
                            }
                          }
                          
                          return DropdownButtonFormField<String>(
                            initialValue: _selectedKategoriFilter,
                            decoration: InputDecoration(
                              labelText: 'Kategori',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: [
                              DropdownMenuItem(value: null, child: Text('Semua Kategori')),
                              ...categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))),
                            ],
                            onChanged: (val) => setState(() => _selectedKategoriFilter = val),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // === LIST SURAT ===
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('surat').where('pembuatId', isEqualTo: uid).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                var docs = snapshot.data!.docs;

                // Apply filters
                if (_selectedStatusFilter != null) {
                  docs = docs.where((d) => d['status'] == _selectedStatusFilter).toList();
                }
                if (_selectedKategoriFilter != null) {
                  docs = docs.where((d) => d['kategori'] == _selectedKategoriFilter).toList();
                }
                if (_searchQuery.isNotEmpty) {
                  docs = docs.where((d) {
                    final kategori = d['kategori']?.toString().toLowerCase() ?? '';
                    final keperluan = d['keperluan']?.toString().toLowerCase() ?? '';
                    return kategori.contains(_searchQuery) || keperluan.contains(_searchQuery);
                  }).toList();
                }

                // Sort by newest first
                docs.sort((a, b) {
                  final aTime = (a['tanggalPengajuan'] as Timestamp?)?.toDate() ?? DateTime(1970);
                  final bTime = (b['tanggalPengajuan'] as Timestamp?)?.toDate() ?? DateTime(1970);
                  return bTime.compareTo(aTime);
                });

                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox, size: 64, color: Colors.grey.shade300),
                          SizedBox(height: 16),
                          Text(
                            'Tidak ada surat ditemukan',
                            style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final kategori = data['kategori'] ?? '-';
                    final keperluan = data['keperluan'] ?? '-';
                    final status = data['status'] ?? 'draft';
                    final tanggal = data['tanggalPengajuan'] as Timestamp?;
                    final tanggalStr = tanggal != null
                        ? DateFormat('dd/MM/yyyy').format(tanggal.toDate())
                        : '-';

                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        contentPadding: EdgeInsets.all(12),
                        leading: Container(
                          width: 4,
                          color: _getStatusColor(status),
                        ),
                        title: Text(kategori, style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 4),
                            Text(keperluan, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12)),
                            SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(status),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(_getStatusLabel(status), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                                ),
                                SizedBox(width: 8),
                                Text(tanggalStr, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                              ],
                            ),
                          ],
                        ),
                        trailing: Icon(Icons.chevron_right),
                        onTap: () => context.push('/detail-surat/${doc.id}'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
