# Fitur Backup & Restore - Jasamarga Inspector

## Fitur Baru: Deteksi Otomatis File Backup

### 🎯 Kemampuan Utama

1. **Scan Otomatis File Backup**
   - Mencari file backup di berbagai lokasi secara otomatis
   - Mendeteksi file di Downloads, Documents, Backup Folder, dan Storage
   - Menampilkan informasi lokasi file backup

2. **Pemilihan Metode Restore**
   - **Scan File Backup**: Cari file backup di perangkat
   - **Pilih File Manual**: Pilih file backup secara manual
   - **File Terdeteksi**: Lihat file yang sudah ditemukan

3. **Deteksi Lokasi File**
   - Downloads: File yang disimpan di folder Downloads
   - Backup Folder: File di folder backup aplikasi
   - Documents: File di folder Documents
   - Storage: File di lokasi lain di storage

### 📁 Lokasi yang Di-scan

1. **Downloads Folder** (`/storage/emulated/0/Download`)
   - Mencari file dengan nama mengandung "backup_inspeksi" atau "backup"
   - Format: `.zip` dan `.json`

2. **Backup Folder Aplikasi**
   - Folder backup internal aplikasi
   - Semua file `.zip` dan `.json`

3. **Documents Folder**
   - Folder Documents aplikasi
   - Semua file `.zip` dan `.json`

4. **External Storage Root**
   - Root storage untuk file dengan nama backup
   - Format: `.zip` dan `.json`

### 🔧 Cara Penggunaan

#### 1. Restore Data
1. Buka menu "Backup & Restore"
2. Klik tombol "Restore Data"
3. Pilih metode restore:
   - **Scan File Backup**: Otomatis mencari file backup
   - **Pilih File Manual**: Pilih file secara manual
   - **File Terdeteksi**: Lihat file yang sudah ditemukan

#### 2. Scan File Backup
1. Klik tombol "Scan File Backup" (jika belum ada file terdeteksi)
2. Aplikasi akan mencari file backup di semua lokasi
3. File yang ditemukan akan ditampilkan dengan informasi:
   - Nama file
   - Ukuran file
   - Tanggal modifikasi
   - Lokasi file
   - Format file (ZIP/JSON)

#### 3. Restore dari File
1. Klik file backup yang ingin di-restore
2. Konfirmasi restore
3. Tunggu proses restore selesai

### 📱 Fitur UI/UX

1. **Dialog Pilihan Metode**
   - Tampilan yang jelas untuk memilih metode restore
   - Informasi jumlah file yang sudah terdeteksi

2. **List File Backup**
   - Tampilan file dengan informasi lengkap
   - Indikator lokasi file
   - Tombol restore yang mudah diakses

3. **Refresh Otomatis**
   - Tombol refresh untuk scan ulang
   - Pull-to-refresh untuk update data

4. **Loading States**
   - Indikator loading saat scan
   - Progress dialog saat restore

### 🔒 Keamanan

1. **Validasi File**
   - Cek ekstensi file (.zip/.json)
   - Validasi ukuran file (min 10 bytes, max 10MB)
   - Verifikasi format JSON/ZIP

2. **Konfirmasi Restore**
   - Dialog konfirmasi sebelum restore
   - Peringatan bahwa data lama akan diganti

3. **Error Handling**
   - Pesan error yang informatif
   - Fallback ke metode manual jika scan gagal

### 📋 Informasi File

Setiap file backup menampilkan:
- **Nama File**: Nama lengkap file
- **Ukuran**: Ukuran dalam KB
- **Tanggal**: Tanggal modifikasi terakhir
- **Lokasi**: Folder tempat file disimpan
- **Format**: ZIP atau JSON
- **Status**: Tombol restore

### 🚀 Keunggulan

1. **Otomatis**: Tidak perlu mencari file manual
2. **Komprehensif**: Scan di semua lokasi yang mungkin
3. **User-friendly**: Interface yang mudah digunakan
4. **Informatif**: Menampilkan detail file yang lengkap
5. **Responsif**: Loading states dan feedback yang baik

### 🔄 Kompatibilitas

- **Format File**: ZIP (v2.0) dan JSON (legacy)
- **Android Version**: Android 6.0+ (API 23+)
- **Storage Access**: Mendukung scoped storage dan legacy storage
- **File Sources**: WhatsApp, Email, File Manager, dll.

### 📝 Catatan Teknis

1. **Permission**: Menggunakan SAF (Storage Access Framework) untuk Android 10+
2. **Performance**: Scan dilakukan secara asynchronous
3. **Memory**: File dibaca secara streaming untuk menghemat memory
4. **Error Recovery**: Fallback ke manual pick jika scan gagal

### 🎨 UI Components

1. **AlertDialog**: Dialog pilihan metode restore
2. **ListView**: Daftar file backup
3. **Card**: Tampilan file dengan shadow dan border
4. **Icon**: Indikator visual untuk tipe file dan lokasi
5. **Button**: Tombol aksi dengan styling yang konsisten

### 🔧 Troubleshooting

1. **File tidak terdeteksi**:
   - Pastikan file ada di Downloads atau Documents
   - Coba scan ulang dengan tombol refresh
   - Gunakan "Pilih File Manual"

2. **Permission error**:
   - Berikan permission storage di pengaturan
   - Restart aplikasi setelah berikan permission

3. **File corrupt**:
   - Coba file backup lain
   - Pastikan file tidak rusak saat transfer

### 📈 Performance

- **Scan Time**: ~2-5 detik tergantung jumlah file
- **Memory Usage**: Minimal, menggunakan streaming
- **Battery Impact**: Rendah, scan dilakukan sekali
- **Storage Access**: Efisien dengan batch reading
