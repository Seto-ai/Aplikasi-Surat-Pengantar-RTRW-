import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../utils/shimmer_loader.dart';

class LihatDataWargaScreen extends StatefulWidget {
  const LihatDataWargaScreen({super.key});

  @override
  _LihatDataWargaScreenState createState() => _LihatDataWargaScreenState();
}

class _LihatDataWargaScreenState extends State<LihatDataWargaScreen> with TickerProviderStateMixin {
  final _firestore = FirebaseFirestore.instance;
  late TabController _tabController;
  String _searchQuery = '';
  String? _userRole;
  String? _userRt;
  String? _userRw;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return;
      
      final data = doc.data() as Map<String, dynamic>;
      setState(() {
        _userRole = data['role']?.toString();
        _userRt = data['rt']?.toString();
        _userRw = data['rw']?.toString();
      });
    } catch (e) {
      print('Error loading user info: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Data Warga'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _loadUserInfo();
              });
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Ringkasan'),
            Tab(text: 'Hierarki'),
            Tab(text: 'Cari'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSummaryTab(),
          _buildHierarchyTab(),
          _buildSearchTab(),
        ],
      ),
    );
  }

  Widget _buildSummaryTab() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadSummaryData(),
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
                  Text(snapshot.error.toString(), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                ],
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                ShimmerLoader.summarySkeleton(),
                SizedBox(height: 24),
                ShimmerLoader.listSkeleton(itemCount: 3),
              ],
            ),
          );
        }

        final data = snapshot.data!;
        final totalWarga = data['totalWarga'] as int;
        final totalRW = data['totalRW'] as int;
        final totalRT = data['totalRT'] as int;
        final rwCounts = data['rwCounts'] as Map<String, int>;
        final rtCounts = data['rtCounts'] as Map<String, int>;

        return SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Summary cards
              Row(
                children: [
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total Warga', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            SizedBox(height: 8),
                            Text('$totalWarga', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total RW', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            SizedBox(height: 8),
                            Text('$totalRW', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total RT', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            SizedBox(height: 8),
                            Text('$totalRT', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.purple.shade700)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),

              // Warga per RW
              Text('Warga per RW', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
              SizedBox(height: 12),
              ...rwCounts.entries.map((e) => Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('RW ${e.key}', style: TextStyle(fontWeight: FontWeight.w600)),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                          child: Text('${e.value} warga', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ),
              )),
              SizedBox(height: 20),

              // RT per RW
              Text('RT per RW', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
              SizedBox(height: 12),
              ...rtCounts.entries.map((e) {
                final parts = e.key.split('/');
                return Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('RT ${parts[0]} / RW ${parts[1]}', style: TextStyle(fontWeight: FontWeight.w600)),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(12)),
                            child: Text('Aktif', style: TextStyle(color: Colors.purple.shade700, fontWeight: FontWeight.w600, fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHierarchyTab() {
    if (_userRole == 'rt' && _userRt != null && _userRw != null) {
      // RT hanya lihat warga di RT mereka sendiri
      return FutureBuilder<QuerySnapshot>(
        future: _firestore
            .collection('users')
            .where('role', isEqualTo: 'warga')
            .where('rt', isEqualTo: _userRt)
            .get(),
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
                    Text('Gagal memuat data', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return SingleChildScrollView(
              child: Column(
                children: [ShimmerLoader.listSkeleton(itemCount: 5)],
              ),
            );
          }
          
          final wargaDocs = snapshot.data!.docs;
          if (wargaDocs.isEmpty) {
            return Center(child: Text('Tidak ada warga di RT $_userRt'));
          }
          
          return ListView(
            padding: EdgeInsets.all(8),
            children: [
              Card(
                margin: EdgeInsets.all(8),
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('RW $_userRw', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      SizedBox(height: 4),
                      Text('RT $_userRt', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.blue.shade700)),
                      SizedBox(height: 8),
                      Text('Total Warga: ${wargaDocs.length}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
              ...wargaDocs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final nama = data['nama'] ?? '-';
                final nik = data['nik'] ?? '-';
                return Card(
                  margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: ListTile(
                    title: Text(nama),
                    subtitle: Text('NIK: $nik', style: TextStyle(fontSize: 12)),
                    leading: CircleAvatar(child: Text(nama.substring(0, 1).toUpperCase())),
                  ),
                );
              }),
            ],
          );
        },
      );
    } else if ((_userRole == 'rw' || _userRole == 'rt_rw') && _userRw != null) {
      // RW lihat RW mereka dengan RT drill-down
      return FutureBuilder<QuerySnapshot>(
        future: _firestore.collection('rt').where('nomor_rw', isEqualTo: _userRw).orderBy('nomor_rt').get(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
          
          final rtDocs = snapshot.data!.docs;
          if (rtDocs.isEmpty) {
            return Center(child: Text('Tidak ada RT di RW $_userRw'));
          }
          
          return ListView.builder(
            padding: EdgeInsets.all(8),
            itemCount: rtDocs.length,
            itemBuilder: (context, rtIndex) {
              final rtData = rtDocs[rtIndex].data() as Map<String, dynamic>;
              final nomorRt = rtData['nomor_rt']?.toString() ?? '-';
              
              return Card(
                margin: EdgeInsets.symmetric(vertical: 6),
                child: ExpansionTile(
                  title: Text('RT $nomorRt', style: TextStyle(fontWeight: FontWeight.w600)),
                  children: [
                    FutureBuilder<QuerySnapshot>(
                      future: _firestore
                          .collection('users')
                          .where('role', isEqualTo: 'warga')
                          .where('rt', isEqualTo: nomorRt)
                          .where('rw', isEqualTo: _userRw)
                          .get(),
                      builder: (context, wargaSnapshot) {
                        if (!wargaSnapshot.hasData) {
                          return Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator());
                        }
                        
                        final wargaDocs = wargaSnapshot.data!.docs;
                        if (wargaDocs.isEmpty) {
                          return Padding(padding: EdgeInsets.all(8), child: Text('Tidak ada warga'));
                        }
                        
                        return Column(
                          children: wargaDocs.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final nama = data['nama'] ?? '-';
                            final nik = data['nik'] ?? '-';
                            return ListTile(
                              title: Text(nama, style: TextStyle(fontSize: 13)),
                              subtitle: Text('NIK: $nik', style: TextStyle(fontSize: 11)),
                              leading: CircleAvatar(child: Text(nama.substring(0, 1).toUpperCase())),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    } else {
      // Kelurahan lihat semua RW dengan RT drill-down
      return FutureBuilder<QuerySnapshot>(
        future: _firestore.collection('rw').orderBy('nomor_rw').get(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final rwDocs = snapshot.data!.docs;
          if (rwDocs.isEmpty) {
            return Center(child: Text('Tidak ada RW ditemukan'));
          }

          return ListView.builder(
            padding: EdgeInsets.all(8),
            itemCount: rwDocs.length,
            itemBuilder: (context, rwIndex) {
              final rwData = rwDocs[rwIndex].data() as Map<String, dynamic>;
              final nomorRw = rwData['nomor_rw']?.toString() ?? '-';

              return Card(
                margin: EdgeInsets.symmetric(vertical: 6),
                child: ExpansionTile(
                  title: Text('RW $nomorRw', style: TextStyle(fontWeight: FontWeight.w600)),
                  children: [
                    FutureBuilder<QuerySnapshot>(
                      future: _firestore
                          .collection('rt')
                          .where('nomor_rw', isEqualTo: nomorRw)
                          .orderBy('nomor_rt')
                          .get(),
                      builder: (context, rtSnapshot) {
                        if (!rtSnapshot.hasData) {
                          return Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator());
                        }

                        final rtDocs = rtSnapshot.data!.docs;
                        if (rtDocs.isEmpty) {
                          return Padding(
                            padding: EdgeInsets.all(8),
                            child: Text('Tidak ada RT di RW $nomorRw'),
                          );
                        }

                        return Column(
                          children: rtDocs.map((rtDoc) {
                            final rtData = rtDoc.data() as Map<String, dynamic>;
                            final nomorRt = rtData['nomor_rt']?.toString() ?? '-';

                            return ExpansionTile(
                              title: Text('RT $nomorRt', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                              children: [
                                FutureBuilder<QuerySnapshot>(
                                  future: _firestore
                                      .collection('users')
                                      .where('role', isEqualTo: 'warga')
                                      .where('rt', isEqualTo: nomorRt)
                                      .get(),
                                  builder: (context, wargaSnapshot) {
                                    if (!wargaSnapshot.hasData) {
                                      return Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator());
                                    }
                                    
                                    final wargaDocs = wargaSnapshot.data!.docs;
                                    if (wargaDocs.isEmpty) {
                                      return Padding(padding: EdgeInsets.all(8), child: Text('Tidak ada warga'));
                                    }
                                    
                                    return Column(
                                      children: wargaDocs.map((doc) {
                                        final data = doc.data() as Map<String, dynamic>;
                                        final nama = data['nama'] ?? '-';
                                        final nik = data['nik'] ?? '-';
                                        return ListTile(
                                          title: Text(nama, style: TextStyle(fontSize: 13)),
                                          subtitle: Text('NIK: $nik', style: TextStyle(fontSize: 11)),
                                          leading: CircleAvatar(child: Text(nama.substring(0, 1).toUpperCase())),
                                        );
                                      }).toList(),
                                    );
                                  },
                                ),
                              ],
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    }
  }

  Widget _buildSearchTab() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              labelText: 'Cari warga (nama/NIK)',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
          ),
          SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getWargaStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
                
                final wargaList = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final nama = data['nama']?.toString().toLowerCase() ?? '';
                  final nik = data['nik']?.toString().toLowerCase() ?? '';
                  
                  if (_searchQuery.isEmpty) return false;
                  return nama.contains(_searchQuery) || nik.contains(_searchQuery);
                }).toList();
                
                if (_searchQuery.isEmpty) {
                  return Center(
                    child: Text('Cari warga berdasarkan nama atau NIK', style: TextStyle(color: Colors.grey.shade600)),
                  );
                }
                
                if (wargaList.isEmpty) {
                  return Center(
                    child: Text('Tidak ada warga yang sesuai', style: TextStyle(color: Colors.grey.shade600)),
                  );
                }
                
                return ListView.builder(
                  itemCount: wargaList.length,
                  itemBuilder: (context, index) {
                    final doc = wargaList[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final nama = data['nama'] ?? '-';
                    final nik = data['nik'] ?? '-';
                    final rt = data['rt'] ?? '-';
                    final rw = data['rw'] ?? '-';
                    
                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        title: Text(nama, style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 4),
                            Text('NIK: $nik', style: TextStyle(fontSize: 12)),
                            Text('RT $rt / RW $rw', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          ],
                        ),
                        trailing: Icon(Icons.person),
                        onTap: () {
                          // PERBAIKAN: Validasi RT sebelum bisa lihat detail warga
                          if (_userRole == 'rt' && rt != _userRt) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Hanya bisa melihat warga di RT Anda sendiri'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          context.push('/detail-akun?readOnly=true');
                        },
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
  
  Stream<QuerySnapshot> _getWargaStream() {
    if (_userRole == 'rt' && _userRt != null) {
      // RT hanya lihat warga di RT mereka
      return _firestore
          .collection('users')
          .where('role', isEqualTo: 'warga')
          .where('rt', isEqualTo: _userRt)
          .snapshots();
    } else if ((_userRole == 'rw' || _userRole == 'rt_rw') && _userRw != null) {
      // RW lihat warga di RW mereka
      return _firestore
          .collection('users')
          .where('role', isEqualTo: 'warga')
          .where('rw', isEqualTo: _userRw)
          .snapshots();
    } else {
      // Kelurahan lihat semua warga
      return _firestore
          .collection('users')
          .where('role', isEqualTo: 'warga')
          .snapshots();
    }
  }

  Future<Map<String, dynamic>> _loadSummaryData() async {
    try {
      final Map<String, int> rwCounts = {};
      final Map<String, int> rtCounts = {};
      int totalWarga = 0;
      int totalRW = 0;
      int totalRT = 0;
      
      if (_userRole == 'rt') {
        // RT hanya lihat warga di RT mereka sendiri
        if (_userRt != null) {
          final wargaSnapshot = await _firestore
              .collection('users')
              .where('role', isEqualTo: 'warga')
              .where('rt', isEqualTo: _userRt)
              .get();
          totalWarga = wargaSnapshot.docs.length;
          rtCounts[_userRt!] = totalWarga;
          totalRT = 1;
          totalRW = 1;
        }
      } else if (_userRole == 'rw' || _userRole == 'rt_rw') {
        // RW lihat warga di RW mereka + RT count
        if (_userRw != null) {
          final wargaSnapshot = await _firestore
              .collection('users')
              .where('role', isEqualTo: 'warga')
              .where('rw', isEqualTo: _userRw)
              .get();
          totalWarga = wargaSnapshot.docs.length;
          
          // Count RT per RW
          final rtSnapshot = await _firestore
              .collection('rt')
              .where('nomor_rw', isEqualTo: _userRw)
              .get();
          totalRT = rtSnapshot.docs.length;
          
          // Count warga per RT in this RW
          for (final doc in wargaSnapshot.docs) {
            final rt = doc['rt']?.toString() ?? '-';
            rtCounts[rt] = (rtCounts[rt] ?? 0) + 1;
          }
          
          totalRW = 1;
          rwCounts[_userRw!] = totalWarga;
        }
      } else {
        // Kelurahan lihat semua
        final wargaSnapshot = await _firestore.collection('users').where('role', isEqualTo: 'warga').get();
        final rwSnapshot = await _firestore.collection('rw').get();
        final rtSnapshot = await _firestore.collection('rt').get();

        totalWarga = wargaSnapshot.docs.length;
        totalRW = rwSnapshot.docs.length;
        totalRT = rtSnapshot.docs.length;

        // Count warga per RW
        for (final doc in wargaSnapshot.docs) {
          final rw = doc['rw']?.toString() ?? '-';
          rwCounts[rw] = (rwCounts[rw] ?? 0) + 1;
        }

        // Count RT
        for (final doc in rtSnapshot.docs) {
          final rt = doc['nomor_rt']?.toString() ?? '-';
          rtCounts[rt] = (rtCounts[rt] ?? 0) + 1;
        }
      }

      return {
        'totalWarga': totalWarga,
        'totalRW': totalRW,
        'totalRT': totalRT,
        'rwCounts': rwCounts,
        'rtCounts': rtCounts,
      };
    } catch (e) {
      rethrow;
    }
  }
}
