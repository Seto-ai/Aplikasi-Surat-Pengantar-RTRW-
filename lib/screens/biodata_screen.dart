import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/ux_helper.dart';
import '../utils/validation_helper.dart';

class BiodataScreen extends StatefulWidget {
  final bool isEditMode;

  const BiodataScreen({super.key, this.isEditMode = false});

  @override
  _BiodataScreenState createState() => _BiodataScreenState();
}

class _BiodataScreenState extends State<BiodataScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;

  // Controllers untuk editing
  late TextEditingController _namaCtrl,
      _nikCtrl,
      _alamatCtrl,
      _kecamatanCtrl,
      _kotaCtrl,
      _provinsiCtrl,
      _tempatLahirCtrl,
      _pekerjaanCtrl,
      _noHpCtrl;

  // Autocomplete suggestions
  final List<String> _pekerjaanList = [
    'PNS',
    'Wiraswasta',
    'Pelajar',
    'Mahasiswa',
    'Pensiunan',
    'Lainnya',
  ];
  final List<String> _statusDiKeluargaList = [
    'Kepala Keluarga',
    'Istri',
    'Suami',
    'Anak',
    'Menantu',
    'Cucu',
    'Orang Tua',
    'Mertua',
    'Family Lain',
    'Lainnya',
  ];
  final List<String> _statusPerkawinanList = [
    'Belum Kawin',
    'Kawin',
    'Cerai Hidup',
    'Cerai Mati',
  ];
  final List<String> _agamaList = [
    'Islam',
    'Kristen Protestan',
    'Kristen Katolik',
    'Hindu',
    'Buddha',
    'Konghucu',
  ];

  // Form values
  String? _selectedAgama,
      _selectedJenisKelamin,
      _selectedStatusDiKeluarga,
      _selectedStatusPerkawinan;
  String? _selectedRt, _selectedRw;
  DateTime? _selectedTanggalLahir;
  String? _urlFotoKk, _urlFotoKtp;

  // Master data for dropdowns
  List<String> _rwList = [];
  List<String> _rtList = [];

  @override
  void initState() {
    super.initState();
    _namaCtrl = TextEditingController();
    _nikCtrl = TextEditingController();
    _alamatCtrl = TextEditingController();
    _kecamatanCtrl = TextEditingController();
    _kotaCtrl = TextEditingController();
    _provinsiCtrl = TextEditingController();
    _tempatLahirCtrl = TextEditingController();
    _pekerjaanCtrl = TextEditingController();
    _noHpCtrl = TextEditingController();

    // Load RT/RW master data
    _loadRtRwData();

    // Load existing data if in edit mode
    if (widget.isEditMode) {
      _loadExistingBiodata();
    }
  }

  Future<void> _loadRtRwData() async {
    try {
      print('[DEBUG] Loading RT/RW data...');

      // Load RW list
      final rwSnapshot = await _firestore.collection('rw').get();
      print(
        '[DEBUG] RW snapshot received: ${rwSnapshot.docs.length} documents',
      );

      var rwList = rwSnapshot.docs
          .map((doc) {
            final nomorRw = doc['nomor_rw']?.toString() ?? '';
            print('[DEBUG] RW doc - nomor_rw: $nomorRw, data: ${doc.data()}');
            return nomorRw;
          })
          .where((rw) => rw.isNotEmpty)
          .toList();

      print('[DEBUG] RW list before dedup and sort: $rwList');

      // Sort with safe parsing
      rwList.sort((a, b) {
        final aNum = int.tryParse(a) ?? 999;
        final bNum = int.tryParse(b) ?? 999;
        return aNum.compareTo(bNum);
      });

      // Remove duplicates after sorting
      rwList = rwList.toSet().toList();

      print('[DEBUG] RW list after dedup and sort: $rwList');

      // Load RT list
      final rtSnapshot = await _firestore.collection('rt').get();
      print(
        '[DEBUG] RT snapshot received: ${rtSnapshot.docs.length} documents',
      );

      var rtList = rtSnapshot.docs
          .map((doc) {
            final nomorRt = doc['nomor_rt']?.toString() ?? '';
            print('[DEBUG] RT doc - nomor_rt: $nomorRt, data: ${doc.data()}');
            return nomorRt;
          })
          .where((rt) => rt.isNotEmpty)
          .toList();

      print('[DEBUG] RT list before dedup and sort: $rtList');

      // Sort with safe parsing
      rtList.sort((a, b) {
        final aNum = int.tryParse(a) ?? 999;
        final bNum = int.tryParse(b) ?? 999;
        return aNum.compareTo(bNum);
      });

      // Remove duplicates after sorting
      rtList = rtList.toSet().toList();

      print('[DEBUG] RT list after dedup and sort: $rtList');

      setState(() {
        _rwList = rwList;
        _rtList = rtList;
      });

      print('[DEBUG] RT/RW data loaded successfully');
    } catch (e, stackTrace) {
      print('Error loading RT/RW data: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading RT/RW: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadExistingBiodata() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return;

      final data = doc.data() as Map<String, dynamic>;
      setState(() {
        _namaCtrl.text = data['nama'] ?? '';
        _nikCtrl.text = data['nik'] ?? '';
        _alamatCtrl.text = data['alamat'] ?? '';
        _selectedRt = data['rt']?.toString();
        _selectedRw = data['rw']?.toString();
        _kecamatanCtrl.text = data['kecamatan'] ?? '';
        _kotaCtrl.text = data['kota'] ?? '';
        _provinsiCtrl.text = data['provinsi'] ?? '';
        _tempatLahirCtrl.text = data['tempatLahir'] ?? '';
        _pekerjaanCtrl.text = data['pekerjaan'] ?? '';
        _noHpCtrl.text = data['noHp'] ?? '';

        _selectedAgama = data['agama'];
        _selectedJenisKelamin = data['jenisKelamin'];
        _selectedStatusDiKeluarga = data['statusDiKeluarga'];
        _selectedStatusPerkawinan = data['statusPerkawinan'];

        if (data['tanggalLahir'] != null) {
          _selectedTanggalLahir = DateTime.parse(
            data['tanggalLahir'] as String,
          );
        }

        _urlFotoKk = data['urlFotoKk'];
        _urlFotoKtp = data['urlFotoKtp'];
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    _nikCtrl.dispose();
    _alamatCtrl.dispose();
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

      // Upload to Supabase with unique filename
      final fileName =
          '${FirebaseAuth.instance.currentUser!.uid}_${type}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bytes = await pickedFile.readAsBytes();

      await _supabase.storage
          .from('dokumen-warga')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(upsert: true),
          );

      // Get public URL
      final url = _supabase.storage
          .from('dokumen-warga')
          .getPublicUrl(fileName);

      setState(() {
        if (type == 'kk') {
          _urlFotoKk = url;
        } else {
          _urlFotoKtp = url;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Foto $type berhasil diupload'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Gagal upload foto: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveBiodata() async {
    if (!_formKey.currentState!.validate()) return;

    // Validasi foto wajib hanya jika create (bukan edit)
    if (!widget.isEditMode && (_urlFotoKk == null || _urlFotoKtp == null)) {
      UxHelper.showWarning(context, 'Foto KK dan KTP harus diupload');
      return;
    }

    // Validasi dropdown
    if (_selectedAgama == null ||
        _selectedJenisKelamin == null ||
        _selectedStatusDiKeluarga == null ||
        _selectedStatusPerkawinan == null ||
        _selectedTanggalLahir == null ||
        _selectedRt == null ||
        _selectedRw == null) {
      UxHelper.showError(context, 'Semua field harus diisi');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final userData = <String, dynamic>{
        'nama': _namaCtrl.text.trim(),
        'nik': _nikCtrl.text.trim(),
        'alamat': _alamatCtrl.text.trim(),
        'rt': _selectedRt!,
        'rw': _selectedRw!,
        'kelurahan': 'Sukorame',
        'kecamatan': _kecamatanCtrl.text.trim(),
        'kota': _kotaCtrl.text.trim(),
        'provinsi': _provinsiCtrl.text.trim(),
        'agama': _selectedAgama!,
        'jenisKelamin': _selectedJenisKelamin!,
        'tanggalLahir': DateFormat('yyyy-MM-dd').format(_selectedTanggalLahir!),
        'tempatLahir': _tempatLahirCtrl.text.trim(),
        'pekerjaan': _pekerjaanCtrl.text.trim(),
        'statusDiKeluarga': _selectedStatusDiKeluarga!,
        'statusPerkawinan': _selectedStatusPerkawinan!,
        'kewarganegaraan': 'NKRI',
        'noHp': _noHpCtrl.text.trim(),
      };

      // Add photos only if not null (for edit mode)
      if (_urlFotoKk != null) userData['urlFotoKk'] = _urlFotoKk;
      if (_urlFotoKtp != null) userData['urlFotoKtp'] = _urlFotoKtp;

      if (widget.isEditMode) {
        // Update existing user
        await _firestore.collection('users').doc(uid).update(userData);
      } else {
        // Create new user
        userData['uid'] = uid;
        userData['role'] = 'warga';
        userData['createdAt'] = DateTime.now().toString();
        userData['email'] = FirebaseAuth.instance.currentUser!.email!;

        await _firestore.collection('users').doc(uid).set(userData);
      }

      if (mounted) {
        UxHelper.showSuccess(context, 'Biodata berhasil disimpan');
        if (widget.isEditMode) {
          Future.delayed(Duration(milliseconds: 800), () {
            if (mounted) context.pop(); // Go back to detail_akun_screen
          });
        } else {
          Future.delayed(Duration(milliseconds: 800), () {
            if (mounted) {
              context.go('/dashboard/warga'); // Go to dashboard after create
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = ValidationHelper.getErrorMessage(e as Exception);
        UxHelper.showError(context, errorMsg);
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
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            // Cek apakah ada navigator history
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              // Jika tidak ada history (baru login), go to login
              context.go('/login');
            }
          },
        ),
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
                    Text(
                      '1. Identitas Pribadi',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _namaCtrl,
                      decoration: InputDecoration(
                        labelText: 'Nama Lengkap *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: ValidationHelper.validateNama,
                    ),
                    SizedBox(height: 12),
                    TextFormField(
                      controller: _nikCtrl,
                      decoration: InputDecoration(
                        labelText: 'NIK (16 digit) *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.badge),
                      ),
                      keyboardType: TextInputType.number,
                      validator: ValidationHelper.validateNIK,
                      maxLength: 16,
                    ),
                    SizedBox(height: 12),
                    TextFormField(
                      controller: _tempatLahirCtrl,
                      decoration: InputDecoration(
                        labelText: 'Tempat Lahir *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) => val!.isEmpty
                          ? 'Tempat lahir tidak boleh kosong'
                          : val.length < 3
                          ? 'Minimal 3 karakter'
                          : null,
                    ),
                    SizedBox(height: 12),
                    GestureDetector(
                      onTap: _pickDate,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedTanggalLahir != null
                                  ? DateFormat(
                                      'dd MMMM yyyy',
                                    ).format(_selectedTanggalLahir!)
                                  : 'Pilih Tanggal Lahir *',
                              style: TextStyle(fontSize: 16),
                            ),
                            Icon(
                              Icons.calendar_today,
                              color: Colors.green.shade700,
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Agama *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.church),
                      ),
                      initialValue: _selectedAgama,
                      items: _agamaList
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: (val) => setState(() => _selectedAgama = val),
                      validator: (val) =>
                          val == null ? 'Agama wajib dipilih' : null,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Jenis Kelamin *',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: Text('Laki-laki'),
                            value: 'Laki-laki',
                            groupValue: _selectedJenisKelamin,
                            onChanged: (val) =>
                                setState(() => _selectedJenisKelamin = val),
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: Text('Perempuan'),
                            value: 'Perempuan',
                            groupValue: _selectedJenisKelamin,
                            onChanged: (val) =>
                                setState(() => _selectedJenisKelamin = val),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 24),
                    Divider(),
                    SizedBox(height: 16),

                    // === ALAMAT & DOMISILI ===
                    Text(
                      '2. Alamat & Domisili',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _alamatCtrl,
                      decoration: InputDecoration(
                        labelText: 'Alamat Lengkap *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.home),
                      ),
                      maxLines: 2,
                      validator: (val) =>
                          val!.isEmpty ? 'Alamat wajib diisi' : null,
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: 'RT *',
                              border: OutlineInputBorder(),
                            ),
                            initialValue: _rtList.contains(_selectedRt)
                                ? _selectedRt
                                : null,
                            items: _rtList.isEmpty
                                ? [
                                    DropdownMenuItem(
                                      value: null,
                                      child: Text('Memuat data...'),
                                    ),
                                  ]
                                : _rtList
                                      .map(
                                        (rt) => DropdownMenuItem(
                                          value: rt,
                                          child: Text('RT $rt'),
                                        ),
                                      )
                                      .toList(),
                            onChanged: (val) =>
                                setState(() => _selectedRt = val),
                            validator: (val) =>
                                val == null ? 'RT wajib dipilih' : null,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: 'RW *',
                              border: OutlineInputBorder(),
                            ),
                            initialValue: _rwList.contains(_selectedRw)
                                ? _selectedRw
                                : null,
                            items: _rwList.isEmpty
                                ? [
                                    DropdownMenuItem(
                                      value: null,
                                      child: Text('Memuat data...'),
                                    ),
                                  ]
                                : _rwList
                                      .map(
                                        (rw) => DropdownMenuItem(
                                          value: rw,
                                          child: Text('RW $rw'),
                                        ),
                                      )
                                      .toList(),
                            onChanged: (val) =>
                                setState(() => _selectedRw = val),
                            validator: (val) =>
                                val == null ? 'RW wajib dipilih' : null,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    TextFormField(
                      controller: _kecamatanCtrl,
                      decoration: InputDecoration(
                        labelText: 'Kecamatan *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) =>
                          val!.isEmpty ? 'Kecamatan wajib diisi' : null,
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _kotaCtrl,
                            decoration: InputDecoration(
                              labelText: 'Kota/Kabupaten *',
                              border: OutlineInputBorder(),
                            ),
                            validator: (val) =>
                                val!.isEmpty ? 'Kota wajib' : null,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _provinsiCtrl,
                            decoration: InputDecoration(
                              labelText: 'Provinsi *',
                              border: OutlineInputBorder(),
                            ),
                            validator: (val) =>
                                val!.isEmpty ? 'Provinsi wajib' : null,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 24),
                    Divider(),
                    SizedBox(height: 16),

                    // === PEKERJAAN & STATUS ===
                    Text(
                      '3. Pekerjaan & Status Keluarga',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                    SizedBox(height: 16),
                    Autocomplete<String>(
                      optionsBuilder: (TextEditingValue value) {
                        if (value.text.isEmpty) return [];
                        return _pekerjaanList.where(
                          (e) => e.toLowerCase().contains(
                            value.text.toLowerCase(),
                          ),
                        );
                      },
                      onSelected: (String selection) {
                        _pekerjaanCtrl.text = selection;
                      },
                      fieldViewBuilder: (context, ttec, tfn, onFieldSubmitted) {
                        return TextFormField(
                          controller: ttec,
                          focusNode: tfn,
                          decoration: InputDecoration(
                            labelText: 'Pekerjaan *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.work),
                          ),
                          validator: (val) =>
                              val!.isEmpty ? 'Pekerjaan wajib diisi' : null,
                          onChanged: (val) => _pekerjaanCtrl.text = val,
                        );
                      },
                    ),
                    SizedBox(height: 12),
                    Autocomplete<String>(
                      optionsBuilder: (TextEditingValue value) {
                        if (value.text.isEmpty) return [];
                        return _statusDiKeluargaList.where(
                          (e) => e.toLowerCase().contains(
                            value.text.toLowerCase(),
                          ),
                        );
                      },
                      onSelected: (String selection) {
                        setState(() => _selectedStatusDiKeluarga = selection);
                      },
                      fieldViewBuilder: (context, ttec, tfn, onFieldSubmitted) {
                        ttec.text = _selectedStatusDiKeluarga ?? '';
                        return TextFormField(
                          controller: ttec,
                          focusNode: tfn,
                          decoration: InputDecoration(
                            labelText: 'Status di Keluarga *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.family_restroom),
                          ),
                          onChanged: (val) => _selectedStatusDiKeluarga = val,
                          validator: (val) => val!.isEmpty
                              ? 'Status di keluarga wajib diisi'
                              : null,
                        );
                      },
                    ),
                    SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Status Perkawinan *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.favorite),
                      ),
                      initialValue: _selectedStatusPerkawinan,
                      items: _statusPerkawinanList
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _selectedStatusPerkawinan = val),
                      validator: (val) => val == null
                          ? 'Status perkawinan wajib dipilih'
                          : null,
                    ),
                    SizedBox(height: 12),
                    TextFormField(
                      controller: _noHpCtrl,
                      decoration: InputDecoration(
                        labelText: 'No. HP (WhatsApp) *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: ValidationHelper.validateNoHp,
                    ),
                    SizedBox(height: 24),
                    Divider(),
                    SizedBox(height: 16),

                    // === DOKUMEN ===
                    Text(
                      '4. Dokumen Pendukung',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _uploadFoto('kk'),
                            icon: Icon(Icons.image),
                            label: Text('Upload Foto KK'),
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
                            label: Text('Upload Foto KTP'),
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_urlFotoKk != null)
                      Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green),
                              SizedBox(width: 8),
                              Text(
                                'Foto KK berhasil diupload',
                                style: TextStyle(color: Colors.green.shade700),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (_urlFotoKtp != null)
                      Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green),
                              SizedBox(width: 8),
                              Text(
                                'Foto KTP berhasil diupload',
                                style: TextStyle(color: Colors.green.shade700),
                              ),
                            ],
                          ),
                        ),
                      ),
                    SizedBox(height: 32),

                    // === TOMBOL SIMPAN ===
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _saveBiodata,
                      child: Text(
                        'Simpan Biodata & Lanjut',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '* Semua field harus diisi lengkap',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
