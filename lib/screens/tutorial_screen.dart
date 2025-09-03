import 'package:flutter/material.dart';
import 'package:jasamarga_inspector/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TutorialScreen extends StatefulWidget {
  final bool isFirstTime;
  const TutorialScreen({super.key, this.isFirstTime = false});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  int _currentPage = 0;
  
     final List<TutorialStep> _tutorialSteps = [
     TutorialStep(
       title: 'Selamat Datang di JJC OPERASIONAL',
       description: 'Aplikasi inspeksi kendaraan terpadu untuk Jalan Layang MBZ. Mari kita pelajari cara menggunakannya.',
       icon: Icons.home_rounded,
       color: const Color(0xFF2257C1),
     ),
     TutorialStep(
       title: 'Buat Form Inspeksi Baru',
       description: 'Klik tombol "Buat Form Inspeksi Baru" untuk memulai inspeksi kendaraan. Pilih jenis kendaraan yang akan diinspeksi.',
       icon: Icons.add_rounded,
       color: const Color(0xFFEBEC07),
     ),
     TutorialStep(
       title: 'Pilih Jenis Kendaraan',
       description: 'Pilih salah satu dari 5 jenis kendaraan: Ambulance, Derek, Plaza, Kamtib, atau Rescue. Setiap jenis memiliki form inspeksi yang berbeda.',
       icon: Icons.directions_car_rounded,
       color: const Color(0xFF2ECC71),
     ),
     TutorialStep(
       title: 'Isi Form Inspeksi',
       description: 'Isi semua field yang diperlukan dengan teliti. Gunakan checklist untuk memastikan semua item terinspeksi. Simpan draft jika perlu melanjutkan nanti.',
       icon: Icons.edit_note_rounded,
       color: const Color(0xFFE74C3C),
     ),
     TutorialStep(
       title: 'Simpan Draft',
       description: 'Jika inspeksi belum selesai, gunakan fitur "Simpan Draft" untuk menyimpan progress. Draft dapat dilanjutkan kapan saja.',
       icon: Icons.save_rounded,
       color: const Color(0xFFF39C12),
     ),
     TutorialStep(
       title: 'Lihat Riwayat',
       description: 'Akses "Riwayat Inspeksi" untuk melihat semua inspeksi yang telah dilakukan. Lihat PDF hasil inspeksi dengan klik "Lihat PDF".',
       icon: Icons.history_rounded,
       color: const Color(0xFF9B59B6),
     ),
     TutorialStep(
       title: 'Siap Menggunakan!',
       description: 'Anda telah mempelajari semua fitur utama aplikasi. Klik "Mulai" untuk mulai menggunakan JJC OPERASIONAL.',
       icon: Icons.check_circle_rounded,
       color: const Color(0xFF27AE60),
     ),
   ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _tutorialSteps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishTutorial();
    }
  }

  void _finishTutorial() async {
    // Jika ini adalah tutorial pertama kali, simpan status
    if (widget.isFirstTime) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('tutorial_completed', true);
    }
    
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
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
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                    onPressed: _finishTutorial,
                  ),
                  const Expanded(
                    child: Text(
                      'Panduan Aplikasi',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2257C1),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48), // Balance the close button
                ],
              ),
            ),
            
            // Page View
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _tutorialSteps.length,
                itemBuilder: (context, index) {
                  final step = _tutorialSteps[index];
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                                                     // Icon
                           Container(
                             width: 100,
                             height: 100,
                             decoration: BoxDecoration(
                               color: step.color.withValues(alpha: 0.1),
                               borderRadius: BorderRadius.circular(50),
                               border: Border.all(
                                 color: step.color.withValues(alpha: 0.3),
                                 width: 2,
                               ),
                             ),
                             child: Icon(
                               step.icon,
                               size: 50,
                               color: step.color,
                             ),
                           ),
                           
                           const SizedBox(height: 24),
                           
                           // Title
                           Text(
                             step.title,
                                                        style: TextStyle(
                             fontSize: 20,
                             fontWeight: FontWeight.w700,
                             color: const Color(0xFF2257C1),
                           ),
                             textAlign: TextAlign.center,
                           ),
                           
                           const SizedBox(height: 12),
                           
                           // Description
                           Expanded(
                             child: SingleChildScrollView(
                               child: Text(
                                 step.description,
                                 style: TextStyle(
                                   fontSize: 14,
                                   color: Colors.grey[600],
                                   height: 1.4,
                                 ),
                                 textAlign: TextAlign.center,
                               ),
                             ),
                           ),
                           
                           
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            
                         // Navigation
             Container(
               padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
               child: Column(
                children: [
                  // Page indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _tutorialSteps.length,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index 
                            ? const Color(0xFF2257C1)
                            : Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  
                                     const SizedBox(height: 20),
                  
                  // Navigation buttons
                  Row(
                    children: [
                      // Previous button
                      if (_currentPage > 0)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _previousPage,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: const BorderSide(color: const Color(0xFF2257C1)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Sebelumnya',
                              style: TextStyle(
                                color: const Color(0xFF2257C1),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      
                      if (_currentPage > 0) const SizedBox(width: 16),
                      
                      // Next/Finish button
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _nextPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2257C1),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: Text(
                            _currentPage == _tutorialSteps.length - 1 
                              ? (widget.isFirstTime ? 'Mulai Aplikasi' : 'Selesai')
                              : 'Selanjutnya',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Skip button
                  TextButton(
                    onPressed: _finishTutorial,
                    child: Text(
                      widget.isFirstTime ? 'Lewati & Mulai Aplikasi' : 'Lewati Tutorial',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
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
}

class TutorialStep {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  TutorialStep({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}
