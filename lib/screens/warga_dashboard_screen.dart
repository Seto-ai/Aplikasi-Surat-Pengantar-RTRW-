import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../utils/shimmer_loader.dart';
import '../utils/localization.dart';
import 'package:provider/provider.dart';

class WargaDashboardScreen extends StatefulWidget {
  const WargaDashboardScreen({super.key});

  @override
  _WargaDashboardScreenState createState() => _WargaDashboardScreenState();
}

class _WargaDashboardScreenState extends State<WargaDashboardScreen> {
  int _selectedIndex = 0;
  Map<String, dynamic>? dataPemohon;
  List<Map<String, dynamic>> anggotaKeluarga = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    setState(() {
      dataPemohon = doc.data();
      anggotaKeluarga = List<Map<String, dynamic>>.from(
        doc['anggotaKeluarga'] ?? [],
      );
    });
  }

  String _getGreeting(LocalizationProvider loc) {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return loc.t('good_morning');
    } else if (hour < 15) {
      return loc.t('good_afternoon');
    } else if (hour < 19) {
      return loc.t('good_evening');
    } else {
      return loc.t('good_night');
    }
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
            title: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(FirebaseAuth.instance.currentUser?.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                String userName = 'User';
                if (snapshot.hasData && snapshot.data != null) {
                  final data = snapshot.data!.data() as Map<String, dynamic>?;
                  userName = data?['nama'] ?? 'User';
                }

                return Row(
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
                        SizedBox(height: 2),
                        Text(
                          userName,
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
                );
              },
            ),
          ),
          body: _selectedIndex == 0
              ? _buildBeranda(locProvider)
              : _buildAkun(locProvider),
          bottomNavigationBar: BottomNavigationBar(
            items: [
              BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: locProvider.t('home'),
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
      offset: Offset(0, 48),
      itemBuilder: (BuildContext context) {
        return [
          PopupMenuItem<String>(
            value: AppLocalization.ID,
            child: Text(locProvider.t('indonesian')),
          ),
          PopupMenuItem<String>(
            value: AppLocalization.EN,
            child: Text(locProvider.t('english')),
          ),
        ];
      },
      onSelected: (String locale) {
        locProvider.setLocale(locale);
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Color(0xFF27AE60)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.language, color: Color(0xFF27AE60), size: 20),
            SizedBox(width: 6),
            Text(
              locProvider.currentLocale.toUpperCase(),
              style: TextStyle(
                color: Color(0xFF27AE60),
                fontWeight: FontWeight.w600,
              ),
            ),
            Icon(Icons.arrow_drop_down, color: Color(0xFF27AE60)),
          ],
        ),
      ),
    );
  }

  Widget _buildBeranda(LocalizationProvider locProvider) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    String? selectedStatus;
    String searchQuery = '';

    return StatefulBuilder(
      builder: (context, setState) => Column(
        children: [
          // Search & Filter Section
          Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              children: [
                // Search
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: locProvider.t('search_letter'),
                      labelStyle: TextStyle(color: Colors.grey.shade600),
                      prefixIcon: Icon(Icons.search, color: Color(0xFF27AE60)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                    ),
                    onChanged: (val) =>
                        setState(() => searchQuery = val.toLowerCase()),
                  ),
                ),
                SizedBox(height: 12),

                // Filter dropdowns
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonFormField<String?>(
                          decoration: InputDecoration(
                            labelText: locProvider.t('status'),
                            labelStyle: TextStyle(color: Colors.grey.shade600),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            prefixIcon: Icon(
                              Icons.filter_list,
                              color: Color(0xFF27AE60),
                            ),
                          ),
                          initialValue: selectedStatus,
                          items: [
                            DropdownMenuItem(
                              value: null,
                              child: Text(locProvider.t('all')),
                            ),
                            DropdownMenuItem(
                              value: 'draft',
                              child: Text(locProvider.t('draft')),
                            ),
                            DropdownMenuItem(
                              value: 'diajukan',
                              child: Text(locProvider.t('processing')),
                            ),
                            DropdownMenuItem(
                              value: 'acc_rt',
                              child: Text(locProvider.t('approved_rt')),
                            ),
                            DropdownMenuItem(
                              value: 'acc_rw',
                              child: Text(locProvider.t('approved_rw')),
                            ),
                            DropdownMenuItem(
                              value: 'acc_kelurahan',
                              child: Text(locProvider.t('approved_kelurahan')),
                            ),
                            DropdownMenuItem(
                              value: 'selesai',
                              child: Text(locProvider.t('completed')),
                            ),
                            DropdownMenuItem(
                              value: 'ditolak',
                              child: Text(locProvider.t('rejected')),
                            ),
                          ],
                          onChanged: (val) =>
                              setState(() => selectedStatus = val),
                        ),
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
              stream: FirebaseFirestore.instance
                  .collection('surat')
                  .where('pembuatId', isEqualTo: uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.red.shade400,
                          ),
                          SizedBox(height: 12),
                          Text(
                            locProvider.t('error'),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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

                var docs = snapshot.data!.docs;

                // Sort by tanggalPengajuan (newest first)
                docs.sort((a, b) {
                  final aTime =
                      (a['tanggalPengajuan'] as Timestamp?)?.toDate() ??
                      DateTime(1970);
                  final bTime =
                      (b['tanggalPengajuan'] as Timestamp?)?.toDate() ??
                      DateTime(1970);
                  return bTime.compareTo(aTime);
                });

                // Apply filters
                final filtered = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final kategori =
                      data['kategori']?.toString().toLowerCase() ?? '';
                  final keperluan =
                      data['keperluan']?.toString().toLowerCase() ?? '';
                  final status = data['status']?.toString() ?? '';

                  if (searchQuery.isNotEmpty &&
                      !kategori.contains(searchQuery) &&
                      !keperluan.contains(searchQuery)) {
                    return false;
                  }

                  if (selectedStatus != null && status != selectedStatus) {
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
                          Icon(
                            Icons.inbox,
                            size: 64,
                            color: Colors.grey.shade300,
                          ),
                          SizedBox(height: 16),
                          Text(
                            locProvider.t('no_letters_found'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            locProvider.t('start_new_letter'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(height: 24),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF27AE60),
                              padding: EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 24,
                              ),
                            ),
                            icon: Icon(Icons.add, color: Colors.white),
                            label: Text(
                              locProvider.t('create_new_letter'),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            onPressed: () => context.go('/buat-surat'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: filtered.length + 1,
                  itemBuilder: (context, index) {
                    if (index == filtered.length) {
                      return Padding(
                        padding: EdgeInsets.all(12),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF27AE60),
                            padding: EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: Icon(Icons.add, color: Colors.white),
                          label: Text(
                            locProvider.t('create_new_letter'),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
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
                    final tanggalStr = tanggal != null
                        ? DateFormat('dd/MM/yyyy').format(tanggal.toDate())
                        : '-';

                    Color statusColor;
                    String statusLabel;
                    switch (status) {
                      case 'draft':
                        statusColor = Colors.grey.shade200;
                        statusLabel = locProvider.t('draft');
                        break;
                      case 'diajukan':
                        statusColor = Colors.orange.shade200;
                        statusLabel = locProvider.t('processing');
                        break;
                      case 'acc_rt':
                        statusColor = Colors.blue.shade200;
                        statusLabel = locProvider.t('approved_rt');
                        break;
                      case 'acc_rw':
                        statusColor = Colors.purple.shade200;
                        statusLabel = locProvider.t('approved_rw');
                        break;
                      case 'acc_kelurahan':
                        statusColor = Colors.green.shade200;
                        statusLabel = locProvider.t('approved_kelurahan');
                        break;
                      case 'selesai':
                        statusColor = Colors.green.shade300;
                        statusLabel = locProvider.t('completed');
                        break;
                      case 'ditolak':
                        statusColor = Colors.red.shade200;
                        statusLabel = locProvider.t('rejected');
                        break;
                      default:
                        statusColor = Colors.grey.shade100;
                        statusLabel = status;
                    }

                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        contentPadding: EdgeInsets.all(12),
                        leading: Container(width: 4, color: statusColor),
                        title: Text(
                          kategori,
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 4),
                            Text(
                              keperluan,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12),
                            ),
                            SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    statusLabel,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  tanggalStr,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
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

  Widget _buildAkun(LocalizationProvider locProvider) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Profile card
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
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: Color(0xFF27AE60),
                    child: Text(
                      (dataPemohon!['nama'] ?? '')
                          .toString()
                          .trim()
                          .split(' ')
                          .where((s) => s.isNotEmpty)
                          .map((s) => s[0].toUpperCase())
                          .take(2)
                          .join(),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dataPemohon!['nama'] ?? 'Nama',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          '${locProvider.t('applicant')} • RT ${dataPemohon!['rt'] ?? '-'} / RW ${dataPemohon!['rw'] ?? '-'}',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
          ],

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
                  onTap: () => context.push('/detail-akun'),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.lock_outline, color: Color(0xFF27AE60)),
                  title: Text(locProvider.t('change_password')),
                  trailing: Icon(Icons.chevron_right),
                  onTap: () => context.push('/ganti-kata-sandi'),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.family_restroom,
                    color: Color(0xFF27AE60),
                  ),
                  title: Text(locProvider.t('family_list')),
                  trailing: Icon(Icons.chevron_right),
                  onTap: () => context.push('/daftar-keluarga'),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.logout, color: Colors.red),
                  title: Text(
                    locProvider.t('logout'),
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(locProvider.t('confirm_logout')),
                        content: Text(locProvider.t('logout_question')),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(locProvider.t('cancel')),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text(locProvider.t('exit')),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await SharedPreferences.getInstance().then(
                        (prefs) => prefs.remove('role'),
                      );
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
  }
}
