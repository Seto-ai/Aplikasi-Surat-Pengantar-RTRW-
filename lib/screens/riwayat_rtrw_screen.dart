import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class RiwayatRTRWScreen extends StatefulWidget {
  @override
  _RiwayatRTRWScreenState createState() => _RiwayatRTRWScreenState();
}

class _RiwayatRTRWScreenState extends State<RiwayatRTRWScreen> {
  final _firestore = FirebaseFirestore.instance;
  
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Riwayat Perubahan RT/RW'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('riwayatRTRW')
            .orderBy('tanggal', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }
          
          final docs = snapshot.data!.docs;
          
          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history, size: 64, color: Colors.grey.shade300),
                    SizedBox(height: 16),
                    Text(
                      'Belum ada riwayat perubahan RT/RW',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            );
          }
          
          return ListView.builder(
            padding: EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final tipe = data['tipe']?.toString() ?? 'N/A'; // 'rekrut' or 'perubahan'
              final noHp = data['noHp']?.toString() ?? '-';
              final nomorRT = data['nomorRT']?.toString() ?? '-';
              final nomorRW = data['nomorRW']?.toString() ?? '-';
              final statusSebelum = data['statusSebelum']?.toString() ?? '-'; // 'ada' or 'kosong'
              final statusSesudah = data['statusSesudah']?.toString() ?? '-'; // 'ada' or 'kosong'
              final waktu = data['tanggal'] as Timestamp?;
              final keterangan = data['keterangan']?.toString() ?? '-';
              final waktuStr = waktu != null 
                  ? DateFormat('dd MMM yyyy, HH:mm').format(waktu.toDate())
                  : '-';
              
              String title = '';
              Color statusColor = Colors.grey;
              IconData icon = Icons.info;
              
              if (tipe == 'rekrut') {
                title = 'Rekrutmen Kepala RT/RW';
                statusColor = Colors.green;
                icon = Icons.person_add;
              } else {
                title = 'Perubahan Status Kepala RT/RW';
                statusColor = Colors.orange;
                icon = Icons.refresh;
              }
              
              return Card(
                margin: EdgeInsets.symmetric(vertical: 6),
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(icon, color: statusColor, size: 20),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: statusColor),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  waktuStr,
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('RT', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                                      Text(nomorRT, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('RW', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                                      Text(nomorRW, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Sebelum', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: statusSebelum == 'ada' ? Colors.blue.shade100 : Colors.red.shade100,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          statusSebelum == 'ada' ? 'Ada Kepala' : 'Kosong',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: statusSebelum == 'ada' ? Colors.blue.shade700 : Colors.red.shade700,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Sesudah', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: statusSesudah == 'ada' ? Colors.green.shade100 : Colors.orange.shade100,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          statusSesudah == 'ada' ? 'Ada Kepala' : 'Kosong',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: statusSesudah == 'ada' ? Colors.green.shade700 : Colors.orange.shade700,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (keterangan != '-') ...[
                        SizedBox(height: 8),
                        Text('Keterangan:', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                        Text(keterangan, style: TextStyle(fontSize: 11)),
                      ],
                      if (noHp != '-') ...[
                        SizedBox(height: 8),
                        Text('No. HP: $noHp', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
