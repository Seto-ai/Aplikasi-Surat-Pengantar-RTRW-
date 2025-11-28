import 'package:aplikasi_surat_mobile/utils/ux_helper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../utils/localization.dart';
import 'package:provider/provider.dart';

class KelurahanDashboardScreen extends StatefulWidget {
  const KelurahanDashboardScreen({super.key});

  @override
  State<KelurahanDashboardScreen> createState() =>
      _KelurahanDashboardScreenState();
}

class _KelurahanDashboardScreenState extends State<KelurahanDashboardScreen> {
  int _selectedIndex = 0; // Reset to default Beranda tab
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _currentUserName;

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
          _currentUserName = (doc['nama'] as String?) ?? 'User';
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
                _buildLanguageDropdown(locProvider),
              ],
            ),
          ),
          body: _selectedIndex == 0
              ? _buildBerandaTab()
              : _selectedIndex == 1
              ? _buildLihatWargaTab()
              : _selectedIndex == 2
              ? _buildManajemenRTRWTab()
              : _selectedIndex == 3
              ? _buildRekrutTab()
              : _buildAkunTab(),
          bottomNavigationBar: BottomNavigationBar(
            backgroundColor: Colors.white,
            selectedItemColor: Colors.green.shade700,
            unselectedItemColor: Colors.grey.shade600,
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
                icon: Icon(Icons.admin_panel_settings),
                label: 'Manajemen',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_add),
                label: 'Pilih RT & RW',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.account_circle),
                label: 'Akun',
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
            value: 'id',
            child: Text('🇮🇩 Indonesian'),
          ),
          const PopupMenuItem<String>(value: 'en', child: Text('🇬🇧 English')),
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
    return BerandaTabKelurahan();
  }

  Widget _buildLihatWargaTab() {
    return LihatWargaTabKelurahan();
  }

  Widget _buildManajemenRTRWTab() {
    return ManajemenRTRWTab();
  }

  Widget _buildRekrutTab() {
    return RekrutTabKelurahan();
  }

  Widget _buildAkunTab() {
    return AkunTabKelurahan();
  }
}

// ============ BERANDA TAB ============
class BerandaTabKelurahan extends StatefulWidget {
  const BerandaTabKelurahan({super.key});

  @override
  State<BerandaTabKelurahan> createState() => _BerandaTabKelurahanState();
}

