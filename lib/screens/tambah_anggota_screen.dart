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
        List<Map<String, dynamic>> anggota = List.from(
          doc['anggotaKeluarga'] ?? [],
        );

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
              Text(
                'Data Anggota',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Nama',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val!.isEmpty ? 'Wajib' : null,
                onChanged: (val) => nama = val,
              ),
              SizedBox(height: 12),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'NIK (16 digit)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge),
                  helperText: 'Masukkan 16 angka',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  // Hanya terima angka
                  FilteringTextInputFormatter.digitsOnly,
                ],
                maxLength: 16,
                validator: (val) {
                  if (val == null || val.isEmpty)
                    return 'NIK tidak boleh kosong';
                  if (val.length != 16) return 'NIK harus 16 digit';
                  if (!RegExp(r'^[0-9]+$').hasMatch(val))
                    return 'NIK hanya boleh berisi angka';
                  return null;
                },
                onChanged: (val) => nik = val,
              ),
              SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Hubungan',
                  border: OutlineInputBorder(),
                ),
                items: ['Istri', 'Anak', 'Orang Tua']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) => setState(() => hubungan = val!),
              ),
              SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _uploadFoto('kk'),
                      child: Text('Upload Foto KK'),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _uploadFoto('ktp'),
                      child: Text('Upload Foto KTP'),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _saveAnggota,
                child: Text('Simpan Anggota'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
