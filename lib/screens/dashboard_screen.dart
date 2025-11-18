import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Future<void> _accSurat(String id, String nextStatus) async {
    await FirebaseFirestore.instance.collection('surat').doc(id).update({'status': nextStatus});
    final doc = await FirebaseFirestore.instance.collection('surat').doc(id).get();
    final noHp = doc['dataPemohon']['noHp'];
    final message = 'Surat Anda telah di-acc oleh ${widget.role}.';
    launch('https://wa.me/${noHp}?text=${Uri.encodeComponent(message)}');
  }

  Future<void> _tolakSurat(String id, String alasan) async {
    await FirebaseFirestore.instance.collection('surat').doc(id).update({'status': 'ditolak', 'alasanTolak': alasan});
    final doc = await FirebaseFirestore.instance.collection('surat').doc(id).get();
    final noHp = doc['dataPemohon']['noHp'];
    launch('https://wa.me/${noHp}?text=Surat ditolak: $alasan');
  }

  void _chatWA(String noHp, String message) {
    launch('https://wa.me/${noHp}?text=${Uri.encodeComponent(message)}');
  }

  Widget _buildBeranda() {
    if (widget.role == 'kelurahan') {
      return Column(
        children: [
          ElevatedButton(onPressed: () => context.go('/rekrut-rtrw'), child: Text('Rekrut RT/RW')),
          ElevatedButton(onPressed: () => _showDataWarga(), child: Text('Lihat Data Warga')),
          Expanded(child: _buildSuratMasukKelurahan()),
        ],
      );
    } else if (widget.role == 'rt' || widget.role == 'rw') {
      return Expanded(child: _buildSuratMasukRT());
    } else {
      return Column(
        children: [
          ElevatedButton(onPressed: () => context.go('/buat-surat'), child: Text('Buat Surat')),
          Expanded(child: _buildRiwayatSurat()),
        ],
      );
    }
  }

  Widget _buildRiwayatSurat() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('surat').where('pembuatId', isEqualTo: FirebaseAuth.instance.currentUser!.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return CircularProgressIndicator();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
              child: Text('Riwayat Surat', style: Theme.of(context).textTheme.titleLarge),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: snapshot.data!.docs.map((doc) {
                  Color statusColor = doc['status'] == 'diajukan' ? Colors.orange.shade300 : doc['status'].toString().contains('acc') ? Colors.green.shade200 : Colors.red.shade200;
                  return Card(
                    elevation: 1,
                    margin: EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      tileColor: statusColor,
                      title: Text(doc['kategori'], style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('Status: ${doc['status']}'),
                      onTap: () => context.go('/detail-surat/${doc.id}'),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSuratMasukKelurahan() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('surat').where('status', isEqualTo: 'acc_rw').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return CircularProgressIndicator();
        return ListView(
          padding: EdgeInsets.all(12),
          children: snapshot.data!.docs.map((doc) {
            return Card(
              margin: EdgeInsets.symmetric(vertical: 6),
              child: ListTile(
                title: Text(doc['kategori'], style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('Pemohon: ${doc['dataPemohon']['nama']}'),
                trailing: Wrap(
                  spacing: 6,
                  children: [
                    ElevatedButton(onPressed: () => _accSurat(doc.id, 'acc_kelurahan'), child: Text('Acc')),
                    OutlinedButton(onPressed: () => _showTolakDialog(doc.id), child: Text('Tolak')),
                    IconButton(onPressed: () => _chatWA(doc['dataPemohon']['noHp'], 'Kelanjutan surat Anda: ${doc['kategori']}'), icon: Icon(Icons.chat)),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildSuratMasukRT() {
    String rt = dataPemohon?['rt']?.toString() ?? '';
    
    if (rt.isEmpty) {
      return Center(child: Text('RT belum diinisialisasi'));
    }

    return StreamBuilder<QuerySnapshot>(
      // fetch all surat and filter 100% client-side to avoid permission/index issues
      stream: FirebaseFirestore.instance.collection('surat').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
        
        // filter client-side: status == diajukan AND dataPemohon.rt must match current user's RT
        final filtered = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) return false;
          
          // check status
          final status = data['status']?.toString() ?? '';
          if (status != 'diajukan') return false;
          
          // check RT
          final dataPemohon = data['dataPemohon'] as Map<String, dynamic>?;
          if (dataPemohon == null) return false;
          final pemohonRt = dataPemohon['rt']?.toString() ?? '';
          return pemohonRt == rt;
        }).toList();

        if (filtered.isEmpty) {
          return Center(child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('Tidak ada surat yang diajukan untuk RT $rt', textAlign: TextAlign.center),
          ));
        }

        return ListView(
          padding: EdgeInsets.all(12),
          children: filtered.map((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            final kategori = data?['kategori'] ?? '-';
            final pemohonData = data?['dataPemohon'] as Map<String, dynamic>? ?? {};
            final pemohonNama = pemohonData['nama'] ?? '-';
            
            return Card(
              margin: EdgeInsets.symmetric(vertical: 6),
              child: ListTile(
                title: Text(kategori, style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('Pemohon: $pemohonNama'),
                trailing: Wrap(
                  spacing: 6,
                  children: [
                    ElevatedButton(onPressed: () => _accSurat(doc.id, 'acc_rt'), child: Text('Acc')),
                    OutlinedButton(onPressed: () => _showTolakDialog(doc.id), child: Text('Tolak')),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  void _showDataWarga() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Pilih RW'),
        content: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('rw').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return CircularProgressIndicator();
            return Column(
              children: snapshot.data!.docs.map((doc) {
                return ListTile(
                  title: Text('RW ${doc['nomor_rw']}'),
                  onTap: () => _showRT(doc['nomor_rw']),
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }

  void _showRT(String rw) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Pilih RT di RW $rw'),
        content: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('rt').where('nomor_rw', isEqualTo: rw).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return CircularProgressIndicator();
            return Column(
              children: snapshot.data!.docs.map((doc) {
                return ListTile(
                  title: Text('RT ${doc['nomor_rt']}'),
                  onTap: () => _showWarga(doc['nomor_rt']),
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }

  void _showWarga(String rt) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Warga di RT $rt'),
        content: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').where('rt', isEqualTo: rt).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return CircularProgressIndicator();
            return Column(
              children: snapshot.data!.docs.map((doc) {
                return ListTile(
                  title: Text(doc['nama']),
                  subtitle: Text('NIK: ${doc['nik']}'),
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }

  void _showTolakDialog(String id) {
    String alasan = '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Alasan Tolak'),
        content: TextField(onChanged: (val) => alasan = val),
        actions: [
          ElevatedButton(onPressed: () { _tolakSurat(id, alasan); Navigator.pop(context); }, child: Text('Tolak')),
        ],
      ),
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
                  onTap: () => context.go('/tambah-anggota'),
                ),
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