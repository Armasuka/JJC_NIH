import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import '../utils/logger.dart';

class PdfStorageService {
  static const String _pdfDirectory = 'inspection_pdfs';

  // Mendapatkan direktori untuk menyimpan PDF
  static Future<Directory> _getPdfDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final pdfDir = Directory('${appDir.path}/$_pdfDirectory');
    if (!await pdfDir.exists()) {
      await pdfDir.create(recursive: true);
    }
    return pdfDir;
  }

  // Menyimpan PDF ke storage lokal
  static Future<String> savePdf(String id, pw.Document pdf) async {
    try {
      final pdfDir = await _getPdfDirectory();
      final file = File('${pdfDir.path}/inspeksi_$id.pdf');
      await file.writeAsBytes(await pdf.save());
      return file.path;
    } catch (e) {
      Logger.debug('Error saving PDF: $e');
      rethrow;
    }
  }

  // Mengambil file PDF berdasarkan ID
  static Future<File?> getPdfFile(String id) async {
    try {
      final pdfDir = await _getPdfDirectory();
      final file = File('${pdfDir.path}/inspeksi_$id.pdf');
      if (await file.exists()) {
        return file;
      }
      return null;
    } catch (e) {
      Logger.debug('Error getting PDF file: $e');
      return null;
    }
  }

  // Menghapus file PDF berdasarkan ID
  static Future<bool> deletePdf(String id) async {
    try {
      final pdfDir = await _getPdfDirectory();
      final file = File('${pdfDir.path}/inspeksi_$id.pdf');
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      Logger.debug('Error deleting PDF: $e');
      return false;
    }
  }

  // Mendapatkan semua file PDF
  static Future<List<File>> getAllPdfFiles() async {
    try {
      final pdfDir = await _getPdfDirectory();
      final files = await pdfDir.list().toList();
      return files
          .whereType<File>()
          .where((file) => file.path.endsWith('.pdf'))
          .toList();
    } catch (e) {
      Logger.debug('Error getting all PDF files: $e');
      return [];
    }
  }

  // Mendapatkan ukuran file PDF
  static Future<int> getPdfFileSize(String id) async {
    try {
      final file = await getPdfFile(id);
      if (file != null) {
        return await file.length();
      }
      return 0;
    } catch (e) {
      Logger.debug('Error getting PDF file size: $e');
      return 0;
    }
  }

  // Membersihkan file PDF yang tidak terpakai
  static Future<void> cleanupUnusedPdfs(List<String> validIds) async {
    try {
      final allFiles = await getAllPdfFiles();
      for (final file in allFiles) {
        final fileName = file.path.split('/').last;
        final id = fileName.replaceAll('inspeksi_', '').replaceAll('.pdf', '');
        if (!validIds.contains(id)) {
          await file.delete();
        }
      }
    } catch (e) {
      Logger.debug('Error cleaning up unused PDFs: $e');
    }
  }
}
