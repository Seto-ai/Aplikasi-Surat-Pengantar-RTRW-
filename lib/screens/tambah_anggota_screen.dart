import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

class TambahAnggotaScreen extends StatefulWidget {
  const TambahAnggotaScreen({super.key});

  @override
  _TambahAnggotaScreenState createState() => _TambahAnggotaScreenState();
}

class _TambahAnggotaScreenState extends State<TambahAnggotaScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  String nama = '',
      nik = '',
      hubungan = '',
      alamat = '',
      rt = '',
      rw = '',
      kelurahan = 'Sukorame',
      kecamatan = '',
      kota = '',
      provinsi = '',
      agama = '',
      jenisKelamin = '',
      tanggalLahir = '',
      tempatLahir = '',
      pekerjaan = '',
      statusDiKeluarga = '',
      statusPerkawinan = '',
      kewarganegaraan = 'NKRI',
      noHp = '';
  String? urlFotoKk, urlFotoKtp;

  Future<void> _uploadFoto(String type) async {
    final picker = ImagePicker();
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Pilih Sumber'),
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
    if (source != null) {
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null) {
        try {
          final uid = FirebaseAuth.instance.currentUser!.uid;
          final fileName =
              '$uid/${DateTime.now().millisecondsSinceEpoch}_$type.jpg';
          final file = File(pickedFile.path);

          await _supabase.storage.from('dokumen-warga').upload(fileName, file);
          final url = _supabase.storage
              .from('dokumen-warga')
              .getPublicUrl(fileName);

          setState(() {
            if (type == 'kk') {
              urlFotoKk = url;
            } else {
              urlFotoKtp = url;
            }
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Foto $type berhasil diupload!'),
              backgroundColor: Colors.green,
            ),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal upload foto: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _saveAnggota() async {
    if (_formKey.currentState!.validate()) {
      if (hubungan.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hubungan harus dipilih'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      try {
        final uid = FirebaseAuth.instance.currentUser!.uid;
        final doc = await _firestore.collection('users').doc(uid).get();

        // Handle jika field anggotaKeluarga tidak ada
        List<Map<String, dynamic>> anggota = [];
        if (doc.exists && doc.data()?.containsKey('anggotaKeluarga') == true) {
          anggota = List.from(doc['anggotaKeluarga'] ?? []);
        }

        // Cek duplikasi NIK
        final nikExists = anggota.any((a) => a['nik'] == nik);
        if (nikExists) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('NIK sudah terdaftar sebagai anggota keluarga'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        anggota.add({
          'nama': nama,
          'nik': nik,
          'hubungan': hubungan,
          'alamat': alamat,
          'rt': rt,
          'rw': rw,
          'kelurahan': kelurahan,
          'kecamatan': kecamatan,
          'kota': kota,
          'provinsi': provinsi,
          'agama': agama,
          'jenisKelamin': jenisKelamin,
          'tanggalLahir': tanggalLahir,
          'tempatLahir': tempatLahir,
          'pekerjaan': pekerjaan,
          'statusDiKeluarga': statusDiKeluarga,
          'statusPerkawinan': statusPerkawinan,
          'kewarganegaraan': kewarganegaraan,
          'noHp': noHp,
          'urlFotoKk': urlFotoKk,
          'urlFotoKtp': urlFotoKtp,
        });

        await _firestore.collection('users').doc(uid).update({
          'anggotaKeluarga': anggota,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Anggota keluarga berhasil ditambahkan'),
            backgroundColor: Colors.green,
          ),
        );

        if (mounted) {
          Future.delayed(Duration(milliseconds: 1000), () {
            if (mounted) context.go('/dashboard/warga');
          });
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tambah Anggota Keluarga'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard/warga'),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ===== DATA ANGGOTA SECTION =====
              Text(
                'Data Anggota',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),

              // Nama
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Nama',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val!.isEmpty ? 'Wajib' : null,
                onChanged: (val) => nama = val,
              ),
              SizedBox(height: 12),

              // NIK
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'NIK (16 digit)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge),
                  helperText: 'Masukkan 16 angka',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 16,
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return 'NIK tidak boleh kosong';
                  }
                  if (val.length != 16) return 'NIK harus 16 digit';
                  if (!RegExp(r'^[0-9]+$').hasMatch(val)) {
                    return 'NIK hanya boleh berisi angka';
                  }
                  return null;
                },
                onChanged: (val) => nik = val,
              ),
              SizedBox(height: 12),

              // Hubungan
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Hubungan',
                  border: OutlineInputBorder(),
                ),
                initialValue: hubungan.isEmpty ? null : hubungan,
                items:
                    [
                          'Istri',
                          'Suami',
                          'Anak',
                          'Orang Tua',
                          'Saudara',
                          'Lainnya',
                        ]
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                validator: (val) => val == null || val.isEmpty
                    ? 'Hubungan wajib dipilih'
                    : null,
                onChanged: (val) => setState(() => hubungan = val ?? ''),
              ),
              SizedBox(height: 12),

              // Tempat Lahir
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Tempat Lahir',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val!.isEmpty ? 'Wajib' : null,
                onChanged: (val) => tempatLahir = val,
              ),
              SizedBox(height: 12),

              // Tanggal Lahir
              GestureDetector(
                onTap: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(1950),
                    lastDate: DateTime.now(),
                  );
                  if (pickedDate != null) {
                    setState(() {
                      tanggalLahir =
                          '${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}';
                    });
                  }
                },
                child: TextFormField(
                  enabled: false,
                  decoration: InputDecoration(
                    labelText: 'Tanggal Lahir',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  controller: TextEditingController(
                    text: tanggalLahir.isEmpty ? '' : tanggalLahir,
                  ),
                  validator: (val) => tanggalLahir.isEmpty ? 'Wajib' : null,
                ),
              ),
              SizedBox(height: 12),

              // Jenis Kelamin
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Jenis Kelamin',
                  border: OutlineInputBorder(),
                ),
                initialValue: jenisKelamin.isEmpty ? null : jenisKelamin,
                items: ['Laki-laki', 'Perempuan']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Wajib dipilih' : null,
                onChanged: (val) => setState(() => jenisKelamin = val ?? ''),
              ),
              SizedBox(height: 12),

              // Agama
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Agama',
                  border: OutlineInputBorder(),
                ),
                initialValue: agama.isEmpty ? null : agama,
                items:
                    [
                          'Islam',
                          'Kristen',
                          'Katolik',
                          'Hindu',
                          'Buddha',
                          'Konghucu',
                        ]
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Wajib dipilih' : null,
                onChanged: (val) => setState(() => agama = val ?? ''),
              ),
              SizedBox(height: 12),

              // Status Perkawinan
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Status Perkawinan',
                  border: OutlineInputBorder(),
                ),
                initialValue: statusPerkawinan.isEmpty ? null : statusPerkawinan,
                items: ['Belum Kawin', 'Kawin', 'Cerai Hidup', 'Cerai Mati']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Wajib dipilih' : null,
                onChanged: (val) =>
                    setState(() => statusPerkawinan = val ?? ''),
              ),
              SizedBox(height: 12),

              // Pekerjaan
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Pekerjaan',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val!.isEmpty ? 'Wajib' : null,
                onChanged: (val) => pekerjaan = val,
              ),
              SizedBox(height: 12),

              // Status di Keluarga
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Status di Keluarga',
                  border: OutlineInputBorder(),
                ),
                initialValue: statusDiKeluarga.isEmpty ? null : statusDiKeluarga,
                items:
                    ['Kepala Keluarga', 'Istri', 'Anak', 'Orang Tua', 'Lainnya']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Wajib dipilih' : null,
                onChanged: (val) =>
                    setState(() => statusDiKeluarga = val ?? ''),
              ),
              SizedBox(height: 12),

              // Kewarganegaraan
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Kewarganegaraan',
                  border: OutlineInputBorder(),
                ),
                initialValue: kewarganegaraan.isEmpty ? 'NKRI' : kewarganegaraan,
                items: ['NKRI', 'Asing']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) =>
                    setState(() => kewarganegaraan = val ?? 'NKRI'),
              ),
              SizedBox(height: 12),

              // No HP
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'No. HP',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
                onChanged: (val) => noHp = val,
              ),
              SizedBox(height: 16),

              // ===== ALAMAT SECTION =====
              Text(
                'Alamat',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),

              // Alamat
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Alamat',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                validator: (val) => val!.isEmpty ? 'Wajib' : null,
                onChanged: (val) => alamat = val,
              ),
              SizedBox(height: 12),

              // RT
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'RT',
                  border: OutlineInputBorder(),
                ),
                initialValue: rt.isEmpty ? null : rt,
                items: List.generate(
                  37,
                  (index) => DropdownMenuItem(
                    value: '${index + 1}',
                    child: Text('${index + 1}'),
                  ),
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? 'RT wajib dipilih' : null,
                onChanged: (val) => setState(() => rt = val ?? ''),
              ),
              SizedBox(height: 12),

              // RW
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'RW',
                  border: OutlineInputBorder(),
                ),
                initialValue: rw.isEmpty ? null : rw,
                items: List.generate(
                  10,
                  (index) => DropdownMenuItem(
                    value: '${index + 1}',
                    child: Text('${index + 1}'),
                  ),
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? 'RW wajib dipilih' : null,
                onChanged: (val) => setState(() => rw = val ?? ''),
              ),
              SizedBox(height: 12),

              // Kelurahan
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Kelurahan',
                  border: OutlineInputBorder(),
                ),
                initialValue: kelurahan,
                onChanged: (val) => kelurahan = val,
              ),
              SizedBox(height: 12),

              // Kecamatan
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Kecamatan',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val!.isEmpty ? 'Wajib' : null,
                onChanged: (val) => kecamatan = val,
              ),
              SizedBox(height: 12),

              // Kota
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Kota/Kabupaten',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val!.isEmpty ? 'Wajib' : null,
                onChanged: (val) => kota = val,
              ),
              SizedBox(height: 12),

              // Provinsi
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Provinsi',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val!.isEmpty ? 'Wajib' : null,
                onChanged: (val) => provinsi = val,
              ),
              SizedBox(height: 24),

              // ===== DOKUMEN SECTION =====
              Text(
                'Dokumen',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _uploadFoto('kk'),
                      icon: Icon(Icons.image),
                      label: Text('Foto KK'),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _uploadFoto('ktp'),
                      icon: Icon(Icons.image),
                      label: Text('Foto KTP'),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),

              if (urlFotoKk != null) ...[
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    border: Border.all(color: Colors.green.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 8),
                      Text(
                        'Foto KK sudah diupload',
                        style: TextStyle(color: Colors.green.shade700),
                      ),
                    ],
                  ),
                ),
              ],

              if (urlFotoKtp != null) ...[
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    border: Border.all(color: Colors.green.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 8),
                      Text(
                        'Foto KTP sudah diupload',
                        style: TextStyle(color: Colors.green.shade700),
                      ),
                    ],
                  ),
                ),
              ],

              SizedBox(height: 32),

              // Simpan Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Color(0xFF27AE60),
                ),
                onPressed: _saveAnggota,
                child: Text(
                  'Simpan Anggota',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),

              SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
