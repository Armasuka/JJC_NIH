# 🚗 FLOWCHART APLIKASI JJC OPERASIONAL

## 📱 Alur Utama Aplikasi

```
┌─────────────────────────────────────────────────────────────────┐
│                    🚀 START APLIKASI                           │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                ⚙️ INITIALIZE SERVICES                          │
│  • Hive Database                                               │
│  • Notification Service                                        │
│  • Auto Backup Check                                          │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                📁 CHECK FILE INTENT                            │
│  Ada file backup yang dibuka dari aplikasi lain?              │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                🎬 SPLASH SCREEN                                │
│  • Logo animasi JJC                                            │
│  • Loading indicator                                           │
│  • Check onboarding status                                     │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                📚 ONBOARDING CHECK                             │
│  First time user? → Onboarding → Tutorial                      │
│  Returning user? → Home Screen                                 │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                🏠 HOME SCREEN                                  │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐              │
│  │🚗 Inspeksi  │ │📋 Riwayat   │ │💾 Backup    │              │
│  │Kendaraan    │ │Inspeksi     │ │& Restore    │              │
│  └─────────────┘ └─────────────┘ └─────────────┘              │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐              │
│  │📝 Draft     │ │❓ Tutorial   │ │🔔 Notifikasi│              │
│  │Tersimpan    │ │Panduan      │ │Settings     │              │
│  └─────────────┘ └─────────────┘ └─────────────┘              │
└─────────────────────────────────────────────────────────────────┘
```

## 🚗 Alur Inspeksi Kendaraan

```
┌─────────────────────────────────────────────────────────────────┐
│                🚗 KENDARAAN SCREEN                             │
│  Pilih Jenis Kendaraan:                                        │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐  │
│  │🚑 Ambul │ │🚛 Derek │ │🚗 Plaza │ │🛡️ Kamtib│ │🚨 Rescue│  │
│  │ance     │ │         │ │         │ │         │ │         │  │
│  └─────────┘ └─────────┘ └─────────┘ └─────────┘ └─────────┘  │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                📝 DRAFT CHECK                                  │
│  Ada draft tersimpan?                                          │
│  • Ya → Dialog pilihan (Buka draft / Buat baru)               │
│  • Tidak → Langsung ke form                                    │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                📋 FORM INSPEKSI                                │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ 1️⃣ Data Petugas                                        │   │
│  │    • Petugas 1 & 2                                      │   │
│  │    • Nama, NIP, Jabatan                                 │   │
│  └─────────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ 2️⃣ Data Kendaraan                                      │   │
│  │    • Nomor Polisi                                       │   │
│  │    • Identitas Kendaraan                                │   │
│  │    • Kondisi (BAIK/RR/RB)                               │   │
│  └─────────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ 3️⃣ Checklist Kelengkapan                               │   │
│  │    • Peralatan sesuai jenis kendaraan                   │   │
│  │    • Status: BAIK/RR/RB                                 │   │
│  └─────────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ 4️⃣ Upload Foto Bukti                                   │   │
│  │    • 📷 STNK, SIM, KIR                                  │   │
│  │    • 📷 Sertifikat, Service, BBM                        │   │
│  └─────────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ 5️⃣ Lokasi GPS                                          │   │
│  │    • 📍 Ambil koordinat otomatis                        │   │
│  │    • ✏️ Manual input jika perlu                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ 6️⃣ Digital Signature                                   │   │
│  │    • ✍️ Petugas 1 & 2                                   │   │
│  │    • ✍️ Manager                                          │   │
│  │    • ✍️ JJC                                             │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                💾 AUTO SAVE DRAFT                              │
│  • Simpan otomatis setiap 30 detik                             │
│  • Simpan ke Hive database                                     │
│  • Resume kapan saja                                           │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                ✅ SUBMIT FORM                                  │
│  • Validasi semua field                                        │
│  • Generate PDF report                                         │
│  • Simpan ke database                                          │
│  • Hapus draft                                                 │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                🎉 SUCCESS SCREEN                               │
│  • Konfirmasi berhasil                                         │
│  • Tombol kembali ke home                                      │
│  • Tombol lihat riwayat                                        │
└─────────────────────────────────────────────────────────────────┘
```

## 📋 Alur Riwayat Inspeksi

