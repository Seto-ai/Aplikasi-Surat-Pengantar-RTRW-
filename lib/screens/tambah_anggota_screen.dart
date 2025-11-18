import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TambahAnggotaScreen extends StatefulWidget {
  @override
  _TambahAnggotaScreenState createState() => _TambahAnggotaScreenState();
}

class _TambahAnggotaScreenState extends State<TambahAnggotaScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  String nama = '', nik = '', hubungan = '', alamat = '', rt = '', rw = '', kelurahan = 'Sukorame', kecamatan = '', kota = '', provinsi = '', agama = '', jenisKelamin = '', tanggalLahir = '', tempatLahir = '', pekerjaan = '', statusDiKeluarga = '', statusPerkawinan = '', kewarganegaraan = 'NKRI', noHp = '';
  String? urlFotoKk, urlFotoKtp;

  Future<void> _uploadFoto(String type) async {
    final picker = ImagePicker();
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Pilih Sumber'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, ImageSource.camera), child: Text('Kamera')),
          TextButton(onPressed: () => Navigator.pop(context, ImageSource.gallery), child: Text('Galeri')),
        ],
      ),
    );
    if (source != null) {
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${type}.jpg';
        await _supabase.storage.from('dokumen-warga').upload(fileName, pickedFile as dynamic);
        final url = _supabase.storage.from('dokumen-warga').getPublicUrl(fileName);
        setState(() {
          if (type == 'kk') urlFotoKk = url; else urlFotoKtp = url;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Foto $type berhasil diupload!')));
      }
    }
  }

  Future<void> _saveAnggota() async {
    if (_formKey.currentState!.validate()) {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final doc = await _firestore.collection('users').doc(uid).get();
      List<Map<String, dynamic>> anggota = List.from(doc['anggotaKeluarga'] ?? []);
      anggota.add({
        'nama': nama, 'nik': nik, 'hubungan': hubungan, 'alamat': alamat, 'rt': rt, 'rw': rw, 'kelurahan': kelurahan, 'kecamatan': kecamatan, 'kota': kota, 'provinsi': provinsi, 'agama': agama, 'jenisKelamin': jenisKelamin, 'tanggalLahir': tanggalLahir, 'tempatLahir': tempatLahir, 'pekerjaan': pekerjaan, 'statusDiKeluarga': statusDiKeluarga, 'statusPerkawinan': statusPerkawinan, 'kewarganegaraan': kewarganegaraan, 'noHp': noHp, 'urlFotoKk': urlFotoKk, 'urlFotoKtp': urlFotoKtp,
      });
      await _firestore.collection('users').doc(uid).update({'anggotaKeluarga': anggota});
      context.go('/dashboard/warga');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Tambah Anggota Keluarga'), leading: IconButton(icon: Icon(Icons.arrow_back), onPressed: () => context.go('/dashboard/warga'))),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Data Anggota', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(height: 16),
              TextFormField(decoration: InputDecoration(labelText: 'Nama', border: OutlineInputBorder()), validator: (val) => val!.isEmpty ? 'Wajib' : null, onChanged: (val) => nama = val),
              SizedBox(height: 12),
              TextFormField(decoration: InputDecoration(labelText: 'NIK', border: OutlineInputBorder()), validator: (val) => val!.isEmpty ? 'Wajib' : null, onChanged: (val) => nik = val),
              SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: 'Hubungan', border: OutlineInputBorder()),
                items: ['Istri', 'Anak', 'Orang Tua'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (val) => setState(() => hubungan = val!),
              ),
              SizedBox(height: 24),
              Row(children: [
                Expanded(child: ElevatedButton(onPressed: () => _uploadFoto('kk'), child: Text('Upload Foto KK'))),
                SizedBox(width: 12),
                Expanded(child: ElevatedButton(onPressed: () => _uploadFoto('ktp'), child: Text('Upload Foto KTP'))),
              ]),
              SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 16)),
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