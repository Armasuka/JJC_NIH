import 'package:flutter/material.dart';
import '../utils/logger.dart';
import 'package:intl/intl.dart';
import 'kendaraan_screen.dart';
import 'history_screen.dart';
import 'tutorial_screen.dart';
import 'backup_restore_screen.dart';
import 'form_ambulance_screen.dart' as ambulance;
import 'form_derek_screen.dart';
import 'form_plaza_screen.dart';
import 'form_kamtib_screen.dart';
import 'form_rescue_screen.dart';
import '../services/draft_service.dart';
import 'notification_settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _logoAnimation;
  late AnimationController _buttonsAnimation;
  late AnimationController _backgroundAnimation;
  bool _hasDrafts = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _logoAnimation = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _buttonsAnimation = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _backgroundAnimation = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    _startAnimations();
    _checkDrafts();
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 100));
    _logoAnimation.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    _buttonsAnimation.forward();
    _backgroundAnimation.repeat(reverse: true);
  }

  void _checkDrafts() {
    try {
      final hasDrafts = DraftService.hasDrafts();
      if (mounted) {
        setState(() {
          _hasDrafts = hasDrafts;
        });
      }
    } catch (e) {
      Logger.debug('Error checking drafts: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _logoAnimation.dispose();
    _buttonsAnimation.dispose();
    _backgroundAnimation.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && mounted) {
      _checkDrafts();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh draft status when screen becomes active
    if (mounted) {
      _checkDrafts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: Stack(
        children: [
          // Background Patterns
          Positioned.fill(
            child: CustomPaint(
              painter: BackgroundPatternPainter(),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Minimalist App Bar
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.help_outline_rounded,
                          color: Color(0xFF2257C1),
                          size: 22,
                        ),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const TutorialScreen(),
                            ),
                          );
                          if (mounted) {
                            _checkDrafts();
                          }
                        },
                        tooltip: 'Panduan Aplikasi',
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(
                          Icons.notifications_rounded,
                          color: Color(0xFF2257C1),
                          size: 22,
                        ),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const NotificationSettingsScreen(),
                            ),
                          );
                          if (mounted) {
                            _checkDrafts();
                          }
                        },
                        tooltip: 'Pengaturan Notifikasi',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15.0),
                      child: Column(
                        children: [
                          const SizedBox(height: 5),
                          // Logo yang diperbesar dan lebih presisi
                          ScaleTransition(
                            scale: _logoAnimation,
                            child: Image.asset(
                              'assets/logo_jjc.png',
                              width: 280,
                              height: 280,
                            ),
                          ),
                          const SizedBox(height: 35),

                          // Main Action Buttons
                          FadeTransition(
                            opacity: _buttonsAnimation,
                            child: Column(
                              children: [
                                _buildActionButton(
                                  icon: Icons.directions_car,
                                  title: 'Inspeksi Kendaraan',
                                  subtitle: 'Mulai inspeksi kendaraan baru',
                                  color: const Color(0xFF2257C1),
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const KendaraanScreen(),
                                      ),
                                    );
                                    if (mounted) {
                                      _checkDrafts();
                                    }
                                  },
                                ),
                                const SizedBox(height: 12),
                                _buildActionButton(
                                  icon: Icons.history,
                                  title: 'Riwayat Inspeksi',
                                  subtitle: 'Lihat data inspeksi sebelumnya',
                                  color: const Color(0xFF4CAF50),
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const HistoryScreen(),
                                      ),
                                    );
                                    if (mounted) {
                                      _checkDrafts();
                                    }
                                  },
                                ),
                                const SizedBox(height: 12),
                                _buildActionButton(
                                  icon: Icons.backup,
                                  title: 'Backup & Restore',
                                  subtitle: 'Kelola data backup',
                                  color: const Color(0xFFFF9800),
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const BackupRestoreScreen(),
                                      ),
                                    );
                                    if (mounted) {
                                      _checkDrafts();
                                    }
                                  },
                                ),
                                const SizedBox(height: 12),
                                _buildActionButton(
                                  icon: Icons.drafts,
                                  title:
                                      _hasDrafts ? 'Draft Tersimpan' : 'Draft',
                                  subtitle: _hasDrafts
                                      ? 'Lanjutkan inspeksi yang tersimpan'
                                      : 'Tidak ada draft tersimpan',
                                  color: _hasDrafts
                                      ? const Color(0xFFE91E63)
                                      : const Color(0xFF9E9E9E),
                                  onTap: _hasDrafts
                                      ? () {
                                          _showDraftDialog();
                                        }
                                      : null,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.1),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: color.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                if (onTap != null)
                  Icon(
                    Icons.arrow_forward_ios,
                    color: color.withOpacity(0.5),
                    size: 16,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDraftDialog() async {
    try {
      final drafts = DraftService.getAllDrafts();

      if (drafts.isEmpty) {
        if (mounted) {
          setState(() {
            _hasDrafts = false;
          });
        }
        return;
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.drafts, color: Color(0xFFE91E63)),
              SizedBox(width: 8),
              Text('Draft Tersimpan'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Pilih draft yang ingin dilanjutkan:'),
                const SizedBox(height: 16),
                ...drafts.map((draft) {
                  final draftData = draft['data'] as Map<String, dynamic>;
                  final formType = draftData['formType'] ?? 'Unknown';
                  final petugas1 = draftData['petugas1'] ?? 'Tidak ada';
                  final timestamp = draftData['timestamp'] ?? '';

                  String formattedDate = '';
                  if (timestamp.isNotEmpty) {
                    try {
                      final date = DateTime.parse(timestamp);
                      formattedDate =
                          DateFormat('dd/MM/yyyy HH:mm').format(date);
                    } catch (e) {
                      formattedDate = 'Tanggal tidak valid';
                    }
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(
                        _getFormIcon(formType),
                        color: _getFormColor(formType),
                      ),
                      title: Text('Form $formType'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Petugas: $petugas1'),
                          Text('Tanggal: $formattedDate'),
                        ],
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () async {
                        Navigator.pop(context);
                        _openDraft(draft['key'] as String, draftData);
                        if (mounted) {
                          _checkDrafts();
                        }
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                if (mounted) {
                  _checkDrafts();
                }
              },
              child: const Text('Batal'),
            ),
          ],
        ),
      );
    } catch (e) {
      Logger.debug('Error showing draft dialog: $e');
    }
  }

  IconData _getFormIcon(String formType) {
    switch (formType.toLowerCase()) {
      case 'ambulance':
        return Icons.local_hospital;
      case 'derek':
        return Icons.local_shipping;
      case 'plaza':
        return Icons.store;
      case 'kamtib':
        return Icons.security;
      case 'rescue':
        return Icons.emergency;
      default:
        return Icons.description;
    }
  }

  Color _getFormColor(String formType) {
    switch (formType.toLowerCase()) {
      case 'ambulance':
        return const Color(0xFFE74C3C);
      case 'derek':
        return const Color(0xFF3498DB);
      case 'plaza':
        return const Color(0xFF2ECC71);
      case 'kamtib':
        return const Color(0xFF9B59B6);
      case 'rescue':
        return const Color(0xFFF39C12);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  void _openDraft(String draftKey, Map<String, dynamic> draftData) async {
    try {
      final formType = draftData['formType'] ?? '';

      Widget? targetScreen;
      switch (formType.toLowerCase()) {
        case 'ambulance':
          targetScreen = ambulance.FormAmbulanceScreen(
              draftData: draftData, draftKey: draftKey);
          break;
        case 'derek':
          targetScreen =
              FormDerekScreen(draftData: draftData, draftKey: draftKey);
          break;
        case 'kamtib':
          targetScreen =
              FormKamtibScreen(draftData: draftData, draftKey: draftKey);
          break;
        case 'plaza':
          targetScreen =
              FormPlazaScreen(draftData: draftData, draftKey: draftKey);
          break;
        case 'rescue':
          targetScreen =
              FormRescueScreen(draftData: draftData, draftKey: draftKey);
          break;
      }

      if (targetScreen != null) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => targetScreen!),
        );
        if (mounted) {
          _checkDrafts();
        }
      }
    } catch (e) {
      Logger.debug('Error opening draft: $e');
    }
  }
}

class BackgroundPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2257C1).withOpacity(0.03)
      ..strokeWidth = 1;

    // Draw diagonal lines
    for (int i = 0; i < size.width + size.height; i += 20) {
      canvas.drawLine(
        Offset(i.toDouble(), 0),
        Offset(0, i.toDouble()),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
