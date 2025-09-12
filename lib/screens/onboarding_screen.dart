import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'tutorial_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardData> _pages = [
    const _OnboardData(
      image: 'assets/onboard2.png',
      title: 'Selamat datang aplikasi di JJC OPERASIONAL',
      subtitle:
          'Sistem Inspeksi Kendaraan Terpadu untuk\nJalan Layang MBZ\nPT Jasamarga Jalanlayang Cikampek',
    ),
    const _OnboardData(
      image: 'assets/onboard1.png',
      title: 'Cetak laporan instan',
      subtitle: 'Hasil inspeksi langsung siap di-print',
    ),
    const _OnboardData(
      image: 'assets/onboard3.png',
      title: 'Lebih cepat & efisien',
      subtitle:
          'Catat inspeksi langsung di lapangan, data tersimpan aman & rapi secara digital.',
    ),
  ];

  void _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (!mounted) return;

    // Tampilkan tutorial setelah onboarding untuk pengguna baru
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
          builder: (_) => const TutorialScreen(isFirstTime: true)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2257C1),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, i) {
                  final data = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 32),
                        Image.asset(data.image, height: 220),
                        const SizedBox(height: 32),
                        Text(
                          data.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          data.subtitle,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        _buildIndicator(),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEBEC07),
                    foregroundColor: const Color(0xFF2257C1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  onPressed: () {
                    if (_currentPage == _pages.length - 1) {
                      _finishOnboarding();
                    } else {
                      _pageController.nextPage(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOut);
                    }
                  },
                  child: const Text('Lanjut'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pages.length, (i) {
        Color color;
        if (_currentPage == i) {
          color = const Color(0xFFEBEC07);
        } else {
          color = Colors.white.withValues(alpha: 0.6);
        }
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}

class _OnboardData {
  final String image;
  final String title;
  final String subtitle;
  const _OnboardData(
      {required this.image, required this.title, required this.subtitle});
}
