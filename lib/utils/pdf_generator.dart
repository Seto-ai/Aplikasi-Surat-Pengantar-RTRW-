import 'package:pdf/widgets.dart' as pw;

class PdfGenerator {
  static Future<pw.Document> generateSurat(Map<String, dynamic> dataPemohon, String kategori, String keperluan) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Surat Pengantar $kategori', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.Text('Data Pemohon:'),
              pw.Text('Nama: ${dataPemohon['nama']}'),
              pw.Text('NIK: ${dataPemohon['nik']}'),
              pw.Text('Alamat: ${dataPemohon['alamat']}'),
              // Tambahkan field lainnya sesuai kebutuhan
              pw.SizedBox(height: 20),
              pw.Text('Keperluan: $keperluan'),
              pw.SizedBox(height: 20),
              pw.Text('Tanggal: ${DateTime.now().toString()}'),
            ],
          );
        },
      ),
    );
    return pdf;
  }
}