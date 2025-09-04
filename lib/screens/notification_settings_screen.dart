import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jasamarga_inspector/services/notification_service.dart';
import 'package:jasamarga_inspector/screens/home_screen.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final NotificationService _notificationService = NotificationService();

  // Daily reminder settings
  bool _dailyReminderEnabled = false;
  TimeOfDay _dailyReminderTime = const TimeOfDay(hour: 8, minute: 0);

  // Weekly reminder settings
  bool _weeklyReminderEnabled = false;
  int _weeklyReminderDay = 1; // Monday
  TimeOfDay _weeklyReminderTime = const TimeOfDay(hour: 9, minute: 0);

  // Maintenance reminder settings
  bool _maintenanceReminderEnabled = false;
  int _maintenanceReminderDays = 7;

  // General settings
  bool _notificationsEnabled = false;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  final List<String> _weekdays = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu'
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      _dailyReminderEnabled = prefs.getBool('daily_reminder_enabled') ?? false;
      _weeklyReminderEnabled =
          prefs.getBool('weekly_reminder_enabled') ?? false;

      _maintenanceReminderEnabled =
          prefs.getBool('maintenance_reminder_enabled') ?? false;
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? false;
      _soundEnabled = prefs.getBool('sound_enabled') ?? true;
      _vibrationEnabled = prefs.getBool('vibration_enabled') ?? true;

      final dailyHour = prefs.getInt('daily_reminder_hour') ?? 8;
      final dailyMinute = prefs.getInt('daily_reminder_minute') ?? 0;
      _dailyReminderTime = TimeOfDay(hour: dailyHour, minute: dailyMinute);

      final weeklyHour = prefs.getInt('weekly_reminder_hour') ?? 9;
      final weeklyMinute = prefs.getInt('weekly_reminder_minute') ?? 0;
      _weeklyReminderTime = TimeOfDay(hour: weeklyHour, minute: weeklyMinute);

      _weeklyReminderDay = prefs.getInt('weekly_reminder_day') ?? 1;

      _maintenanceReminderDays = prefs.getInt('maintenance_reminder_days') ?? 7;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('daily_reminder_enabled', _dailyReminderEnabled);
    await prefs.setBool('weekly_reminder_enabled', _weeklyReminderEnabled);

    await prefs.setBool(
        'maintenance_reminder_enabled', _maintenanceReminderEnabled);
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
    await prefs.setBool('sound_enabled', _soundEnabled);
    await prefs.setBool('vibration_enabled', _vibrationEnabled);

    await prefs.setInt('daily_reminder_hour', _dailyReminderTime.hour);
    await prefs.setInt('daily_reminder_minute', _dailyReminderTime.minute);
    await prefs.setInt('weekly_reminder_hour', _weeklyReminderTime.hour);
    await prefs.setInt('weekly_reminder_minute', _weeklyReminderTime.minute);
    await prefs.setInt('weekly_reminder_day', _weeklyReminderDay);

    await prefs.setInt('maintenance_reminder_days', _maintenanceReminderDays);
  }

  Future<void> _updateDailyReminder() async {
    if (_dailyReminderEnabled) {
      await _notificationService.scheduleDailyReminder(
        hour: _dailyReminderTime.hour,
        minute: _dailyReminderTime.minute,
      );
    } else {
      await _notificationService.cancelNotification(1);
    }
  }

  Future<void> _updateWeeklyReminder() async {
    if (_weeklyReminderEnabled) {
      await _notificationService.scheduleWeeklyReminder(
        weekday: _weeklyReminderDay,
        hour: _weeklyReminderTime.hour,
        minute: _weeklyReminderTime.minute,
      );
    } else {
      await _notificationService.cancelNotification(2);
    }
  }

  Future<void> _testNotification() async {
    await _notificationService.showNotification(
      title: 'Test Notifikasi',
      body: 'Ini adalah notifikasi test dari aplikasi Jasamarga Inspeksi',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notifikasi test telah dikirim'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Pengaturan Notifikasi'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2257C1),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2257C1)),
          onPressed: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.notifications_active,
                    size: 48,
                    color: Color(0xFF2257C1),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Pengaturan Notifikasi',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Atur reminder dan notifikasi untuk inspeksi kendaraan',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // General Settings
            _buildSectionCard(
              title: 'Pengaturan Umum',
              icon: Icons.settings,
              children: [
                SwitchListTile(
                  title: const Text('Aktifkan Notifikasi'),
                  subtitle: const Text('Terima notifikasi dari aplikasi'),
                  value: _notificationsEnabled,
                  onChanged: (value) {
                    setState(() {
                      _notificationsEnabled = value;
                    });
                    _saveSettings();
                  },
                  activeColor: const Color(0xFF2257C1),
                ),
                SwitchListTile(
                  title: const Text('Suara Notifikasi'),
                  subtitle: const Text('Putar suara saat notifikasi'),
                  value: _soundEnabled,
                  onChanged: _notificationsEnabled
                      ? (value) {
                          setState(() {
                            _soundEnabled = value;
                          });
                          _saveSettings();
                        }
                      : null,
                  activeColor: const Color(0xFF2257C1),
                ),
                SwitchListTile(
                  title: const Text('Getaran'),
                  subtitle: const Text('Getar saat notifikasi'),
                  value: _vibrationEnabled,
                  onChanged: _notificationsEnabled
                      ? (value) {
                          setState(() {
                            _vibrationEnabled = value;
                          });
                          _saveSettings();
                        }
                      : null,
                  activeColor: const Color(0xFF2257C1),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Daily Reminder
            _buildSectionCard(
              title: 'Reminder Harian',
              icon: Icons.calendar_today,
              children: [
                SwitchListTile(
                  title: const Text('Aktifkan Reminder Harian'),
                  subtitle: const Text('Reminder setiap hari untuk inspeksi'),
                  value: _dailyReminderEnabled,
                  onChanged: _notificationsEnabled
                      ? (value) async {
                          setState(() {
                            _dailyReminderEnabled = value;
                          });
                          await _updateDailyReminder();
                          await _saveSettings();
                        }
                      : null,
                  activeColor: const Color(0xFF2257C1),
                ),
                if (_dailyReminderEnabled) ...[
                  ListTile(
                    title: const Text('Waktu Reminder'),
                    subtitle: Text(_dailyReminderTime.format(context)),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: _dailyReminderTime,
                      );
                      if (time != null) {
                        setState(() {
                          _dailyReminderTime = time;
                        });
                        await _updateDailyReminder();
                        await _saveSettings();
                      }
                    },
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // Weekly Reminder
            _buildSectionCard(
              title: 'Reminder Mingguan',
              icon: Icons.calendar_view_week,
              children: [
                SwitchListTile(
                  title: const Text('Aktifkan Reminder Mingguan'),
                  subtitle: const Text('Reminder setiap minggu untuk inspeksi'),
                  value: _weeklyReminderEnabled,
                  onChanged: _notificationsEnabled
                      ? (value) async {
                          setState(() {
                            _weeklyReminderEnabled = value;
                          });
                          await _updateWeeklyReminder();
                          await _saveSettings();
                        }
                      : null,
                  activeColor: const Color(0xFF2257C1),
                ),
                if (_weeklyReminderEnabled) ...[
                  ListTile(
                    title: const Text('Hari Reminder'),
                    subtitle: Text(_weekdays[_weeklyReminderDay - 1]),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Pilih Hari'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: _weekdays.asMap().entries.map((entry) {
                              return RadioListTile<int>(
                                title: Text(entry.value),
                                value: entry.key + 1,
                                groupValue: _weeklyReminderDay,
                                onChanged: (value) async {
                                  setState(() {
                                    _weeklyReminderDay = value!;
                                  });
                                  await _updateWeeklyReminder();
                                  await _saveSettings();
                                  Navigator.pop(context);
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    title: const Text('Waktu Reminder'),
                    subtitle: Text(_weeklyReminderTime.format(context)),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: _weeklyReminderTime,
                      );
                      if (time != null) {
                        setState(() {
                          _weeklyReminderTime = time;
                        });
                        await _updateWeeklyReminder();
                        await _saveSettings();
                      }
                    },
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // Maintenance Reminder
            _buildSectionCard(
              title: 'Reminder Maintenance',
              icon: Icons.build,
              children: [
                SwitchListTile(
                  title: const Text('Aktifkan Reminder Maintenance'),
                  subtitle: const Text(
                      'Reminder untuk kendaraan yang belum diinspeksi'),
                  value: _maintenanceReminderEnabled,
                  onChanged: _notificationsEnabled
                      ? (value) {
                          setState(() {
                            _maintenanceReminderEnabled = value;
                          });
                          _saveSettings();
                        }
                      : null,
                  activeColor: const Color(0xFF2257C1),
                ),
                if (_maintenanceReminderEnabled) ...[
                  ListTile(
                    title: const Text('Jarak Hari'),
                    subtitle: Text('$_maintenanceReminderDays hari'),
                    trailing: const Icon(Icons.tune),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Jarak Hari'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [3, 5, 7, 10, 14].map((days) {
                              return RadioListTile<int>(
                                title: Text('$days hari'),
                                value: days,
                                groupValue: _maintenanceReminderDays,
                                onChanged: (value) {
                                  setState(() {
                                    _maintenanceReminderDays = value!;
                                  });
                                  _saveSettings();
                                  Navigator.pop(context);
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),

            // Test Notification Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEBEC07),
                  foregroundColor: const Color(0xFF2257C1),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _notificationsEnabled ? _testNotification : null,
                icon: const Icon(Icons.notifications),
                label: const Text('Test Notifikasi'),
              ),
            ),
            const SizedBox(height: 16),

            // Info Card
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
                      const Icon(Icons.info_outline, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        'Informasi Notifikasi',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Reminder harian akan muncul setiap hari pada waktu yang ditentukan\n'
                    '• Reminder mingguan akan muncul setiap minggu pada hari dan waktu yang ditentukan\n'
                    '• Reminder maintenance akan memeriksa kendaraan yang belum diinspeksi\n'
                    '• Pastikan aplikasi tidak di-force close untuk menerima notifikasi',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[600],
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

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2257C1).withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: const Color(0xFF2257C1),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2257C1),
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}
