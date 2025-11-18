import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

class BiodataScreen extends StatefulWidget {
  @override
  _BiodataScreenState createState() => _BiodataScreenState();
}

class _BiodataScreenState extends State<BiodataScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = false;
  
  // Controllers untuk editing
  late TextEditingController _namaCtrl, _nikCtrl, _alamatCtrl, _rtCtrl, _rwCtrl, _kecamatanCtrl, _kotaCtrl, _provinsiCtrl, _tempatLahirCtrl, _pekerjaanCtrl, _noHpCtrl;
  
  // Autocomplete suggestions
  final List<String> _pekerjaanList = ['PNS', 'Wiraswasta', 'Pelajar', 'Mahasiswa', 'Pensiunan', 'Lainnya'];
  final List<String> _statusDiKeluargaList = ['Kepala Keluarga', 'Istri', 'Suami', 'Anak', 'Menantu', 'Cucu', 'Orang Tua', 'Mertua', 'Family Lain', 'Lainnya'];
  final List<String> _statusPerkawinanList = ['Belum Kawin', 'Kawin', 'Cerai Hidup', 'Cerai Mati'];
  final List<String> _agamaList = ['Islam', 'Kristen Protestan', 'Kristen Katolik', 'Hindu', 'Buddha', 'Konghucu'];

  // Form values
  String? _selectedAgama, _selectedJenisKelamin, _selectedStatusDiKeluarga, _selectedStatusPerkawinan;
  DateTime? _selectedTanggalLahir;
  String? _urlFotoKk, _urlFotoKtp;

  @override
  void initState() {
    super.initState();
    _namaCtrl = TextEditingController();
    _nikCtrl = TextEditingController();
    _alamatCtrl = TextEditingController();
    _rtCtrl = TextEditingController();
    _rwCtrl = TextEditingController();
    _kecamatanCtrl = TextEditingController();
    _kotaCtrl = TextEditingController();
    _provinsiCtrl = TextEditingController();
    _tempatLahirCtrl = TextEditingController();
    _pekerjaanCtrl = TextEditingController();
    _noHpCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    _nikCtrl.dispose();
    _alamatCtrl.dispose();
    _rtCtrl.dispose();
    _rwCtrl.dispose();
    _kecamatanCtrl.dispose();
    _kotaCtrl.dispose();
    _provinsiCtrl.dispose();
    _tempatLahirCtrl.dispose();
    _pekerjaanCtrl.dispose();
    _noHpCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedTanggalLahir ?? DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedTanggalLahir = picked);
    }
  }

  Future<void> _uploadFoto(String type) async {
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

      // Upload to Supabase with unique filename
      final fileName = '${FirebaseAuth.instance.currentUser!.uid}_${type}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bytes = await pickedFile.readAsBytes();
      
      await _supabase.storage
          .from('dokumen-warga')
          .uploadBinary(fileName, bytes, fileOptions: FileOptions(upsert: true));
      
      // Get public URL
      final url = _supabase.storage.from('dokumen-warga').getPublicUrl(fileName);
      
      setState(() {
        if (type == 'kk') {
          _urlFotoKk = url;
        } else {
          _urlFotoKtp = url;
        }
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✓ Foto $type berhasil diupload'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Gagal upload foto: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _saveBiodata() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Validasi foto wajib
    if (_urlFotoKk == null || _urlFotoKtp == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Foto KK dan KTP harus diupload'), backgroundColor: Colors.orange),
      );
      return;
    }
    
    // Validasi dropdown
    if (_selectedAgama == null || _selectedJenisKelamin == null || _selectedStatusDiKeluarga == null || _selectedStatusPerkawinan == null || _selectedTanggalLahir == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Semua field harus diisi'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = UserModel(
        uid: FirebaseAuth.instance.currentUser!.uid,
        nama: _namaCtrl.text.trim(),
        nik: _nikCtrl.text.trim(),
        alamat: _alamatCtrl.text.trim(),
        rt: _rtCtrl.text.trim(),
        rw: _rwCtrl.text.trim(),
        kelurahan: 'Sukorame',
        kecamatan: _kecamatanCtrl.text.trim(),
        kota: _kotaCtrl.text.trim(),
        provinsi: _provinsiCtrl.text.trim(),
        agama: _selectedAgama!,
        jenisKelamin: _selectedJenisKelamin!,
        tanggalLahir: DateFormat('yyyy-MM-dd').format(_selectedTanggalLahir!),
        tempatLahir: _tempatLahirCtrl.text.trim(),
        pekerjaan: _pekerjaanCtrl.text.trim(),
        statusDiKeluarga: _selectedStatusDiKeluarga!,
        statusPerkawinan: _selectedStatusPerkawinan!,
        kewarganegaraan: 'NKRI',
        role: 'warga',
        createdAt: DateTime.now().toString(),
        email: FirebaseAuth.instance.currentUser!.email!,
        noHp: _noHpCtrl.text.trim(),
        urlFotoKk: _urlFotoKk,
        urlFotoKtp: _urlFotoKtp,
      );

      await _firestore.collection('users').doc(user.uid).set(user.toMap());
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✓ Biodata berhasil disimpan'), backgroundColor: Colors.green),
        );
        context.go('/dashboard/warga');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Gagal menyimpan: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Isi Biodata Lengkap'),
        leading: IconButton(icon: Icon(Icons.arrow_back), onPressed: () => context.go('/')),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // === IDENTITAS PRIBADI ===
                    Text('1. Identitas Pribadi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _namaCtrl,
                      decoration: InputDecoration(labelText: 'Nama Lengkap *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
                      validator: (val) => val!.isEmpty ? 'Nama wajib diisi' : null,
                    ),
                    SizedBox(height: 12),
                    TextFormField(
                      controller: _nikCtrl,
                      decoration: InputDecoration(labelText: 'NIK (16 digit) *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.badge)),
                      keyboardType: TextInputType.number,
                      validator: (val) {
                        if (val!.isEmpty) return 'NIK wajib diisi';
                        if (val.length != 16) return 'NIK harus tepat 16 digit';
                        return null;
                      },
                      maxLength: 16,
                    ),
                    SizedBox(height: 12),
                    TextFormField(
                      controller: _tempatLahirCtrl,
                      decoration: InputDecoration(labelText: 'Tempat Lahir *', border: OutlineInputBorder()),
                      validator: (val) => val!.isEmpty ? 'Tempat lahir wajib diisi' : null,
                    ),
                    SizedBox(height: 12),
                    GestureDetector(
                      onTap: _pickDate,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedTanggalLahir != null ? DateFormat('dd MMMM yyyy').format(_selectedTanggalLahir!) : 'Pilih Tanggal Lahir *',
                              style: TextStyle(fontSize: 16),
                            ),
                            Icon(Icons.calendar_today, color: Colors.green.shade700),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(labelText: 'Agama *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.church)),
                      value: _selectedAgama,
                      items: _agamaList.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (val) => setState(() => _selectedAgama = val),
                      validator: (val) => val == null ? 'Agama wajib dipilih' : null,
                    ),
                    SizedBox(height: 12),
                    Text('Jenis Kelamin *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: Text('Laki-laki'),
                            value: 'Laki-laki',
                            groupValue: _selectedJenisKelamin,
                            onChanged: (val) => setState(() => _selectedJenisKelamin = val),
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: Text('Perempuan'),
                            value: 'Perempuan',
                            groupValue: _selectedJenisKelamin,
                            onChanged: (val) => setState(() => _selectedJenisKelamin = val),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 24),
                    Divider(),
                    SizedBox(height: 16),

                    // === ALAMAT & DOMISILI ===
                    Text('2. Alamat & Domisili', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _alamatCtrl,
                      decoration: InputDecoration(labelText: 'Alamat Lengkap *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.home)),
                      maxLines: 2,
                      validator: (val) => val!.isEmpty ? 'Alamat wajib diisi' : null,
                    ),
                    SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: TextFormField(
                        controller: _rtCtrl,
                        decoration: InputDecoration(labelText: 'RT *', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                        validator: (val) => val!.isEmpty ? 'RT wajib' : null,
                      )),
                      SizedBox(width: 12),
                      Expanded(child: TextFormField(
                        controller: _rwCtrl,
                        decoration: InputDecoration(labelText: 'RW *', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                        validator: (val) => val!.isEmpty ? 'RW wajib' : null,
                      )),
                    ]),
                    SizedBox(height: 12),
                    TextFormField(
                      controller: _kecamatanCtrl,
                      decoration: InputDecoration(labelText: 'Kecamatan *', border: OutlineInputBorder()),
                      validator: (val) => val!.isEmpty ? 'Kecamatan wajib diisi' : null,
                    ),
                    SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: TextFormField(
                        controller: _kotaCtrl,
                        decoration: InputDecoration(labelText: 'Kota/Kabupaten *', border: OutlineInputBorder()),
                        validator: (val) => val!.isEmpty ? 'Kota wajib' : null,
                      )),
                      SizedBox(width: 12),
                      Expanded(child: TextFormField(
                        controller: _provinsiCtrl,
                        decoration: InputDecoration(labelText: 'Provinsi *', border: OutlineInputBorder()),
                        validator: (val) => val!.isEmpty ? 'Provinsi wajib' : null,
                      )),
                    ]),
                    SizedBox(height: 24),
                    Divider(),
                    SizedBox(height: 16),

                    // === PEKERJAAN & STATUS ===
                    Text('3. Pekerjaan & Status Keluarga', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                    SizedBox(height: 16),
                    Autocomplete<String>(
                      optionsBuilder: (TextEditingValue value) {
                        if (value.text.isEmpty) return [];
                        return _pekerjaanList.where((e) => e.toLowerCase().contains(value.text.toLowerCase()));
                      },
                      onSelected: (String selection) {
                        _pekerjaanCtrl.text = selection;
                      },
                      fieldViewBuilder: (context, ttec, tfn, onFieldSubmitted) {
                        _pekerjaanCtrl = ttec;
                        return TextFormField(
                          controller: ttec,
                          focusNode: tfn,
                          decoration: InputDecoration(labelText: 'Pekerjaan *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.work)),
                          validator: (val) => val!.isEmpty ? 'Pekerjaan wajib diisi' : null,
                        );
                      },
                    ),
                    SizedBox(height: 12),
                    Autocomplete<String>(
                      optionsBuilder: (TextEditingValue value) {
                        if (value.text.isEmpty) return [];
                        return _statusDiKeluargaList.where((e) => e.toLowerCase().contains(value.text.toLowerCase()));
                      },
                      onSelected: (String selection) {
                        setState(() => _selectedStatusDiKeluarga = selection);
                      },
                      fieldViewBuilder: (context, ttec, tfn, onFieldSubmitted) {
                        ttec.text = _selectedStatusDiKeluarga ?? '';
                        return TextFormField(
                          controller: ttec,
                          focusNode: tfn,
                          decoration: InputDecoration(labelText: 'Status di Keluarga *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.family_restroom)),
                          onChanged: (val) => _selectedStatusDiKeluarga = val,
                          validator: (val) => val!.isEmpty ? 'Status di keluarga wajib diisi' : null,
                        );
                      },
                    ),
                    SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(labelText: 'Status Perkawinan *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.favorite)),
                      value: _selectedStatusPerkawinan,
                      items: _statusPerkawinanList.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (val) => setState(() => _selectedStatusPerkawinan = val),
                      validator: (val) => val == null ? 'Status perkawinan wajib dipilih' : null,
                    ),
                    SizedBox(height: 12),
                    TextFormField(
                      controller: _noHpCtrl,
                      decoration: InputDecoration(labelText: 'No. HP (WhatsApp) *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone)),
                      keyboardType: TextInputType.phone,
                      validator: (val) => val!.isEmpty ? 'No. HP wajib diisi' : null,
                    ),
                    SizedBox(height: 24),
                    Divider(),
                    SizedBox(height: 16),

                    // === DOKUMEN ===
                    Text('4. Dokumen Pendukung', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                    SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _uploadFoto('kk'),
                          icon: Icon(Icons.image),
                          label: Text('Upload Foto KK'),
                          style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 12)),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _uploadFoto('ktp'),
                          icon: Icon(Icons.image),
                          label: Text('Upload Foto KTP'),
                          style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 12)),
                        ),
                      ),
                    ]),
                    if (_urlFotoKk != null) Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(4)),
                        child: Row(children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 8), Text('Foto KK berhasil diupload', style: TextStyle(color: Colors.green.shade700))]),
                      ),
                    ),
                    if (_urlFotoKtp != null) Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(4)),
                        child: Row(children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 8), Text('Foto KTP berhasil diupload', style: TextStyle(color: Colors.green.shade700))]),
                      ),
                    ),
                    SizedBox(height: 32),

                    // === TOMBOL SIMPAN ===
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 16)),
                      onPressed: _saveBiodata,
                      child: Text('Simpan Biodata & Lanjut', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                    SizedBox(height: 8),
                    Text('* Semua field harus diisi lengkap', style: TextStyle(fontSize: 12, color: Colors.orange, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
            ),
    );
  }
}