import 'dart:io';
import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:archive/archive.dart';
import 'pdf_storage_service.dart';

class BackupService {
  static const String _backupBoxName = 'backup_schedule';
  
  // Cek apakah perlu melakukan auto-backup
  static Future<bool> shouldPerformAutoBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final autoBackupEnabled = prefs.getBool('auto_backup_enabled') ?? false;
      
      if (!autoBackupEnabled) return false;
      
      final lastBackupTime = prefs.getString('last_auto_backup_time');
      final backupFrequency = prefs.getString('backup_frequency') ?? 'weekly';
      final backupHour = prefs.getInt('backup_time_hour') ?? 20;
      final backupMinute = prefs.getInt('backup_time_minute') ?? 0;
      
      if (lastBackupTime == null) {
        // Belum pernah backup, cek apakah sudah waktunya
        final now = DateTime.now();
        final backupTime = DateTime(now.year, now.month, now.day, backupHour, backupMinute);
        return now.isAfter(backupTime);
      }
      
      final lastBackup = DateTime.parse(lastBackupTime);
      final now = DateTime.now();
      
      // Cek apakah sudah waktunya untuk backup berikutnya
      switch (backupFrequency) {
        case 'daily':
          return now.difference(lastBackup).inDays >= 1;
        case 'weekly':
          return now.difference(lastBackup).inDays >= 7;
        case 'monthly':
          return now.difference(lastBackup).inDays >= 30;
        default:
          return false;
      }
    } catch (e) {
      print('Error checking auto-backup: $e');
      return false;
    }
  }
  
  // Lakukan auto-backup
  static Future<bool> performAutoBackup() async {
    try {
      // Ambil data dari Hive
      final box = Hive.box('inspection_history');
      final data = box.values.toList();
      
      if (data.isEmpty) {
        print('No data to backup');
        return true;
      }
      
      // Analisis data
      final dataAnalysis = _analyzeBackupData(data);
      
      // Buat backup data
      final backupData = {
        'version': '2.1',
        'timestamp': DateTime.now().toIso8601String(),
        'total_records': data.length,
        'app_name': 'Jasamarga Inspector',
        'backup_type': 'auto',
        'data_analysis': dataAnalysis,
        'backup_info': {
          'created_by': 'Jasamarga Inspector App (Auto-Backup)',
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
        throw Exception('Cannot access backup directory');
      }
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'auto_backup_inspeksi_${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}_${timestamp}.zip';
      final file = File('${backupDir.path}/$fileName');
      
      // Buat ZIP archive
      final archive = Archive();
      
      // Tambahkan file data.json
      final dataFile = ArchiveFile('data.json', jsonBytes.length, jsonBytes);
      archive.addFile(dataFile);
      
      // Tambahkan file PDF
      final pdfFiles = await PdfStorageService.getAllPdfFiles();
      int pdfCount = 0;
      for (final pdfFile in pdfFiles) {
        try {
          final pdfBytes = await pdfFile.readAsBytes();
          final fileName = pdfFile.path.split('/').last;
          final pdfArchiveFile = ArchiveFile('pdfs/$fileName', pdfBytes.length, pdfBytes);
          archive.addFile(pdfArchiveFile);
          pdfCount++;
        } catch (e) {
          print('Error adding PDF file ${pdfFile.path}: $e');
        }
      }
      
      // Tambahkan metadata
      final metadata = '''
Jasamarga Inspector - Auto Backup Data v2.1
==========================================
Tanggal Backup: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}
Waktu Backup: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}
Total Records: ${data.length}
Total PDF Files: $pdfCount
Versi Backup: 2.1
Tipe Backup: Auto-Backup

ANALISIS DATA:
${dataAnalysis['period_range']}
${dataAnalysis['vehicle_types']}
${dataAnalysis['total_vehicles']}

File ini dibuat secara otomatis oleh sistem backup.
        ''';
      final metadataBytes = utf8.encode(metadata);
      final metadataFile = ArchiveFile('metadata.txt', metadataBytes.length, metadataBytes);
      archive.addFile(metadataFile);
      
      // Encode dan tulis ZIP
      final zipData = ZipEncoder().encode(archive);
      if (zipData == null) {
        throw Exception('Failed to create ZIP file');
      }
      
      await file.writeAsBytes(zipData);
      
      // Update last backup time
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_auto_backup_time', DateTime.now().toIso8601String());
      
      print('Auto-backup completed: ${file.path}');
      return true;
    } catch (e) {
      print('Error performing auto-backup: $e');
      return false;
    }
  }
  
  // Mendapatkan direktori backup
  static Future<Directory?> _getBackupDirectory() async {
    try {
      Directory? externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        final backupDir = Directory('${externalDir.path}/backup');
        if (!await backupDir.exists()) {
          await backupDir.create(recursive: true);
        }
        return backupDir;
      }
      
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
  
  // Analisis data backup
  static Map<String, String> _analyzeBackupData(List data) {
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
        if (item['tanggal'] != null) {
          try {
            final date = DateTime.parse(item['tanggal']);
            dates.add(date);
          } catch (e) {
            print('Error parsing date: $e');
          }
        }

        final jenis = item['jenis']?.toString() ?? 'Unknown';
        vehicleTypes[jenis] = (vehicleTypes[jenis] ?? 0) + 1;

        final nopol = item['nopol']?.toString() ?? 'Unknown';
        vehicles.add(nopol);
      }
    }

    String periodRange = 'Tidak ada data tanggal';
    if (dates.isNotEmpty) {
      dates.sort();
      final startDate = dates.first;
      final endDate = dates.last;
      periodRange = 'Periode: ${startDate.day}/${startDate.month}/${startDate.year} - ${endDate.day}/${endDate.month}/${endDate.year}';
    }

    final vehicleTypesStr = vehicleTypes.entries
        .map((e) => '${e.key}: ${e.value}')
        .join(', ');

    return {
      'period_range': periodRange,
      'vehicle_types': 'Jenis: $vehicleTypesStr',
      'total_vehicles': 'Total kendaraan unik: ${vehicles.length}',
    };
  }
  
  // Cleanup backup files lama (hapus yang lebih dari 30 hari)
  static Future<void> cleanupOldBackups() async {
    try {
      final backupDir = await _getBackupDirectory();
      if (backupDir == null) return;
      
      final files = await backupDir.list().toList();
      final now = DateTime.now();
      
      for (final file in files) {
        if (file is File && (file.path.endsWith('.zip') || file.path.endsWith('.json'))) {
          try {
            final stat = await file.stat();
            final daysOld = now.difference(stat.modified).inDays;
            
            if (daysOld > 30) {
              await file.delete();
              print('Deleted old backup file: ${file.path}');
            }
          } catch (e) {
            print('Error checking file age: $e');
          }
        }
      }
    } catch (e) {
      print('Error cleaning up old backups: $e');
    }
  }
}
