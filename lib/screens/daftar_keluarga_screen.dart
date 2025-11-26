import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DaftarKeluargaScreen extends StatefulWidget {
  const DaftarKeluargaScreen({super.key});

  @override
  _DaftarKeluargaScreenState createState() => _DaftarKeluargaScreenState();
}

class _DaftarKeluargaScreenState extends State<DaftarKeluargaScreen> {
  final _firestore = FirebaseFirestore.instance;
  
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Daftar Keluarga'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: _firestore.collection('users').doc(uid).get(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }
          
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data == null) {
            return Center(child: Text('Data tidak ditemukan'));
          }
          
          final List<Map<String, dynamic>> anggotaKeluarga = 
              List<Map<String, dynamic>>.from(data['anggotaKeluarga'] ?? []);
          
          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Info Header
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Kepala Keluarga', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      SizedBox(height: 8),
                      Text(data['nama'] ?? 'N/A', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      SizedBox(height: 4),
                      Text('NIK: ${data['nik'] ?? '-'}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                    ],
                  ),
                ),
                SizedBox(height: 24),
                
                // Anggota Keluarga List
                if (anggotaKeluarga.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Anggota Keluarga', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.green.shade700)),
                      Text('${anggotaKeluarga.length}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                    ],
                  ),
                  SizedBox(height: 12),
                  ...anggotaKeluarga.map((anggota) => Card(
                    margin: EdgeInsets.symmetric(vertical: 6),
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.blue.shade100,
                                child: Text(
                                  (anggota['nama'] ?? 'N')
                                      .toString()
                                      .split(' ')
                                      .take(1)
                                      .join()
                                      .substring(0, 1)
                                      .toUpperCase(),
                                  style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold),
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      anggota['nama'] ?? '-',
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      anggota['statusDiKeluarga'] ?? 'Anggota',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('NIK', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                                    Text(anggota['nik'] ?? '-', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Status Perkawinan', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                                    Text(anggota['statusPerkawinan'] ?? '-', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
                            child: Text(
                              '${anggota['jenisKelamin'] ?? '-'} • ${anggota['agama'] ?? '-'}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),
                ] else ...[
                  SizedBox(height: 32),
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.people_outline, size: 64, color: Colors.grey.shade300),
                        SizedBox(height: 16),
                        Text(
                          'Belum ada anggota keluarga',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
                
                SizedBox(height: 24),
                
                // Tambah Anggota Button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    padding: EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: Icon(Icons.person_add),
                  label: Text('Tambah Anggota Keluarga', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  onPressed: () => context.go('/tambah-anggota'),
                ),
                
                SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}
