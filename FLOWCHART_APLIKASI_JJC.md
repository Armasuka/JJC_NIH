# FLOWCHART APLIKASI JJC OPERASIONAL

## Alur Kerja Utama Aplikasi

```mermaid
flowchart TD
    A[Start Aplikasi] --> B[Initialize Services]
    B --> C[Check Auto Backup]
    C --> D[Check Shared File Intent]
    
    D --> E{Ada File Backup?}
    E -->|Ya| F[Validasi File]
    F --> G{File Valid?}
    G -->|Ya| H[Restore Screen]
    G -->|Tidak| I[Invalid File Screen]
    H --> J[Backup Restore Screen]
    I --> K[Splash Screen]
    
    E -->|Tidak| K[Splash Screen]
    K --> L[Check Onboarding Status]
    L --> M{Onboarding Done?}
    M -->|Tidak| N[Onboarding Screen]
    M -->|Ya| O[Home Screen]
    
    N --> P[Tutorial Screen]
    P --> O[Home Screen]
    
    O --> Q{User Action}
    Q -->|Inspeksi Kendaraan| R[Kendaraan Screen]
    Q -->|Riwayat Inspeksi| S[History Screen]
    Q -->|Backup & Restore| T[Backup Restore Screen]
    Q -->|Draft| U[Draft Dialog]
    Q -->|Tutorial| P
    Q -->|Notifikasi| V[Notification Settings]
    
    R --> W[Pilih Jenis Kendaraan]
    W --> X{Ada Draft?}
    X -->|Ya| Y[Draft Dialog]
    X -->|Tidak| Z[Form Inspeksi]
    
    Y --> AA{User Choice}
    AA -->|Buka Draft| Z
    AA -->|Buat Baru| Z
    
    Z --> BB[Form Ambulance/Derek/Plaza/Kamtib/Rescue]
    BB --> CC[Auto Save Draft]
    CC --> DD[Isi Form]
    DD --> EE[Upload Foto]
    EE --> FF[Ambil Lokasi GPS]
    FF --> GG[Signature Digital]
    GG --> HH[Submit Form]
    HH --> II[Generate PDF]
    II --> JJ[Save ke Hive Database]
    JJ --> KK[Success Screen]
    KK --> LL{User Choice}
    LL -->|Kembali Home| O
    LL -->|Lihat Riwayat| S
    
    S --> MM[Filter & Search]
    MM --> NN[View/Print/Share PDF]
    NN --> OO[Delete Records]
    OO --> S
    
    T --> PP[Backup Data]
    T --> QQ[Restore Data]
    T --> RR[Auto Backup Settings]
    PP --> SS[Export ZIP/JSON]
    QQ --> TT[Import File]
    RR --> UU[Schedule Backup]
    
    U --> VV[Select Draft]
    VV --> Z
    
    V --> WW[Notification Settings]
    WW --> O
```

## Detail Alur Form Inspeksi

```mermaid
flowchart TD
    A[Form Inspeksi] --> B[Input Data Petugas]
    B --> C[Input Data Kendaraan]
    C --> D[Input Data Lokasi]
    D --> E[Checklist Kelengkapan]
    E --> F[Upload Foto STNK]
    F --> G[Upload Foto SIM]
    G --> H[Upload Foto KIR]
    H --> I[Upload Foto Sertifikat]
    I --> J[Upload Foto Service]
    J --> K[Upload Foto BBM]
    K --> L[Ambil Lokasi GPS]
    L --> M[Signature Petugas 1]
    M --> N[Signature Petugas 2]
    N --> O[Signature Manager]
    O --> P[Signature JJC]
    P --> Q[Validasi Form]
    Q --> R{Form Valid?}
    R -->|Tidak| S[Show Error]
    S --> A
    R -->|Ya| T[Generate PDF Report]
    T --> U[Save ke Database]
    U --> V[Clear Draft]
    V --> W[Success Screen]
```

## Alur Backup & Restore

```mermaid
flowchart TD
    A[Backup Restore Screen] --> B{User Action}
    B -->|Backup Manual| C[Create Backup]
    B -->|Restore| D[Select File]
    B -->|Auto Backup| E[Configure Settings]
    
    C --> F[Collect Data]
    F --> G[Export to ZIP/JSON]
    G --> H[Save to Storage]
    H --> I[Share File]
    
    D --> J[File Picker]
    J --> K[Validate File]
    K --> L{File Valid?}
    L -->|Tidak| M[Show Error]
    L -->|Ya| N[Import Data]
    N --> O[Replace Database]
    O --> P[Success Message]
    
    E --> Q[Set Frequency]
    Q --> R[Set Time]
    R --> S[Enable Auto Backup]
    S --> T[Schedule Task]
```

## Struktur Database

```mermaid
erDiagram
    INSPECTION_HISTORY {
        string id PK
        string formType
        string petugas1
        string petugas2
        string nopol
        string lokasi
        datetime timestamp
        string pdfPath
        json formData
    }
    
    DRAFTS {
        string key PK
        string formType
        json draftData
        datetime lastModified
    }
    
    PDF_STORAGE {
        string id PK
        string inspectionId FK
        string filePath
        datetime createdAt
    }
    
    INSPECTION_HISTORY ||--o{ PDF_STORAGE : "has"
```

## Fitur Utama Aplikasi

### 1. **Inspeksi Kendaraan**
- 5 jenis kendaraan: Ambulance, Derek, Plaza, Kamtib, Rescue
- Form inspeksi lengkap dengan checklist
- Upload foto bukti (STNK, SIM, KIR, dll)
- GPS location tracking
- Digital signature
- Auto-save draft

### 2. **Riwayat Inspeksi**
- View semua data inspeksi
- Filter berdasarkan tanggal dan jenis kendaraan
- Search functionality
- Print/Share PDF reports
- Delete records
- Statistics dan charts

### 3. **Backup & Restore**
- Manual backup (ZIP/JSON format)
- Auto backup dengan jadwal
- Restore dari file
- Share backup files
- Import dari file intent

### 4. **Draft Management**
- Auto-save setiap 30 detik
- Resume draft yang tersimpan
- Multiple draft support
- Draft conflict resolution

### 5. **PDF Generation**
- Generate laporan PDF otomatis
- Include foto dan signature
- Professional layout
- Print dan share functionality

## Teknologi yang Digunakan

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

## Alur Data

1. **Input** → Form inspeksi dengan validasi
2. **Processing** → Auto-save draft, generate PDF
3. **Storage** → Hive database (local)
4. **Output** → PDF report, backup files
5. **Sharing** → Print, share, export

## Keamanan & Backup

- Data tersimpan lokal di Hive database
- Auto-backup dengan jadwal yang dapat dikonfigurasi
- Manual backup/restore functionality
- File sharing untuk transfer data antar device
- Draft management untuk mencegah kehilangan data
