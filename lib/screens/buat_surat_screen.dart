import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../utils/ux_helper.dart';
import '../utils/validation_helper.dart';

class BuatSuratScreen extends StatefulWidget {
  final String? suratId; // ID surat untuk mode edit
  final String mode; // 'create' atau 'edit'

  const BuatSuratScreen({super.key, this.suratId, this.mode = 'create'});

  @override
  _BuatSuratScreenState createState() => _BuatSuratScreenState();
}

class _BuatSuratScreenState extends State<BuatSuratScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String kategori = 'Surat Keterangan Usaha';
  String keperluan = '';
  Map<String, dynamic>? dataPemohon;
  List<Map<String, dynamic>> anggotaKeluarga = [];
  Map<String, dynamic>? selectedPemohon;
  String searchQuery = '';

  Future<void> _loadBiodata() async {
    final uid = _auth.currentUser!.uid;
    final doc = await _firestore.collection('users').doc(uid).get();
    setState(() {
      dataPemohon = doc.data();
      anggotaKeluarga = List<Map<String, dynamic>>.from(
        doc['anggotaKeluarga'] ?? [],
      );
    });
  }

  List<Map<String, dynamic>> _getFilteredPemohon() {
    final list = [
      if (dataPemohon != null) {...dataPemohon!, 'isSelf': true},
      ...anggotaKeluarga.map((a) => {...a, 'isSelf': false}),
    ];
    if (searchQuery.isEmpty) return list;
    return list
        .where(
          (p) => (p['nama'] as String).toLowerCase().contains(
            searchQuery.toLowerCase(),
          ),
        )
        .toList();
  }

  void _showPemohonBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final filtered = _getFilteredPemohon();
          return SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Pilih Pemohon',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Divider(height: 0),
                Padding(
                  padding: EdgeInsets.all(16),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Cari nama',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (val) => setModalState(() => searchQuery = val),
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(child: Text('Tidak ada pemohon'))
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => SizedBox(height: 8),
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          itemBuilder: (context, index) {
                            final pemohon = filtered[index];
                            final isSelf = pemohon['isSelf'] == true;
                            final nama = pemohon['nama'] ?? 'Unknown';
                            final nik = pemohon['nik'] ?? '';

                            return GestureDetector(
                              onTap: () {
                                setState(() => selectedPemohon = pemohon);
                                Navigator.pop(context);
                              },
                              child: Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: selectedPemohon == pemohon
                                        ? Colors.green.shade700
                                        : Colors.grey.shade300,
                                    width: selectedPemohon == pemohon ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  color: selectedPemohon == pemohon
                                      ? Colors.green.shade50
                                      : Colors.white,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isSelf
                                                ? 'Pemohon 1'
                                                : 'Anggota Keluarga',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                          SizedBox(height: 6),
                                          Text(
                                            nama,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'NIK: $nik',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right,
                                      color: Colors.green.shade700,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: EdgeInsets.all(16),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 48),
                    ),
                    icon: Icon(Icons.person_add),
                    label: Text('Tambah Anggota'),
                    onPressed: () {
                      Navigator.pop(context);
                      context.push('/tambah-anggota');
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _generatePDF() async {
    if (selectedPemohon == null) {
      UxHelper.showError(context, 'Pilih pemohon terlebih dahulu');
      return;
    }

    final pdf = pw.Document();

    final nama = selectedPemohon!['nama'] ?? 'N/A';
    final nik = selectedPemohon!['nik'] ?? 'N/A';
    final tempatLahir = selectedPemohon!['tempatLahir'] ?? 'N/A';
    final tglLahir = selectedPemohon!['tanggalLahir'] ?? 'N/A';
    final jenisKelamin = selectedPemohon!['jenisKelamin'] ?? 'N/A';
    final pekerjaan = selectedPemohon!['pekerjaan'] ?? 'N/A';
    final alamat = selectedPemohon!['alamat'] ?? 'N/A';
    final rt = selectedPemohon!['rt'] ?? 'N/A';
    final rw = selectedPemohon!['rw'] ?? 'N/A';

    final tglPengajuan = DateFormat('dd MMMM yyyy').format(DateTime.now());

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
                      'Sukorame, $tglPengajuan',
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

  Future<void> _buatSurat() async {
    if (selectedPemohon == null || keperluan.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lengkapi field')));
      return;
    }

    try {
      // Bersihkan selectedPemohon dari field internal seperti 'isSelf'
      final cleanPemohon = Map<String, dynamic>.from(selectedPemohon ?? {});
      cleanPemohon.remove('isSelf');

      final suratRef = await _firestore.collection('surat').add({
        'dataPemohon': cleanPemohon,
        'kategori': kategori,
        'keperluan': keperluan,
        'pembuatId': _auth.currentUser!.uid,
        'namaPemohon': cleanPemohon['nama'] ?? 'Tanpa Nama',
        'status': 'draft',
        'urlSuratTtd': null,
        'tanggalPengajuan': Timestamp.now(),
      });

      if (mounted) {
        UxHelper.showSuccess(context, 'Surat dibuat');
        Future.delayed(Duration(milliseconds: 800), () {
          if (mounted) context.push('/detail-surat/${suratRef.id}');
        });
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = ValidationHelper.getErrorMessage(e as Exception);
        UxHelper.showError(context, errorMsg);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadBiodata();
    // Jika mode edit, load data surat existing
    if (widget.mode == 'edit' && widget.suratId != null) {
      _loadSuratForEdit(widget.suratId!);
    }
  }

  Future<void> _loadSuratForEdit(String suratId) async {
    try {
      final doc = await _firestore.collection('surat').doc(suratId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          kategori = data['kategori'] ?? 'Surat Keterangan Usaha';
          keperluan = data['keperluan'] ?? '';
          // TODO: Load data pemohon jika perlu
        });
      }
    } catch (e) {
      print('Error loading surat for edit: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.mode == 'edit' ? 'Edit Surat' : 'Buat Surat'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard/warga'),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '1. Detail Surat',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: kategori,
              decoration: InputDecoration(
                labelText: 'Kategori *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              items: [
                'Surat Keterangan Usaha',
                'Surat Pengantar Nikah',
                'Surat Keterangan Tidak Mampu',
                'Surat Domisili',
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (val) => setState(() => kategori = val!),
            ),
            SizedBox(height: 12),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Keperluan *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.edit_note),
              ),
              maxLines: 3,
              onChanged: (val) => setState(() => keperluan = val),
            ),
            SizedBox(height: 24),
            Divider(),
            SizedBox(height: 16),
            Text(
              '2. Pilih Pemohon',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
            SizedBox(height: 16),
            GestureDetector(
              onTap: _showPemohonBottomSheet,
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: selectedPemohon != null
                        ? Colors.green.shade700
                        : Colors.grey.shade300,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  color: selectedPemohon != null
                      ? Colors.green.shade50
                      : Colors.white,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedPemohon != null
                                ? (selectedPemohon!['isSelf'] == true
                                      ? 'Pemohon 1'
                                      : 'Anggota Keluarga')
                                : 'Pilih Pemohon',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          if (selectedPemohon != null) ...[
                            SizedBox(height: 8),
                            Text(
                              selectedPemohon!['nama'] ?? 'N/A',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'NIK: ${selectedPemohon!['nik'] ?? 'N/A'}',
                              style: TextStyle(fontSize: 12),
                            ),
                          ] else ...[
                            SizedBox(height: 4),
                            Text(
                              '${1 + anggotaKeluarga.length} pilihan tersedia',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: selectedPemohon != null
                          ? Colors.green.shade700
                          : Colors.grey,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),
            Divider(),
            SizedBox(height: 16),
            Text(
              '3. Pratinjau & Lanjut',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 14),
              ),
              icon: Icon(Icons.visibility),
              label: Text('Pratinjau PDF'),
              onPressed: _generatePDF,
            ),
            SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Colors.green.shade700,
              ),
              icon: Icon(Icons.check_circle),
              label: Text('Buat & Lanjut'),
              onPressed: _buatSurat,
            ),
            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
