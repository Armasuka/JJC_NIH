import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'form_ambulance_screen.dart' as ambulance;
import 'form_derek_screen.dart';
import 'form_kamtib_screen.dart';
import 'form_plaza_screen.dart';
import 'form_rescue_screen.dart';
import '../services/draft_service.dart';

class KendaraanScreen extends StatefulWidget {
  const KendaraanScreen({super.key});

  @override
  State<KendaraanScreen> createState() => _KendaraanScreenState();
}

class _KendaraanScreenState extends State<KendaraanScreen> with TickerProviderStateMixin {
  final List<Map<String, dynamic>> vehicleTypes = [
    {
      'name': 'Ambulance',
      'icon': Icons.medical_services_rounded,
      'color': const Color(0xFFE74C3C),

      'description': 'Unit medis darurat',
    },
    {
      'name': 'Derek',
      'icon': Icons.car_repair_rounded,
      'color': const Color(0xFF3498DB),

      'description': 'Unit evakuasi kendaraan',
    },
    {
      'name': 'Plaza',
      'icon': Icons.directions_car_rounded,
      'color': const Color(0xFF2ECC71),

      'description': 'Unit layanan tol',
    },
    {
      'name': 'Kamtib',
      'icon': Icons.security_rounded,
      'color': const Color(0xFF9B59B6),

      'description': 'Unit keamanan & ketertiban',
    },
    {
      'name': 'Rescue',
      'icon': Icons.emergency_rounded,
      'color': const Color(0xFFF39C12),

      'description': 'Unit penyelamatan',
    },
  ];

