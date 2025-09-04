import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import '../utils/logger.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permissions - removed as not available in this version
    // await _notifications.resolvePlatformSpecificImplementation<
    //     AndroidFlutterLocalNotificationsPlugin>()?.requestPermission();
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap
    Logger.debug('Notification tapped: ${response.payload}');
  }

  // Schedule daily reminder
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    String title = 'Jadwal Inspeksi',
    String body = 'Waktunya melakukan inspeksi kendaraan hari ini',
  }) async {
    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);

    // If time has passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _notifications.zonedSchedule(
      1, // Daily reminder ID
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder',
          'Daily Reminder',
          channelDescription: 'Reminder untuk inspeksi harian',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // Schedule weekly reminder
  Future<void> scheduleWeeklyReminder({
    required int weekday, // 1 = Monday, 7 = Sunday
    required int hour,
    required int minute,
    String title = 'Inspeksi Mingguan',
    String body = 'Jangan lupa lakukan inspeksi mingguan',
  }) async {
    final now = DateTime.now();
    var scheduledDate = _nextInstanceOfWeekday(weekday, hour, minute);

    // If time has passed this week, schedule for next week
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 7));
    }

    await _notifications.zonedSchedule(
      2, // Weekly reminder ID
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'weekly_reminder',
          'Weekly Reminder',
          channelDescription: 'Reminder untuk inspeksi mingguan',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  // Schedule specific vehicle inspection reminder
  Future<void> scheduleVehicleReminder({
    required String vehicleType,
    required String nopol,
    required DateTime dueDate,
    String? notes,
  }) async {
    final title = 'Inspeksi $vehicleType';
    final body =
        'Kendaraan $nopol perlu diinspeksi${notes != null ? ': $notes' : ''}';

    // Schedule 1 day before due date
    final reminderDate = dueDate.subtract(const Duration(days: 1));

    if (reminderDate.isAfter(DateTime.now())) {
      await _notifications.zonedSchedule(
        DateTime.now().millisecondsSinceEpoch ~/ 1000, // Unique ID
        title,
        body,
        tz.TZDateTime.from(reminderDate, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'vehicle_reminder',
            'Vehicle Reminder',
            channelDescription: 'Reminder untuk inspeksi kendaraan spesifik',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: '$vehicleType|$nopol|${dueDate.toIso8601String()}',
      );
    }
  }

  // Schedule maintenance reminder based on inspection history
  Future<void> scheduleMaintenanceReminder() async {
    final box = Hive.box('inspection_history');
    final inspections = box.values.toList();

    // Group by vehicle type and nopol
    final vehicleGroups = <String, List<Map>>{};

    for (var inspection in inspections) {
      if (inspection is Map) {
        final key = '${inspection['jenis']}_${inspection['nopol']}';
        vehicleGroups.putIfAbsent(key, () => []).add(inspection);
      }
    }

    // Check for vehicles that haven't been inspected recently
    final now = DateTime.now();
    for (var entry in vehicleGroups.entries) {
      final inspections = entry.value;
      if (inspections.isNotEmpty) {
        final lastInspection = inspections.first;
        final lastDate = DateTime.tryParse(lastInspection['tanggal'] ?? '');

        if (lastDate != null) {
          final daysSinceLastInspection = now.difference(lastDate).inDays;

          // Remind if more than 7 days since last inspection
          if (daysSinceLastInspection > 7) {
            final vehicleType = lastInspection['jenis'] ?? '';
            final nopol = lastInspection['nopol'] ?? '';

            await scheduleVehicleReminder(
              vehicleType: vehicleType,
              nopol: nopol,
              dueDate: now.add(const Duration(days: 1)),
              notes: 'Belum diinspeksi selama $daysSinceLastInspection hari',
            );
          }
        }
      }
    }
  }

  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  // Cancel specific notification
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  // Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  // Show immediate notification
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'immediate',
          'Immediate Notifications',
          channelDescription: 'Notifikasi langsung',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }

  // Helper method to get next instance of weekday
  DateTime _nextInstanceOfWeekday(int weekday, int hour, int minute) {
    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);

    while (scheduledDate.weekday != weekday) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  // Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    final androidImplementation =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    return await androidImplementation?.areNotificationsEnabled() ?? false;
  }

  // Request notification permissions
  Future<bool> requestPermissions() async {
    final androidImplementation =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    // For now, return true as requestPermission is not available in this version
    // In a real app, you might want to check areNotificationsEnabled() instead
    return await androidImplementation?.areNotificationsEnabled() ?? false;
  }

  // Generate detailed inspection table for PDF
  pw.Widget generateInspectionDetailTable(
      List<Map> inspections, pw.Font font, pw.Font fontBold) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header section
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: const pw.BoxDecoration(
              color: PdfColors.grey200,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Text(
              'Tabel Detail Inspeksi',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                font: fontBold,
                fontSize: 14,
              ),
            ),
          ),
          pw.SizedBox(height: 8),

          // Table
          pw.Table(
            border: pw.TableBorder.all(width: 1, color: PdfColors.grey400),
            columnWidths: {
              0: const pw.FixedColumnWidth(30), // No
              1: const pw.FixedColumnWidth(70), // Tanggal
              2: const pw.FixedColumnWidth(80), // Jenis Kendaraan
              3: const pw.FixedColumnWidth(80), // Nopol
              4: const pw.FixedColumnWidth(100), // Lokasi
              5: const pw.FixedColumnWidth(80), // Petugas
              6: const pw.FixedColumnWidth(60), // Status
            },
            children: [
              // Header row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        vertical: 6, horizontal: 4),
                    child: pw.Center(
                      child: pw.Text(
                        'No',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          font: fontBold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        vertical: 6, horizontal: 4),
                    child: pw.Center(
                      child: pw.Text(
                        'Tanggal',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          font: fontBold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        vertical: 6, horizontal: 4),
                    child: pw.Center(
                      child: pw.Text(
                        'Jenis\nKendaraan',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          font: fontBold,
                          fontSize: 10,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        vertical: 6, horizontal: 4),
                    child: pw.Center(
                      child: pw.Text(
                        'Nopol',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          font: fontBold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        vertical: 6, horizontal: 4),
                    child: pw.Center(
                      child: pw.Text(
                        'Lokasi',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          font: fontBold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        vertical: 6, horizontal: 4),
                    child: pw.Center(
                      child: pw.Text(
                        'Petugas',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          font: fontBold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        vertical: 6, horizontal: 4),
                    child: pw.Center(
                      child: pw.Text(
                        'Status',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          font: fontBold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // Data rows
              ...inspections.asMap().entries.map((entry) {
                final index = entry.key;
                final inspection = entry.value;
                final date = DateTime.tryParse(inspection['tanggal'] ?? '') ??
                    DateTime.now();

                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: index % 2 == 0 ? PdfColors.grey50 : PdfColors.white,
                  ),
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          vertical: 4, horizontal: 4),
                      child: pw.Center(
                        child: pw.Text(
                          '${index + 1}',
                          style: pw.TextStyle(font: font, fontSize: 9),
                        ),
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          vertical: 4, horizontal: 4),
                      child: pw.Center(
                        child: pw.Text(
                          DateFormat('dd/MM/yyyy', 'id_ID').format(date),
                          style: pw.TextStyle(font: font, fontSize: 9),
                        ),
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          vertical: 4, horizontal: 4),
                      child: pw.Center(
                        child: pw.Text(
                          inspection['jenis'] ?? '-',
                          style: pw.TextStyle(font: font, fontSize: 9),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          vertical: 4, horizontal: 4),
                      child: pw.Center(
                        child: pw.Text(
                          inspection['nopol'] ?? '-',
                          style: pw.TextStyle(font: font, fontSize: 9),
                        ),
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          vertical: 4, horizontal: 4),
                      child: pw.Center(
                        child: pw.Text(
                          inspection['lokasi'] ?? '-',
                          style: pw.TextStyle(font: font, fontSize: 9),
                        ),
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          vertical: 4, horizontal: 4),
                      child: pw.Center(
                        child: pw.Text(
                          inspection['petugas1'] ?? '-',
                          style: pw.TextStyle(font: font, fontSize: 9),
                        ),
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          vertical: 4, horizontal: 4),
                      child: pw.Center(
                        child: pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: const pw.BoxDecoration(
                            color: PdfColors.green,
                            borderRadius:
                                pw.BorderRadius.all(pw.Radius.circular(12)),
                          ),
                          child: pw.Text(
                            'Selesai',
                            style: pw.TextStyle(
                              font: font,
                              fontSize: 8,
                              color: PdfColors.white,
                            ),
                          ),
                        ),
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
}
