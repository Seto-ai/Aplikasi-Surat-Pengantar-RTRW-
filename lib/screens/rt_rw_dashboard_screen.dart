import 'package:aplikasi_surat_mobile/utils/ux_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../utils/localization.dart';
import 'package:provider/provider.dart';

class RTRWDashboardScreen extends StatefulWidget {
  final String role; // 'rt' atau 'rw'

  const RTRWDashboardScreen({super.key, required this.role});

  @override
  State<RTRWDashboardScreen> createState() {
    print('DEBUG: RTRWDashboardScreen created with role: $role');
    return _RTRWDashboardScreenState();
  }
}

class _RTRWDashboardScreenState extends State<RTRWDashboardScreen> {
  int _selectedIndex = 0;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _currentUserName;
  String? _currentUserRT;
  String? _currentUserRW;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final uid = _auth.currentUser!.uid;
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        setState(() {
          _currentUserName = doc['nama'] ?? 'User';
          _currentUserRT = doc['rt'];
          _currentUserRW = doc['rw'];
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  String _getGreeting(LocalizationProvider loc) {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Selamat Pagi';
    if (hour < 15) return 'Selamat Siang';
    if (hour < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LocalizationProvider>(
      builder: (context, locProvider, _) {
        return Scaffold(
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.white,
            automaticallyImplyLeading: false,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Greeting + Name di kiri
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getGreeting(locProvider),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _currentUserName ?? 'User',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
                // Language dropdown di kanan
                _buildLanguageDropdown(locProvider),
              ],
            ),
          ),
          body: _selectedIndex == 0
              ? _buildBerandaTab()
              : _selectedIndex == 1
                  ? _buildLihatWargaTab()
                  : _buildAkunTab(),
          bottomNavigationBar: BottomNavigationBar(
            items: [
              BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: locProvider.t('home'),
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.people),
                label: 'Lihat Warga',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.account_circle),
                label: locProvider.t('account'),
              ),
            ],
            currentIndex: _selectedIndex,
            onTap: (index) => setState(() => _selectedIndex = index),
          ),
        );
      },
    );
  }

  Widget _buildLanguageDropdown(LocalizationProvider locProvider) {
    return PopupMenuButton<String>(
      offset: const Offset(0, 48),
      itemBuilder: (BuildContext context) {
        return [
          const PopupMenuItem<String>(
            value: AppLocalization.ID,
            child: Text('🇮🇩 Indonesian'),
          ),
          const PopupMenuItem<String>(
            value: AppLocalization.EN,
            child: Text('🇬🇧 English'),
          ),
        ];
      },
      onSelected: (String locale) {
        locProvider.setLocale(locale);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.green.shade700),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.language, color: Colors.green.shade700, size: 20),
            const SizedBox(width: 6),
            Text(
              locProvider.currentLocale.toUpperCase(),
              style: TextStyle(
                color: Colors.green.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            Icon(Icons.arrow_drop_down, color: Colors.green.shade700),
          ],
        ),
      ),
    );
  }

  Widget _buildBerandaTab() {
    return BerandaTabRT(
      myRT: _currentUserRT,
      myRW: _currentUserRW,
      role: widget.role,
    );
  }

  Widget _buildLihatWargaTab() {
    return LihatWargaTabRT(
      myRT: _currentUserRT,
      myRW: _currentUserRW,
      role: widget.role,
    );
  }

  Widget _buildAkunTab() {
    return AkunTabRT(
      userName: _currentUserName ?? 'User',
      userRT: _currentUserRT ?? '',
      userRW: _currentUserRW ?? '',
    );
  }
}

// ============ BERANDA TAB ============
class BerandaTabRT extends StatefulWidget {
  final String? myRT;
  final String? myRW;
  final String role;

  const BerandaTabRT({
    super.key,
    required this.myRT,
    required this.myRW,
    required this.role,
  });

  @override
  State<BerandaTabRT> createState() => _BerandaTabRTState();
}

