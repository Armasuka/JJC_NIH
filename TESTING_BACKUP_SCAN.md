# 🧪 Testing Fitur Scan Backup

## File Test yang Sudah Dibuat

Saya telah membuat beberapa file backup test untuk menguji fitur scan:

### 📁 File Test yang Tersedia:

1. **`test_backup.json`** - File JSON test sederhana
2. **`test_backup.zip`** - File ZIP test sederhana  
3. **`backup_inspeksi_test_20240115.json`** - File backup dengan format nama yang sesuai
4. **`backup_inspeksi_test_20240115.zip`** - File ZIP backup dengan format nama yang sesuai

## 🔧 Cara Testing

### 1. Copy File Test ke Device
- Copy salah satu file test di atas ke folder Downloads di device Android
- Atau copy ke folder Documents aplikasi

### 2. Jalankan Aplikasi
```bash
flutter run
```

### 3. Test Fitur Scan
1. Buka menu "Backup & Restore"
2. Klik tombol "Scan File Backup" 
3. Atau klik "Restore Data" → "Scan File Backup"
4. Lihat hasil scan di console/log

### 4. Debugging
- Buka console/log untuk melihat output scan
- Cari log dengan emoji 🔍 untuk melihat proses scan
- Log akan menampilkan:
  - 📁 Lokasi yang di-scan
  - 📂 Jumlah file yang ditemukan
  - 📄 Path file yang ditemukan
  - ✅ Hasil akhir scan

## 🐛 Troubleshooting

### Jika File Tidak Terdeteksi:

1. **Cek Permission**:
   - Pastikan aplikasi memiliki permission storage
   - Buka Settings → Apps → Jasamarga Inspector → Permissions
   - Aktifkan "Storage" permission

2. **Cek Lokasi File**:
   - File harus ada di salah satu lokasi:
     - `/storage/emulated/0/Download`
     - `/sdcard/Download` 
     - Documents folder aplikasi
     - External storage root

3. **Cek Format File**:
   - File harus berformat `.json` atau `.zip`
   - Nama file sebaiknya mengandung "backup" atau "inspeksi"

4. **Cek Log Console**:
   - Lihat output di console untuk error messages
   - Cari log dengan ❌ untuk error

### Test Manual:
1. Klik tombol "Buat File Backup Test" di aplikasi
2. File test akan dibuat otomatis
3. Kemudian scan ulang untuk melihat file tersebut

## 📱 Expected Behavior

### Jika Berhasil:
- File backup akan muncul di list
- Menampilkan informasi: nama, ukuran, tanggal, lokasi
- Bisa langsung klik file untuk restore

### Jika Gagal:
- Muncul pesan "Tidak ada file backup ditemukan"
- Ada tombol "Pilih File Manual" sebagai fallback
- Log error di console

## 🔍 Debug Commands

Untuk melihat log scan secara real-time:
```bash
flutter logs
```

Atau lihat di Android Studio/VS Code console saat aplikasi running.