```
┌─────────────────────────────────────────────────────────────────┐
│                📋 HISTORY SCREEN                               │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ 🔍 Filter & Search                                     │   │
│  │ • Berdasarkan tanggal                                  │   │
│  │ • Berdasarkan jenis kendaraan                          │   │
│  │ • Search text                                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ 📋 List Riwayat                                        │   │
│  │ • Tampilkan semua data inspeksi                        │   │
│  │ • 👁️ View detail                                       │   │
│  │ • 🖨️ Print/Share PDF                                   │   │
│  │ • 🗑️ Delete records                                    │   │
│  └─────────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ 📊 Statistics & Charts                                 │   │
│  │ • Grafik inspeksi per bulan                            │   │
│  │ • Statistik per jenis kendaraan                        │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## 💾 Alur Backup & Restore

```
┌─────────────────────────────────────────────────────────────────┐
│                💾 BACKUP & RESTORE                             │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ 📤 Manual Backup                                       │   │
│  │ • Export data ke ZIP/JSON                              │   │
│  │ • Share file                                           │   │
│  └─────────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ 📥 Restore Data                                        │   │
│  │ • Import dari file                                     │   │
│  │ • Replace database                                     │   │
│  └─────────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ ⏰ Auto Backup                                         │   │
│  │ • Jadwal otomatis                                      │   │
│  │ • Konfigurasi waktu                                    │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## 🗄️ Struktur Database

```
┌─────────────────────────────────────────────────────────────────┐
│                🗄️ HIVE DATABASE                                │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ 📋 inspection_history Box                              │   │
│  │ • id (String)                                          │   │
│  │ • formType (String)                                    │   │
│  │ • petugas1, petugas2 (String)                          │   │
│  │ • nopol (String)                                       │   │
│  │ • lokasi (String)                                      │   │
│  │ • timestamp (DateTime)                                 │   │
│  │ • pdfPath (String)                                     │   │
│  │ • formData (JSON)                                      │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ 📝 drafts Box                                          │   │
│  │ • key (String) - formType_draft                         │   │
│  │ • formType (String)                                    │   │
│  │ • draftData (JSON)                                     │   │
│  │ • lastModified (DateTime)                              │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ 📄 PDF Storage                                         │   │
│  │ • File system storage                                   │   │
│  │ • Organized by date                                     │   │
│  │ • Automatic cleanup                                     │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## 🎯 Fitur Utama Aplikasi

### 1. 📱 **Mobile-First Design**
- Responsive UI untuk berbagai ukuran layar
- Touch-friendly interface
- Offline capability

### 2. 🔄 **Auto-Save Draft**
- Simpan otomatis setiap 30 detik
- Resume kapan saja
- Conflict resolution

### 3. 📄 **PDF Generation**
- Generate laporan profesional
- Include foto dan signature
- Print dan share functionality

### 4. 📊 **Data Management**
- Local Hive database
- Backup/restore functionality
- Data export/import

### 5. 📍 **Location Tracking**
- GPS integration
- Automatic location capture
- Manual override

### 6. ✍️ **Digital Signature**
- Multiple signature support
- Secure signature capture
- PDF integration

### 7. 🔔 **Notifications**
- Local notifications
- Backup reminders
- System alerts

### 8. 🎨 **Modern UI/UX**
- Material Design 3
- Smooth animations
- Intuitive navigation

## 🔧 Teknologi yang Digunakan

- **Framework**: Flutter
- **Database**: Hive (Local NoSQL)
- **PDF**: pdf package
- **Image**: image_picker
- **Location**: geolocator
- **Signature**: signature package
- **Storage**: path_provider, file_picker
- **Share**: share_plus
- **Print**: printing package
- **Charts**: fl_chart
- **Notifications**: flutter_local_notifications

## 📊 Alur Data

```
Input → Processing → Storage → Output → Sharing
  │         │          │         │         │
  ▼         ▼          ▼         ▼         ▼
Form → Auto-save → Hive DB → PDF → Print/Share
Data → Generate → Local → Report → Export
      PDF      Storage
```

## 🔒 Keamanan & Backup

- Data tersimpan lokal di Hive database
- Auto-backup dengan jadwal yang dapat dikonfigurasi
- Manual backup/restore functionality
- File sharing untuk transfer data antar device
- Draft management untuk mencegah kehilangan data





