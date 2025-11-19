import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../utils/shimmer_loader.dart';

class DashboardScreen extends StatefulWidget {
  final String role;
  DashboardScreen({required this.role});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  Map<String, dynamic>? dataPemohon;
  List<Map<String, dynamic>> anggotaKeluarga = [];

  Future<void> _loadData() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    setState(() {
      dataPemohon = doc.data();
      anggotaKeluarga = List<Map<String, dynamic>>.from(doc['anggotaKeluarga'] ?? []);
    });
  }

  Widget _buildBeranda() {
    if (widget.role == 'kelurahan') {
      return Column(
        children: [
          ElevatedButton(onPressed: () => context.go('/rekrut-rtrw'), child: Text('Rekrut RT/RW')),
          ElevatedButton(onPressed: () => context.go('/lihat-data-warga'), child: Text('Lihat Data Warga')),
          Expanded(child: _buildSuratMasukKelurahan()),
        ],
      );
    } else if (widget.role == 'rt' || widget.role == 'rw' || widget.role == 'rt_rw') {
      return Expanded(child: _buildSuratMasukRT());
    } else {
      // Warga beranda - integrated riwayat surat with search/filter
      return _buildWargaBeranda();
    }
  }

  Widget _buildWargaBeranda() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    String? _selectedStatus;
    String? _selectedKategori;
    String _searchQuery = '';
    
    return StatefulBuilder(
      builder: (context, setState) => Column(
        children: [
          // Search & Filter Section
          Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              children: [
                // Search
                TextFormField(
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
                      child: DropdownButtonFormField<String?>(
                        decoration: InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        ),
                        value: _selectedStatus,
                        items: [
                          DropdownMenuItem(value: null, child: Text('Semua')),
                          DropdownMenuItem(value: 'draft', child: Text('Draft')),
                          DropdownMenuItem(value: 'diajukan', child: Text('Sedang Diproses')),
                          DropdownMenuItem(value: 'acc_rt', child: Text('Disetujui RT')),
                          DropdownMenuItem(value: 'acc_rw', child: Text('Disetujui RW')),
                          DropdownMenuItem(value: 'acc_kelurahan', child: Text('Disetujui Kelurahan')),
                          DropdownMenuItem(value: 'selesai', child: Text('Selesai')),
                          DropdownMenuItem(value: 'ditolak', child: Text('Ditolak')),
                        ],
                        onChanged: (val) => setState(() => _selectedStatus = val),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('surat').where('pembuatId', isEqualTo: uid).snapshots(),
                        builder: (context, snapshot) {
                          final categories = <String>{};
                          if (snapshot.hasData) {
                            for (final doc in snapshot.data!.docs) {
                              final kategori = doc['kategori']?.toString();
                              if (kategori != null) categories.add(kategori);
                            }
                          }
                          
                          return DropdownButtonFormField<String?>(
                            decoration: InputDecoration(
                              labelText: 'Kategori',
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                            ),
                            value: _selectedKategori,
                            items: [
                              DropdownMenuItem(value: null, child: Text('Semua')),
                              ...categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))),
                            ],
                            onChanged: (val) => setState(() => _selectedKategori = val),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Surat List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('surat').where('pembuatId', isEqualTo: uid).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
                          SizedBox(height: 12),
                          Text('Terjadi kesalahan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          SizedBox(height: 8),
                          Text(snapshot.error.toString(), style: TextStyle(color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return SingleChildScrollView(
                    child: Column(
                      children: [
                        ShimmerLoader.listSkeleton(itemCount: 5),
                      ],
                    ),
                  );
                }

                var docs = snapshot.data!.docs;
                
                // Sort by tanggalPengajuan (newest first)
                docs.sort((a, b) {
                  final aTime = (a['tanggalPengajuan'] as Timestamp?)?.toDate() ?? DateTime(1970);
                  final bTime = (b['tanggalPengajuan'] as Timestamp?)?.toDate() ?? DateTime(1970);
                  return bTime.compareTo(aTime);
                });

                // Apply filters
                final filtered = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final kategori = data['kategori']?.toString().toLowerCase() ?? '';
                  final keperluan = data['keperluan']?.toString().toLowerCase() ?? '';
                  final status = data['status']?.toString() ?? '';
                  
                  // Search filter
                  if (_searchQuery.isNotEmpty && !kategori.contains(_searchQuery) && !keperluan.contains(_searchQuery)) {
                    return false;
                  }
                  
                  // Status filter
                  if (_selectedStatus != null && status != _selectedStatus) {
                    return false;
                  }
                  
                  // Kategori filter
                  if (_selectedKategori != null && kategori != _selectedKategori!.toLowerCase()) {
                    return false;
                  }
                  
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox, size: 64, color: Colors.grey.shade300),
                          SizedBox(height: 16),
                          Text('Tidak ada surat ditemukan', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 16, fontWeight: FontWeight.w500)),
                          SizedBox(height: 8),
                          Text('Mulai dengan membuat surat baru', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: filtered.length + 1,
                  itemBuilder: (context, index) {
                    // Tombol Buat Surat di bawah list
                    if (index == filtered.length) {
                      return Padding(
                        padding: EdgeInsets.all(12),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            padding: EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: Icon(Icons.add, color: Colors.white),
                          label: Text('Buat Surat Baru', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                          onPressed: () => context.go('/buat-surat'),
                        ),
                      );
                    }

                    final doc = filtered[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final kategori = data['kategori'] ?? '-';
                    final keperluan = data['keperluan'] ?? '-';
                    final status = data['status'] ?? 'draft';
                    final tanggal = data['tanggalPengajuan'] as Timestamp?;
                    final tanggalStr = tanggal != null ? DateFormat('dd/MM/yyyy').format(tanggal.toDate()) : '-';

                    Color statusColor;
                    String statusLabel;
                    switch (status) {
                      case 'draft': statusColor = Colors.grey.shade200; statusLabel = 'Draft'; break;
                      case 'diajukan': statusColor = Colors.orange.shade200; statusLabel = 'Sedang Diproses'; break;
                      case 'acc_rt': statusColor = Colors.blue.shade200; statusLabel = 'Disetujui RT'; break;
                      case 'acc_rw': statusColor = Colors.purple.shade200; statusLabel = 'Disetujui RW'; break;
                      case 'acc_kelurahan': statusColor = Colors.green.shade200; statusLabel = 'Disetujui Kelurahan'; break;
                      case 'selesai': statusColor = Colors.green.shade300; statusLabel = 'Selesai'; break;
                      case 'ditolak': statusColor = Colors.red.shade200; statusLabel = 'Ditolak'; break;
                      default: statusColor = Colors.grey.shade100; statusLabel = status;
                    }

                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        contentPadding: EdgeInsets.all(12),
                        leading: Container(width: 4, color: statusColor),
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
                                  decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(4)),
                                  child: Text(statusLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
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

  Widget _buildSuratMasukKelurahan() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('surat').where('status', isEqualTo: 'acc_rw').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
        
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('Tidak ada surat yang menunggu persetujuan dari Kelurahan', textAlign: TextAlign.center),
          ));
        }

        return ListView(
          padding: EdgeInsets.all(12),
          children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            if (data == null) return SizedBox.shrink();
            
            final kategori = data['kategori']?.toString() ?? '-';
            final pemohonData = (data['dataPemohon'] as Map<String, dynamic>?) ?? {};
            final pemohonNama = pemohonData['nama']?.toString() ?? '-';
            final pemohonRt = pemohonData['rt']?.toString() ?? '-';
            final pemohonRw = pemohonData['rw']?.toString() ?? '-';
            
            return Card(
              margin: EdgeInsets.symmetric(vertical: 6),
              child: ListTile(
                title: Text(kategori, style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 4),
                    Text('Pemohon: $pemohonNama'),
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(4)),
                          child: Text('RT $pemohonRt', style: TextStyle(fontSize: 11, color: Colors.blue.shade700)),
                        ),
                        SizedBox(width: 6),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.purple.shade100, borderRadius: BorderRadius.circular(4)),
                          child: Text('RW $pemohonRw', style: TextStyle(fontSize: 11, color: Colors.purple.shade700)),
                        ),
                      ],
                    ),
                  ],
                ),
                trailing: Icon(Icons.chevron_right),
                onTap: () => context.push('/detail-surat/${doc.id}'),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildSuratMasukRT() {
    String rt = dataPemohon?['rt']?.toString() ?? '';
    String rw = dataPemohon?['rw']?.toString() ?? '';
    
    // Determine what status to look for based on user role
    String targetStatus = 'diajukan'; // default for RT
    if (widget.role == 'rw' || widget.role == 'rt_rw') {
      targetStatus = 'acc_rt'; // RW sees surat approved by RT
    }
    
    if (rt.isEmpty || rw.isEmpty) {
      return Center(child: Text('RT/RW belum diinisialisasi'));
    }

    return StreamBuilder<QuerySnapshot>(
      // fetch all surat and filter 100% client-side to avoid permission/index issues
      stream: FirebaseFirestore.instance.collection('surat').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
        
        // filter client-side: status == targetStatus AND:
        // - if RT: dataPemohon.rt must match current user's RT
        // - if RW: dataPemohon.rw must match current user's RW
        final filtered = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) return false;
          
          // check status matches what this role expects
          final status = data['status']?.toString() ?? '';
          if (status != targetStatus) return false;
          
          // check RT/RW match
          final dataPemohon = data['dataPemohon'] as Map<String, dynamic>?;
          if (dataPemohon == null) return false;
          
          if (widget.role == 'rt') {
            // RT only sees surat from their own RT
            final pemohonRt = dataPemohon['rt']?.toString() ?? '';
            return pemohonRt == rt;
          } else if (widget.role == 'rw' || widget.role == 'rt_rw') {
            // RW sees surat from all RT in their RW
            final pemohonRw = dataPemohon['rw']?.toString() ?? '';
            return pemohonRw == rw;
          }
          return false;
        }).toList();

        if (filtered.isEmpty) {
          final roleText = widget.role == 'rt' ? 'RT $rt' : 'RW $rw';
          final statusText = targetStatus == 'diajukan' ? 'diajukan' : 'diterima RT';
          return Center(child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('Tidak ada surat dengan status "$statusText" untuk $roleText', textAlign: TextAlign.center),
          ));
        }

        return ListView(
          padding: EdgeInsets.all(12),
          children: filtered.map((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            final kategori = data?['kategori'] ?? '-';
            final pemohonData = data?['dataPemohon'] as Map<String, dynamic>? ?? {};
            final pemohonNama = pemohonData['nama'] ?? '-';
            final pemohonRt = pemohonData['rt']?.toString() ?? '-';
            
            return Card(
              margin: EdgeInsets.symmetric(vertical: 6),
              child: ListTile(
                title: Text(kategori, style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 4),
                    Text('Pemohon: $pemohonNama'),
                    if (widget.role == 'rw' || widget.role == 'rt_rw')
                      Text('Dari RT $pemohonRt', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  ],
                ),
                trailing: Icon(Icons.chevron_right),
                onTap: () => context.push('/detail-surat/${doc.id}'),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ignore: unused_element
  Widget _buildGrafik() {
    return PieChart(
      PieChartData(
        sections: [
          PieChartSectionData(value: 40, color: Colors.blue, title: 'PNS'),
          PieChartSectionData(value: 30, color: Colors.green, title: 'Wiraswasta'),
          PieChartSectionData(value: 30, color: Colors.red, title: 'Lainnya'),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedIndex == 0 ? 'Beranda ${widget.role}' : 'Akun'),
        actions: [IconButton(onPressed: () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('role');
          await FirebaseAuth.instance.signOut();
          context.go('/');
        }, icon: Icon(Icons.logout))],
      ),
      body: Container(
        color: Color(0xFFF3FBF5),
        child: _selectedIndex == 0 ? _buildBeranda() : _buildAkun(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Beranda'),
          BottomNavigationBarItem(icon: Icon(Icons.account_circle), label: 'Akun'),
        ],
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }

  Widget _buildAkun() {
    // Account overview and actions
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top profile card
          if (dataPemohon != null) ...[
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
              ),
              child: Row(
                children: [
                  // Avatar with initials
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: Colors.green.shade700,
                    child: Text(
                      // initials from name
                      (dataPemohon!['nama'] ?? '')
                          .toString()
                          .trim()
                          .split(' ')
                          .where((s) => s.isNotEmpty)
                          .map((s) => s[0].toUpperCase())
                          .take(2)
                          .join(),
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(dataPemohon!['nama'] ?? 'Nama', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        SizedBox(height: 6),
                        Text('Warga • RT ${dataPemohon!['rt'] ?? '-'} / RW ${dataPemohon!['rw'] ?? '-'}', style: TextStyle(color: Colors.grey[700])),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            ElevatedButton(
                              onPressed: () => context.push('/detail-akun'),
                              style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
                              child: Text('Lihat Profil'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
          ],

          // Menu list (simple list tiles)
          Card(
            elevation: 0,
            color: Colors.transparent,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.lock_outline),
                  title: Text('Ganti Kata Sandi'),
                  trailing: Icon(Icons.chevron_right),
                  onTap: () => context.push('/ganti-kata-sandi'),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.family_restroom),
                  title: Text('Daftar Keluarga'),
                  trailing: Icon(Icons.chevron_right),
                  onTap: () => context.push('/daftar-keluarga'),
                ),
                if (widget.role == 'rt' || widget.role == 'rw' || widget.role == 'rt_rw') ...[
                  Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.history),
                    title: Text('Riwayat RT/RW'),
                    trailing: Icon(Icons.chevron_right),
                    onTap: () => context.push('/riwayat-rtrw'),
                  ),
                ],
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.help_outline),
                  title: Text('Pusat Bantuan'),
                  trailing: Icon(Icons.chevron_right),
                  onTap: () => context.push('/pusat-bantuan'),
                ),
                Divider(height: 1),
                // About app (no chevron, show subtitle)
                ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('Tentang Aplikasi'),
                  subtitle: Text('Versi 1.0'),
                  onTap: () => context.push('/tentang'),
                ),
                Divider(height: 1),
                // Language toggle
                _LanguageToggleTile(),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.logout, color: Colors.red),
                  title: Text('Logout', style: TextStyle(color: Colors.red)),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('Konfirmasi Logout'),
                        content: Text('Apakah Anda yakin ingin keluar?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Batal')),
                          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text('Keluar')),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      // perform logout
                      await SharedPreferences.getInstance().then((prefs) => prefs.remove('role'));
                      await FirebaseAuth.instance.signOut();
                      context.go('/');
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}

class _LanguageToggleTile extends StatefulWidget {
  @override
  State<_LanguageToggleTile> createState() => _LanguageToggleTileState();
}

class _LanguageToggleTileState extends State<_LanguageToggleTile> {
  bool _isEnglish = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isEnglish = prefs.getBool('isEnglish') ?? false;
    });
  }

  Future<void> _set(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isEnglish', v);
    setState(() {
      _isEnglish = v;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bahasa diubah: ${v ? 'English' : 'Bahasa Indonesia'}')));
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(Icons.language),
      title: Text('Bahasa'),
      subtitle: Text(_isEnglish ? 'English' : 'Bahasa Indonesia'),
      trailing: Switch(value: _isEnglish, onChanged: _set),
    );
  }
}