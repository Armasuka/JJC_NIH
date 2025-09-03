import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/backup_restore_screen.dart';
import 'services/notification_service.dart';
import 'services/backup_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize services in parallel for faster loading
  await Future.wait([
    initializeDateFormatting('id_ID', null),
    Hive.initFlutter(),
    NotificationService().initialize(),
  ]);
  
  // Open Hive boxes
  await Future.wait([
    Hive.openBox('inspection_history'),
    Hive.openBox('drafts'),
  ]);
  
  // Check and perform auto-backup if needed
  _checkAutoBackup();
  
  final prefs = await SharedPreferences.getInstance();
  final onboardingDone = prefs.getBool('onboarding_done') ?? false;
  runApp(JasaMargaApp(onboardingDone: onboardingDone));
}

class JasaMargaApp extends StatefulWidget {
  final bool onboardingDone;
  const JasaMargaApp({super.key, required this.onboardingDone});

  @override
  State<JasaMargaApp> createState() => _JasaMargaAppState();
}

class _JasaMargaAppState extends State<JasaMargaApp> {
  String? _sharedFilePath;
  static const platform = MethodChannel('com.example.jasamarga_inspeksi/file_intent');

  @override
  void initState() {
    super.initState();
    _setupMethodChannel();
    _checkForSharedFile();
    // Check multiple times to catch files opened while app is starting
    Future.delayed(const Duration(milliseconds: 100), () {
      _checkForSharedFile();
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      _checkForSharedFile();
    });
    Future.delayed(const Duration(milliseconds: 1000), () {
      _checkForSharedFile();
    });
    Future.delayed(const Duration(milliseconds: 2000), () {
      _checkForSharedFile();
    });
    Future.delayed(const Duration(milliseconds: 3000), () {
      _checkForSharedFile();
    });
  }

  void _setupMethodChannel() {
    platform.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'fileReceived':
          final String filePath = call.arguments as String;
          print('File received from Android: $filePath');
          setState(() {
            _sharedFilePath = filePath;
          });
          break;
        default:
          print('Unknown method: ${call.method}');
      }
    });
  }

  void _checkForSharedFile() async {
    try {
      print('Checking for shared file...');
      final String? filePath = await platform.invokeMethod('getSharedFilePath');
      print('MethodChannel returned: $filePath');
      if (filePath != null && filePath.isNotEmpty) {
        print('Found shared file path: $filePath');
        setState(() {
          _sharedFilePath = filePath;
        });
        print('Set _sharedFilePath to: $_sharedFilePath');
      } else {
        print('No shared file found');
      }
    } catch (e) {
      print('Error checking for shared file: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    print('Building app with sharedFilePath: $_sharedFilePath');
    
    return MaterialApp(
      title: 'JASAMARGA INSPECTOR',
      theme: ThemeData(
        primaryColor: const Color(0xFFEBEC07),
        scaffoldBackgroundColor: const Color(0xFF2257C1), // Set background to match splash
        textTheme: GoogleFonts.poppinsTextTheme(),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEBEC07),
            foregroundColor: const Color(0xFF2257C1),
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF2257C1),
            side: const BorderSide(color: Color(0xFF2257C1)),
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF2257C1),
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFF2257C1);
            }
            return Colors.grey;
          }),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF2257C1),
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Color(0xFF2257C1),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      home: _sharedFilePath != null 
          ? _buildRestoreScreen() 
          : const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }

  Widget _buildRestoreScreen() {
    if (_sharedFilePath == null) return const SplashScreen();
    
    final file = File(_sharedFilePath!);
    final fileName = file.path.split('/').last;
    final fileExtension = fileName.split('.').last.toLowerCase();
    
    // Cek apakah file adalah backup yang valid
    if (fileExtension != 'zip' && fileExtension != 'json') {
      return _buildInvalidFileScreen();
    }
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Restore dari File'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2257C1),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              _sharedFilePath = null;
            });
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              fileExtension == 'zip' ? Icons.archive : Icons.insert_drive_file,
              size: 80,
              color: fileExtension == 'zip' ? Colors.green : Colors.blue,
            ),
            const SizedBox(height: 20),
            Text(
              'File Backup Ditemukan',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              fileName,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Text(
              'File ini akan digunakan untuk restore data inspeksi.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => BackupRestoreScreen(initialFile: file),
                  ),
                );
              },
              icon: const Icon(Icons.restore),
              label: const Text('Restore Data'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2257C1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                setState(() {
                  _sharedFilePath = null;
                });
              },
              child: const Text('Batal'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvalidFileScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('File Tidak Valid'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2257C1),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              _sharedFilePath = null;
            });
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.red,
            ),
            const SizedBox(height: 20),
            Text(
              'File Tidak Dikenali',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _sharedFilePath?.split('/').last ?? 'Unknown file',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Text(
              'File ini bukan file backup yang valid.\nHanya file .zip dan .json yang didukung.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _sharedFilePath = null;
                });
              },
              child: const Text('Kembali ke Aplikasi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2257C1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Function to check and perform auto-backup
void _checkAutoBackup() async {
  try {
    if (await BackupService.shouldPerformAutoBackup()) {
      print('Performing auto-backup...');
      await BackupService.performAutoBackup();
    }
    
    // Cleanup old backups
    await BackupService.cleanupOldBackups();
  } catch (e) {
    print('Error in auto-backup check: $e');
  }
}
