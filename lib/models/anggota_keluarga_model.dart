class AnggotaKeluargaModel {
  String nama, nik, hubungan, alamat, rt, rw, kelurahan, kecamatan, kota, provinsi, agama, jenisKelamin, tanggalLahir, tempatLahir, pekerjaan, statusDiKeluarga, statusPerkawinan, kewarganegaraan;
  String? urlFotoKk, urlFotoKtp;

  AnggotaKeluargaModel({
    required this.nama, required this.nik, required this.hubungan, required this.alamat, required this.rt, required this.rw, required this.kelurahan, required this.kecamatan, required this.kota, required this.provinsi, required this.agama, required this.jenisKelamin, required this.tanggalLahir, required this.tempatLahir, required this.pekerjaan, required this.statusDiKeluarga, required this.statusPerkawinan, required this.kewarganegaraan, this.urlFotoKk, this.urlFotoKtp,
  });

  Map<String, dynamic> toMap() {
    return {
      'nama': nama, 'nik': nik, 'hubungan': hubungan, 'alamat': alamat, 'rt': rt, 'rw': rw, 'kelurahan': kelurahan, 'kecamatan': kecamatan, 'kota': kota, 'provinsi': provinsi, 'agama': agama, 'jenisKelamin': jenisKelamin, 'tanggalLahir': tanggalLahir, 'tempatLahir': tempatLahir, 'pekerjaan': pekerjaan, 'statusDiKeluarga': statusDiKeluarga, 'statusPerkawinan': statusPerkawinan, 'kewarganegaraan': kewarganegaraan, 'urlFotoKk': urlFotoKk, 'urlFotoKtp': urlFotoKtp,
    };
  }
}