class _BerandaTabRTState extends State<BerandaTabRT> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _searchQuery = '';
  String _sortBy = 'newest';

  String _getStatusLabel(String status) {
    final labelMap = {
      'draft': 'Draft',
      'diajukan': 'Menunggu Persetujuan RT',
      'acc_rt': 'Disetujui RT, Menunggu RW',
      'acc_rw': 'Disetujui RW, Menunggu Kelurahan',
      'acc_kelurahan': 'Disetujui',
      'ditolak': 'Ditolak',
    };
    return labelMap[status] ?? status;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'draft':
        return Colors.orange;
      case 'diajukan':
      case 'acc_rt':
      case 'acc_rw':
        return Colors.blue;
      case 'acc_kelurahan':
        return Colors.green;
      case 'ditolak':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setState) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Search
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Cari surat...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (val) {
                    setState(() => _searchQuery = val.toLowerCase());
                  },
                ),
                const SizedBox(height: 12),
                // Sort
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildSortChip('Terbaru', 'newest', setState),
                      const SizedBox(width: 8),
                      _buildSortChip('Terlama', 'oldest', setState),
                      const SizedBox(width: 8),
                      _buildSortChip('Disetujui', 'acc', setState),
                      const SizedBox(width: 8),
                      _buildSortChip('Ditolak', 'ditolak', setState),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildSuratListStream(),
          ),
        ],
      ),
    );
  }

  Widget _buildSortChip(String label, String value, Function(VoidCallback) setState) {
    final isSelected = _sortBy == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _sortBy = value);
      },
      backgroundColor: Colors.white,
      selectedColor: Colors.green.shade100,
      labelStyle: TextStyle(
        color: isSelected ? Colors.green.shade700 : Colors.black,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
      ),
    );
  }

  Widget _buildSuratListStream() {
    Query query = _firestore.collection('surat');

    // Sesuaikan query berdasarkan peran untuk menggunakan field di dalam dataPemohon
    if (widget.role == 'rt') {
      query = query
          .where('dataPemohon.rt', isEqualTo: widget.myRT)
          .where('status', isEqualTo: 'diajukan');
    } else if (widget.role == 'rw') {
      query = query
          .where('dataPemohon.rw', isEqualTo: widget.myRW)
          .where('status', isEqualTo: 'acc_rt');
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var docs = snapshot.data!.docs;

        // Sort
        if (_sortBy == 'oldest') {
          docs.sort((a, b) {
            final aTime = (a['tanggalPengajuan'] as Timestamp?)?.toDate() ?? DateTime(1970);
            final bTime = (b['tanggalPengajuan'] as Timestamp?)?.toDate() ?? DateTime(1970);
            return aTime.compareTo(bTime);
          });
        } else if (_sortBy == 'newest') {
          docs.sort((a, b) {
            final aTime = (a['tanggalPengajuan'] as Timestamp?)?.toDate() ?? DateTime(1970);
            final bTime = (b['tanggalPengajuan'] as Timestamp?)?.toDate() ?? DateTime(1970);
            return bTime.compareTo(aTime);
          });
        } else if (_sortBy == 'acc') {
          docs = docs.where((d) => 
              d['status'] == 'acc_rt' || 
              d['status'] == 'acc_rw' || 
              d['status'] == 'acc_kelurahan').toList();
        } else if (_sortBy == 'ditolak') {
          docs = docs.where((d) => d['status'] == 'ditolak').toList();
        }

        // Filter by search
        final filtered = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final dataPemohon = data['dataPemohon'] as Map<String, dynamic>? ?? {};
          final namaPemohon = (dataPemohon['nama'] as String?) ?? '';
          final keperluan = (data['keperluan'] as String?) ?? '';
          
          if (_searchQuery.isEmpty) return true;
          return namaPemohon.toLowerCase().contains(_searchQuery) ||
              keperluan.toLowerCase().contains(_searchQuery);
        }).toList();

        if (filtered.isEmpty) {
          return const Center(child: Text('Tidak ada surat masuk'));
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final doc = filtered[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildSuratCard(doc.id, data);
          },
        );
      },
    );
  }

  Widget _buildSuratCard(String docId, Map<String, dynamic> data) {
    final dataPemohon = data['dataPemohon'] as Map<String, dynamic>? ?? {};
    final namaPemohon = dataPemohon['nama'] ?? 'Tanpa Nama';
    final keperluan = data['keperluan'] ?? '-';
    final status = data['status'] ?? 'draft';
    final statusLabel = _getStatusLabel(status);
    final statusColor = _getStatusColor(status);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      child: ListTile(
        title: Text(
          namaPemohon,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(keperluan, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(
              statusLabel,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/detail-surat/$docId'),
      ),
    );
  }
}

// ============ LIHAT WARGA TAB ============
class LihatWargaTabRT extends StatefulWidget {
  final String? myRT;
  final String? myRW;
  final String role;

  const LihatWargaTabRT({
    super.key,
    required this.myRT,
    required this.myRW,
    required this.role,
  });

  @override
  State<LihatWargaTabRT> createState() => _LihatWargaTabRTState();
}

class _LihatWargaTabRTState extends State<LihatWargaTabRT> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _rtList = []; // For RW role
  final Map<String, List<Map<String, dynamic>>> _wargaByRT = {}; // For RT role
  final Set<String> _expandedRTs = {}; // Track expanded RTs

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);

      if (widget.role == 'rt') {
        await _loadWargaForRT();
      } else if (widget.role == 'rw') {
        await _loadRTsForRW();
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      print('Error loading data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        UxHelper.showError(context, 'Gagal memuat data: $e');
      }
    }
  }

  Future<void> _loadWargaForRT() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('rt', isEqualTo: widget.myRT)
          .where('role', isEqualTo: 'warga')
          .get();

      _wargaByRT[widget.myRT!] =
          snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    } catch (e) {
      print('Error loading warga: $e');
    }
  }

  Future<void> _loadRTsForRW() async {
    try {
      final rtSnapshot = await _firestore
          .collection('users')
          .where('rw', isEqualTo: widget.myRW)
          .where('role', isEqualTo: 'rt')
          .get();

      _rtList =
          rtSnapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();

      // Load warga untuk setiap RT
      for (var rt in _rtList) {
        final wargaSnapshot = await _firestore
            .collection('users')
            .where('rt', isEqualTo: rt['rt'])
            .where('role', isEqualTo: 'warga')
            .get();
        _wargaByRT[rt['rt']] = wargaSnapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList();
      }
    } catch (e) {
      print('Error loading RTs: $e');
    }
  }

  void _toggleRT(String rtValue) {
    setState(() {
      if (_expandedRTs.contains(rtValue)) {
        _expandedRTs.remove(rtValue);
      } else {
        _expandedRTs.add(rtValue);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.role == 'rt') {
      return _buildRTView();
    } else {
      return _buildRWView();
    }
  }

  Widget _buildRTView() {
    final wargaList = _wargaByRT[widget.myRT] ?? [];

    return wargaList.isEmpty
        ? const Center(child: Text('Tidak ada warga'))
        : ListView.builder(
            itemCount: wargaList.length,
            itemBuilder: (context, index) {
              final warga = wargaList[index];
              return _buildWargaCard(warga);
            },
          );
  }

  Widget _buildRWView() {
    return ListView.builder(
      itemCount: _rtList.length,
      itemBuilder: (context, index) {
        final rt = _rtList[index];
        final rtValue = rt['rt'];
        final isExpanded = _expandedRTs.contains(rtValue);
        final wargaList = _wargaByRT[rtValue] ?? [];

        return Column(
          children: [
            ListTile(
              title: Text(
                'Ketua RT $rtValue - ${rt['nama'] ?? "N/A"}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text('RW ${widget.myRW}'),
              trailing:
                  Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
              onTap: () => _toggleRT(rtValue),
              tileColor: Colors.grey.shade100,
            ),
            if (isExpanded)
              ...wargaList.map((warga) => Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: _buildWargaCard(warga),
                  )),
          ],
        );
      },
    );
  }

  Widget _buildWargaCard(Map<String, dynamic> warga) {
    // Check if this is an RT card (when RW viewing RT members)
    final name = warga['nama'] ?? 'N/A';
    final rt = warga['rt']?.toString() ?? '';
    final isRT = warga['role'] == 'rt';
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.shade700,
          child: Icon(isRT ? Icons.admin_panel_settings : Icons.person, color: Colors.white),
        ),
        title: Text(
          isRT ? 'Ketua RT $rt - $name' : name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle:
            Text(warga['email'] ?? 'N/A', style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios,
            size: 14, color: Colors.grey),
        onTap: () => context.push('/detail-akun?readOnly=true'),
      ),
    );
  }
}