  String? selectedKategori;
  late AnimationController _animationController;
  late AnimationController _buttonAnimationController;
  late List<Animation<double>> _cardAnimations;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _buttonAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _cardAnimations = List.generate(
      vehicleTypes.length,
      (index) => Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(
            index * 0.1,
            0.5 + index * 0.1,
            curve: Curves.easeOutBack,
          ),
        ),
      ),
    );
    
    _animationController.forward();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    _buttonAnimationController.dispose();
    super.dispose();
  }

  void navigateToForm(String kategori) {
    // Cek apakah sudah ada draft untuk form ini
    final draftKey = '${kategori.toLowerCase()}_draft';
    final existingDraft = DraftService.loadDraft(draftKey);
    
    if (existingDraft != null) {
      // Jika ada draft, tampilkan dialog konfirmasi
      _showDraftExistsDialog(kategori, draftKey, existingDraft);
    } else {
      // Jika tidak ada draft, buat form baru
      _createNewForm(kategori);
    }
  }

  void _showDraftExistsDialog(String kategori, String draftKey, Map<String, dynamic> draftData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.save_rounded, color: Color(0xFF2196F3)),
            SizedBox(width: 8),
            Text('Draft Tersimpan'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Anda memiliki draft Form $kategori yang tersimpan.'),
            SizedBox(height: 8),
            Text(
              'Petugas: ${draftData['petugas1'] ?? 'Tidak ada'}',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            SizedBox(height: 16),
            Text(
              'Apa yang ingin Anda lakukan?',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _openExistingDraft(kategori, draftKey, draftData);
            },
            style: TextButton.styleFrom(foregroundColor: Color(0xFF2196F3)),
            child: Text('Buka Draft'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _createNewForm(kategori);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: Text('Buat Form Baru'),
          ),
        ],
      ),
    );
  }



  void _openExistingDraft(String kategori, String draftKey, Map<String, dynamic> draftData) {
    Widget? targetScreen;
    
    switch (kategori) {
      case 'Ambulance':
        targetScreen = ambulance.FormAmbulanceScreen(draftData: draftData, draftKey: draftKey);
        break;
      case 'Derek':
        targetScreen = FormDerekScreen(draftData: draftData, draftKey: draftKey);
        break;
      case 'Kamtib':
        targetScreen = FormKamtibScreen(draftData: draftData, draftKey: draftKey);
        break;
      case 'Plaza':
        targetScreen = FormPlazaScreen(draftData: draftData, draftKey: draftKey);
        break;
      case 'Rescue':
        targetScreen = FormRescueScreen(draftData: draftData, draftKey: draftKey);
        break;
    }
    
    if (targetScreen != null) {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => targetScreen!,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeOutCubic;

            var tween = Tween(begin: begin, end: end).chain(
              CurveTween(curve: curve),
            );

            return SlideTransition(
              position: animation.drive(tween),
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    }
  }

  void _createNewForm(String kategori) {
    Widget? targetScreen;
    
    switch (kategori) {
      case 'Ambulance':
        targetScreen = const ambulance.FormAmbulanceScreen();
        break;
      case 'Derek':
        targetScreen = const FormDerekScreen();
        break;
      case 'Kamtib':
        targetScreen = const FormKamtibScreen();
        break;
      case 'Plaza':
        targetScreen = const FormPlazaScreen();
        break;
      case 'Rescue':
        targetScreen = const FormRescueScreen();
        break;
    }
    
    if (targetScreen != null) {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => targetScreen!,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeOutCubic;

            var tween = Tween(begin: begin, end: end).chain(
              CurveTween(curve: curve),
            );

            return SlideTransition(
              position: animation.drive(tween),
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Form untuk $kategori belum tersedia'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Column(
          children: [
            // Minimalist App Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded, 
                      color: Colors.grey[700], 
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      'Pilih Jenis Kendaraan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            // Header dengan animasi
            FadeTransition(
              opacity: _animationController,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -0.3),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: _animationController,
                  curve: Curves.easeOutCubic,
                )),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  padding: const EdgeInsets.all(20),
                                     decoration: BoxDecoration(
                     color: Colors.white,
                     borderRadius: BorderRadius.circular(16),
                     border: Border.all(
                       color: Colors.grey[200]!,
                       width: 1,
                     ),
                     boxShadow: [
                       BoxShadow(
                         color: Colors.black.withValues(alpha: 0.05),
                         blurRadius: 8,
                         offset: const Offset(0, 4),
                       ),
                     ],
                   ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.assignment_turned_in_rounded,
                        size: 40,
                        color: Color(0xFF2257C1),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pilih jenis kendaraan yang akan diinspeksi',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Vehicle Cards dengan animasi stagger
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: GridView.builder(
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: vehicleTypes.length,
                  itemBuilder: (context, index) {
                    final vehicle = vehicleTypes[index];
                    final isSelected = selectedKategori == vehicle['name'];
                    
                    return ScaleTransition(
                      scale: _cardAnimations[index],
                      child: GestureDetector(
                        onTapDown: (_) {
                          _buttonAnimationController.forward();
                        },
                        onTapUp: (_) {
                          _buttonAnimationController.reverse();
                        },
                        onTapCancel: () {
                          _buttonAnimationController.reverse();
                        },
                        onTap: () {
                          setState(() {
                            if (selectedKategori == vehicle['name']) {
                              selectedKategori = null;
                            } else {
                              selectedKategori = vehicle['name'];
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          transform: Matrix4.identity(),
                                                                                                           decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFEBEC07) : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF2257C1) : Colors.grey[200]!,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isSelected 
                                    ? const Color(0xFFEBEC07).withValues(alpha: 0.3)
                                    : Colors.black.withValues(alpha: 0.05),
                                  blurRadius: isSelected ? 12 : 6,
                                  offset: Offset(0, isSelected ? 6 : 3),
                                ),
                              ],
                            ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                                                                                           Icon(
                                vehicle['icon'],
                                size: 40,
                                color: isSelected ? const Color(0xFF2257C1) : vehicle['color'],
                              ),
                              const SizedBox(height: 12),
                                                             Text(
                                 vehicle['name'],
                                 style: TextStyle(
                                   fontSize: 16,
                                   fontWeight: FontWeight.w600,
                                   color: isSelected ? const Color(0xFF2257C1) : Colors.grey[800],
                                 ),
                               ),
                              const SizedBox(height: 4),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                                                 child: Text(
                                   vehicle['description'],
                                   style: TextStyle(
                                     fontSize: 11,
                                     color: isSelected 
                                       ? const Color(0xFF2257C1).withValues(alpha: 0.8)
                                       : Colors.grey[600],
                                   ),
                                   textAlign: TextAlign.center,
                                 ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            // Bottom Button dengan animasi
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(
                    0,
                    100 * (1 - _animationController.value),
                  ),
                  child: Opacity(
                    opacity: _animationController.value,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(
                            color: Colors.grey[200]!,
                            width: 1,
                          ),
                        ),
                      ),
                      child: SafeArea(
                        top: false,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: double.infinity,
                          height: 60,
                                                                                                           decoration: BoxDecoration(
                              color: selectedKategori != null
                                ? const Color(0xFFEBEC07)
                                : Colors.grey[300],
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: selectedKategori != null ? [
                                BoxShadow(
                                  color: const Color(0xFFEBEC07).withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ] : [],
                            ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: selectedKategori != null
                                  ? () {
                                      navigateToForm(selectedKategori!);
                                    }
                                  : null,
                              borderRadius: BorderRadius.circular(16),
                              child: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                                                           Text(
                                         selectedKategori != null
                                           ? 'Lanjutkan'
                                           : 'Pilih Kendaraan',
                                         style: TextStyle(
                                           fontWeight: FontWeight.w600,
                                           fontSize: 16,
                                           color: selectedKategori != null
                                             ? const Color(0xFF2257C1)
                                             : Colors.grey[600],
                                         ),
                                       ),
                                    if (selectedKategori != null) ...[
                                      const SizedBox(width: 8),
                                                                                                                   const Icon(
                                        Icons.arrow_forward_rounded,
                                        color: Color(0xFF2257C1),
                                        size: 20,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
