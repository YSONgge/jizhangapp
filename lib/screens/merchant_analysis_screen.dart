import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:expense_tracker/database/database_helper.dart';
import 'package:intl/intl.dart';

class MerchantAnalysisScreen extends StatefulWidget {
  final int? initialYear;
  final int? initialMonth;
  final int? initialQuarter;

  const MerchantAnalysisScreen({
    super.key,
    this.initialYear,
    this.initialMonth,
    this.initialQuarter,
  });

  @override
  State<MerchantAnalysisScreen> createState() => _MerchantAnalysisScreenState();
}

class _MerchantAnalysisScreenState extends State<MerchantAnalysisScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late int _selectedYear;
  late int _selectedMonth;
  late int _selectedQuarter;
  late int _selectedPeriodType;
  List<Map<String, dynamic>> _merchantData = [];
  Map<String, double> _monthlyTrend = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialYear ?? DateTime.now().year;
    _selectedMonth = widget.initialMonth ?? DateTime.now().month;
    _selectedQuarter = widget.initialQuarter ?? ((DateTime.now().month - 1) ~/ 3 + 1);
    _selectedPeriodType = 0;
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  DateTime get _periodStartDate {
    if (_selectedPeriodType == 0) {
      return DateTime(_selectedYear, _selectedMonth, 1);
    } else if (_selectedPeriodType == 1) {
      final startMonth = (_selectedQuarter - 1) * 3 + 1;
      return DateTime(_selectedYear, startMonth, 1);
    } else {
      return DateTime(_selectedYear, 1, 1);
    }
  }

  DateTime get _periodEndDate {
    if (_selectedPeriodType == 0) {
      return DateTime(_selectedYear, _selectedMonth + 1, 0, 23, 59, 59);
    } else if (_selectedPeriodType == 1) {
      final endMonth = _selectedQuarter * 3;
      return DateTime(_selectedYear, endMonth + 1, 0, 23, 59, 59);
    } else {
      return DateTime(_selectedYear, 12, 31, 23, 59, 59);
    }
  }

  String get _periodLabel {
    if (_selectedPeriodType == 0) {
      return '$_selectedYear年${_selectedMonth.toString().padLeft(2, '0')}月';
    } else if (_selectedPeriodType == 1) {
      return '$_selectedYear年Q$_selectedQuarter';
    } else {
      return '$_selectedYear年';
    }
  }

  void _previousPeriod() {
    setState(() {
      if (_selectedPeriodType == 0) {
        if (_selectedMonth > 1) {
          _selectedMonth--;
        } else {
          _selectedMonth = 12;
          _selectedYear--;
        }
      } else if (_selectedPeriodType == 1) {
        if (_selectedQuarter > 1) {
          _selectedQuarter--;
        } else {
          _selectedQuarter = 4;
          _selectedYear--;
        }
      } else {
        _selectedYear--;
      }
    });
    _loadData();
  }

  void _nextPeriod() {
    setState(() {
      if (_selectedPeriodType == 0) {
        if (_selectedMonth < 12) {
          _selectedMonth++;
        } else {
          _selectedMonth = 1;
          _selectedYear++;
        }
      } else if (_selectedPeriodType == 1) {
        if (_selectedQuarter < 4) {
          _selectedQuarter++;
        } else {
          _selectedQuarter = 1;
          _selectedYear++;
        }
      } else {
        _selectedYear++;
      }
    });
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final merchantData = await DatabaseHelper.instance.getMerchantExpenseDetail(
      start: _periodStartDate,
      end: _periodEndDate,
    );

    setState(() {
      _merchantData = merchantData;
      _isLoading = false;
    });
  }

  Future<void> _loadMerchantTrend(String merchant) async {
    final start = DateTime(_selectedYear - 1, _selectedMonth, 1);
    final end = DateTime(_selectedYear, _selectedMonth + 1, 0, 23, 59, 59);
    
    final trend = await DatabaseHelper.instance.getMerchantMonthlyTrend(
      merchant: merchant,
      start: start,
      end: end,
    );
    
    setState(() {
      _monthlyTrend = trend;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('商家消费分析'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF4A90E2),
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: const Color(0xFF4A90E2),
          tabs: const [
            Tab(text: '商家列表'),
            Tab(text: '消费趋势'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildPeriodSelector(),
          if (_merchantData.isNotEmpty) _buildSummary(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMerchantList(),
                _buildTrendView(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _previousPeriod,
              ),
              Text(
                _periodLabel,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _nextPeriod,
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildPeriodTypeButton('月', 0),
              SizedBox(width: 8.w),
              _buildPeriodTypeButton('季度', 1),
              SizedBox(width: 8.w),
              _buildPeriodTypeButton('年', 2),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodTypeButton(String label, int type) {
    final isSelected = _selectedPeriodType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPeriodType = type;
        });
        _loadData();
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4A90E2) : Colors.grey[200],
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            color: isSelected ? Colors.white : Colors.grey[600],
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildSummary() {
    final totalAmount = _merchantData.fold(0.0, (sum, item) => sum + (item['total'] as num).toDouble());
    final merchantCount = _merchantData.length;
    final totalCount = _merchantData.fold(0, (sum, item) => sum + (item['count'] as int));

    return Container(
      color: Colors.white,
      margin: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 0),
      padding: EdgeInsets.all(16.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('商家数', '$merchantCount', Icons.store),
          _buildSummaryItem('消费总额', '¥${NumberFormat('#,##0').format(totalAmount)}', Icons.payments),
          _buildSummaryItem('消费笔数', '$totalCount', Icons.receipt_long),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF4A90E2), size: 24.w),
        SizedBox(height: 4.h),
        Text(value, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(fontSize: 12.sp, color: Colors.grey[500])),
      ],
    );
  }

  Widget _buildMerchantList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_merchantData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.store_outlined, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16.h),
            Text(
              '暂无商家消费记录',
              style: TextStyle(color: Colors.grey[500], fontSize: 16.sp),
            ),
          ],
        ),
      );
    }

    final maxAmount = (_merchantData.first['total'] as num).toDouble();

    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: _merchantData.length,
      itemBuilder: (context, index) {
        final item = _merchantData[index];
        return _buildMerchantItem(item, index, maxAmount);
      },
    );
  }

  Widget _buildMerchantItem(Map<String, dynamic> item, int index, double maxAmount) {
    final merchant = item['merchant'] as String? ?? '未知';
    final amount = (item['total'] as num).toDouble();
    final count = item['count'] as int;
    final avgAmount = (item['avg_amount'] as num).toDouble();
    final categoryName = item['category_name'] as String? ?? '未分类';
    final progress = maxAmount > 0 ? amount / maxAmount : 0.0;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: InkWell(
        onTap: () => _showMerchantDetail(merchant),
        borderRadius: BorderRadius.circular(12.r),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40.w,
                    height: 40.w,
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: const Icon(Icons.store, color: Colors.blue),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          merchant,
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          categoryName,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '¥${NumberFormat('#,##0').format(amount)}',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFE53935),
                        ),
                      ),
                      Text(
                        '$count笔',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 6.h,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(3.r),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: progress.clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(3.r),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Text(
                    '均价¥${NumberFormat('#,##0').format(avgAmount)}',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrendView() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_monthlyTrend.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.trending_up, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16.h),
            Text(
              '点击上方商家查看消费趋势',
              style: TextStyle(color: Colors.grey[500], fontSize: 14.sp),
            ),
          ],
        ),
      );
    }

    final entries = _monthlyTrend.entries.toList();
    final maxY = entries.isEmpty ? 0.0 : entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return Padding(
      padding: EdgeInsets.all(16.w),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY > 0 ? maxY / 4 : 1,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey[200]!,
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < entries.length) {
                    return Padding(
                      padding: EdgeInsets.only(top: 8.h),
                      child: Text(
                        entries[index].key.substring(5),
                        style: TextStyle(fontSize: 10.sp, color: Colors.grey[500]),
                      ),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '¥${(value / 1000).toStringAsFixed(0)}k',
                    style: TextStyle(fontSize: 10.sp, color: Colors.grey[500]),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: entries.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.value)).toList(),
              isCurved: true,
              color: Colors.blue,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                  radius: 4,
                  color: Colors.blue,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.blue.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMerchantDetail(String merchant) {
    _loadMerchantTrend(merchant);
    _tabController.animateTo(1);
  }
}
