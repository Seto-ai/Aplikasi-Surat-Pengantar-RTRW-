import 'package:flutter/material.dart';

// Kategori Surat Pengantar yang tersedia
class SuratCategories {
  static const List<String> categories = [
    'Surat Keterangan Miskin',
    'Rekomendasi Perkawinan',
    'Legalisasi Pendaftaran TNI PORLI',
    'Legalisasi Pernyataan Waris',
    'Legalisasi Persyaratan Pensiun',
    'Legalisasi Pengajuan Cerai PNS',
    'Surat Keterangan Belum Menikah',
    'Rekomendasi Izin Keramaian',
    'Surat Keterangan Bepergian (BORO)',
    'Surat Keterangan Domisili',
    'Surat Keterangan Kematian dan Kutipan Kematian',
    'Surat Keterangan Penghasilan',
    'Surat Keterangan Usaha',
    'Legalisasi Surat Kuasa',
    'Keterangan Umum',
    'Lain-Lain',
  ];

  // Dropdown menu items untuk mudah digunakan
  static List<DropdownMenuItem<String>> getDropdownItems() {
    return [
      const DropdownMenuItem(
        value: '',
        child: Text('-- Pilih Maksud/Tujuan --'),
      ),
      ...categories.map((category) {
        return DropdownMenuItem(value: category, child: Text(category));
      }),
    ];
  }
}