class _BerandaTabKelurahanState extends State<BerandaTabKelurahan> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _searchQuery = '';
  String _sortBy = 'newest';

  // Helper function to safely parse tanggalPengajuan
  DateTime _parseTanggal(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    } else if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return DateTime(1970);
      }
    }
    return DateTime(1970);
  }

  String _getStatusLabel(String status) {
    final labelMap = {
      'draft': 'Draft',
      'diajukan': 'Menunggu Persetujuan RT',
      'acc_rt': 'Disetujui RT, Menunggu RW',
      'acc_rw': 'Disetujui RW',
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
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Cari surat...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (val) {
                    setState(() => _searchQuery = val.toLowerCase());
                  },
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildSortChip('Terbaru', 'newest', setState),
                      const SizedBox(width: 8),
                      _buildSortChip('Terlama', 'oldest', setState),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildSuratListStream()),
        ],
      ),
    );
  }

  Widget _buildSortChip(
    String label,
    String value,
    Function(VoidCallback) setState,
  ) {
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
    // Kelurahan hanya lihat surat yang sudah disetujui RT dan RW (status: acc_rw)
    // Setelah kelurahan menyetujui, surat hilang dari dashboard
    Query query = _firestore
        .collection('surat')
        .where('status', isEqualTo: 'acc_rw');

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var docs = snapshot.data!.docs;

        // Sort based on selected filter
        if (_sortBy == 'oldest') {
          docs.sort((a, b) {
            final aTime = _parseTanggal(a['tanggalPengajuan']);
            final bTime = _parseTanggal(b['tanggalPengajuan']);
            return aTime.compareTo(bTime);
          });
        } else if (_sortBy == 'newest') {
          docs.sort((a, b) {
            final aTime = _parseTanggal(a['tanggalPengajuan']);
            final bTime = _parseTanggal(b['tanggalPengajuan']);
            return bTime.compareTo(aTime);
          });
        }

        final filtered = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final namaPemohon = (data['namaPemohon'] as String?) ?? '';
          final keperluan = (data['keperluan'] as String?) ?? '';

          if (_searchQuery.isEmpty) return true;
          return namaPemohon.toLowerCase().contains(_searchQuery) ||
              keperluan.toLowerCase().contains(_searchQuery);
        }).toList();

        if (filtered.isEmpty) {
          return const Center(child: Text('Tidak ada surat'));
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
    final namaPemohon = (data['namaPemohon'] as String?) ?? 'Tanpa Nama';
    final keperluan = (data['keperluan'] as String?) ?? '-';
    final statusLabel = _getStatusLabel((data['status'] as String?) ?? 'draft');
    final statusColor = _getStatusColor((data['status'] as String?) ?? 'draft');

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
class LihatWargaTabKelurahan extends StatefulWidget {
  const LihatWargaTabKelurahan({super.key});

  @override
  State<LihatWargaTabKelurahan> createState() => _LihatWargaTabKelurahanState();
}

class _LihatWargaTabKelurahanState extends State<LihatWargaTabKelurahan> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _rwList = [];
  final Map<String, List<Map<String, dynamic>>> _rtByRW = {};
  final Map<String, List<Map<String, dynamic>>> _wargaByRT = {};
  final Set<String> _expandedRWs = {};
  final Set<String> _expandedRTs = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);

      // Load all RT users to get RW numbers and RT mapping
      final rtUsersSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'rt')
          .get();

      final rtUsers = rtUsersSnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();

      print('[DEBUG] Loaded ${rtUsers.length} RT users from users collection');

      // Extract unique RW numbers from RT users (rw field)
      final uniqueRWNumbers = <String>{};
      for (var rtUser in rtUsers) {
        final rwNum = rtUser['rw']?.toString();
        if (rwNum != null) {
          uniqueRWNumbers.add(rwNum);
        }
      }

      print(
        '[DEBUG] Found ${uniqueRWNumbers.length} unique RW numbers: $uniqueRWNumbers',
      );

      // Also load all RT from collection 'rt' to get RT ketua data
      final rtFromCollSnapshot = await _firestore.collection('rt').get();
      final allRTs = rtFromCollSnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
      print('[DEBUG] Loaded ${allRTs.length} total RT from collection rt');

      // Build RW list from collection 'rw' with nomor_rw field
      // RW data stored in collection 'rw' with uid, nama, nomor_rw, etc.
      _rwList = [];
      for (var rwNum in uniqueRWNumbers) {
        // Query collection 'rw' with nomor_rw field (convert to int for comparison)
        final rwSnapshot = await _firestore
            .collection('rw')
            .where('nomor_rw', isEqualTo: int.tryParse(rwNum) ?? rwNum)
            .limit(1)
            .get();

        Map<String, dynamic> rwDoc = {
          'rw': rwNum,
          'nama': 'RW $rwNum',
          'id': 'rw_$rwNum',
        };

        if (rwSnapshot.docs.isNotEmpty) {
          final rwData = rwSnapshot.docs.first;
          final ketuaNama = (rwData['nama'] as String?) ?? '';
          final ketuaUid = (rwData['uid'] as String?) ?? '';

          print(
            '[DEBUG] RW $rwNum found in collection rw - nama: "$ketuaNama", uid: "$ketuaUid"',
          );

          // If nama is empty/null, try fallback to users collection with role='rw'
          if (ketuaNama.isEmpty) {
            print(
              '[DEBUG] RW $rwNum has empty nama, trying users collection with role=rw',
            );
            final rwUserSnapshot = await _firestore
                .collection('users')
                .where('role', isEqualTo: 'rw')
                .where('rw', isEqualTo: rwNum)
                .limit(1)
                .get();
            if (rwUserSnapshot.docs.isNotEmpty) {
              final rwUserData = rwUserSnapshot.docs.first;
              final fallbackNama =
                  (rwUserData['nama'] as String?) ?? 'RW $rwNum';
              rwDoc = {
                'id': rwData.id,
                'rw': rwNum,
                'nama': fallbackNama,
                'uid': (rwUserData['uid'] as String?) ?? ketuaUid,
              };
              print(
                '[DEBUG] Found fallback RW $rwNum from users: $fallbackNama',
              );
            } else {
              rwDoc = {
                'id': rwData.id,
                'rw': rwNum,
                'nama': 'RW $rwNum',
                'uid': ketuaUid,
              };
              print(
                '[DEBUG] No fallback found for RW $rwNum, using default name',
              );
            }
          } else {
            rwDoc = {
              'id': rwData.id,
              'rw': rwNum,
              'nama': ketuaNama,
              'uid': ketuaUid,
            };
            print('[DEBUG] Using RW $rwNum ketua: $ketuaNama');
          }
        } else {
          print(
            '[DEBUG] No ketua RW record found for nomor_rw=$rwNum in rw collection. Trying from users collection with role=rw',
          );
          // Fallback: try to find from users collection with role='rw'
          final rwUserSnapshot = await _firestore
              .collection('users')
              .where('role', isEqualTo: 'rw')
              .where('rw', isEqualTo: rwNum)
              .limit(1)
              .get();
          if (rwUserSnapshot.docs.isNotEmpty) {
            final rwUserData = rwUserSnapshot.docs.first;
            final ketuaNama = (rwUserData['nama'] as String?) ?? 'RW $rwNum';
            rwDoc['nama'] = ketuaNama;
            rwDoc['uid'] = (rwUserData['uid'] as String?) ?? '';
            print(
              '[DEBUG] Found ketua RW $rwNum from users collection: $ketuaNama',
            );
          }
        }

        _rwList.add(rwDoc);
      }

      // Sort RW by nomor_rw (1-10)
      _rwList.sort((a, b) {
        final aNum = int.tryParse(a['rw']?.toString() ?? '0') ?? 0;
        final bNum = int.tryParse(b['rw']?.toString() ?? '0') ?? 0;
        return aNum.compareTo(bNum);
      });

      print('[DEBUG] Total RW after merging: ${_rwList.length}');
      for (var rw in _rwList) {
        print('[DEBUG] RW: ${rw['rw']} - ${rw['nama']}');
      }

      // Load all warga once
      final allWargaSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'warga')
          .get();
      final allWarga = allWargaSnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();

      print('[DEBUG] Loaded ${allWarga.length} total warga');
      for (var w in allWarga) {
        print('[DEBUG] Warga: ${w['nama']}, RT: ${w['rt']}, RW: ${w['rw']}');
      }

      // Load RT for each RW
      for (var rw in _rwList) {
        final rwNum = rw['rw']?.toString();
        if (rwNum == null) continue;

        // Filter RT for this RW: get RT users with matching rw field
        final rtList = rtUsers
            .where((rtUser) => rtUser['rw']?.toString() == rwNum)
            .map((rtUser) {
              // Get matching RT from collection
              final rtNum = rtUser['rt']?.toString();
              final rtFromCollection = allRTs.firstWhere(
                (rt) => rt['nomor_rt']?.toString() == rtNum,
                orElse: () => {
                  'nomor_rt': rtNum,
                  'nama': 'RT $rtNum',
                  'uid': '',
                },
              );
              return {...rtUser, ...rtFromCollection};
            })
            .toList();

        print('[DEBUG] Loaded ${rtList.length} RT for RW $rwNum');

        // Sort RT by rt/nomor_rt (1-37)
        rtList.sort((a, b) {
          final aNum =
              int.tryParse(
                a['rt']?.toString() ?? a['nomor_rt']?.toString() ?? '0',
              ) ??
              0;
          final bNum =
              int.tryParse(
                b['rt']?.toString() ?? b['nomor_rt']?.toString() ?? '0',
              ) ??
              0;
          return aNum.compareTo(bNum);
        });

        _rtByRW[rwNum] = rtList;

        // Filter warga for each RT from the allWarga list
        for (var rt in rtList) {
          final rtNum = rt['rt']?.toString() ?? rt['nomor_rt']?.toString();
          if (rtNum == null) continue;

          // Filter warga yang memiliki rt dan rw yang sama
          final wargaList = allWarga.where((warga) {
            final wargaRT = warga['rt']?.toString();
            final wargaRW = warga['rw']?.toString();
            final match = wargaRT == rtNum && wargaRW == rwNum;
            return match;
          }).toList();

          print('[DEBUG] RT $rtNum RW $rwNum: found ${wargaList.length} warga');
          for (var w in wargaList) {
            print('[DEBUG]   - ${w['nama']} (RT: ${w['rt']}, RW: ${w['rw']})');
          }

          _wargaByRT[rtNum] = wargaList;
        }
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      print('Error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        UxHelper.showError(context, 'Gagal memuat data: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView.builder(
      itemCount: _rwList.length,
      itemBuilder: (context, rwIndex) {
        final rw = _rwList[rwIndex];
        final rwValue = rw['rw']?.toString() ?? '';
        final isRWExpanded = _expandedRWs.contains(rwValue);
        final rtList = _rtByRW[rwValue] ?? [];

        return Column(
          children: [
            ListTile(
              title: Text(
                'Ketua RW $rwValue - ${(rw['nama'] as String?) ?? "RW $rwValue"}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              trailing: Icon(
                isRWExpanded ? Icons.expand_less : Icons.expand_more,
              ),
              onTap: () {
                setState(() {
                  if (_expandedRWs.contains(rwValue)) {
                    _expandedRWs.remove(rwValue);
                  } else {
                    _expandedRWs.add(rwValue);
                  }
                });
              },
              tileColor: Colors.blue.shade50,
            ),
            if (isRWExpanded)
              ...rtList.map((rt) {
                final rtValue = rt['rt']?.toString() ?? '';
                final isRTExpanded = _expandedRTs.contains(rtValue);
                final wargaList = _wargaByRT[rtValue] ?? [];

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: ListTile(
                        title: Text(
                          'Ketua RT $rtValue - ${(rt['nama'] as String?) ?? "RT $rtValue"}',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        trailing: Icon(
                          isRTExpanded ? Icons.expand_less : Icons.expand_more,
                        ),
                        onTap: () {
                          setState(() {
                            if (_expandedRTs.contains(rtValue)) {
                              _expandedRTs.remove(rtValue);
                            } else {
                              _expandedRTs.add(rtValue);
                            }
                          });
                        },
                        tileColor: Colors.grey.shade100,
                      ),
                    ),
                    if (isRTExpanded)
                      ...wargaList.map(
                        (warga) => Padding(
                          padding: const EdgeInsets.only(left: 32),
                          child: _buildWargaCard(warga),
                        ),
                      ),
                  ],
                );
              }),
          ],
        );
      },
    );
  }

  Widget _buildWargaCard(Map<String, dynamic> warga) {
    final wargaId = (warga['id'] as String?) ?? '';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.shade700,
          child: const Icon(Icons.person, color: Colors.white),
        ),
        title: Text((warga['nama'] as String?) ?? 'N/A'),
        subtitle: Text(
          (warga['email'] as String?) ?? 'N/A',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 14,
          color: Colors.grey,
        ),
        onTap: () => context.push('/detail-akun?readOnly=true&userId=$wargaId'),
      ),
    );
  }
}

