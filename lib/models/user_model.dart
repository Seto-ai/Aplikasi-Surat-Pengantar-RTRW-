class UserModel {
  String uid, nama, nik, alamat, rt, rw, kelurahan, kecamatan, kota, provinsi, agama, jenisKelamin, tanggalLahir, tempatLahir, pekerjaan, statusDiKeluarga, statusPerkawinan, kewarganegaraan, role, createdAt, email, noHp;
  String? urlFotoKk, urlFotoKtp;
  List<Map<String, dynamic>> anggotaKeluarga; // Tambah list anggota keluarga

  UserModel({
    required this.uid, required this.nama, required this.nik, required this.alamat, required this.rt, required this.rw, required this.kelurahan, required this.kecamatan, required this.kota, required this.provinsi, required this.agama, required this.jenisKelamin, required this.tanggalLahir, required this.tempatLahir, required this.pekerjaan, required this.statusDiKeluarga, required this.statusPerkawinan, required this.kewarganegaraan, required this.role, required this.createdAt, required this.email, required this.noHp, this.urlFotoKk, this.urlFotoKtp, this.anggotaKeluarga = const [],
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'], nama: map['nama'], nik: map['nik'], alamat: map['alamat'], rt: map['rt'], rw: map['rw'], kelurahan: map['kelurahan'], kecamatan: map['kecamatan'], kota: map['kota'], provinsi: map['provinsi'], agama: map['agama'], jenisKelamin: map['jenisKelamin'], tanggalLahir: map['tanggalLahir'], tempatLahir: map['tempatLahir'], pekerjaan: map['pekerjaan'], statusDiKeluarga: map['statusDiKeluarga'], statusPerkawinan: map['statusPerkawinan'], kewarganegaraan: map['kewarganegaraan'], role: map['role'], createdAt: map['createdAt'], email: map['email'], noHp: map['noHp'], urlFotoKk: map['urlFotoKk'], urlFotoKtp: map['urlFotoKtp'], anggotaKeluarga: List<Map<String, dynamic>>.from(map['anggotaKeluarga'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid, 'nama': nama, 'nik': nik, 'alamat': alamat, 'rt': rt, 'rw': rw, 'kelurahan': kelurahan, 'kecamatan': kecamatan, 'kota': kota, 'provinsi': provinsi, 'agama': agama, 'jenisKelamin': jenisKelamin, 'tanggalLahir': tanggalLahir, 'tempatLahir': tempatLahir, 'pekerjaan': pekerjaan, 'statusDiKeluarga': statusDiKeluarga, 'statusPerkawinan': statusPerkawinan, 'kewarganegaraan': kewarganegaraan, 'role': role, 'createdAt': createdAt, 'email': email, 'noHp': noHp, 'urlFotoKk': urlFotoKk, 'urlFotoKtp': urlFotoKtp, 'anggotaKeluarga': anggotaKeluarga,
    };
  }
}