// ============ AKUN TAB ============
class AkunTabRT extends StatefulWidget {
  final String userName;
  final String userRT;
  final String userRW;

  const AkunTabRT({
    super.key,
    required this.userName,
    required this.userRT,
    required this.userRW,
  });

  @override
  State<AkunTabRT> createState() => _AkunTabRTState();
}

class _AkunTabRTState extends State<AkunTabRT> {
  @override
  Widget build(BuildContext context) {
    return Consumer<LocalizationProvider>(
      builder: (context, locProvider, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Profile card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: Color(0xFF27AE60),
                      child: Text(
                        (widget.userName)
                            .toString()
                            .trim()
                            .split(' ')
                            .where((s) => s.isNotEmpty)
                            .map((s) => s[0].toUpperCase())
                            .take(2)
                            .join(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.userName,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Text(
                              'RT ${widget.userRT} / RW ${widget.userRW}',
                              style: TextStyle(
                                  color: Colors.grey[700], fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Menu list
              Card(
                elevation: 0,
                color: Colors.transparent,
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.person, color: Color(0xFF27AE60)),
                      title: Text(locProvider.t('view_profile')),
                      trailing: Icon(Icons.chevron_right),
                      onTap: () => context.push('/detail-akun?readOnly=true'),
                    ),
                    Divider(height: 1),
                    ListTile(
                      leading:
                          Icon(Icons.lock_outline, color: Color(0xFF27AE60)),
                      title: Text(locProvider.t('change_password')),
                      trailing: Icon(Icons.chevron_right),
                      onTap: () => context.push('/ganti-kata-sandi'),
                    ),
                    Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.logout, color: Colors.red),
                      title: Text(locProvider.t('logout'),
                          style: const TextStyle(color: Colors.red)),
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(locProvider.t('confirm_logout')),
                            content: Text(locProvider.t('logout_question')),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(context, false),
                                child: Text(locProvider.t('cancel')),
                              ),
                              ElevatedButton(
                                onPressed: () =>
                                    Navigator.pop(context, true),
                                child: Text(locProvider.t('exit')),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await FirebaseAuth.instance.signOut();
                          if (mounted) context.go('/');
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}