// ============ MANAJEMEN RT/RW TAB ============
class ManajemenRTRWTab extends StatefulWidget {
  const ManajemenRTRWTab({super.key});

  @override
  State<ManajemenRTRWTab> createState() => _ManajemenRTRWTabState();
}

class _ManajemenRTRWTabState extends State<ManajemenRTRWTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _rtRWActive = [];
  List<Map<String, dynamic>> _rtRWHistory = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);

      // Load active RT/RW (from users collection)
      final snapshot = await _firestore
          .collection('users')
          .where('role', whereIn: ['rt', 'rw', 'rt_rw'])
          .get();

      _rtRWActive = snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();

      // Sort: RW first (1-10), then RT (1-37)
      _rtRWActive.sort((a, b) {
        final aRole = a['role']?.toString() ?? '';
        final bRole = b['role']?.toString() ?? '';

        // RW comes first
        if (aRole == 'rw' && bRole != 'rw') return -1;
        if (aRole != 'rw' && bRole == 'rw') return 1;

        // Sort by number within same role
        if (aRole == bRole) {
          final field = aRole == 'rw' ? 'rw' : 'rt';
          final aNum = int.tryParse(a[field]?.toString() ?? '0') ?? 0;
          final bNum = int.tryParse(b[field]?.toString() ?? '0') ?? 0;
          return aNum.compareTo(bNum);
        }

        return 0;
      });

      // Load history (from riwayatRTRW collection)
      final historySnapshot = await _firestore.collection('riwayatRTRW').get();

      _rtRWHistory = historySnapshot.docs
          .map((doc) => {...doc.data()})
          .toList();

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        UxHelper.showError(context, 'Error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            labelColor: Colors.black87,
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: Colors.green.shade700,
            tabs: const [
              Tab(text: 'Yang Menjabat'),
              Tab(text: 'Riwayat'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [_buildActiveList(), _buildHistoryList()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveList() {
    if (_rtRWActive.isEmpty) {
      return const Center(child: Text('Tidak ada RT/RW yang menjabat'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _rtRWActive.length,
      itemBuilder: (context, index) {
        final person = _rtRWActive[index];
        final role = person['role'];
        String title = '';
        if (role == 'rt') {
          title = 'Ketua RT ${person['rt']}';
        } else if (role == 'rw') {
          title = 'Ketua RW ${person['rw']}';
        } else if (role == 'rt_rw') {
          title = 'Ketua RT ${person['rt']} & RW ${person['rw']}';
        }

        return Card(
          child: ListTile(
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text((person['nama'] as String?) ?? 'N/A'),
            trailing: const Icon(Icons.info_outline),
            onTap: () => context.push('/detail-akun?readOnly=true'),
          ),
        );
      },
    );
  }

  Widget _buildHistoryList() {
    if (_rtRWHistory.isEmpty) {
      return const Center(child: Text('Tidak ada riwayat'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _rtRWHistory.length,
      itemBuilder: (context, index) {
        final history = _rtRWHistory[index];
        final periodeStr =
            '${history['periode_mulai']} s/d ${history['periode_akhir']}';

        // Build posisi string based on nomor_rt and nomor_rw
        String posisiStr = '';
        if (history['nomor_rt'] != null) {
          posisiStr += 'RT ${history['nomor_rt']}';
        }
        if (history['nomor_rw'] != null) {
          if (posisiStr.isNotEmpty) {
            posisiStr += ' / RW ${history['nomor_rw']}';
          } else {
            posisiStr = 'RW ${history['nomor_rw']}';
          }
        }
        if (posisiStr.isEmpty) {
          posisiStr = 'N/A';
        }

        return Card(
          child: ListTile(
            title: Text(
              (history['nama'] as String?) ?? 'N/A',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text('$posisiStr\n$periodeStr'),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}

// ============ REKRUT TAB ============
class RekrutTabKelurahan extends StatefulWidget {
  const RekrutTabKelurahan({super.key});

  @override
  State<RekrutTabKelurahan> createState() => _RekrutTabKelurahanState();
}

class _RekrutTabKelurahanState extends State<RekrutTabKelurahan> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _warnings = [];
  String _filterType = 'all'; // 'all', 'rt', 'rw'

  @override
  void initState() {
    super.initState();
    _loadWarnings();
  }

  Future<void> _loadWarnings() async {
    try {
      setState(() => _isLoading = true);
      _warnings = [];

      // Get all RW
      final rwSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'rw')
          .get();

      for (var rwDoc in rwSnapshot.docs) {
        final rwData = rwDoc.data();
        final rwValue = rwData['rw'];
        if (rwValue == null) continue;

        // Check if there's any RT with this RW
        final rtCount = await _firestore
            .collection('users')
            .where('rw', isEqualTo: rwValue)
            .where('role', isEqualTo: 'rt')
            .count()
            .get();

        if (rtCount.count == 0) {
          _warnings.add({
            'type': 'rw',
            'nomor': rwValue,
            'nama': (rwData['nama'] as String?) ?? 'RW $rwValue',
            'message': 'RW $rwValue belum ada yang menjabat',
          });
        }
      }

      // Get all RT positions that don't have anyone
      final allRTs = await _firestore.collection('users').get();
      final allRTNumbers = <String>{};

      for (var doc in allRTs.docs) {
        final data = doc.data();
        if (data.containsKey('rt')) {
          final rtValue = data['rt'];
          if (rtValue != null) {
            allRTNumbers.add(rtValue.toString());
          }
        }
      }

      // Check which RTs are empty
      for (String rt in allRTNumbers) {
        final rtExists = await _firestore
            .collection('users')
            .where('rt', isEqualTo: rt)
            .where('role', isEqualTo: 'rt')
            .count()
            .get();

        if (rtExists.count == 0) {
          _warnings.add({
            'type': 'rt',
            'nomor': rt,
            'message': 'RT $rt belum ada yang menjabat',
          });
        }
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      print('Error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        UxHelper.showError(context, 'Error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredWarnings = _warnings.where((w) {
      if (_filterType == 'all') return true;
      return w['type'] == _filterType;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: DropdownButton<String>(
                  value: _filterType,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Semua')),
                    DropdownMenuItem(value: 'rw', child: Text('RW')),
                    DropdownMenuItem(value: 'rt', child: Text('RT')),
                  ],
                  onChanged: (val) {
                    setState(() => _filterType = val ?? 'all');
                  },
                  isExpanded: true,
                ),
              ),
              SizedBox(width: 8),
              ElevatedButton.icon(
                icon: Icon(Icons.refresh),
                label: Text('Refresh'),
                onPressed: _loadWarnings,
              ),
            ],
          ),
        ),
        Expanded(
          child: filteredWarnings.isEmpty
              ? const Center(child: Text('Semua posisi sudah terisi'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filteredWarnings.length,
                  itemBuilder: (context, index) {
                    final warning = filteredWarnings[index];
                    return _buildWarningCard(warning);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildWarningCard(Map<String, dynamic> warning) {
    return Card(
      child: ListTile(
        leading: Icon(
          warning['type'] == 'rw' ? Icons.warning : Icons.info,
          color: Colors.orange,
        ),
        title: Text(
          warning['message'],
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(warning['type'].toUpperCase()),
        trailing: const Icon(Icons.arrow_forward),
        onTap: () async {
          // Navigate to warga selection screen
          final result = await context.push(
            '/rekrut-kelurahan?type=${warning["type"]}&nomor=${warning["nomor"]}',
          );
          if (result == true) {
            _loadWarnings();
          }
        },
      ),
    );
  }
}

// ============ AKUN TAB ============
class AkunTabKelurahan extends StatefulWidget {
  const AkunTabKelurahan({super.key});

  @override
  State<AkunTabKelurahan> createState() => _AkunTabKelurahanState();
}

class _AkunTabKelurahanState extends State<AkunTabKelurahan> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _userName;
  String? _userEmail;
  String? _userKelurahan;

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
          _userName = (doc['nama'] as String?) ?? 'User';
          _userEmail = (doc['email'] as String?) ?? 'N/A';
          _userKelurahan = (doc['kelurahan'] as String?) ?? 'N/A';
        });
      }
    } catch (e) {
      print('Error loading user: $e');
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Apakah Anda yakin ingin logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _auth.signOut();
      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal logout: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Profile Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.green.shade700,
                    child: const Icon(
                      Icons.person,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _userName ?? 'Loading...',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Kelurahan: ${_userKelurahan ?? 'N/A'}',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _userEmail ?? 'N/A',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Logout Button
          ElevatedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}
