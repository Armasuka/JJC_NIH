import 'package:flutter/material.dart';
import '../utils/logger.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:typed_data';

import 'package:fl_chart/fl_chart.dart';
import 'package:share_plus/share_plus.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allHistory = [];
  List<Map<String, dynamic>> _filteredHistory = [];
  bool _isLoading = true;
  String _selectedTimeFilter = 'Semua';
  String _selectedVehicleType = 'Semua';
  
  // Tambahan untuk filter tanggal kustom
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;

  final List<String> _timeFilters = [
    'Semua',
    'Hari Ini',
    'Minggu Ini',
    'Bulan Ini',
    'Tahun Ini',
    'Kustom',
  ];

  final List<String> _vehicleTypes = [
    'Semua',
    'Ambulance',
    'Derek',
    'Plaza',
    'Kamtib',
    'Rescue',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (!Hive.isBoxOpen('inspection_history')) {
        await Hive.openBox('inspection_history');
      }

      final box = Hive.box('inspection_history');
      Logger.debug('Box length: ${box.length}');

      _allHistory = [];
      for (var item in box.values) {
        if (item is Map) {
          _allHistory.add(Map<String, dynamic>.from(item));
        }
      }

      _filterData();

      setState(() {
        _isLoading = false;
      });

      Logger.debug('Loaded ${_allHistory.length} items');
    } catch (e) {
      Logger.debug('Error: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterData() {
    List<Map<String, dynamic>> filtered = List.from(_allHistory);

    // Filter berdasarkan pencarian
    if (_searchController.text.isNotEmpty) {
      filtered = filtered.where((item) {
        final searchTerm = _searchController.text.toLowerCase();
        return item['nopol']?.toString().toLowerCase().contains(searchTerm) == true ||
               item['jenis']?.toString().toLowerCase().contains(searchTerm) == true ||
               item['tanggal']?.toString().toLowerCase().contains(searchTerm) == true;
      }).toList();
    }

    // Filter berdasarkan waktu
    if (_selectedTimeFilter != 'Semua') {
      final now = DateTime.now();
      DateTime startDate;
      DateTime endDate;

      switch (_selectedTimeFilter) {
        case 'Hari Ini':
          startDate = DateTime(now.year, now.month, now.day, 0, 0, 0);
          endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          Logger.debug('Filter Hari Ini: ${startDate.toString()} - ${endDate.toString()}');
          break;
        case 'Minggu Ini':
          startDate = now.subtract(Duration(days: now.weekday - 1));
          startDate = DateTime(startDate.year, startDate.month, startDate.day);
          endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
          break;
        case 'Bulan Ini':
          startDate = DateTime(now.year, now.month, 1);
          endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
          break;
        case 'Tahun Ini':
          startDate = DateTime(now.year, 1, 1);
          endDate = DateTime(now.year, 12, 31, 23, 59, 59);
          break;
        case 'Kustom':
          if (_selectedStartDate != null && _selectedEndDate != null) {
            startDate = _selectedStartDate!;
            endDate = _selectedEndDate!;
          } else {
            return; // Tidak filter jika tanggal kustom belum dipilih
          }
          break;
        default:
          return;
      }

      filtered = filtered.where((item) {
        final itemDate = DateTime.tryParse(item['tanggal'] ?? '');
        if (itemDate == null) {
          Logger.debug('Invalid date for item: ${item['tanggal']}');
          return false;
        }
        
        // Normalize tanggal untuk perbandingan (hilangkan waktu)
        final itemDateOnly = DateTime(itemDate.year, itemDate.month, itemDate.day);
        final startDateOnly = DateTime(startDate.year, startDate.month, startDate.day);
        final endDateOnly = DateTime(endDate.year, endDate.month, endDate.day);
        
        final isInRange = (itemDateOnly.isAfter(startDateOnly) || itemDateOnly.isAtSameMomentAs(startDateOnly)) &&
                         (itemDateOnly.isBefore(endDateOnly) || itemDateOnly.isAtSameMomentAs(endDateOnly));
        
        if (_selectedTimeFilter == 'Hari Ini') {
          Logger.debug('Hari Ini Filter - Item: ${item['jenis']} - ${item['nopol']}, ItemDate: ${itemDateOnly.toString()}, Today: ${startDateOnly.toString()}, InRange: $isInRange');
        }
        
        return isInRange;
      }).toList();
    }

    // Filter berdasarkan jenis kendaraan
    if (_selectedVehicleType != 'Semua') {
      filtered = filtered.where((item) {
        final jenis = item['jenis']?.toString();
        // Jika filter bukan "Semua", tampilkan hanya jenis yang dipilih
        // Rekap tidak difilter berdasarkan jenis kendaraan karena itu adalah sistem generated
        return jenis == _selectedVehicleType || (item['isRekap'] == true && jenis == 'Rekap');
      }).toList();
    }

    Logger.debug('Filter applied: ${_selectedTimeFilter}, ${_selectedVehicleType}');
    Logger.debug('Before filter: ${_allHistory.length} items, After filter: ${filtered.length} items');
    
    setState(() {
      _filteredHistory = filtered;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Riwayat Inspeksi'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2257C1),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Header dengan total inspeksi
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color: Colors.white,
                    child: Column(
                      children: [
                        Text(
                          'Total ${_filteredHistory.length} inspeksi',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Search Bar
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Cari berdasarkan nopol...',
                            prefixIcon: const Icon(Icons.search, color: Colors.grey),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          onChanged: (value) => _filterData(),
                        ),
                        const SizedBox(height: 16),
                        
                        // Filter Row
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedTimeFilter,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                hint: const Text('Semua'),
                                items: _timeFilters.map((filter) {
                                  return DropdownMenuItem(
                                    value: filter,
                                    child: Text(filter),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedTimeFilter = value!;
                                    if (value == 'Kustom') {
                                      _showDateRangePicker();
                                    } else {
                                      _selectedStartDate = null;
                                      _selectedEndDate = null;
                                      _filterData();
                                    }
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedVehicleType,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                hint: const Text('Semua'),
                                items: _vehicleTypes.map((type) {
                                  return DropdownMenuItem(
                                    value: type,
                                    child: Text(type),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedVehicleType = value!;
                                    _filterData();
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        
                        // Custom Date Range Display
                        if (_selectedStartDate != null && _selectedEndDate != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Periode: ${DateFormat('dd/MM/yyyy').format(_selectedStartDate!)} - ${DateFormat('dd/MM/yyyy').format(_selectedEndDate!)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  // Tombol Rekap Bulanan
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ElevatedButton.icon(
                      onPressed: _exportMonthlyData,
                      icon: const Icon(Icons.calendar_month, color: Colors.black87),
                      label: const Text(
                        'Rekap Bulanan',
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFE066), // Warna kuning seperti gambar
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  
                  // Info text
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Menampilkan ${_filteredHistory.length} dari ${_allHistory.length} inspeksi',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        if (_selectedTimeFilter != 'Semua' || _selectedVehicleType != 'Semua' || _searchController.text.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.filter_alt, size: 14, color: Colors.orange),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Filter aktif: ${_getActiveFilterText()}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.orange,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _clearAllFilters,
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    minimumSize: const Size(0, 0),
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'Reset',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                                     // Section Statistik
                   _buildStatisticsSection(),
                   
                   // Section Daftar PDF
                   _buildPDFListSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatisticsSection() {
    if (_filteredHistory.isEmpty) {
      return Container();
    }

    final chartData = _getChartData();
    final totalInspeksi = chartData.values.fold(0, (sum, count) => sum + count);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            children: [
              const Icon(Icons.bar_chart, color: Color(0xFF2257C1)),
              const SizedBox(width: 8),
              const Text(
                'Statistik Inspeksi',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2257C1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Bar Chart
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                         child: Padding(
               padding: const EdgeInsets.all(10),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   const Text(
                     'Statistik Inspeksi',
                     style: TextStyle(
                       fontSize: 14,
                       fontWeight: FontWeight.bold,
                     ),
                   ),
                                      const SizedBox(height: 8),
                   SizedBox(
                     height: 160,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: chartData.values.isEmpty ? 10 : chartData.values.reduce((a, b) => a > b ? a : b).toDouble() + 1,
                        barTouchData: BarTouchData(enabled: false),
                        titlesData: FlTitlesData(
                          show: true,
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final types = chartData.keys.toList();
                                if (value.toInt() < types.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      types[value.toInt()],
                                      style: const TextStyle(fontSize: 10),
                                      textAlign: TextAlign.center,
                                    ),
                                  );
                                }
                                return const Text('');
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  value.toInt().toString(),
                                  style: const TextStyle(fontSize: 12),
                                );
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: _buildBarChartGroups(chartData),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Pie Chart
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                         child: Padding(
               padding: const EdgeInsets.all(10),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Row(
                     children: [
                       const Icon(Icons.pie_chart, color: Color(0xFF2257C1)),
                       const SizedBox(width: 8),
                       const Text(
                         'Distribusi Jenis Kendaraan',
                         style: TextStyle(
                           fontSize: 14,
                           fontWeight: FontWeight.bold,
                         ),
                       ),
                     ],
                   ),
                   const SizedBox(height: 8),
                  Row(
                    children: [
                      // Pie Chart
                      Expanded(
                        flex: 2,
                                                 child: SizedBox(
                           height: 110,
                          child: PieChart(
                            PieChartData(
                              sections: _buildPieChartSections(chartData),
                              centerSpaceRadius: 30,
                              sectionsSpace: 2,
                            ),
                          ),
                        ),
                      ),
                      
                      // Legend
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: chartData.entries.map((entry) {
                            final index = chartData.keys.toList().indexOf(entry.key);
                            final colors = [
                              Colors.red,
                              Colors.orange,
                              Colors.blue,
                              Colors.green,
                              Colors.purple,
                              Colors.teal,
                            ];
                            final color = colors[index % colors.length];
                            final percentage = totalInspeksi > 0 ? (entry.value / totalInspeksi * 100).toStringAsFixed(1) : '0';
                            
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          entry.key,
                                          style: const TextStyle(fontSize: 12),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          '$percentage%',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPDFListSection() {
    // Filter untuk mendapatkan data yang memiliki PDF
    final dataWithPDF = _filteredHistory.where((item) => 
      item['pdfPath'] != null && item['pdfPath'].toString().isNotEmpty
    ).toList();
    
    // Urutkan berdasarkan tanggal terbaru
    dataWithPDF.sort((a, b) {
      final dateA = DateTime.tryParse(a['tanggal'] ?? '') ?? DateTime(1970);
      final dateB = DateTime.tryParse(b['tanggal'] ?? '') ?? DateTime(1970);
      return dateB.compareTo(dateA); // Terbaru di atas
    });

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            children: [
              const Icon(Icons.picture_as_pdf, color: Colors.red),
              const SizedBox(width: 8),
              const Text(
                'Riwayat PDF Inspeksi',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'PDF yang sudah di inspeksi dan berurutan berdasarkan inspeksi terbaru',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 6),

          // Daftar PDF
          if (dataWithPDF.isEmpty)
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                child: const Column(
                  children: [
                    Icon(Icons.picture_as_pdf, size: 48, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'Belum ada PDF inspeksi tersedia',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: dataWithPDF.length,
              itemBuilder: (context, index) {
                final item = dataWithPDF[index];
                return _buildPDFCard(item, index + 1);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPDFCard(Map<String, dynamic> item, int number) {
    final date = DateTime.tryParse(item['tanggal'] ?? '');
    final formattedDate = date != null 
        ? DateFormat('dd/MM/yyyy HH:mm').format(date)
        : 'Tanggal tidak valid';
    
    final isRekap = item['isRekap'] == true;
    
         return Card(
       elevation: 2,
       margin: const EdgeInsets.symmetric(vertical: 1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: isRekap ? Colors.orange : _getVehicleTypeColor(item['jenis']),
              child: Icon(
                isRekap ? Icons.summarize : Icons.picture_as_pdf,
                color: Colors.white,
                size: 20,
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$number',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
        title: Text(
          isRekap 
            ? 'Rekap Bulanan - ${item['periode'] ?? 'Periode tidak diketahui'}'
            : '${item['jenis']} - ${item['nopol']}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(formattedDate),
            if (isRekap && item['totalInspeksi'] != null)
              Text('Total: ${item['totalInspeksi']} inspeksi', style: const TextStyle(fontSize: 12))
            else if (item['lokasi'] != null)
              Text('Lokasi: ${item['lokasi']}', style: const TextStyle(fontSize: 12)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.visibility, color: Color(0xFF2257C1)),
              onPressed: () => _openPDF(item),
              tooltip: 'Buka PDF',
            ),
            IconButton(
              icon: const Icon(Icons.share, color: Colors.green),
              onPressed: () => _sharePDF(item),
              tooltip: 'Bagikan PDF',
            ),
          ],
        ),
      ),
    );
  }



  List<PieChartSectionData> _buildPieChartSections(Map<String, int> chartData) {
    final colors = [
      Colors.red,
      Colors.orange,
      Colors.blue,
      Colors.green,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
    ];

    return chartData.entries.map((entry) {
      final index = chartData.keys.toList().indexOf(entry.key);
      final color = colors[index % colors.length];
      final total = chartData.values.fold(0, (sum, count) => sum + count);
      final percentage = total > 0 ? (entry.value / total * 100).toStringAsFixed(1) : '0';

      return PieChartSectionData(
        color: color,
        value: entry.value.toDouble(),
        title: '${entry.key}\n$percentage%',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  List<BarChartGroupData> _buildBarChartGroups(Map<String, int> chartData) {
    return chartData.entries.map((entry) {
      final index = chartData.keys.toList().indexOf(entry.key);
      final colors = [
        Colors.red,
        Colors.orange,
        Colors.blue,
        Colors.green,
        Colors.purple,
        Colors.teal,
        Colors.pink,
        Colors.indigo,
      ];
      final color = colors[index % colors.length];

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: entry.value.toDouble(),
            color: color,
            width: 20,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
        ],
      );
    }).toList();
  }



  Color _getVehicleTypeColor(String? type) {
    switch (type) {
      case 'Ambulance':
        return Colors.red;
      case 'Derek':
        return Colors.orange;
      case 'Plaza':
        return Colors.blue;
      case 'Kamtib':
        return Colors.green;
      case 'Rescue':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }





  Future<void> _openPDF(Map<String, dynamic> item) async {
    try {
      final pdfPath = item['pdfPath'];
      if (pdfPath != null && await File(pdfPath).exists()) {
        Logger.debug('Opening PDF: $pdfPath');
        
        // Baca file PDF sebagai bytes
        final pdfFile = File(pdfPath);
        final pdfBytes = await pdfFile.readAsBytes();
        
        // Tampilkan PDF viewer dialog
        await _showFullPDFViewer(pdfBytes, item);
      } else {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('PDF Tidak Tersedia'),
              content: Text('PDF hasil inspeksi untuk ${item['jenis']} - ${item['nopol']} belum tersimpan.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Tutup'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      Logger.error('Error opening PDF: $e');
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: Text('Gagal membuka PDF: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tutup'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _showFullPDFViewer(Uint8List pdfBytes, Map<String, dynamic> item) async {
    final isRekap = item['isRekap'] == true;
    final title = isRekap 
        ? 'Rekap Bulanan - ${item['periode'] ?? 'Periode tidak diketahui'}'
        : '${item['jenis']} - ${item['nopol']}';
    
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.95,
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isRekap ? Colors.orange : const Color(0xFF2257C1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isRekap ? Icons.summarize : Icons.picture_as_pdf,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              
              // PDF Viewer
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(8),
                  child: PdfPreview(
                    build: (format) => pdfBytes,
                    allowPrinting: true,
                    allowSharing: true,
                    canChangePageFormat: false,
                    canDebug: false,
                    maxPageWidth: 400,
                    actions: [
                      // Custom action untuk share
                      PdfPreviewAction(
                        icon: const Icon(Icons.share),
                        onPressed: (context, build, pageFormat) async {
                          await _sharePDF(item);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sharePDF(Map<String, dynamic> item) async {
    try {
      final pdfPath = item['pdfPath'];
      if (pdfPath != null && await File(pdfPath).exists()) {
        await Share.shareXFiles([XFile(pdfPath)], text: 'PDF Inspeksi ${item['jenis']} - ${item['nopol']}');
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PDF tidak tersedia untuk dibagikan')),
          );
        }
      }
    } catch (e) {
      Logger.error('Error sharing PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membagikan PDF: $e')),
        );
      }
    }
  }

  Future<void> _showDateRangePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedStartDate != null && _selectedEndDate != null
          ? DateTimeRange(start: _selectedStartDate!, end: _selectedEndDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _selectedStartDate = picked.start;
        _selectedEndDate = picked.end;
        _filterData();
      });
    }
  }

  String _getPeriodText() {
    if (_selectedTimeFilter == 'Kustom' && _selectedStartDate != null && _selectedEndDate != null) {
      return 'Periode: ${DateFormat('dd/MM/yyyy').format(_selectedStartDate!)} - ${DateFormat('dd/MM/yyyy').format(_selectedEndDate!)}';
    } else if (_selectedTimeFilter != 'Semua') {
      return 'Periode: $_selectedTimeFilter';
    }
    return 'Semua Periode';
  }

  String _getActiveFilterText() {
    List<String> activeFilters = [];
    
    if (_selectedTimeFilter != 'Semua') {
      if (_selectedTimeFilter == 'Kustom' && _selectedStartDate != null && _selectedEndDate != null) {
        activeFilters.add('${DateFormat('dd/MM').format(_selectedStartDate!)} - ${DateFormat('dd/MM').format(_selectedEndDate!)}');
      } else {
        activeFilters.add(_selectedTimeFilter);
      }
    }
    
    if (_selectedVehicleType != 'Semua') {
      activeFilters.add(_selectedVehicleType);
    }
    
    if (_searchController.text.isNotEmpty) {
      activeFilters.add('Pencarian: "${_searchController.text}"');
    }
    
    return activeFilters.join(', ');
  }

  void _clearAllFilters() {
    setState(() {
      _selectedTimeFilter = 'Semua';
      _selectedVehicleType = 'Semua';
      _selectedStartDate = null;
      _selectedEndDate = null;
      _searchController.clear();
    });
    _filterData();
  }

  Map<String, int> _getChartData() {
    final Map<String, int> data = {};
    for (final item in _filteredHistory) {
      final type = item['jenis']?.toString() ?? 'Unknown';
      data[type] = (data[type] ?? 0) + 1;
    }
    return data;
  }

  Future<void> _exportMonthlyData() async {
    final chartData = _getChartData();
    final totalInspeksi = chartData.values.fold(0, (sum, count) => sum + count);
    
    if (totalInspeksi == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada data untuk diekspor')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Membuat PDF Rekap...'),
          ],
        ),
      ),
    );

    try {
      final pdf = pw.Document();
      final font = await PdfGoogleFonts.nunitoRegular();
      final fontBold = await PdfGoogleFonts.nunitoBold();
      final logoBytes = await rootBundle.load('assets/logo_jjc.png');
      final logo = pw.MemoryImage(logoBytes.buffer.asUint8List());

      // Halaman 1 - Cover dan Summary
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) => [
            // Header dengan logo dan nama perusahaan
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Image(logo, width: 150, height: 150),
                pw.SizedBox(height: 10),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'REKAP INSPEKSI KENDARAAN',
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      _getPeriodText(),
                      style: pw.TextStyle(
                        font: font,
                        fontSize: 12,
                      ),
                    ),
                    pw.Text(
                      'Total: $totalInspeksi inspeksi',
                      style: pw.TextStyle(
                        font: font,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // Summary Section
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Column(
                    children: [
                      pw.Text(
                        'Total Inspeksi',
                        style: pw.TextStyle(
                          font: font,
                          fontSize: 10,
                        ),
                      ),
                      pw.Text(
                        '$totalInspeksi',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue,
                        ),
                      ),
                    ],
                  ),
                  pw.VerticalDivider(color: PdfColors.grey400),
                  pw.Column(
                    children: [
                      pw.Text(
                        'Jenis Kendaraan',
                        style: pw.TextStyle(
                          font: font,
                          fontSize: 10,
                        ),
                      ),
                      pw.Text(
                        '${chartData.entries.where((entry) => entry.value > 0).length}',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Chart Data - Diagram Batang
            pw.Text(
              'Detail per Jenis Kendaraan',
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            
            // Diagram Batang Horizontal
            pw.Container(
              height: 150,
              child: pw.Column(
                children: chartData.entries.map((entry) {
                  final percentage = totalInspeksi > 0 ? (entry.value / totalInspeksi * 100) : 0.0;
                  final maxCount = chartData.values.isEmpty ? 1 : chartData.values.reduce((a, b) => a > b ? a : b);
                  final barWidth = (entry.value / maxCount) * 300; // Max width 300
                  
                  // Warna untuk setiap jenis kendaraan
                  final colors = {
                    'Ambulance': PdfColors.red,
                    'Derek': PdfColors.orange,
                    'Plaza': PdfColors.blue,
                    'Kamtib': PdfColors.green,
                    'Rescue': PdfColors.purple,
                  };
                  final barColor = colors[entry.key] ?? PdfColors.grey;
                  
                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Row(
                      children: [
                        // Label jenis kendaraan
                        pw.SizedBox(
                          width: 80,
                          child: pw.Text(
                            entry.key,
                            style: pw.TextStyle(font: font, fontSize: 10),
                            textAlign: pw.TextAlign.left,
                          ),
                        ),
                        pw.SizedBox(width: 10),
                        
                        // Bar chart
                        pw.Container(
                          width: barWidth,
                          height: 16,
                          decoration: pw.BoxDecoration(
                            color: barColor,
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
                          ),
                        ),
                        pw.SizedBox(width: 10),
                        
                        // Nilai dan persentase
                        pw.Text(
                          '${entry.value} (${percentage.toStringAsFixed(1)}%)',
                          style: pw.TextStyle(font: font, fontSize: 9),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            
            // Tambahan: Detail data inspeksi per item
            pw.SizedBox(height: 4),
            pw.Text(
              'Detail Riwayat Inspeksi',
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            
            // Tabel detail inspeksi
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('No', style: pw.TextStyle(font: fontBold, fontSize: 10)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('Tanggal', style: pw.TextStyle(font: fontBold, fontSize: 10)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('Jenis', style: pw.TextStyle(font: fontBold, fontSize: 10)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('Nopol', style: pw.TextStyle(font: fontBold, fontSize: 10)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('Lokasi', style: pw.TextStyle(font: fontBold, fontSize: 10)),
                    ),
                  ],
                ),
                // Data rows - batasi maksimal 50 item untuk mencegah PDF terlalu panjang
                ..._filteredHistory.take(50).toList().asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final date = DateTime.tryParse(item['tanggal'] ?? '');
                  final formattedDate = date != null 
                      ? DateFormat('dd/MM/yy HH:mm').format(date)
                      : 'N/A';
                  
                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('${index + 1}', style: pw.TextStyle(font: font, fontSize: 9)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(formattedDate, style: pw.TextStyle(font: font, fontSize: 9)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(item['jenis']?.toString() ?? 'N/A', style: pw.TextStyle(font: font, fontSize: 9)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(item['nopol']?.toString() ?? 'N/A', style: pw.TextStyle(font: font, fontSize: 9)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(item['lokasi']?.toString() ?? 'N/A', style: pw.TextStyle(font: font, fontSize: 9)),
                      ),
                    ],
                  );
                }).toList(),
              ],
            ),

            // Footer info jika data lebih dari 50
            if (_filteredHistory.length > 50)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 10),
                child: pw.Text(
                  'Menampilkan 50 dari ${_filteredHistory.length} data inspeksi. Untuk data lengkap, gunakan filter periode yang lebih spesifik.',
                  style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600),
                ),
              ),
          ],
        ),
      );

      // Generate PDF bytes
      final bytes = await pdf.save();
      final fileName = 'rekap_inspeksi_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        
        // Langsung buka PDF untuk preview
        await _showPDFPreview(bytes, fileName, chartData, totalInspeksi);
      }
      
    } catch (e) {
      Logger.error('Error generating PDF: $e');
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuat PDF: $e')),
        );
      }
    }
  }

  Future<void> _showPDFPreview(Uint8List pdfBytes, String fileName, Map<String, int> chartData, int totalInspeksi) async {
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF2257C1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.picture_as_pdf, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Rekap Inspeksi Siap',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '$totalInspeksi inspeksi • ${_getPeriodText()}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              
              // Preview PDF
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: PdfPreview(
                      build: (format) => pdfBytes,
                      allowPrinting: false,
                      allowSharing: false,
                      canChangePageFormat: false,
                      canDebug: false,
                      maxPageWidth: 400,
                    ),
                  ),
                ),
              ),
              
              // Action buttons
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _savePDFToDevice(pdfBytes, fileName);
                        },
                        icon: const Icon(Icons.download),
                        label: const Text('Simpan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _sharePDFBytes(pdfBytes, fileName);
                        },
                        icon: const Icon(Icons.share),
                        label: const Text('Bagikan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2257C1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _savePDFToDevice(Uint8List pdfBytes, String fileName) async {
    try {
      // Simpan ke Downloads folder
      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }
      final downloadFile = File('${downloadsDir.path}/$fileName');
      await downloadFile.writeAsBytes(pdfBytes);
      
      // Simpan entry ke riwayat juga
      await _saveRekapToHistory(downloadFile.path, fileName);
      
      // Juga panggil printing untuk compatibility
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) => pdfBytes,
        name: fileName,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF berhasil disimpan: $fileName'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Refresh data untuk menampilkan PDF baru di riwayat
        _loadData();
      }
    } catch (e) {
      Logger.error('Error saving PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveRekapToHistory(String pdfPath, String fileName) async {
    try {
      if (!Hive.isBoxOpen('inspection_history')) {
        await Hive.openBox('inspection_history');
      }
      
      final box = Hive.box('inspection_history');
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      
      box.add({
        'id': id,
        'jenis': 'Rekap',
        'tanggal': DateTime.now().toIso8601String(),
        'nopol': 'Rekap Bulanan',
        'petugas1': 'System',
        'petugas2': '',
        'lokasi': 'System Generated',
        'pdfPath': pdfPath,
        'isRekap': true, // Flag untuk membedakan rekap dengan inspeksi biasa
        'periode': _getPeriodText(),
        'totalInspeksi': _filteredHistory.length,
      });
      
      Logger.debug('Rekap saved to history: $fileName');
    } catch (e) {
      Logger.error('Error saving rekap to history: $e');
    }
  }

  Future<void> _sharePDFBytes(Uint8List pdfBytes, String fileName) async {
    try {
      // Simpan temporary file untuk sharing
      final tempDir = await Directory.systemTemp.createTemp();
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(pdfBytes);
      
      await Share.shareXFiles(
        [XFile(tempFile.path)],
        text: 'Rekap Inspeksi Kendaraan - ${_getPeriodText()}',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF berhasil dibagikan'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      Logger.error('Error sharing PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membagikan PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
