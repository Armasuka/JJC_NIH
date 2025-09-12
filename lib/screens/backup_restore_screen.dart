import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart'
    show openAppSettings;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'dart:convert';

import 'package:archive/archive.dart';
import '../services/pdf_storage_service.dart';
import 'home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackupRestoreScreen extends StatefulWidget {
  final File? initialFile;
  const BackupRestoreScreen({super.key, this.initialFile});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  bool _isLoading = false;
  String? _lastBackupPath;
  int _totalRecords = 0;
  String? _lastBackupSize;
  List<FileSystemEntity> _backupFiles = [];
  bool _autoBackupEnabled = false;
  String _backupFrequency = 'weekly'; // daily, weekly, monthly
  TimeOfDay _backupTime = const TimeOfDay(hour: 20, minute: 0); // 8 PM default

  // Fungsi untuk meminta permission storage
  Future<bool> _requestStoragePermission() async {
    // Menyimpan ke direktori aplikasi (external app-specific) tidak memerlukan permission
    // pada Android 10+ (scoped storage). File picker juga memakai SAF sehingga
    // tidak perlu READ_EXTERNAL_STORAGE. Kembalikan true agar tidak memblokir proses.
    return true;
  }

  // Mendapatkan direktori yang bisa diakses user untuk backup
  Future<Directory?> _getBackupDirectory() async {
    try {
      // Coba dapatkan external storage directory terlebih dahulu
      Directory? externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        // Buat folder backup di dalam folder aplikasi
        final backupDir = Directory('${externalDir.path}/backup');
        if (!await backupDir.exists()) {
          await backupDir.create(recursive: true);
        }
        return backupDir;
      }

      // Fallback ke application documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${appDir.path}/backup');
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }
      return backupDir;
    } catch (e) {
      print('Error getting backup directory: $e');
      return null;
    }
  }

  // Backup data ke file JSON
  Future<void> _backupData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Minta permission storage terlebih dahulu
      final hasPermission = await _requestStoragePermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.error, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        'Permission storage diperlukan untuk backup data. Silakan berikan permission di pengaturan aplikasi.'),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 6),
              action: SnackBarAction(
                label: 'Pengaturan',
                textColor: Colors.white,
                onPressed: () {
                  openAppSettings();
                },
              ),
            ),
          );
        }
        return;
      }

      // Ambil data dari Hive
      final box = Hive.box('inspection_history');
      final data = box.values.toList();

      if (data.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.info, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Tidak ada data untuk di-backup'),
                  ),
                ],
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Analisis data untuk metadata yang lebih lengkap
      final dataAnalysis = _analyzeBackupData(data);

      // Convert ke JSON dengan format yang lebih baik
      final backupData = {
        'version': '2.1',
        'timestamp': DateTime.now().toIso8601String(),
        'total_records': data.length,
        'app_name': 'Jasamarga Inspector',
        'data_analysis': dataAnalysis,
        'backup_info': {
          'created_by': 'Jasamarga Inspector App',
          'compatibility': 'Android/iOS',
          'data_preservation': 'Full (including dates, photos, PDFs)',
          'restore_behavior': 'Merge with existing data (no reset)',
        },
        'data': data,
      };

      final jsonData = jsonEncode(backupData);
      final jsonBytes = utf8.encode(jsonData);

      // Dapatkan direktori backup
      final backupDir = await _getBackupDirectory();
      if (backupDir == null) {
        throw Exception(
            'Tidak dapat mengakses direktori backup. Pastikan aplikasi memiliki permission storage dan coba lagi.');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName =
          'backup_inspeksi_${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}_$timestamp.zip';
      final file = File('${backupDir.path}/$fileName');

      // Coba simpan ke Downloads folder agar muncul di Recent Files
      Directory? downloadsDir;
      try {
        if (Platform.isAndroid) {
          // Coba akses Downloads folder
          downloadsDir = Directory('/storage/emulated/0/Download');
          if (!await downloadsDir.exists()) {
            downloadsDir = null;
          }
        }
      } catch (e) {
        print('Cannot access Downloads folder: $e');
        downloadsDir = null;
      }
      try {
        // Buat ZIP archive
        final archive = Archive();

        // Tambahkan file data.json ke archive
        final dataFile = ArchiveFile('data.json', jsonBytes.length, jsonBytes);
        archive.addFile(dataFile);

        // Tambahkan file PDF ke archive
        final pdfFiles = await PdfStorageService.getAllPdfFiles();
        int pdfCount = 0;
        for (final pdfFile in pdfFiles) {
          try {
            final pdfBytes = await pdfFile.readAsBytes();
            final fileName = pdfFile.path.split('/').last;
            final pdfArchiveFile =
                ArchiveFile('pdfs/$fileName', pdfBytes.length, pdfBytes);
            archive.addFile(pdfArchiveFile);
            pdfCount++;
          } catch (e) {
            print('Error adding PDF file ${pdfFile.path}: $e');
          }
        }

        // Tambahkan file metadata.txt yang lebih informatif
        final metadata = '''
Jasamarga Inspector - Backup Data v2.1
=====================================
Tanggal Backup: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}
Waktu Backup: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}
Total Records: ${data.length}
Total PDF Files: $pdfCount
Versi Backup: 2.1
Format: ZIP Archive dengan JSON data dan PDF files

ANALISIS DATA:
${dataAnalysis['period_range']}
${dataAnalysis['vehicle_types']}
${dataAnalysis['total_vehicles']}

CARA RESTORE:
1. Buka aplikasi Jasamarga Inspector
2. Pilih menu Backup & Restore
3. Klik tombol "Restore Data" atau pilih file backup ini
4. Data akan digabungkan dengan data yang ada (tidak mereset)
5. Tanggal inspeksi akan tetap terjaga sesuai aslinya

FITUR KHUSUS:
✓ Preservasi tanggal inspeksi (tidak mereset ke bulan saat restore)
✓ Gabungan data (merge) bukan penggantian total
✓ Backup file PDF lengkap
✓ Kompatibel antar device
✓ Metadata lengkap untuk tracking

File ini berisi data inspeksi kendaraan dan file PDF yang telah di-backup.
Jangan edit atau hapus file ini jika ingin data tetap aman.
        ''';
        final metadataBytes = utf8.encode(metadata);
        final metadataFile =
            ArchiveFile('metadata.txt', metadataBytes.length, metadataBytes);
        archive.addFile(metadataFile);

        // Encode ZIP
        final zipData = ZipEncoder().encode(archive);
        if (zipData == null) {
          throw Exception('Gagal membuat file ZIP');
        }

        // Tulis file ZIP
        await file.writeAsBytes(zipData);

        // Jika berhasil, coba copy ke Downloads folder
        if (downloadsDir != null) {
          try {
            final downloadsFile = File('${downloadsDir.path}/$fileName');
            await downloadsFile.writeAsBytes(zipData);
            print('Backup file also saved to Downloads: ${downloadsFile.path}');
          } catch (e) {
            print('Failed to copy to Downloads: $e');
          }
        }
      } catch (e) {
        throw Exception(
            'Tidak dapat menulis file backup: ${e.toString()}. Pastikan ada ruang penyimpanan yang cukup.');
      }

      // Hitung ukuran file
      int fileSize;
      try {
        fileSize = await file.length();
      } catch (e) {
        throw Exception(
            'Tidak dapat menghitung ukuran file backup: ${e.toString()}');
      }
      final sizeInKB = (fileSize / 1024).toStringAsFixed(1);

      if (fileSize == 0) {
        throw Exception(
            'File backup berhasil dibuat tetapi ukurannya 0 bytes. Kemungkinan ada masalah dengan penyimpanan.');
      }

      // Simpan path backup untuk ditampilkan dan refresh jumlah data
      setState(() {
        _lastBackupPath =
            downloadsDir != null ? '${downloadsDir.path}/$fileName' : file.path;
        _lastBackupSize = '$sizeInKB KB';
        _totalRecords = data.length;
      });

      // Refresh daftar file backup
      try {
        await _loadBackupFiles();
      } catch (e) {
        print('Error refreshing backup files: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Backup berhasil! File: $fileName (ZIP)'),
                      if (downloadsDir != null)
                        const Text(
                          'Tersimpan di Downloads folder',
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      Text(
                        'Data: ${data.length} records, ${dataAnalysis['period_range']}',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () async {
                    try {
                      final shareFile = downloadsDir != null
                          ? File('${downloadsDir.path}/$fileName')
                          : file;
                      await Share.shareXFiles(
                        [XFile(shareFile.path)],
                        text:
                            'Backup inspeksi Jasamarga Inspector: $fileName\n\nFile ini berisi data inspeksi kendaraan yang telah di-backup. Buka dengan aplikasi Jasamarga Inspector untuk restore data.',
                        subject: 'Backup Data Inspeksi Jasamarga Inspector',
                      );
                    } catch (_) {}
                  },
                  child: const Text(
                    'Bagikan',
                    style: TextStyle(
                        color: Colors.white,
                        decoration: TextDecoration.underline),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      print('Backup error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Error backup: ${e.toString()}'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Fungsi untuk menganalisis data backup
  Map<String, String> _analyzeBackupData(List data) {
    if (data.isEmpty) {
      return {
        'period_range': 'Tidak ada data',
        'vehicle_types': 'Tidak ada data',
        'total_vehicles': 'Tidak ada data',
      };
    }

    final dates = <DateTime>[];
    final vehicleTypes = <String, int>{};
    final vehicles = <String>{};

    for (var item in data) {
      if (item is Map) {
        // Analisis tanggal
        if (item['tanggal'] != null) {
          try {
            final date = DateTime.parse(item['tanggal']);
            dates.add(date);
          } catch (e) {
            print('Error parsing date: $e');
          }
        }

        // Analisis jenis kendaraan
        final jenis = item['jenis']?.toString() ?? 'Unknown';
        vehicleTypes[jenis] = (vehicleTypes[jenis] ?? 0) + 1;

        // Analisis nopol
        final nopol = item['nopol']?.toString() ?? 'Unknown';
        vehicles.add(nopol);
      }
    }

    // Hitung range tanggal
    String periodRange = 'Tidak ada data tanggal';
    if (dates.isNotEmpty) {
      dates.sort();
      final startDate = dates.first;
      final endDate = dates.last;
      periodRange =
          'Periode: ${startDate.day}/${startDate.month}/${startDate.year} - ${endDate.day}/${endDate.month}/${endDate.year}';
    }

    // Format jenis kendaraan
    final vehicleTypesStr =
        vehicleTypes.entries.map((e) => '${e.key}: ${e.value}').join(', ');

    return {
      'period_range': periodRange,
      'vehicle_types': 'Jenis: $vehicleTypesStr',
      'total_vehicles': 'Total kendaraan unik: ${vehicles.length}',
    };
  }

  // Restore data dari file JSON
  Future<void> _restoreData() async {
    try {
      // Pilih file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip', 'json'],
        allowMultiple: false,
      );

      if (result != null) {
        await _processRestoreFile(File(result.files.single.path!));
      }
    } catch (e) {
      print('Restore error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Error restore: ${e.toString()}'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }

  // Restore data dari file yang dipilih
  Future<void> _restoreFromFile(File file) async {
    // Tampilkan konfirmasi terlebih dahulu dengan opsi merge
    final restoreMode = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.restore, color: Colors.blue[700]),
            const SizedBox(width: 8),
            const Text('Pilih Mode Restore'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'File: ${file.path.split('/').last}\n',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const Text(
              'Pilih cara restore data:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            _buildRestoreOption(
              icon: Icons.merge_type,
              title: 'Gabungkan Data (Merge)',
              subtitle: 'Data backup akan ditambahkan ke data yang ada',
              color: Colors.green,
              value: 'merge',
            ),
            const SizedBox(height: 8),
            _buildRestoreOption(
              icon: Icons.refresh,
              title: 'Ganti Semua Data',
              subtitle: 'Data yang ada akan dihapus dan diganti',
              color: Colors.red,
              value: 'replace',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Batal'),
          ),
        ],
      ),
    );

    if (restoreMode != null) {
      await _processRestoreFile(file, mode: restoreMode);
    }
  }

  Widget _buildRestoreOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required String value,
  }) {
    return InkWell(
      onTap: () => Navigator.of(context).pop(value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: color.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Proses restore file
  Future<void> _processRestoreFile(File file, {String mode = 'merge'}) async {
    setState(() {
      _isLoading = true;
    });

    // Tampilkan dialog progress
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Memulihkan data...'),
                  const SizedBox(height: 4),
                  Text(
                    'Mode: ${mode == 'merge' ? 'Gabungkan Data' : 'Ganti Semua Data'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    try {
      if (!await file.exists()) {
        throw Exception(
            'File yang dipilih tidak ditemukan atau tidak dapat diakses');
      }

      int fileSize;
      try {
        fileSize = await file.length();
      } catch (e) {
        throw Exception(
            'Tidak dapat menghitung ukuran file yang dipilih: ${e.toString()}');
      }
      final sizeInKB = (fileSize / 1024).toStringAsFixed(1);

      // Limitasi ukuran file dihapus untuk memungkinkan restore file backup yang lebih besar

      // Cek ukuran file (minimal 10 bytes)
      if (fileSize < 10) {
        throw Exception(
            'File terlalu kecil ($fileSize bytes). File backup harus minimal 10 bytes.');
      }

      if (mounted) {
        final fileExtension = file.path.split('.').last.toLowerCase();
        final formatType = fileExtension == 'zip' ? 'ZIP' : 'JSON';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'File dipilih: ${file.path.split('/').last} ($sizeInKB KB, $formatType)'),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Cek apakah file ZIP atau JSON
      final fileExtension = file.path.split('.').last.toLowerCase();
      dynamic backupData;

      if (fileExtension == 'zip') {
        // Proses file ZIP
        try {
          final zipBytes = await file.readAsBytes();
          final archive = ZipDecoder().decodeBytes(zipBytes);

          // Cari file data.json dalam archive
          final dataFile = archive.findFile('data.json');
          if (dataFile == null) {
            throw Exception(
                'File ZIP tidak mengandung data.json. Pastikan file adalah backup yang valid.');
          }

          final jsonString = utf8.decode(dataFile.content as List<int>);
          if (jsonString.isEmpty) {
            throw Exception(
                'File data.json dalam ZIP kosong. Pastikan file backup tidak rusak.');
          }

          backupData = jsonDecode(jsonString);

          // Tampilkan informasi metadata jika ada
          final metadataFile = archive.findFile('metadata.txt');
          if (metadataFile != null) {
            final metadata = utf8.decode(metadataFile.content as List<int>);
            print('Metadata backup: $metadata');
          }
        } catch (e) {
          throw Exception(
              'Tidak dapat membaca file ZIP: ${e.toString()}. Pastikan file adalah backup yang valid.');
        }
      } else {
        // Proses file JSON (legacy support)
        String jsonString;
        try {
          jsonString = await file.readAsString(encoding: utf8);
        } catch (e) {
          throw Exception(
              'Tidak dapat membaca file yang dipilih: ${e.toString()}. Pastikan file tidak rusak.');
        }
        if (jsonString.isEmpty) {
          throw Exception(
              'File backup kosong atau tidak dapat dibaca. Ukuran file: $fileSize bytes. Pastikan file tidak kosong.');
        }

        try {
          backupData = jsonDecode(jsonString);
        } catch (e) {
          throw Exception(
              'File backup tidak valid JSON: ${e.toString()}. Pastikan file adalah file backup yang valid dan tidak rusak.');
        }
      }

      // Handle format backup yang baru dan lama
      List data;
      String backupVersion = 'Unknown';

      if (backupData is Map && backupData.containsKey('data')) {
        // Format baru dengan metadata
        data = backupData['data'] as List;
        backupVersion = backupData['version'] ?? '1.0';

        // Tampilkan informasi versi
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Format backup v$backupVersion terdeteksi'),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else if (backupData is List) {
        // Format lama
        data = backupData;
        backupVersion = 'Legacy';

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Format backup legacy terdeteksi'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        throw Exception(
            'Format file backup tidak valid. File harus berisi array JSON atau object dengan field "data". Tipe data terdeteksi: ${backupData.runtimeType}. Pastikan file adalah file backup yang dibuat oleh aplikasi ini dan tidak dimodifikasi.');
      }

      if (data.isEmpty) {
        throw Exception(
            'File backup tidak mengandung data atau format data tidak valid. Jumlah records: ${data.length}. Pastikan file backup tidak kosong dan berisi data inspeksi yang valid.');
      }

      // Tampilkan informasi jumlah records dan timestamp
      if (backupData is Map) {
        if (backupData.containsKey('total_records')) {
          final totalRecords = backupData['total_records'];
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('File berisi $totalRecords records'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }

        if (backupData.containsKey('timestamp')) {
          final timestamp = backupData['timestamp'];
          try {
            final dateTime = DateTime.parse(timestamp);
            final dateStr =
                '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Backup dibuat pada: $dateStr'),
                  backgroundColor: Colors.blue,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          } catch (e) {
            print('Error parsing timestamp: $e');
          }
        }
      }

      // Restore ke Hive dengan mode merge atau replace
      final box = Hive.box('inspection_history');
      int newCount = 0;
      int duplicateCount = 0;
      String restorePrefix = '';

      try {
        if (mode == 'replace') {
          // Mode replace: hapus semua data lama
          await box.clear();
        }

        // Generate unique prefix untuk menghindari konflik ID
        restorePrefix = DateTime.now().millisecondsSinceEpoch.toString();

        for (var item in data) {
          // Cek apakah data sudah ada (untuk mode merge)
          if (mode == 'merge') {
            final existingData = box.values.where((existing) {
              return existing['tanggal'] == item['tanggal'] &&
                  existing['nopol'] == item['nopol'] &&
                  existing['jenis'] == item['jenis'];
            }).toList();

            if (existingData.isNotEmpty) {
              duplicateCount++;
              continue; // Skip data yang duplikat
            }
          }

          // Buat ID baru yang unik untuk menghindari konflik
          final originalId = item['id'] as String? ?? '';
          final newId = '${restorePrefix}_$originalId';

          // Update item dengan ID baru
          final updatedItem = Map<String, dynamic>.from(item);
          updatedItem['id'] = newId;

          // Update pdfPath untuk mencocokkan ID baru jika ada
          if (updatedItem['pdfPath'] != null) {
            final appDir = await getApplicationDocumentsDirectory();
            final newPdfPath =
                '${appDir.path}/inspection_pdfs/inspeksi_$newId.pdf';
            updatedItem['pdfPath'] = newPdfPath;
          }

          // Tambahkan timestamp restore untuk tracking
          updatedItem['restored_at'] = DateTime.now().toIso8601String();
          updatedItem['restore_mode'] = mode;

          await box.add(updatedItem);
          newCount++;
        }
      } catch (e) {
        throw Exception(
            'Tidak dapat menyimpan data ke database: ${e.toString()}. Pastikan data backup valid.');
      }

      // Restore PDF files jika ada (hanya untuk format ZIP)
      int restoredPdfCount = 0;
      if (fileExtension == 'zip') {
        try {
          final zipBytes = await file.readAsBytes();
          final archive = ZipDecoder().decodeBytes(zipBytes);

          // Cari folder pdfs dalam archive
          final pdfFiles =
              archive.where((file) => file.name.startsWith('pdfs/')).toList();

          for (final pdfArchiveFile in pdfFiles) {
            try {
              final fileName = pdfArchiveFile.name.split('/').last;
              final pdfBytes = pdfArchiveFile.content as List<int>;

              // Ekstrak ID dari nama file (inspeksi_ID.pdf)
              final originalId =
                  fileName.replaceAll('inspeksi_', '').replaceAll('.pdf', '');

              // Buat ID baru yang sesuai dengan data yang di-restore
              final newId = '${restorePrefix}_$originalId';
              final newFileName = 'inspeksi_$newId.pdf';

              print('Restoring PDF: $fileName -> $newFileName');
              print('Original ID: $originalId, New ID: $newId');

              // Simpan PDF menggunakan PdfStorageService
              final appDir = await getApplicationDocumentsDirectory();
              final pdfDir = Directory('${appDir.path}/inspection_pdfs');
              if (!await pdfDir.exists()) {
                await pdfDir.create(recursive: true);
              }
              final pdfFile = File('${pdfDir.path}/$newFileName');
              await pdfFile.writeAsBytes(pdfBytes);

              print('PDF saved successfully to: ${pdfFile.path}');
              print('PDF file size: ${pdfBytes.length} bytes');

              restoredPdfCount++;
            } catch (e) {
              print('Error restoring PDF file ${pdfArchiveFile.name}: $e');
            }
          }
        } catch (e) {
          print('Error restoring PDF files: $e');
        }
      }

      // Refresh jumlah data
      setState(() {
        _totalRecords = box.length;
      });

      // Refresh daftar file backup
      try {
        await _loadBackupFiles();
      } catch (e) {
        print('Error refreshing backup files: $e');
      }

      // Tutup dialog progress
      if (mounted) {
        Navigator.of(context).pop(); // Tutup dialog progress
      }

      if (mounted) {
        String message = 'Data berhasil dipulihkan!';
        if (mode == 'merge') {
          message += ' ($newCount item baru ditambahkan';
          if (duplicateCount > 0) {
            message += ', $duplicateCount duplikat dilewati';
          }
        } else {
          message += ' ($newCount item';
        }
        if (restoredPdfCount > 0) {
          message += ', $restoredPdfCount PDF';
        }
        message += ')';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(message),
                      Text(
                        'Mode: ${mode == 'merge' ? 'Gabungkan' : 'Ganti Semua'}',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      print('Restore error: $e');

      // Tutup dialog progress jika masih terbuka
      if (mounted) {
        Navigator.of(context).pop(); // Tutup dialog progress
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Error restore: ${e.toString()}'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadRecordCount();
    _loadBackupFiles();
    _loadBackupSettings();

    // Jika ada file yang dibuka dari aplikasi lain, langsung proses restore
    if (widget.initialFile != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleInitialFile();
      });
    }
  }

  // Load pengaturan backup dari SharedPreferences
  Future<void> _loadBackupSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _autoBackupEnabled = prefs.getBool('auto_backup_enabled') ?? false;
        _backupFrequency = prefs.getString('backup_frequency') ?? 'weekly';
        final hour = prefs.getInt('backup_time_hour') ?? 20;
        final minute = prefs.getInt('backup_time_minute') ?? 0;
        _backupTime = TimeOfDay(hour: hour, minute: minute);
      });
    } catch (e) {
      print('Error loading backup settings: $e');
    }
  }

  // Save pengaturan backup ke SharedPreferences
  Future<void> _saveBackupSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('auto_backup_enabled', _autoBackupEnabled);
      await prefs.setString('backup_frequency', _backupFrequency);
      await prefs.setInt('backup_time_hour', _backupTime.hour);
      await prefs.setInt('backup_time_minute', _backupTime.minute);
    } catch (e) {
      print('Error saving backup settings: $e');
    }
  }

  // Tampilkan dialog pengaturan auto-backup
  void _showAutoBackupSettings() {
    // Buat variabel lokal untuk menyimpan pengaturan sementara
    bool tempAutoBackupEnabled = _autoBackupEnabled;
    String tempBackupFrequency = _backupFrequency;
    TimeOfDay tempBackupTime = _backupTime;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.schedule, color: Colors.blue[700]),
              const SizedBox(width: 8),
              const Text('Pengaturan Auto-Backup'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Toggle Auto-Backup
              Row(
                children: [
                  Switch(
                    value: tempAutoBackupEnabled,
                    onChanged: (value) {
                      setDialogState(() {
                        tempAutoBackupEnabled = value;
                      });
                    },
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Aktifkan Auto-Backup',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Frequency Selection
              const Text(
                'Frekuensi Backup:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: tempBackupFrequency,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: const [
                  DropdownMenuItem(value: 'daily', child: Text('Setiap Hari')),
                  DropdownMenuItem(
                      value: 'weekly', child: Text('Setiap Minggu')),
                  DropdownMenuItem(
                      value: 'monthly', child: Text('Setiap Bulan')),
                ],
                onChanged: (value) {
                  setDialogState(() {
                    tempBackupFrequency = value!;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Time Selection
              const Text(
                'Waktu Backup:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: tempBackupTime,
                  );
                  if (time != null) {
                    setDialogState(() {
                      tempBackupTime = time;
                    });
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.access_time, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      Text(
                        '${tempBackupTime.hour.toString().padLeft(2, '0')}:${tempBackupTime.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue[700], size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Info Auto-Backup',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Backup otomatis akan berjalan di background\n'
                      '• File backup akan disimpan di Downloads folder\n'
                      '• Hanya backup jika ada data baru\n'
                      '• Tidak akan mengganggu penggunaan aplikasi',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Terapkan pengaturan sementara ke state utama
                setState(() {
                  _autoBackupEnabled = tempAutoBackupEnabled;
                  _backupFrequency = tempBackupFrequency;
                  _backupTime = tempBackupTime;
                });

                // Simpan ke SharedPreferences
                await _saveBackupSettings();

                if (mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _autoBackupEnabled
                            ? 'Auto-backup diaktifkan (${_getFrequencyText()})'
                            : 'Auto-backup dinonaktifkan',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  String _getFrequencyText() {
    switch (_backupFrequency) {
      case 'daily':
        return 'Setiap hari jam ${_backupTime.hour.toString().padLeft(2, '0')}:${_backupTime.minute.toString().padLeft(2, '0')}';
      case 'weekly':
        return 'Setiap minggu jam ${_backupTime.hour.toString().padLeft(2, '0')}:${_backupTime.minute.toString().padLeft(2, '0')}';
      case 'monthly':
        return 'Setiap bulan jam ${_backupTime.hour.toString().padLeft(2, '0')}:${_backupTime.minute.toString().padLeft(2, '0')}';
      default:
        return 'Setiap minggu';
    }
  }

  void _handleInitialFile() {
    if (widget.initialFile != null) {
      _restoreFromFile(widget.initialFile!);
    }
  }

  Future<void> _loadRecordCount() async {
    try {
      final box = Hive.box('inspection_history');
      setState(() {
        _totalRecords = box.length;
      });
    } catch (e) {
      print('Error loading record count: $e');
      setState(() {
        _totalRecords = 0;
      });
    }
  }

  Future<void> _loadBackupFiles() async {
    try {
      final backupDir = await _getBackupDirectory();
      if (backupDir != null && await backupDir.exists()) {
        final files = await backupDir.list().toList();
        final backupFiles = files
            .where((file) =>
                (file.path.endsWith('.json') || file.path.endsWith('.zip')) &&
                file is File)
            .toList();

        // Sort by modification time (newest first)
        backupFiles.sort((a, b) {
          try {
            return b.statSync().modified.compareTo(a.statSync().modified);
          } catch (e) {
            return 0;
          }
        });

        setState(() {
          _backupFiles = backupFiles;
        });
      }
    } catch (e) {
      print('Error loading backup files: $e');
    }
  }

  // Tampilkan dialog dengan semua file backup
  void _showAllBackupFiles() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.folder_open, color: Colors.blue[700]),
            const SizedBox(width: 8),
            Text(
              'Semua File Backup',
              style: TextStyle(
                color: Colors.blue[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: Column(
            children: [
              Text(
                'Klik file untuk langsung restore',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: _backupFiles.length,
                  itemBuilder: (context, index) {
                    final file = _backupFiles[index] as File;
                    final fileName = file.path.split('/').last;
                    int fileSize = 0;
                    String dateStr = 'Unknown';

                    try {
                      fileSize = file.lengthSync();
                      final modified = file.statSync().modified;
                      dateStr =
                          '${modified.day}/${modified.month}/${modified.year} ${modified.hour}:${modified.minute.toString().padLeft(2, '0')}';
                    } catch (e) {
                      print('Error getting file info: $e');
                    }

                    final sizeInKB = (fileSize / 1024).toStringAsFixed(1);
                    final fileExtension =
                        file.path.split('.').last.toLowerCase();
                    final isZipFile = fileExtension == 'zip';

                    return InkWell(
                      onTap: () {
                        Navigator.of(context).pop(); // Tutup dialog
                        HapticFeedback.lightImpact();
                        _restoreFromFile(file);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: isZipFile
                                  ? Colors.green[100]!
                                  : Colors.blue[100]!),
                          boxShadow: [
                            BoxShadow(
                              color: (isZipFile ? Colors.green : Colors.blue)
                                  .withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                                isZipFile
                                    ? Icons.archive
                                    : Icons.insert_drive_file,
                                color: isZipFile
                                    ? Colors.green[600]
                                    : Colors.blue[600],
                                size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    fileName,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isZipFile
                                          ? Colors.green[700]
                                          : Colors.blue[700],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$dateStr • $sizeInKB KB • ${isZipFile ? 'ZIP' : 'JSON'}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isZipFile
                                          ? Colors.green[600]
                                          : Colors.blue[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.preview,
                                        size: 12,
                                        color: Colors.blue[700],
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        'Preview',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.blue[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.orange[100],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.restore,
                                        size: 14,
                                        color: Colors.orange[700],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Restore',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.orange[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  // Tampilkan preview backup file
  void _showBackupPreview(File file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.preview, color: Colors.blue[700]),
            const SizedBox(width: 8),
            const Text('Preview Backup'),
          ],
        ),
        content: FutureBuilder<String>(
          future: _getBackupPreview(file),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            }

            return SizedBox(
              width: double.maxFinite,
              height: 300,
              child: SingleChildScrollView(
                child: Text(
                  snapshot.data ?? 'Tidak dapat membaca preview',
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tutup'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _restoreFromFile(file);
            },
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  // Mendapatkan preview dari file backup
  Future<String> _getBackupPreview(File file) async {
    try {
      final fileExtension = file.path.split('.').last.toLowerCase();

      if (fileExtension == 'zip') {
        final zipBytes = await file.readAsBytes();
        final archive = ZipDecoder().decodeBytes(zipBytes);

        final dataFile = archive.findFile('data.json');
        if (dataFile == null) {
          return 'File ZIP tidak mengandung data.json';
        }

        final jsonString = utf8.decode(dataFile.content as List<int>);
        final backupData = jsonDecode(jsonString);

        return _formatBackupPreview(backupData);
      } else {
        final jsonString = await file.readAsString();
        final backupData = jsonDecode(jsonString);

        return _formatBackupPreview(backupData);
      }
    } catch (e) {
      return 'Error membaca file: $e';
    }
  }

  // Format preview backup
  String _formatBackupPreview(Map<String, dynamic> backupData) {
    final buffer = StringBuffer();

    buffer.writeln('=== INFORMASI BACKUP ===');
    buffer.writeln('Versi: ${backupData['version'] ?? 'Unknown'}');
    buffer.writeln('Aplikasi: ${backupData['app_name'] ?? 'Unknown'}');
    buffer.writeln('Total Records: ${backupData['total_records'] ?? 0}');

    if (backupData['timestamp'] != null) {
      try {
        final date = DateTime.parse(backupData['timestamp']);
        buffer.writeln(
            'Tanggal Backup: ${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}');
      } catch (e) {
        buffer.writeln('Tanggal Backup: ${backupData['timestamp']}');
      }
    }

    if (backupData['backup_info'] != null) {
      final info = backupData['backup_info'] as Map<String, dynamic>;
      buffer.writeln('Tipe Backup: ${info['data_preservation'] ?? 'Unknown'}');
      buffer.writeln('Kompatibilitas: ${info['compatibility'] ?? 'Unknown'}');
      buffer.writeln('Penyimpanan: ${info['data_preservation'] ?? 'Unknown'}');
      buffer.writeln(
          'Perilaku Restore: ${info['restore_behavior'] ?? 'Unknown'}');
    }

    if (backupData['data_analysis'] != null) {
      final analysis = backupData['data_analysis'] as Map<String, dynamic>;
      buffer.writeln('\n=== ANALISIS DATA ===');
      buffer.writeln(analysis['period_range'] ?? 'Tidak ada data');
      buffer.writeln(analysis['vehicle_types'] ?? 'Tidak ada data');
      buffer.writeln(analysis['total_vehicles'] ?? 'Tidak ada data');
    }

    if (backupData['data'] != null) {
      final data = backupData['data'] as List;
      buffer.writeln('\n=== SAMPLE DATA (5 item pertama) ===');

      for (int i = 0; i < data.length && i < 5; i++) {
        final item = data[i];
        buffer.writeln(
            '${i + 1}. ${item['jenis'] ?? 'Unknown'} - ${item['nopol'] ?? 'Unknown'}');
        buffer.writeln('   Tanggal: ${item['tanggal'] ?? 'Unknown'}');
        buffer.writeln('   Petugas: ${item['petugas1'] ?? 'Unknown'}');
        buffer.writeln('');
      }

      if (data.length > 5) {
        buffer.writeln('... dan ${data.length - 5} item lainnya');
      }
    }

    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Backup & Restore Data'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2257C1),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Memproses data...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {
                await _loadRecordCount();
                await _loadBackupFiles();
              },
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Info Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.backup,
                              size: 64,
                              color: Color(0xFF2257C1),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Backup & Restore Data',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Simpan dan pulihkan data inspeksi Anda',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2257C1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Total Data: $_totalRecords',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Backup Button
                    ElevatedButton.icon(
                      onPressed: _backupData,
                      icon: const Icon(Icons.cloud_upload),
                      label: const Text('Backup Data'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2257C1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Restore Button
                    ElevatedButton.icon(
                      onPressed: _restoreData,
                      icon: const Icon(Icons.cloud_download),
                      label: const Text('Restore Data'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Auto-Backup Settings Button
                    OutlinedButton.icon(
                      onPressed: _showAutoBackupSettings,
                      icon: Icon(
                        _autoBackupEnabled
                            ? Icons.schedule
                            : Icons.schedule_outlined,
                        color: _autoBackupEnabled ? Colors.green : Colors.grey,
                      ),
                      label: Text(
                        _autoBackupEnabled
                            ? 'Auto-Backup Aktif (${_getFrequencyText()})'
                            : 'Pengaturan Auto-Backup',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            _autoBackupEnabled ? Colors.green : Colors.grey,
                        side: BorderSide(
                          color:
                              _autoBackupEnabled ? Colors.green : Colors.grey,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Backup Location Info
                    if (_lastBackupPath != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.folder, color: Colors.green[700]),
                                const SizedBox(width: 8),
                                Text(
                                  'Lokasi Backup Terakhir',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[700],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_lastBackupPath != null &&
                                _lastBackupPath!.contains('Download'))
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '✓ Muncul di Recent Files',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.green[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 8),
                            Text(
                              _lastBackupPath!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green[700],
                                fontFamily: 'monospace',
                              ),
                            ),
                            if (_lastBackupSize != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Ukuran: $_lastBackupSize',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.green[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                    if (_lastBackupPath != null) const SizedBox(height: 20),

                    // Backup Files List
                    if (_backupFiles.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.folder_open,
                                    color: Colors.blue[700]),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'File Backup Tersedia (${_backupFiles.length})',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue[700],
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Tap untuk restore • Long press untuk preview',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.blue[600],
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ...(_backupFiles.take(3).map((file) {
                              final fileName = file.path.split('/').last;
                              int fileSize = 0;
                              String dateStr = 'Unknown';

                              try {
                                fileSize = (file as File).lengthSync();
                                final modified = file.statSync().modified;
                                dateStr =
                                    '${modified.day}/${modified.month}/${modified.year} ${modified.hour}:${modified.minute.toString().padLeft(2, '0')}';
                              } catch (e) {
                                print('Error getting file info: $e');
                              }

                              final sizeInKB =
                                  (fileSize / 1024).toStringAsFixed(1);

                              final fileExtension =
                                  file.path.split('.').last.toLowerCase();
                              final isZipFile = fileExtension == 'zip';

                              return InkWell(
                                onTap: () {
                                  // Tambahkan efek haptic feedback
                                  HapticFeedback.lightImpact();
                                  _restoreFromFile(file as File);
                                },
                                onLongPress: () {
                                  HapticFeedback.mediumImpact();
                                  _showBackupPreview(file as File);
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: isZipFile
                                            ? Colors.green[100]!
                                            : Colors.blue[100]!),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (isZipFile
                                                ? Colors.green
                                                : Colors.blue)
                                            .withOpacity(0.1),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                          isZipFile
                                              ? Icons.archive
                                              : Icons.insert_drive_file,
                                          color: isZipFile
                                              ? Colors.green[600]
                                              : Colors.blue[600],
                                          size: 20),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              fileName,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: isZipFile
                                                    ? Colors.green[700]
                                                    : Colors.blue[700],
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '$dateStr • $sizeInKB KB • ${isZipFile ? 'ZIP' : 'JSON'}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isZipFile
                                                    ? Colors.green[600]
                                                    : Colors.blue[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.orange[100],
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.restore,
                                              size: 14,
                                              color: Colors.orange[700],
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Restore',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.orange[700],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            })),
                            if (_backupFiles.length > 3) ...[
                              const SizedBox(height: 8),
                              Center(
                                child: TextButton.icon(
                                  onPressed: () => _showAllBackupFiles(),
                                  icon: Icon(Icons.list,
                                      size: 16, color: Colors.blue[600]),
                                  label: Text(
                                    'Lihat Semua File (${_backupFiles.length})',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue[600],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    backgroundColor: Colors.blue[50],
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.folder_open, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Belum ada file backup tersedia',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Info Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info, color: Colors.blue[700]),
                              const SizedBox(width: 8),
                              Text(
                                'Informasi Penting',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '• Backup akan menyimpan semua data inspeksi ke file ZIP\n'
                            '• Restore dengan 2 mode: Gabungkan atau Ganti Semua\n'
                            '• Tanggal inspeksi tetap terjaga (tidak mereset)\n'
                            '• File backup disimpan di Downloads folder\n'
                            '• Format ZIP yang lebih efisien dan Android-friendly\n'
                            '• Versi backup: 2.1 (dengan analisis data)\n'
                            '• Klik file backup untuk langsung restore\n'
                            '• Mendukung restore dari file JSON lama (legacy)\n'
                            '• Deteksi duplikat otomatis saat merge',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40), // Extra padding for scroll
                  ],
                ),
              ),
            ),
    );
  }
}
