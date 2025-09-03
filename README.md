# JASAMARGA INSPECTOR

Sistem Inspeksi Kendaraan Terpadu untuk Jalan Layang Cikampek

## Fitur Utama

### 1. Inspeksi Kendaraan
- **Ambulance**: Form inspeksi khusus untuk kendaraan ambulance
- **Derek**: Form inspeksi untuk kendaraan derek
- **Plaza**: Form inspeksi untuk kendaraan plaza
- **Kamtib**: Form inspeksi untuk kendaraan kamtib
- **Rescue**: Form inspeksi untuk kendaraan rescue

### 2. Riwayat Inspeksi dengan Diagram dan Rekap
- **Tab Diagram**: Menampilkan visualisasi data inspeksi
  - Pie Chart: Distribusi jenis kendaraan
  - Bar Chart: Jumlah inspeksi per jenis kendaraan
  - Summary Cards: Total inspeksi dan jenis kendaraan
- **Tab Daftar**: Menampilkan daftar riwayat inspeksi
- **Filter Waktu**:
  - Hari Ini
  - Minggu Ini
  - Bulan Ini
  - Tahun Ini
  - Kustom (pilih rentang tanggal)
- **Filter Jenis Kendaraan**: Semua, Ambulance, Derek, Plaza, Kamtib, Rescue
- **Pencarian**: Berdasarkan nopol, jenis, atau tanggal
- **Ekspor PDF**: Rekap data dengan diagram dan tabel

### 3. Manajemen PDF
- **Lihat PDF**: Buka hasil PDF inspeksi
- **Bagikan PDF**: Bagikan hasil inspeksi
- **Ekspor Rekap**: Buat laporan rekap dalam format PDF

### 4. Backup dan Restore
- Backup data ke file
- Restore data dari file
- Manajemen draft inspeksi

### 5. Notifikasi
- Pengaturan notifikasi
- Notifikasi inspeksi terjadwal

## Teknologi yang Digunakan

- **Flutter**: Framework UI
- **Hive**: Database lokal
- **PDF**: Pembuatan dan manajemen file PDF
- **FL Chart**: Visualisasi data (diagram)
- **Share Plus**: Berbagi file
- **File Picker**: Pemilihan file
- **Intl**: Format tanggal dan waktu
- **Geolocator**: Lokasi GPS
- **Image Picker**: Pemilihan gambar
- **Signature**: Tanda tangan digital

## Instalasi

1. Clone repository ini
2. Jalankan `flutter pub get`
3. Jalankan `flutter run`

## Struktur Proyek

```
lib/
├── main.dart
├── screens/
│   ├── home_screen.dart
│   ├── history_screen.dart (dengan diagram dan rekap)
│   ├── form_ambulance_screen.dart
│   ├── form_kamtib_screen_fixed.dart
│   ├── form_rescue_screen.dart
│   ├── backup_restore_screen.dart
│   ├── notification_settings_screen.dart
│   └── ...
├── services/
│   ├── backup_service.dart
│   ├── draft_service.dart
│   ├── notification_service.dart
│   └── pdf_storage_service.dart
└── utils/
    └── logger.dart
```

## Fitur Diagram dan Rekap

### Diagram Tab
- **Pie Chart**: Menampilkan distribusi persentase jenis kendaraan yang diinspeksi
- **Bar Chart**: Menampilkan jumlah inspeksi per jenis kendaraan
- **Summary Cards**: Menampilkan total inspeksi dan jumlah jenis kendaraan

### Filter Waktu
- **Hari Ini**: Data inspeksi hari ini
- **Minggu Ini**: Data inspeksi minggu ini (Senin-Minggu)
- **Bulan Ini**: Data inspeksi bulan ini
- **Tahun Ini**: Data inspeksi tahun ini
- **Kustom**: Pilih rentang tanggal tertentu

### Ekspor PDF Rekap
- Header dengan logo perusahaan
- Summary data inspeksi
- Tabel detail per jenis kendaraan
- Persentase distribusi
- Timestamp pembuatan laporan

## Penggunaan

1. **Inspeksi Kendaraan**:
   - Pilih jenis kendaraan di halaman utama
   - Isi form inspeksi sesuai jenis kendaraan
   - Simpan hasil inspeksi

2. **Lihat Riwayat**:
   - Buka tab "Riwayat" di halaman utama
   - Gunakan filter waktu dan jenis kendaraan
   - Lihat diagram di tab "Diagram"
   - Lihat daftar di tab "Daftar"

3. **Ekspor Data**:
   - Klik tombol ekspor di halaman riwayat
   - PDF rekap akan dibuat dengan diagram dan tabel
   - File dapat dibagikan atau disimpan

4. **Manajemen PDF**:
   - Klik menu di setiap item riwayat
   - Pilih "Buka PDF" untuk melihat hasil
   - Pilih "Bagikan" untuk membagikan file

## Lisensi

Proyek ini dikembangkan untuk JASAMARGA JALANLAYANG CIKAMPEK.
