import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class DetailSuratScreen extends StatefulWidget {
  final String id;
  DetailSuratScreen({required this.id});

  @override
  _DetailSuratScreenState createState() => _DetailSuratScreenState();
}

class _DetailSuratScreenState extends State<DetailSuratScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _supabase = Supabase.instance.client;
  
  DocumentSnapshot? suratDoc;
  bool _isLoading = false;
  String? _myRole;

  Future<void> _loadMyRole() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await _firestore.collection('users').doc(uid).get();
    setState(() {
      _myRole = doc.data()?['role']?.toString();
    });
  }

  Future<void> _loadSurat() async {
    final doc = await _firestore.collection('surat').doc(widget.id).get();
    setState(() => suratDoc = doc);
  }

  Future<void> _generatePDF() async {
    if (suratDoc == null) return;
    final data = suratDoc!.data() as Map<String, dynamic>;
    final pdf = pw.Document();
    final nama = data['dataPemohon']['nama'] ?? 'N/A';
    final nik = data['dataPemohon']['nik'] ?? 'N/A';
    final alamat = data['dataPemohon']['alamat'] ?? 'N/A';
    final tglBuat = DateFormat('dd MMMM yyyy').format((data['tanggalPengajuan'] as Timestamp).toDate());

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Center(
            child: pw.Text(
              'SURAT KETERANGAN',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Text('Kategori: ${data['kategori']}', style: pw.TextStyle(fontSize: 12)),
          pw.Text('Pemohon: $nama', style: pw.TextStyle(fontSize: 12)),
          pw.Text('NIK: $nik', style: pw.TextStyle(fontSize: 12)),
          pw.Text('Alamat: $alamat', style: pw.TextStyle(fontSize: 12)),
          pw.Text('Keperluan: ${data['keperluan']}', style: pw.TextStyle(fontSize: 12)),
          pw.Text('Tanggal Pengajuan: $tglBuat', style: pw.TextStyle(fontSize: 12)),
          pw.SizedBox(height: 40),
          pw.Text('Tanda Tangan: _______________________', style: pw.TextStyle(fontSize: 12)),
          pw.SizedBox(height: 20),
          pw.Text('Catatan: Print surat ini, tandatangani dengan tinta hitam, scan kembali, lalu upload.', 
            style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic)),
        ],
      ),
    ));
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  Future<void> _uploadFotoTTD() async {
    try {
      final picker = ImagePicker();
      final source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Pilih Sumber Foto'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, ImageSource.camera), child: Text('Kamera')),
            TextButton(onPressed: () => Navigator.pop(context, ImageSource.gallery), child: Text('Galeri')),
          ],
        ),
      );
      
      if (source == null) return;
      
      final pickedFile = await picker.pickImage(source: source, imageQuality: 80);
      if (pickedFile == null) return;

      setState(() => _isLoading = true);

      // Upload ke Supabase
      final fileName = '${widget.id}_ttd_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bytes = await pickedFile.readAsBytes();
      
      await _supabase.storage
          .from('dokumen-warga')
          .uploadBinary(fileName, bytes, fileOptions: FileOptions(upsert: true));
      
      // Get public URL
      final url = _supabase.storage.from('dokumen-warga').getPublicUrl(fileName);
      
      // Update Firestore
      await _firestore.collection('surat').doc(widget.id).update({
        'urlSuratTtd': url,
        'status': 'diajukan',
        'tanggalDiajukan': Timestamp.now(),
      });

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✓ Surat berhasil diajukan ke RT'), backgroundColor: Colors.green),
        );
        // Reload data
        _loadSurat();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Gagal upload: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSurat();
    _loadMyRole();
  }

  @override
  Widget build(BuildContext context) {
    if (suratDoc == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Detail Surat')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final data = suratDoc!.data() as Map<String, dynamic>;
    final status = data['status'] ?? 'draft';
    final isAjukan = status == 'diajukan';
    final tglBuat = DateFormat('dd MMMM yyyy, HH:mm').format((data['tanggalPengajuan'] as Timestamp).toDate());

    return Scaffold(
      appBar: AppBar(
        title: Text('Detail Surat'),
        leading: IconButton(icon: Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // === STATUS BADGE ===
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isAjukan ? Colors.blue.shade50 : Colors.orange.shade50,
                      border: Border.all(color: isAjukan ? Colors.blue.shade700 : Colors.orange.shade700),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(isAjukan ? Icons.check_circle : Icons.pending, 
                          color: isAjukan ? Colors.blue.shade700 : Colors.orange.shade700),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isAjukan ? 'Sudah Diajukan' : 'Belum Diajukan',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, 
                                  color: isAjukan ? Colors.blue.shade700 : Colors.orange.shade700),
                              ),
                              Text(
                                isAjukan ? 'Menunggu persetujuan RT' : 'Selesaikan upload TTD untuk ajukan',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),

                  // === DETAIL SURAT ===
                  Text('Detail Surat', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                  SizedBox(height: 12),
                  ListTile(
                    title: Text('Jenis Surat'),
                    subtitle: Text(data['kategori'] ?? 'N/A'),
                    trailing: Icon(Icons.description),
                  ),
                  ListTile(
                    title: Text('Keperluan'),
                    subtitle: Text(data['keperluan'] ?? 'N/A'),
                    trailing: Icon(Icons.edit_note),
                  ),
                  ListTile(
                    title: Text('Tanggal Dibuat'),
                    subtitle: Text(tglBuat),
                    trailing: Icon(Icons.calendar_today),
                  ),
                  SizedBox(height: 24),
                  Divider(),
                  SizedBox(height: 16),

                  // === DATA PEMOHON ===
                  Text('Data Pemohon', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                  SizedBox(height: 12),
                  ListTile(
                    title: Text('Nama'),
                    subtitle: Text(data['dataPemohon']['nama'] ?? 'N/A'),
                    trailing: Icon(Icons.person),
                  ),
                  ListTile(
                    title: Text('NIK'),
                    subtitle: Text(data['dataPemohon']['nik'] ?? 'N/A'),
                    trailing: Icon(Icons.badge),
                  ),
                  ListTile(
                    title: Text('Alamat'),
                    subtitle: Text(data['dataPemohon']['alamat'] ?? 'N/A'),
                    trailing: Icon(Icons.home),
                  ),
                  if (data['dataPemohon']['urlFotoKk'] != null) ...[
                    SizedBox(height: 16),
                    Text('Foto KK:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade700)),
                    SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(data['dataPemohon']['urlFotoKk']!, height: 120, fit: BoxFit.cover),
                    ),
                  ],
                  if (data['dataPemohon']['urlFotoKtp'] != null) ...[
                    SizedBox(height: 16),
                    Text('Foto KTP:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade700)),
                    SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(data['dataPemohon']['urlFotoKtp']!, height: 120, fit: BoxFit.cover),
                    ),
                  ],
                  SizedBox(height: 24),
                  Divider(),
                  SizedBox(height: 16),

                  // === ACTION BUTTONS ===
                  Text('Langkah Selanjutnya', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                  SizedBox(height: 16),
                  
                  if (!isAjukan) ...[
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 14)),
                      icon: Icon(Icons.download),
                      label: Text('Download Surat PDF', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      onPressed: _generatePDF,
                    ),
                    SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.green.shade700,
                      ),
                      icon: Icon(Icons.upload_file),
                      label: Text('Upload Foto Surat TTD & Ajukan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      onPressed: _uploadFotoTTD,
                    ),
                  ] else ...[
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        border: Border.all(color: Colors.green.shade700),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('✓ Surat sudah diajukan', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w600)),
                          SizedBox(height: 8),
                          Text('Menunggu persetujuan dari RT. Anda akan menerima notifikasi ketika surat telah disetujui atau ditolak.',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                        ],
                      ),
                    ),
                    SizedBox(height: 12),
                    // If current user is RT/RW, show approve/reject controls
                    if (_myRole != null && ( _myRole == 'rt' || _myRole == 'rw' || _myRole == 'rt_rw')) ...[
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 14)),
                              onPressed: () async {
                                // Reject flow with reason
                                String alasan = '';
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text('Tolak Surat'),
                                    content: TextField(onChanged: (v) => alasan = v, decoration: InputDecoration(labelText: 'Alasan penolakan')),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Batal')),
                                      ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text('Tolak')),
                                    ],
                                  ),
                                );
                                if (ok != true) return;
                                try {
                                  await _firestore.collection('surat').doc(widget.id).update({
                                    'status': 'ditolak',
                                    'alasanTolak': alasan,
                                    'ditolakOleh': FirebaseAuth.instance.currentUser!.uid,
                                    'tanggalDitolak': Timestamp.now(),
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Surat ditolak')));
                                  // reload and go back
                                  await _loadSurat();
                                  context.pop();
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menolak surat: $e')));
                                }
                              },
                              child: Text('Tolak', style: TextStyle(color: Colors.red)),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 14), backgroundColor: Colors.green.shade700),
                              onPressed: () async {
                                // Approve flow
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text('Konfirmasi Terima'),
                                    content: Text('Terima surat ini? Setelah diterima, status akan diperbarui.'),
                                    actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Batal')), ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text('Terima'))],
                                  ),
                                );
                                if (confirm != true) return;
                                try {
                                  final newStatus = _myRole == 'rw' ? 'acc_rw' : 'acc_rt';
                                  await _firestore.collection('surat').doc(widget.id).update({
                                    'status': newStatus,
                                    'approvedBy': FirebaseAuth.instance.currentUser!.uid,
                                    'tanggalAcc': Timestamp.now(),
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Surat diterima')));
                                  await _loadSurat();
                                  context.pop();
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menerima surat: $e')));
                                }
                              },
                              child: Text('Terima'),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (data['urlSuratTtd'] != null)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 14)),
                        icon: Icon(Icons.visibility),
                        label: Text('Lihat Foto Surat TTD', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        onPressed: () async {
                          final url = data['urlSuratTtd'];
                          if (await canLaunchUrl(Uri.parse(url))) {
                            await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                          }
                        },
                      ),
                  ],

                  SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 14)),
                    icon: Icon(Icons.arrow_back),
                    label: Text('Kembali ke Beranda', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    onPressed: () => context.go('/dashboard/warga'),
                  ),
                  SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}