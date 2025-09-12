import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hive/hive.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:signature/signature.dart';
import '../services/draft_service.dart';
import '../services/pdf_storage_service.dart';
import '../utils/logger.dart';

import 'success_screen.dart';

class FormAmbulanceScreen extends StatefulWidget {
  final Map<String, dynamic>? draftData;
  final String? draftKey;

  const FormAmbulanceScreen({
    super.key,
    this.draftData,
    this.draftKey,
  });

  @override
  State<FormAmbulanceScreen> createState() => _FormAmbulanceScreenState();
}

class _FormAmbulanceScreenState extends State<FormAmbulanceScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController petugas1Controller = TextEditingController();
  final TextEditingController petugas2Controller = TextEditingController();
  final TextEditingController nopolController = TextEditingController();
  final TextEditingController identitasKendaraanController =
      TextEditingController();
  final TextEditingController lokasiController = TextEditingController();
  final TextEditingController managerNameController = TextEditingController();
  final TextEditingController jjcNameController = TextEditingController();
  DateTime tanggal = DateTime.now();

  // Controller untuk foto bukti
  final ImagePicker _picker = ImagePicker();
  File? fotoStnk;
  File? fotoSim1;
  File? fotoSim2;
  File? fotoKir;
  File? fotoSertifikatParamedis;
  File? fotoService;
  File? fotoBbm;
  String? currentLocation;

  // Signature controllers
  final SignatureController signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  // Variables to store signatures
  Uint8List? petugas1Signature;
  Uint8List? petugas2Signature;
  Uint8List? managerSignature;
  Uint8List? jjcSignature;

  // Auto-save functionality
  Timer? _autoSaveTimer;
  bool _hasUnsavedChanges = false;
  bool _isFormSubmitted =
      false; // Flag to prevent auto-save after form submission
  static const Duration _autoSaveInterval = Duration(seconds: 30);

  final List<String> kondisiOptions = ['BAIK', 'RR', 'RB'];

  final List<String> kelengkapanSaranaList = [
    'Tas Medis',
    'Tensi Meter',
    'Stetoscope',
    'Thermo Meter Digital',
    'Tongue Spatel',
    'Resuscitate Marks/Air Bag',
    'Tromol Gas',
    'Tabung Oksigen',
    'Vertebrace Collars Set',
    'Kantong Jenazah',
    'Spalk Kayu Kaki & Tangan',
    'Spalk Leher',
    'Head Immobilizer',
    'Infus Set / Abocath',
    'Cairan Infus RL / NaCl',
    'Brankar / Scope',
    'Mitella',
    'Scoop Strecher / Tandu',
    'Long Spine Board (LSB)',
    'Selimut Penderita',
    'Kendrik Ekstation',
    'Obat-obatan',
    'Face Masker',
    'Sarung Tangan Karet',
    'Celemek'
  ];

  final List<String> kelengkapanKendaraanList = [
    'Kaca Spion Luar',
    'Kaca Spion Dalam',
    'Lampu Kecil',
    'Lampu Besar',
    'Lampu Sein Depan',
    'Lampu Sein Belakang',
    'Lampu Rem',
    'Rotator',
    'Ban Depan & Velg',
    'Ban Belakang &Velg',
    'Ban Cadangan & Velg',
    'Radio Kunikasi',
    'Antena',
    'Amply',
    'Public Address',
    'Sirine',
    'Wastafel Tempel',
    'Apar 6 Kg'
  ];

  final Map<String, Map<String, dynamic>> kelengkapanSarana = {};
  final Map<String, Map<String, dynamic>> kelengkapanKendaraan = {};

  final Map<String, TextEditingController> masaBerlakuController = {
    'STNK': TextEditingController(),
    'KIR': TextEditingController(),
    'SIM Operator 1': TextEditingController(),
    'SIM Operator 2': TextEditingController(),
    'Sertifikat Paramedis': TextEditingController(),
    'Service': TextEditingController(),
    'BBM': TextEditingController(),
  };

  @override
  void initState() {
    super.initState();
    for (var listName in [
      {'list': kelengkapanSaranaList, 'target': kelengkapanSarana},
      {'list': kelengkapanKendaraanList, 'target': kelengkapanKendaraan}
    ]) {
      final list = listName['list'] as List<String>;
      final target = listName['target'] as Map<String, Map<String, dynamic>>;
      for (var item in list) {
        target[item] = {
          'ada': false,
          'jumlah': TextEditingController(),
          'kondisi': 'BAIK'
        };
      }
    }

    // Start auto-save timer
    _startAutoSave();

    // Load draft if exists
    _loadDraft();

    // Check if there's a saved draft
    _checkForSavedDraft();
  }

  @override
  void dispose() {
    // Save draft before disposing if there are unsaved changes
    if (_hasUnsavedChanges) {
      _saveDraft();
    }
    _autoSaveTimer?.cancel();

    petugas1Controller.dispose();
    petugas2Controller.dispose();
    nopolController.dispose();
    identitasKendaraanController.dispose();
    lokasiController.dispose();
    managerNameController.dispose();
    jjcNameController.dispose();
    signatureController.dispose();
    for (var c in masaBerlakuController.values) {
      c.dispose();
    }
    for (var map in [kelengkapanSarana, kelengkapanKendaraan]) {
      for (var item in map.values) {
        (item['jumlah'] as TextEditingController).dispose();
      }
    }
    super.dispose();
  }

  // Auto-save methods
  void _startAutoSave() {
    _autoSaveTimer = Timer.periodic(_autoSaveInterval, (timer) {
      if (_hasUnsavedChanges && !_isFormSubmitted) {
        _saveDraft();
      }
    });
  }

  void _markAsChanged() {
    _hasUnsavedChanges = true;
  }

  Future<void> _saveDraft() async {
    try {
      final draftData = {
        'petugas1': petugas1Controller.text,
        'petugas2': petugas2Controller.text,
        'nopol': nopolController.text,
        'identitasKendaraan': identitasKendaraanController.text,
        'lokasi': lokasiController.text,
        'managerName': managerNameController.text,
        'jjcName': jjcNameController.text,
        'tanggal': tanggal.toIso8601String(),
        'masaBerlaku': Map.fromEntries(masaBerlakuController.entries
            .map((e) => MapEntry(e.key, e.value.text))),
        'kelengkapanSarana': _serializeChecklist(kelengkapanSarana),
        'kelengkapanKendaraan': _serializeChecklist(kelengkapanKendaraan),
        'signatures': {
          'petugas1': petugas1Signature != null
              ? base64Encode(petugas1Signature!)
              : null,
          'petugas2': petugas2Signature != null
              ? base64Encode(petugas2Signature!)
              : null,
          'manager':
              managerSignature != null ? base64Encode(managerSignature!) : null,
          'jjc': jjcSignature != null ? base64Encode(jjcSignature!) : null,
        },
        'photos': {
          'stnk': fotoStnk?.path,
          'kir': fotoKir?.path,
          'sim1': fotoSim1?.path,
          'sim2': fotoSim2?.path,
          'sertifikatParamedis': fotoSertifikatParamedis?.path,
          'service': fotoService?.path,
          'bbm': fotoBbm?.path,
        },
      };

      final success = await DraftService.saveDraft(
        formType: 'Ambulance',
        data: draftData,
      );

      // If this is a loaded draft, update the draft key
      if (widget.draftKey != null) {
        // Delete the old draft and save with the new key
        await DraftService.deleteDraft(widget.draftKey!);
      }

      if (success) {
        setState(() {
          _hasUnsavedChanges = false;
        });
        DraftService.debugPrintAllDrafts();
      } else {
        throw Exception('Failed to save draft via DraftService');
      }
    } catch (e) {
      print('❌ Error saving draft: $e');

      // Show error to user - gunakan addPostFrameCallback untuk memastikan widget sudah siap
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Error menyimpan draft: $e'),
                    ),
                  ],
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        });
      }
    }
  }

  Future<void> _loadDraft() async {
    try {
      // Only load draft if draft data is passed from constructor
      // For new forms, don't load any existing draft
      Map<String, dynamic>? draftData;
      if (widget.draftData != null) {
        draftData = widget.draftData;
      }
      // If widget.draftData is null, don't load any draft (this is a new form)

      if (draftData != null) {
        setState(() {
          petugas1Controller.text = (draftData!['petugas1'] as String?) ?? '';
          petugas2Controller.text = (draftData['petugas2'] as String?) ?? '';
          nopolController.text = (draftData['nopol'] as String?) ?? '';
          identitasKendaraanController.text =
              (draftData['identitasKendaraan'] as String?) ?? '';
          lokasiController.text = (draftData['lokasi'] as String?) ?? '';
          managerNameController.text =
              (draftData['managerName'] as String?) ?? '';
          jjcNameController.text = (draftData['jjcName'] as String?) ?? '';

          // Load masa berlaku
          final masaBerlaku =
              draftData['masaBerlaku'] as Map<String, dynamic>? ?? {};
          for (var entry in masaBerlaku.entries) {
            if (masaBerlakuController.containsKey(entry.key)) {
              masaBerlakuController[entry.key]!.text =
                  (entry.value as String?) ?? '';
            }
          }

          // Load checklists
          _deserializeChecklist(
              draftData['kelengkapanSarana'] as Map<String, dynamic>? ?? {},
              kelengkapanSarana);
          _deserializeChecklist(
              draftData['kelengkapanKendaraan'] as Map<String, dynamic>? ?? {},
              kelengkapanKendaraan);

          // Load signatures
          final signatures =
              draftData['signatures'] as Map<String, dynamic>? ?? {};
          if (signatures['petugas1'] != null) {
            petugas1Signature = base64Decode(signatures['petugas1'] as String);
          }
          if (signatures['petugas2'] != null) {
            petugas2Signature = base64Decode(signatures['petugas2'] as String);
          }
          if (signatures['manager'] != null) {
            managerSignature = base64Decode(signatures['manager'] as String);
          }
          if (signatures['jjc'] != null) {
            jjcSignature = base64Decode(signatures['jjc'] as String);
          }

          // Load photos
          final photos = draftData['photos'] as Map<String, dynamic>? ?? {};
          if (photos['stnk'] != null) fotoStnk = File(photos['stnk'] as String);
          if (photos['kir'] != null) fotoKir = File(photos['kir'] as String);
          if (photos['sim1'] != null) fotoSim1 = File(photos['sim1'] as String);
          if (photos['sim2'] != null) fotoSim2 = File(photos['sim2'] as String);
          if (photos['sertifikatParamedis'] != null)
            fotoSertifikatParamedis =
                File(photos['sertifikatParamedis'] as String);
          if (photos['service'] != null)
            fotoService = File(photos['service'] as String);
          if (photos['bbm'] != null) fotoBbm = File(photos['bbm'] as String);
        });

        _checkForSavedDraft();
      }
    } catch (e) {
      print('Error loading draft: $e');
    }
  }

  Map<String, dynamic> _serializeChecklist(
      Map<String, Map<String, dynamic>> checklist) {
    final serialized = <String, Map<String, dynamic>>{};
    for (var entry in checklist.entries) {
      serialized[entry.key] = {
        'ada': entry.value['ada'],
        'jumlah': (entry.value['jumlah'] as TextEditingController).text,
        'kondisi': entry.value['kondisi'],
      };
    }
    return serialized;
  }

  void _deserializeChecklist(Map<String, dynamic> serialized,
      Map<String, Map<String, dynamic>> checklist) {
    for (var entry in serialized.entries) {
      if (checklist.containsKey(entry.key)) {
        checklist[entry.key]!['ada'] = entry.value['ada'] ?? false;
        (checklist[entry.key]!['jumlah'] as TextEditingController).text =
            entry.value['jumlah'] ?? '';
        checklist[entry.key]!['kondisi'] = entry.value['kondisi'] ?? 'BAIK';
      }
    }
  }

  Future<void> _clearDraft() async {
    // Use the specific draft key if available, otherwise use default
    final draftKey = widget.draftKey ?? 'ambulance_draft';
    final success = await DraftService.deleteDraft(draftKey);
    if (success) {
      setState(() {
        _hasUnsavedChanges = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.delete, color: Colors.white),
                SizedBox(width: 8),
                Text('🗑️ Draft berhasil dihapus'),
              ],
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _checkForSavedDraft() {
    final draftExists = DraftService.loadDraft('ambulance_draft') != null;
    if (draftExists && mounted) {
      // Gunakan addPostFrameCallback untuk memastikan widget sudah siap
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.info, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('📋 Draft ditemukan dan telah dimuat'),
                  ),
                ],
              ),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'OK',
                textColor: Colors.white,
                onPressed: () {},
              ),
            ),
          );
        }
      });
    }
  }

  // Method untuk mendapatkan lokasi terkini
  Future<void> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lokasi tidak tersedia')),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Izin lokasi ditolak')),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Izin lokasi ditolak permanen')),
        );
        return;
      }

      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        currentLocation = '${position.latitude}, ${position.longitude}';
        lokasiController.text = currentLocation!;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error mendapatkan lokasi: $e')),
      );
    }
  }

  // Method untuk menangani signature
  Future<void> handleSignature(String type) async {
    try {
      final signature = await signatureController.toPngBytes();
      if (signature != null) {
        setState(() {
          switch (type) {
            case 'petugas1':
              petugas1Signature = signature;
              break;
            case 'petugas2':
              petugas2Signature = signature;
              break;
            case 'manager':
              managerSignature = signature;
              break;
            case 'jjc':
              jjcSignature = signature;
              break;
          }
        });
        signatureController.clear();
        Navigator.of(context).pop();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error menyimpan tanda tangan: $e')),
      );
    }
  }

  // Method untuk menampilkan dialog signature
  void showSignatureDialog(String type, String title) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 300,
            height: 200,
            child: Signature(
              controller: signatureController,
              backgroundColor: Colors.white,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                signatureController.clear();
                Navigator.of(context).pop();
              },
              child: const Text('Clear'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => handleSignature(type),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2257C1),
                foregroundColor: Colors.white,
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  // Method untuk mengambil foto
  Future<void> pickImage(String type) async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.camera);
      if (image != null) {
        setState(() {
          switch (type) {
            case 'stnk':
              fotoStnk = File(image.path);
              break;
            case 'sim1':
              fotoSim1 = File(image.path);
              break;
            case 'sim2':
              fotoSim2 = File(image.path);
              break;
            case 'kir':
              fotoKir = File(image.path);
              break;
            case 'sertifikatParamedis':
              fotoSertifikatParamedis = File(image.path);
              break;
            case 'service':
              fotoService = File(image.path);
              break;
            case 'bbm':
              fotoBbm = File(image.path);
              break;
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error mengambil foto: $e')),
      );
    }
  }

  Widget buildChecklist(
      String title, Map<String, Map<String, dynamic>> dataMap) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Color(0xFF2257C1),
              ),
            ),
            const Divider(height: 24),
            ...dataMap.keys.map((item) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Theme(
                            data: Theme.of(context).copyWith(
                              unselectedWidgetColor: Colors.grey[600],
                            ),
                            child: Checkbox(
                              value: dataMap[item]!['ada'] as bool,
                              onChanged: (val) {
                                setState(() {
                                  dataMap[item]!['ada'] = val ?? false;
                                  // Jika tidak diceklis, bersihkan field jumlah dan set kondisi ke default
                                  if (!(val ?? false)) {
                                    (dataMap[item]!['jumlah']
                                            as TextEditingController)
                                        .clear();
                                    dataMap[item]!['kondisi'] = 'BAIK';
                                  }
                                });
                                _markAsChanged();
                              },
                              activeColor: const Color(0xFF2257C1),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              item,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const SizedBox(width: 48),
                          Expanded(
                            child: Container(
                              height: 40,
                              decoration: BoxDecoration(
                                color: (dataMap[item]!['ada'] as bool)
                                    ? Colors.white
                                    : Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: (dataMap[item]!['ada'] as bool)
                                        ? Colors.grey[400]!
                                        : Colors.grey[300]!),
                              ),
                              child: TextField(
                                controller: dataMap[item]!['jumlah']
                                    as TextEditingController,
                                keyboardType: TextInputType.number,
                                enabled: dataMap[item]!['ada'] as bool,
                                decoration: InputDecoration(
                                  labelText: 'Jumlah',
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  hintStyle: TextStyle(
                                    color: (dataMap[item]!['ada'] as bool)
                                        ? Colors.grey[600]
                                        : Colors.grey[400],
                                  ),
                                ),
                                onChanged: (value) => _markAsChanged(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: (dataMap[item]!['ada'] as bool)
                                  ? Colors.white
                                  : Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: (dataMap[item]!['ada'] as bool)
                                      ? Colors.grey[400]!
                                      : Colors.grey[300]!),
                            ),
                            child: DropdownButton<String>(
                              value: dataMap[item]!['kondisi'] as String,
                              underline: const SizedBox(),
                              items: kondisiOptions
                                  .map((k) => DropdownMenuItem(
                                        value: k,
                                        child: Text(k == 'RR'
                                            ? 'RUSAK RINGAN'
                                            : k == 'RB'
                                                ? 'RUSAK BERAT'
                                                : k),
                                      ))
                                  .toList(),
                              onChanged: (dataMap[item]!['ada'] as bool)
                                  ? (val) {
                                      setState(() =>
                                          dataMap[item]!['kondisi'] = val!);
                                      _markAsChanged();
                                    }
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget buildMasaBerlakuFields() {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masa Berlaku Dokumen',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Color(0xFF2257C1),
              ),
            ),
            const Divider(height: 24),
            ...masaBerlakuController.keys.map((key) {
              if (key == 'BBM') {
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: TextFormField(
                    controller: masaBerlakuController[key],
                    decoration: InputDecoration(
                      labelText: 'Status BBM',
                      prefixIcon: const Icon(Icons.local_gas_station),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (value) => _markAsChanged(),
                  ),
                );
              } else {
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: GestureDetector(
                    onTap: () async {
                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.tryParse(
                                masaBerlakuController[key]!.text) ??
                            DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() {
                          masaBerlakuController[key]!.text =
                              "${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                          _markAsChanged();
                        });
                      }
                    },
                    child: AbsorbPointer(
                      child: TextFormField(
                        controller: masaBerlakuController[key],
                        decoration: InputDecoration(
                          labelText: 'Masa Berlaku $key',
                          prefixIcon: const Icon(Icons.calendar_today),
                          suffixIcon: const Icon(Icons.arrow_drop_down),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        validator: (val) =>
                            val == null || val.isEmpty ? 'Wajib diisi' : null,
                      ),
                    ),
                  ),
                );
              }
            }),
          ],
        ),
      ),
    );
  }

  // Helper function untuk membaca foto dengan aman
  pw.Widget _buildSafeImage(File file, pw.Font font) {
    try {
      return pw.Image(
        pw.MemoryImage(file.readAsBytesSync()),
        width: 200,
        height: 150,
        fit: pw.BoxFit.contain,
      );
    } catch (e) {
      return pw.Container(
        width: 200,
        height: 150,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(width: 1, color: PdfColors.grey400),
          color: PdfColors.grey100,
        ),
        child: pw.Center(
          child: pw.Text(
            'Gagal memuat foto',
            style: pw.TextStyle(
                font: font, fontSize: 10, color: PdfColors.grey600),
          ),
        ),
      );
    }
  }

  Future<void> generatePdf() async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Membuat PDF...'),
            ],
          ),
        );
      },
    );

    try {
      final pdf = pw.Document();
      final font = await PdfGoogleFonts.nunitoRegular();
      final fontBold = await PdfGoogleFonts.nunitoBold();
      final hariList = [
        'Minggu',
        'Senin',
        'Selasa',
        'Rabu',
        'Kamis',
        'Jumat',
        'Sabtu'
      ];
      final hari = hariList[tanggal.weekday % 7];
      final logoBytes = await rootBundle.load('assets/logo_jjc.png');
      final logo = pw.MemoryImage(logoBytes.buffer.asUint8List());

      pw.Widget buildTableSection(
          String sectionTitle, Map<String, Map<String, dynamic>> dataMap) {
        int idx = 1;
        return pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header section tanpa border
              pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.grey200,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Text(sectionTitle,
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        font: fontBold,
                        fontSize: 13)),
              ),
              pw.SizedBox(height: 4),
              // Tabel tanpa border dan lebih compact
              pw.Table(
                border: pw.TableBorder.all(
                    width: 0), // Menghilangkan semua border dengan width 0
                columnWidths: {
                  0: const pw.FixedColumnWidth(25), // No - diperbesar sedikit
                  1: const pw.FlexColumnWidth(1.0), // Uraian - diperkecil lagi
                  2: const pw.FixedColumnWidth(35), // Ada - diperbesar lagi
                  3: const pw.FixedColumnWidth(35), // Tidak - diperbesar lagi
                  4: const pw.FixedColumnWidth(45), // Jumlah - diperbesar lagi
                  5: const pw.FixedColumnWidth(35), // Baik - diperbesar lagi
                  6: const pw.FixedColumnWidth(35), // RR - diperbesar lagi
                  7: const pw.FixedColumnWidth(35), // RB - diperbesar lagi
                },
                children: [
                  // Header row dengan background abu-abu muda
                  pw.TableRow(
                    decoration:
                        const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                            vertical: 3, horizontal: 2),
                        child: pw.Center(
                            child: pw.Text('NO',
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    font: fontBold,
                                    fontSize: 10))),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                            vertical: 3, horizontal: 4),
                        child: pw.Center(
                            child: pw.Text('URAIAN',
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    font: fontBold,
                                    fontSize: 10))),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 3),
                        child: pw.Center(
                            child: pw.Text('ADA',
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    font: fontBold,
                                    fontSize: 10))),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 3),
                        child: pw.Center(
                            child: pw.Text('TIDAK',
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    font: fontBold,
                                    fontSize: 9))),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 3),
                        child: pw.Center(
                            child: pw.Text('JUMLAH',
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    font: fontBold,
                                    fontSize: 9))),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 3),
                        child: pw.Center(
                            child: pw.Text('BAIK',
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    font: fontBold,
                                    fontSize: 10))),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 3),
                        child: pw.Center(
                            child: pw.Text('RR',
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    font: fontBold,
                                    fontSize: 10))),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 3),
                        child: pw.Center(
                            child: pw.Text('RB',
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    font: fontBold,
                                    fontSize: 10))),
                      ),
                    ],
                  ),
                  // Data rows dengan alternating background untuk readability
                  ...dataMap.entries.map((entry) {
                    final no = idx++;
                    final ada = entry.value['ada'] == true;
                    final kondisi = entry.value['kondisi'] ?? '';
                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: no % 2 == 0 ? PdfColors.grey50 : PdfColors.white,
                      ),
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              vertical: 2, horizontal: 2),
                          child: pw.Center(
                              child: pw.Text(no.toString(),
                                  style:
                                      pw.TextStyle(font: font, fontSize: 10))),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              vertical: 2, horizontal: 4),
                          child: pw.Text(entry.key,
                              style: pw.TextStyle(font: font, fontSize: 10)),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(vertical: 2),
                          child: pw.Center(
                            child: ada
                                ? pw.Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const pw.BoxDecoration(
                                      color: PdfColors.black,
                                      shape: pw.BoxShape.circle,
                                    ),
                                  )
                                : pw.SizedBox(width: 8, height: 8),
                          ),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(vertical: 2),
                          child: pw.Center(
                            child: !ada
                                ? pw.Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const pw.BoxDecoration(
                                      color: PdfColors.black,
                                      shape: pw.BoxShape.circle,
                                    ),
                                  )
                                : pw.SizedBox(width: 8, height: 8),
                          ),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              vertical: 2, horizontal: 2),
                          child: pw.Center(
                            child: pw.Text(
                              (entry.value['jumlah'] as TextEditingController)
                                      .text
                                      .isNotEmpty
                                  ? (entry.value['jumlah']
                                          as TextEditingController)
                                      .text
                                  : '-',
                              style: pw.TextStyle(font: font, fontSize: 9),
                            ),
                          ),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(vertical: 2),
                          child: pw.Center(
                            child: kondisi == 'BAIK'
                                ? pw.Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const pw.BoxDecoration(
                                      color: PdfColors.black,
                                      shape: pw.BoxShape.circle,
                                    ),
                                  )
                                : pw.SizedBox(width: 8, height: 8),
                          ),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(vertical: 2),
                          child: pw.Center(
                            child: kondisi == 'RR'
                                ? pw.Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const pw.BoxDecoration(
                                      color: PdfColors.black,
                                      shape: pw.BoxShape.circle,
                                    ),
                                  )
                                : pw.SizedBox(width: 8, height: 8),
                          ),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(vertical: 2),
                          child: pw.Center(
                            child: kondisi == 'RB'
                                ? pw.Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const pw.BoxDecoration(
                                      color: PdfColors.black,
                                      shape: pw.BoxShape.circle,
                                    ),
                                  )
                                : pw.SizedBox(width: 8, height: 8),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ],
          ),
        );
      }

      // Halaman 1 - Header, Kelengkapan Sarana, dan Tanda Tangan Petugas 1
      pdf.addPage(
        pw.MultiPage(
          margin: const pw.EdgeInsets.symmetric(horizontal: 50, vertical: 10),
          maxPages: 1,
          build: (context) => [
            // Header yang lebih compact
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Image(logo, width: 150, height: 150),
                  pw.SizedBox(height: 10),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('FORM INSPEKSI KENDARAAN AMBULANCE',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              font: fontBold,
                              fontSize: 12)),
                      pw.Text(
                          'HARI: $hari | TANGGAL: ${tanggal.toLocal().toString().split(' ')[0]}',
                          style: pw.TextStyle(font: font, fontSize: 11)),
                      pw.Text(
                          'NO. POLISI: ${nopolController.text} | IDENTITAS: ${identitasKendaraanController.text}',
                          style: pw.TextStyle(font: font, fontSize: 11)),
                      pw.Text(
                          'LOKASI: ${lokasiController.text.isNotEmpty ? lokasiController.text : '-'}',
                          style: pw.TextStyle(font: font, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 6),

            // Kelengkapan Sarana
            buildTableSection('KELENGKAPAN SARANA', kelengkapanSarana),
            pw.SizedBox(height: 8),

            // Tanda tangan - Hanya Petugas 1
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.start,
              children: [
                pw.Column(
                  children: [
                    petugas1Signature != null
                        ? pw.Image(pw.MemoryImage(petugas1Signature!),
                            width: 120, height: 50)
                        : pw.Container(
                            width: 120,
                            height: 50,
                            decoration: const pw.BoxDecoration(
                              border:
                                  pw.Border(bottom: pw.BorderSide(width: 1)),
                            ),
                          ),
                    pw.SizedBox(height: 4),
                    pw.Text('Petugas 1',
                        style: pw.TextStyle(font: fontBold, fontSize: 11)),
                    pw.Text('(${petugas1Controller.text})',
                        style: pw.TextStyle(font: font, fontSize: 9)),
                  ],
                ),
              ],
            ),
          ],
        ),
      );

      // Halaman 2 - Kelengkapan Kendaraan dan Masa Berlaku Dokumen (jika diperlukan)
      if (kelengkapanKendaraan.isNotEmpty ||
          masaBerlakuController.values
              .any((controller) => controller.text.isNotEmpty)) {
        pdf.addPage(
          pw.MultiPage(
            margin: const pw.EdgeInsets.symmetric(horizontal: 50, vertical: 10),
            maxPages: 1,
            build: (context) => [
              // Header yang sama
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Image(logo, width: 150, height: 150),
                    pw.SizedBox(height: 10),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('FORM INSPEKSI KENDARAAN AMBULANCE',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                font: fontBold,
                                fontSize: 12)),
                        pw.Text(
                            'HARI: $hari | TANGGAL: ${tanggal.toLocal().toString().split(' ')[0]}',
                            style: pw.TextStyle(font: font, fontSize: 11)),
                        pw.Text(
                            'NO. POLISI: ${nopolController.text} | IDENTITAS: ${identitasKendaraanController.text}',
                            style: pw.TextStyle(font: font, fontSize: 11)),
                        pw.Text(
                            'LOKASI: ${lokasiController.text.isNotEmpty ? lokasiController.text : '-'}',
                            style: pw.TextStyle(font: font, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 6),

              // Kelengkapan Kendaraan
              buildTableSection('KELENGKAPAN KENDARAAN', kelengkapanKendaraan),
              pw.SizedBox(height: 8),

              // Masa Berlaku Dokumen yang lebih compact
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 0.5, color: PdfColors.grey300),
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('MASA BERLAKU DOKUMEN',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            font: fontBold,
                            fontSize: 12)),
                    pw.SizedBox(height: 4),
                    pw.Table(
                      border: pw.TableBorder.all(width: 0),
                      columnWidths: {
                        for (int i = 0; i < masaBerlakuController.length; i++)
                          i: const pw.FlexColumnWidth(1),
                      },
                      children: [
                        pw.TableRow(
                          decoration:
                              const pw.BoxDecoration(color: PdfColors.grey100),
                          children: masaBerlakuController.keys
                              .map((k) => pw.Container(
                                    padding: const pw.EdgeInsets.symmetric(
                                        vertical: 3, horizontal: 4),
                                    child: pw.Center(
                                      child: pw.Text(k,
                                          style: pw.TextStyle(
                                              font: fontBold,
                                              fontSize: 10,
                                              fontWeight: pw.FontWeight.bold)),
                                    ),
                                  ))
                              .toList(),
                        ),
                        pw.TableRow(
                          children: masaBerlakuController.values
                              .map((v) => pw.Container(
                                    padding: const pw.EdgeInsets.symmetric(
                                        vertical: 3, horizontal: 4),
                                    child: pw.Center(
                                      child: pw.Text(
                                          v.text.isNotEmpty ? v.text : '-',
                                          style: pw.TextStyle(
                                              font: font, fontSize: 10)),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 15),

              // Tanda tangan PT JMTO Manager Traffic dan PT JJC - diposisikan lebih ke tengah
              pw.Container(
                margin: const pw.EdgeInsets.symmetric(horizontal: 50),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                  children: [
                    // Tanda tangan PT JMTO Manager Traffic
                    pw.Column(
                      children: [
                        pw.Text('Mengetahui,',
                            style: pw.TextStyle(font: font, fontSize: 11)),
                        pw.Text('PT JMTO',
                            style: pw.TextStyle(
                                font: fontBold,
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 6),
                        managerSignature != null
                            ? pw.Image(pw.MemoryImage(managerSignature!),
                                width: 100, height: 40)
                            : pw.Container(
                                width: 100,
                                height: 40,
                                decoration: const pw.BoxDecoration(
                                  border: pw.Border(
                                      bottom: pw.BorderSide(width: 1)),
                                ),
                              ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                            '(${managerNameController.text.isNotEmpty ? managerNameController.text : '_____________'})',
                            style: pw.TextStyle(font: font, fontSize: 9)),
                      ],
                    ),
                    // Tanda tangan PT JJC dengan NIK
                    pw.Column(
                      children: [
                        pw.Text('Mengetahui,',
                            style: pw.TextStyle(font: font, fontSize: 11)),
                        pw.Text('PT.JJC',
                            style: pw.TextStyle(
                                font: fontBold,
                                fontSize: 11,
                                fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 6),
                        jjcSignature != null
                            ? pw.Image(pw.MemoryImage(jjcSignature!),
                                width: 100, height: 40)
                            : pw.Container(
                                width: 100,
                                height: 40,
                                decoration: const pw.BoxDecoration(
                                  border: pw.Border(
                                      bottom: pw.BorderSide(width: 1)),
                                ),
                              ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                            '(${jjcNameController.text.isNotEmpty ? jjcNameController.text : '_____________'})',
                            style: pw.TextStyle(font: font, fontSize: 9)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }

      // Halaman 3 - Lampiran (jika ada foto)
      if (fotoStnk != null ||
          fotoSim1 != null ||
          fotoSim2 != null ||
          fotoKir != null ||
          fotoSertifikatParamedis != null ||
          fotoService != null ||
          fotoBbm != null) {
        // Buat list foto yang ada
        List<Map<String, dynamic>> fotoList = [];
        if (fotoStnk != null)
          fotoList.add({'title': 'Bukti STNK:', 'file': fotoStnk});
        if (fotoSim1 != null)
          fotoList.add({'title': 'Bukti SIM Operator 1:', 'file': fotoSim1});
        if (fotoSim2 != null)
          fotoList.add({'title': 'Bukti SIM Operator 2:', 'file': fotoSim2});
        if (fotoKir != null)
          fotoList.add({'title': 'Bukti KIR:', 'file': fotoKir});
        if (fotoSertifikatParamedis != null)
          fotoList.add({
            'title': 'Bukti Sertifikat Paramedis:',
            'file': fotoSertifikatParamedis
          });
        if (fotoService != null)
          fotoList.add({'title': 'Bukti Service:', 'file': fotoService});
        if (fotoBbm != null)
          fotoList.add({'title': 'Bukti BBM:', 'file': fotoBbm});

        // Bagi foto menjadi halaman dengan maksimal 3 foto per halaman
        for (int i = 0; i < fotoList.length; i += 3) {
          List<Map<String, dynamic>> pageFotos =
              fotoList.skip(i).take(3).toList();

          pdf.addPage(
            pw.MultiPage(
              margin:
                  const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              build: (context) => [
                // Header yang konsisten dengan halaman lain
                pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Image(logo, width: 120, height: 120),
                      pw.SizedBox(height: 8),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('FORM INSPEKSI KENDARAAN AMBULANCE',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  font: fontBold,
                                  fontSize: 11)),
                          pw.Text(
                              'HARI: $hari | TANGGAL: ${tanggal.toLocal().toString().split(' ')[0]}',
                              style: pw.TextStyle(font: font, fontSize: 9)),
                          pw.Text(
                              'NO. POLISI: ${nopolController.text} | IDENTITAS: ${identitasKendaraanController.text}',
                              style: pw.TextStyle(font: font, fontSize: 9)),
                          pw.Text(
                              'LOKASI: ${lokasiController.text.isNotEmpty ? lokasiController.text : '-'}',
                              style: pw.TextStyle(font: font, fontSize: 9)),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 10),

                // Judul Lampiran Foto
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Text('LAMPIRAN FOTO BUKTI',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          font: fontBold,
                          fontSize: 16)),
                ),
                pw.SizedBox(height: 15),
                ...pageFotos
                    .map((foto) => [
                          pw.Container(
                            padding: const pw.EdgeInsets.all(12),
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(
                                  width: 1, color: PdfColors.grey400),
                              borderRadius: const pw.BorderRadius.all(
                                  pw.Radius.circular(8)),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(foto['title'],
                                    style: pw.TextStyle(
                                        fontWeight: pw.FontWeight.bold,
                                        font: fontBold,
                                        fontSize: 12)),
                                pw.SizedBox(height: 8),
                                pw.Center(
                                  child: _buildSafeImage(foto['file'], font),
                                ),
                              ],
                            ),
                          ),
                          pw.SizedBox(height: 10),
                        ])
                    .expand((element) => element),
              ],
            ),
          );
        }
      }

      // Simpan riwayat inspeksi ke Hive terlebih dahulu
      final box = Hive.box('inspection_history');
      final id = DateTime.now().millisecondsSinceEpoch.toString();

      // Simpan PDF ke storage lokal
      final pdfPath = await PdfStorageService.savePdf(id, pdf);

      // Copy ke Downloads dengan nama yang sesuai
      const vehicleName = 'Ambulance';
      final vehicleId =
          nopolController.text.isNotEmpty ? nopolController.text : 'Unknown';
      final fileName =
          '${vehicleName}_${vehicleId}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }
      final downloadFile = File('${downloadsDir.path}/$fileName');
      final pdfBytes = await pdf.save();
      await downloadFile.writeAsBytes(pdfBytes);

      // Dismiss loading dialog after successful PDF generation
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Generate and print PDF with delay and better error handling
      try {
        await Future.delayed(const Duration(milliseconds: 500));
        await Printing.layoutPdf(
          onLayout: (format) => pdfBytes,
          name: fileName,
        );
      } catch (printError) {
        Logger.error('Printing error: $printError');
        // Show error but don't fail the entire process
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'PDF berhasil disimpan, tetapi gagal mencetak: $printError'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }

      box.add({
        'id': id,
        'jenis': 'Ambulance',
        'tanggal': tanggal.toIso8601String(),
        'nopol': nopolController.text,
        'petugas1': petugas1Controller.text,
        'petugas2': petugas2Controller.text,
        'lokasi': lokasiController.text,
        'pdfPath': pdfPath, // Path ke file PDF yang tersimpan
        'kelengkapanSarana': kelengkapanSarana.map((k, v) => MapEntry(k, {
              'ada': v['ada'],
              'jumlah': v['jumlah'].text,
              'kondisi': v['kondisi'],
            })),
        'kelengkapanKendaraan': kelengkapanKendaraan.map((k, v) => MapEntry(k, {
              'ada': v['ada'],
              'jumlah': v['jumlah'].text,
              'kondisi': v['kondisi'],
            })),
        'masaBerlaku': masaBerlakuController.map((k, v) => MapEntry(k, v.text)),
        'fotos': {
          'stnk': fotoStnk?.path,
          'sim1': fotoSim1?.path,
          'sim2': fotoSim2?.path,
          'kir': fotoKir?.path,
          'service': fotoService?.path,
          'bbm': fotoBbm?.path,
        },
      });

      // Clear draft after successful PDF generation
      await _clearDraft();

      // Navigate to success screen
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => SuccessScreen(
              title: 'Form Ambulance Berhasil Disimpan',
              message:
                  'Data inspeksi kendaraan Ambulance telah berhasil disimpan dan PDF telah dibuat.',
              pdfPath: downloadFile.path,
            ),
          ),
        );
      }
    } catch (e) {
      // Dismiss loading dialog if error occurs
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Form Ambulance'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2257C1),
        elevation: 2,
        actions: [
          // Draft indicator
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _hasUnsavedChanges ? Colors.orange : Colors.grey,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _hasUnsavedChanges ? Icons.save : Icons.check_circle,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  _hasUnsavedChanges ? 'Draft' : 'Saved',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card Informasi Dasar
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Informasi Dasar',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Color(0xFF2257C1),
                        ),
                      ),
                      const Divider(height: 24),
                      TextFormField(
                        controller: petugas1Controller,
                        decoration: InputDecoration(
                          labelText: 'Nama Petugas 1',
                          prefixIcon: const Icon(Icons.person),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        validator: (val) =>
                            val == null || val.isEmpty ? 'Wajib diisi' : null,
                        onChanged: (value) => _markAsChanged(),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: petugas2Controller,
                        decoration: InputDecoration(
                          labelText: 'Nama Petugas 2',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        validator: (val) =>
                            val == null || val.isEmpty ? 'Wajib diisi' : null,
                        onChanged: (value) => _markAsChanged(),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: nopolController,
                        decoration: InputDecoration(
                          labelText: 'Nomor Polisi',
                          prefixIcon: const Icon(Icons.directions_car),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        validator: (val) =>
                            val == null || val.isEmpty ? 'Wajib diisi' : null,
                        onChanged: (value) => _markAsChanged(),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: identitasKendaraanController,
                        decoration: InputDecoration(
                          labelText: 'Identitas Kendaraan',
                          prefixIcon: const Icon(Icons.badge),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        validator: (val) =>
                            val == null || val.isEmpty ? 'Wajib diisi' : null,
                        onChanged: (value) => _markAsChanged(),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: lokasiController,
                              decoration: InputDecoration(
                                labelText: 'Lokasi Terkini *',
                                prefixIcon: const Icon(Icons.location_on),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                errorStyle: const TextStyle(color: Colors.red),
                              ),
                              readOnly: true,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Lokasi wajib diisi';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF2257C1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              onPressed: () async {
                                try {
                                  await getCurrentLocation();
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e')),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.my_location,
                                  color: Colors.white),
                              tooltip: 'Dapatkan Lokasi',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Checklist sections
              buildChecklist('Kelengkapan Sarana', kelengkapanSarana),
              buildChecklist('Kelengkapan Kendaraan', kelengkapanKendaraan),
              buildMasaBerlakuFields(),

              const SizedBox(height: 16),

              // Card Foto Bukti - Dipindah ke bawah
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Foto Bukti Dokumen',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Color(0xFF2257C1),
                        ),
                      ),
                      const Divider(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: fotoStnk != null
                                    ? Colors.green
                                    : const Color(0xFFEBEC07),
                                foregroundColor: fotoStnk != null
                                    ? Colors.white
                                    : const Color(0xFF2257C1),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () async {
                                try {
                                  await pickImage('stnk');
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e')),
                                    );
                                  }
                                }
                              },
                              icon: Icon(fotoStnk != null
                                  ? Icons.check_circle
                                  : Icons.camera_alt),
                              label: Text(
                                  fotoStnk != null ? 'STNK ✓' : 'Foto STNK'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: fotoKir != null
                                    ? Colors.green
                                    : const Color(0xFFEBEC07),
                                foregroundColor: fotoKir != null
                                    ? Colors.white
                                    : const Color(0xFF2257C1),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () async {
                                try {
                                  await pickImage('kir');
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e')),
                                    );
                                  }
                                }
                              },
                              icon: Icon(fotoKir != null
                                  ? Icons.check_circle
                                  : Icons.camera_alt),
                              label:
                                  Text(fotoKir != null ? 'KIR ✓' : 'Foto KIR'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: fotoSim1 != null
                                    ? Colors.green
                                    : const Color(0xFFEBEC07),
                                foregroundColor: fotoSim1 != null
                                    ? Colors.white
                                    : const Color(0xFF2257C1),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () async {
                                try {
                                  await pickImage('sim1');
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e')),
                                    );
                                  }
                                }
                              },
                              icon: Icon(fotoSim1 != null
                                  ? Icons.check_circle
                                  : Icons.camera_alt),
                              label: Text(
                                  fotoSim1 != null ? 'SIM 1 ✓' : 'Foto SIM 1'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: fotoSim2 != null
                                    ? Colors.green
                                    : const Color(0xFFEBEC07),
                                foregroundColor: fotoSim2 != null
                                    ? Colors.white
                                    : const Color(0xFF2257C1),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () async {
                                try {
                                  await pickImage('sim2');
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e')),
                                    );
                                  }
                                }
                              },
                              icon: Icon(fotoSim2 != null
                                  ? Icons.check_circle
                                  : Icons.camera_alt),
                              label: Text(
                                  fotoSim2 != null ? 'SIM 2 ✓' : 'Foto SIM 2'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: fotoSertifikatParamedis != null
                                    ? Colors.green
                                    : const Color(0xFFEBEC07),
                                foregroundColor: fotoSertifikatParamedis != null
                                    ? Colors.white
                                    : const Color(0xFF2257C1),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () async {
                                try {
                                  await pickImage('sertifikatParamedis');
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e')),
                                    );
                                  }
                                }
                              },
                              icon: Icon(fotoSertifikatParamedis != null
                                  ? Icons.check_circle
                                  : Icons.camera_alt),
                              label: Text(fotoSertifikatParamedis != null
                                  ? 'Sertifikat Paramedis ✓'
                                  : 'Foto Sertifikat Paramedis'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: fotoService != null
                                    ? Colors.green
                                    : const Color(0xFFEBEC07),
                                foregroundColor: fotoService != null
                                    ? Colors.white
                                    : const Color(0xFF2257C1),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () async {
                                try {
                                  await pickImage('service');
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e')),
                                    );
                                  }
                                }
                              },
                              icon: Icon(fotoService != null
                                  ? Icons.check_circle
                                  : Icons.camera_alt),
                              label: Text(fotoService != null
                                  ? 'Service ✓'
                                  : 'Foto Service'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: fotoBbm != null
                                    ? Colors.green
                                    : const Color(0xFFEBEC07),
                                foregroundColor: fotoBbm != null
                                    ? Colors.white
                                    : const Color(0xFF2257C1),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () async {
                                try {
                                  await pickImage('bbm');
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e')),
                                    );
                                  }
                                }
                              },
                              icon: Icon(fotoBbm != null
                                  ? Icons.check_circle
                                  : Icons.camera_alt),
                              label:
                                  Text(fotoBbm != null ? 'BBM ✓' : 'Foto BBM'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Card Tanda Tangan Digital
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tanda Tangan Digital',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Color(0xFF2257C1),
                        ),
                      ),
                      const Divider(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: petugas1Signature != null
                                    ? Colors.green
                                    : const Color(0xFFEBEC07),
                                foregroundColor: petugas1Signature != null
                                    ? Colors.white
                                    : const Color(0xFF2257C1),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () => showSignatureDialog(
                                  'petugas1', 'Tanda Tangan Petugas 1'),
                              icon: Icon(petugas1Signature != null
                                  ? Icons.check_circle
                                  : Icons.edit),
                              label: Text(petugas1Signature != null
                                  ? 'Petugas 1 ✓'
                                  : 'Tanda Tangan Petugas 1'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: managerSignature != null
                                    ? Colors.green
                                    : const Color(0xFFEBEC07),
                                foregroundColor: managerSignature != null
                                    ? Colors.white
                                    : const Color(0xFF2257C1),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () => showSignatureDialog(
                                  'manager', 'Tanda Tangan Manager Traffic'),
                              icon: Icon(managerSignature != null
                                  ? Icons.check_circle
                                  : Icons.edit),
                              label: Text(managerSignature != null
                                  ? 'Manager Traffic ✓'
                                  : 'Tanda Tangan Manager Traffic'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: jjcSignature != null
                                    ? Colors.green
                                    : const Color(0xFFEBEC07),
                                foregroundColor: jjcSignature != null
                                    ? Colors.white
                                    : const Color(0xFF2257C1),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () => showSignatureDialog(
                                  'jjc', 'Tanda Tangan PT JJC'),
                              icon: Icon(jjcSignature != null
                                  ? Icons.check_circle
                                  : Icons.edit),
                              label: Text(jjcSignature != null
                                  ? 'PT JJC ✓'
                                  : 'Tanda Tangan PT JJC'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: managerNameController,
                              decoration: InputDecoration(
                                labelText: 'Nama Manager Traffic',
                                prefixIcon: const Icon(Icons.person),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onChanged: (value) => _markAsChanged(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: jjcNameController,
                              decoration: InputDecoration(
                                labelText: 'Nama PT JJC',
                                prefixIcon: const Icon(Icons.person),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onChanged: (value) => _markAsChanged(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Draft Management Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () async {
                        await _saveDraft();

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Row(
                                children: [
                                  Icon(Icons.save, color: Colors.white),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '💾 Draft berhasil disimpan! Data Anda aman.',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                              backgroundColor: Colors.green,
                              duration: const Duration(seconds: 3),
                              action: SnackBarAction(
                                label: 'OK',
                                textColor: Colors.white,
                                onPressed: () {},
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.save),
                      label: const Text('Simpan Draft'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Hapus Draft'),
                            content: const Text(
                                'Apakah Anda yakin ingin menghapus draft ini?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Batal'),
                              ),
                              TextButton(
                                onPressed: () {
                                  _clearDraft();
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Draft telah dihapus'),
                                      backgroundColor: Colors.red,
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                                child: const Text('Hapus'),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.delete),
                      label: const Text('Hapus Draft'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Tombol Cetak
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2257C1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      // Cancel auto-save timer to prevent saving draft during PDF generation
                      _autoSaveTimer?.cancel();
                      _hasUnsavedChanges = false;
                      _isFormSubmitted =
                          true; // Prevent auto-save after form submission

                      await generatePdf();
                      // _clearDraft() is already called inside generatePdf()
                    }
                  },
                  icon: const Icon(Icons.print, size: 24),
                  label: const Text(
                    'Cetak Laporan PDF',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
