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
import '../utils/ux_helper.dart';

class DetailSuratScreen extends StatefulWidget {
  final String id;
  const DetailSuratScreen({super.key, required this.id});

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
      _myRole = doc.data()?['role']?.toString().toLowerCase().trim();
    });
  }

  Future<void> _loadSurat() async {
    final doc = await _firestore.collection('surat').doc(widget.id).get();
    setState(() => suratDoc = doc);
  }

  Future<void> _generatePDF() async {
    if (suratDoc == null) return;
    final data = suratDoc!.data() as Map<String, dynamic>;
    final dataPemohon = data['dataPemohon'] as Map<String, dynamic>;
    final pdf = pw.Document();

    final nama = dataPemohon['nama'] ?? 'N/A';
    final nik = dataPemohon['nik'] ?? 'N/A';
    final tempatLahir = dataPemohon['tempatLahir'] ?? 'N/A';
    final tglLahir = dataPemohon['tanggalLahir'] ?? 'N/A';
    final jenisKelamin = dataPemohon['jenisKelamin'] ?? 'N/A';
    final pekerjaan = dataPemohon['pekerjaan'] ?? 'N/A';
    final alamat = dataPemohon['alamat'] ?? 'N/A';
    final rt = dataPemohon['rt'] ?? 'N/A';
    final rw = dataPemohon['rw'] ?? 'N/A';
    final kategori = data['kategori'] ?? 'N/A';
    final keperluan = data['keperluan'] ?? 'N/A';

    final tglBuat = DateFormat(
      'dd MMMM yyyy',
    ).format((data['tanggalPengajuan'] as Timestamp).toDate());

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(20),
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header - Judul Surat
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    'SURAT PENGANTAR RT/RW',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Kelurahan Sukorame',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Divider(),
            pw.SizedBox(height: 16),

            // Kalimat Pembuka
            pw.Text(
              'Yang bertanda tangan di bawah ini, penduduk Kelurahan Sukorame menerangkan bahwa:',
              style: pw.TextStyle(fontSize: 11, height: 1.5),
            ),
            pw.SizedBox(height: 16),

            // Data Pemohon
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildPdfField('Nama', nama),
                _buildPdfField('Jenis Kelamin', jenisKelamin),
                _buildPdfField('Tempat Lahir', tempatLahir),
                _buildPdfField('Tanggal Lahir', tglLahir),
                _buildPdfField('Pekerjaan', pekerjaan),
                _buildPdfField('Alamat', alamat),
                _buildPdfField('RT', rt),
                _buildPdfField('RW', rw),
                _buildPdfField('NIK', nik),
                _buildPdfField('Kategori Surat', kategori),
                _buildPdfField('Keperluan', keperluan),
              ],
            ),
            pw.SizedBox(height: 20),

            // Pernyataan
            pw.Text(
              'Demikian surat pengantar ini diberikan kepada yang bersangkutan untuk digunakan sesuai dengan keperluan.',
              style: pw.TextStyle(fontSize: 11, height: 1.5),
            ),
            pw.SizedBox(height: 32),

            // Tempat dan Tanggal
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Sukorame, $tglBuat',
                      style: pw.TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 32),

            // Area Tanda Tangan Pemohon
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text('Pemohon,', style: pw.TextStyle(fontSize: 11)),
                    pw.SizedBox(height: 50),
                    pw.Text(
                      '(___________________)',
                      style: pw.TextStyle(fontSize: 11),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(nama, style: pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  // Helper untuk membuat field di PDF
  pw.Widget _buildPdfField(String label, String value) {
    return pw.Padding(
      padding: pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 120,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Text(': '),
          pw.Expanded(child: pw.Text(value, style: pw.TextStyle(fontSize: 10))),
        ],
      ),
    );
  }

  Future<void> _uploadFotoTTD() async {
    try {
      final picker = ImagePicker();
      final source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Pilih Sumber Foto'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, ImageSource.camera),
              child: Text('Kamera'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, ImageSource.gallery),
              child: Text('Galeri'),
            ),
          ],
        ),
      );

      if (source == null) return;

      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 80,
      );
      if (pickedFile == null) return;

      setState(() => _isLoading = true);

      // Upload ke Supabase dengan struktur folder yang benar
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final fileName =
          '$uid/${widget.id}_ttd_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bytes = await pickedFile.readAsBytes();

      try {
        await _supabase.storage
            .from('dokumen-warga')
            .uploadBinary(
              fileName,
              bytes,
              fileOptions: FileOptions(upsert: true),
            );
      } catch (uploadError) {
        // Jika error terkait permission, tampilkan pesan detail
        if (uploadError.toString().contains('permission') ||
            uploadError.toString().contains('denied')) {
          throw Exception(
            'Permission denied: Pastikan Anda memiliki izin untuk upload file. Hubungi admin jika masalah berlanjut.',
          );
        }
        rethrow;
      }

      // Get public URL
      final url = _supabase.storage
          .from('dokumen-warga')
          .getPublicUrl(fileName);

      // Update Firestore - pastikan data struktur sesuai
      try {
        await _firestore.collection('surat').doc(widget.id).update({
          'urlSuratTtd': url,
          'status': 'diajukan',
          'tanggalDiajukan': Timestamp.now(),
        });
      } on FirebaseException catch (e) {
        // Handle permission errors dari Firestore rules
        if (e.code == 'permission-denied') {
          throw Exception(
            'Tidak bisa upload: Surat hanya bisa diajukan dari status draft. Silakan refresh halaman dan coba lagi.',
          );
        }
        rethrow;
      }

      if (mounted) {
        setState(() => _isLoading = false);
        UxHelper.showSuccess(context, 'Surat berhasil diajukan ke RT');
        _loadSurat();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        UxHelper.showError(context, 'Gagal upload: $e');
      }
    }
  }

  Future<void> _deleteSurat() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus Surat?'),
        content: Text(
          'Surat draft akan dihapus selamanya. Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      setState(() => _isLoading = true);

      // Hapus file TTD dari Supabase jika ada
      if (suratDoc != null) {
        final data = suratDoc!.data() as Map<String, dynamic>;
        if (data['urlSuratTtd'] != null) {
          try {
            final uid = FirebaseAuth.instance.currentUser!.uid;
            final files = await _supabase.storage
                .from('dokumen-warga')
                .list(path: uid);
            for (var file in files) {
              if (file.name.contains('${widget.id}_ttd_')) {
                await _supabase.storage.from('dokumen-warga').remove([
                  '$uid/${file.name}',
                ]);
              }
            }
          } catch (e) {
            print('Supabase cleanup error: $e');
          }
        }
      }

      // Hapus dokumen surat dari Firestore
      try {
        await _firestore.collection('surat').doc(widget.id).delete();
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          throw Exception(
            'Tidak bisa menghapus: Anda hanya bisa menghapus surat dengan status draft.',
          );
        }
        rethrow;
      }

      if (mounted) {
        UxHelper.showSuccess(context, 'Surat berhasil dihapus');
        Future.delayed(Duration(milliseconds: 800), () {
          if (mounted) context.go('/dashboard/warga');
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        UxHelper.showError(context, 'Gagal hapus surat: $e');
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
    final tglBuat = DateFormat(
      'dd MMMM yyyy, HH:mm',
    ).format((data['tanggalPengajuan'] as Timestamp).toDate());

    return Scaffold(
      appBar: AppBar(
        title: Text('Detail Surat'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
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
                      color: isAjukan
                          ? Colors.blue.shade50
                          : Colors.orange.shade50,
                      border: Border.all(
                        color: isAjukan
                            ? Colors.blue.shade700
                            : Colors.orange.shade700,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isAjukan ? Icons.check_circle : Icons.pending,
                          color: isAjukan
                              ? Colors.blue.shade700
                              : Colors.orange.shade700,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isAjukan ? 'Sudah Diajukan' : 'Belum Diajukan',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isAjukan
                                      ? Colors.blue.shade700
                                      : Colors.orange.shade700,
                                ),
                              ),
                              Text(
                                isAjukan
                                    ? 'Menunggu persetujuan RT'
                                    : 'Selesaikan upload TTD untuk ajukan',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),

                  // === DETAIL SURAT ===
                  Text(
                    'Detail Surat',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
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
                  Text(
                    'Data Pemohon',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
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
                    Text(
                      'Foto KK:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        data['dataPemohon']['urlFotoKk']!,
                        height: 120,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                  if (data['dataPemohon']['urlFotoKtp'] != null) ...[
                    SizedBox(height: 16),
                    Text(
                      'Foto KTP:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        data['dataPemohon']['urlFotoKtp']!,
                        height: 120,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                  SizedBox(height: 24),
                  Divider(),
                  SizedBox(height: 16),

                  // === ACTION BUTTONS ===
                  Text(
                    'Langkah Selanjutnya',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                  SizedBox(height: 16),

                  if (status == 'draft') ...[
                    // Untuk draft, tampilkan Download, Upload, Edit, Delete
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: Icon(Icons.download),
                      label: Text(
                        'Download Surat PDF',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: _generatePDF,
                    ),
                    SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.green.shade700,
                      ),
                      icon: Icon(Icons.upload_file),
                      label: Text(
                        'Upload Foto Surat TTD & Ajukan',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: _uploadFotoTTD,
                    ),
                    SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.orange.shade600,
                      ),
                      icon: Icon(Icons.edit),
                      label: Text(
                        'Edit Surat',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () {
                        // PERBAIKAN: Implementasi edit surat
                        context.push('/buat-surat?id=${widget.id}&mode=edit');
                      },
                    ),
                    SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.red.shade600,
                      ),
                      icon: Icon(Icons.delete),
                      label: Text(
                        'Hapus Surat',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: _deleteSurat,
                    ),
                  ] else if (status == 'diajukan') ...[
                    // Untuk sudah diajukan
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
                          Text(
                            '✓ Surat sudah diajukan',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Menunggu persetujuan dari RT. Anda akan menerima notifikasi ketika surat telah disetujui atau ditolak.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 12),
                  ] else ...[
                    // Untuk status yang sudah di-acc atau ditolak
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        border: Border.all(color: Colors.blue.shade700),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ℹ️ Surat sedang diproses',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Surat Anda sedang diproses oleh RT/RW. Anda akan menerima pemberitahuan ketika surat telah disetujui atau ditolak.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 12),
                  ],

                  // Tampilkan approval controls untuk RT/RW saja (bukan kelurahan)
                  if (_myRole != null &&
                      (_myRole == 'rt' ||
                          _myRole == 'rw' ||
                          _myRole == 'rt_rw'))
                    if ((_myRole == 'rt' && status == 'diajukan') ||
                        (_myRole == 'rw' && status == 'acc_rt') ||
                        (_myRole == 'rt_rw' &&
                            (status == 'diajukan' || status == 'acc_rt'))) ...[
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: () async {
                                String alasan = '';
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text('Tolak Surat'),
                                    content: TextField(
                                      onChanged: (v) => alasan = v,
                                      decoration: InputDecoration(
                                        labelText: 'Alasan penolakan',
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: Text('Batal'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: Text('Tolak'),
                                      ),
                                    ],
                                  ),
                                );
                                if (ok != true) return;
                                try {
                                  await _firestore
                                      .collection('surat')
                                      .doc(widget.id)
                                      .update({
                                        'status': 'ditolak',
                                        'alasanTolak': alasan,
                                        'ditolakOleh': FirebaseAuth
                                            .instance
                                            .currentUser!
                                            .uid,
                                        'tanggalDitolak': Timestamp.now(),
                                      });
                                  if (mounted) {
                                    UxHelper.showSuccess(
                                      context,
                                      'Surat ditolak',
                                    );
                                  }
                                  await _loadSurat();
                                  Future.delayed(
                                    Duration(milliseconds: 600),
                                    () {
                                      if (mounted) context.pop();
                                    },
                                  );
                                } catch (e) {
                                  if (mounted) {
                                    print('[DEBUG] Reject error - $e');
                                    print(
                                      '[DEBUG] User role: $_myRole, Surat ID: ${widget.id}',
                                    );
                                    UxHelper.showError(
                                      context,
                                      'Gagal menolak surat: $e',
                                    );
                                  }
                                }
                              },
                              child: Text(
                                'Tolak',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 14),
                                backgroundColor: Colors.green.shade700,
                              ),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text('Konfirmasi Terima'),
                                    content: Text('Terima surat ini?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: Text('Batal'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: Text('Terima'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm != true) return;
                                try {
                                  final newStatus = _myRole == 'rw'
                                      ? 'acc_rw'
                                      : _myRole == 'kelurahan'
                                      ? 'acc_kelurahan'
                                      : 'acc_rt';
                                  print(
                                    '[DEBUG] Approval - Role: $_myRole, Current Status: $status, New Status: $newStatus',
                                  );
                                  await _firestore
                                      .collection('surat')
                                      .doc(widget.id)
                                      .update({
                                        'status': newStatus,
                                        'approvedBy': FirebaseAuth
                                            .instance
                                            .currentUser!
                                            .uid,
                                        'tanggalAcc': Timestamp.now(),
                                      });
                                  if (mounted) {
                                    UxHelper.showSuccess(
                                      context,
                                      'Surat diterima',
                                    );
                                  }
                                  await _loadSurat();
                                  Future.delayed(
                                    Duration(milliseconds: 600),
                                    () {
                                      if (mounted) context.pop();
                                    },
                                  );
                                } catch (e) {
                                  if (mounted) {
                                    print('[DEBUG] Approval error - $e');
                                    print(
                                      '[DEBUG] User role: $_myRole, Surat ID: ${widget.id}',
                                    );
                                    UxHelper.showError(
                                      context,
                                      'Gagal menerima surat: $e',
                                    );
                                  }
                                }
                              },
                              child: Text('Terima'),
                            ),
                          ),
                        ],
                      ),
                    ],

                  if (data['urlSuratTtd'] != null) ...[
                    SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: Icon(Icons.visibility),
                      label: Text(
                        'Lihat Foto Surat TTD',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text('Foto Surat TTD'),
                            content: SizedBox(
                              width: double.maxFinite,
                              child: Image.network(data['urlSuratTtd']),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text('Tutup'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],

                  SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}
