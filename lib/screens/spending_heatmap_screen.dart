import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:expense_tracker/database/database_helper.dart';

class SpendingHeatmapScreen extends StatefulWidget {
  final int? initialYear;
  final int? initialMonth;

  const SpendingHeatmapScreen({
    super.key,
    this.initialYear,
    this.initialMonth,
  });

  @override
  State<SpendingHeatmapScreen> createState() => _SpendingHeatmapScreenState();
}

class _SpendingHeatmapScreenState extends State<SpendingHeatmapScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late int _selectedYear;
  late int _selectedMonth;
  Map<int, double> _dayOfWeekData = {};
  Map<int, double> _dayOfMonthData = {};
  Map<String, double> _dateData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialYear ?? DateTime.now().year;
    _selectedMonth = widget.initialMonth ?? DateTime.now().month;
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  DateTime get _periodStartDate => DateTime(_selectedYear, _selectedMonth, 1);
  DateTime get _periodEndDate => DateTime(_selectedYear, _selectedMonth + 1, 0, 23, 59, 59);

  void _previousMonth() {
    setState(() {
      if (_selectedMonth > 1) {
        _selectedMonth--;
      } else {
        _selectedMonth = 12;
        _selectedYear--;
      }
    });
    _loadData();
  }

  void _nextMonth() {
    setState(() {
      if (_selectedMonth < 12) {
        _selectedMonth++;
      } else {
        _selectedMonth = 1;
        _selectedYear++;
      }
    });
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final dayOfWeek = await DatabaseHelper.instance.getExpenseByDayOfWeek(
      start: _periodStartDate,
      end: _periodEndDate,
    );
    
    final dayOfMonth = await DatabaseHelper.instance.getExpenseByDayOfMonth(
      start: _periodStartDate,
      end: _periodEndDate,
    );

    final yearStart = DateTime(_selectedYear, 1, 1);
    final yearEnd = DateTime(_selectedYear, 12, 31, 23, 59, 59);
    final dateData = await DatabaseHelper.instance.getExpenseByDate(
      start: yearStart,
      end: yearEnd,
    );

    setState(() {
      _dayOfWeekData = dayOfWeek;
      _dayOfMonthData = dayOfMonth;
      _dateData = dateData;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('消费热力图'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF4A90E2),
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: const Color(0xFF4A90E2),
          tabs: const [
            Tab(text: '星期分布'),
            Tab(text: '日期分布'),
            Tab(text: '年度日历'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildPeriodSelector(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildWeekdayView(),
                _buildDayOfMonthView(),
                _buildYearCalendarView(),
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
      padding: EdgeInsets.symmetric(vertical: 12.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _previousMonth,
          ),
          Text(
            '$_selectedYear年${_selectedMonth.toString().padLeft(2, '0')}月',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _nextMonth,
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayView() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final weekDays = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    final maxValue = _dayOfWeekData.values.isEmpty ? 1.0 : _dayOfWeekData.values.reduce((a, b) => a > b ? a : b);
    final total = _dayOfWeekData.values.fold(0.0, (a, b) => a + b);

    double getWeekdayAvg() {
      final count = _dayOfWeekData.values.where((v) => v > 0).length;
      return count > 0 ? total / count : 0;
    }

    String getInsight() {
      final weekendTotal = (_dayOfWeekData[0] ?? 0) + (_dayOfWeekData[6] ?? 0);
      final weekdayTotal = total - weekendTotal;
      final weekdayCount = ((_dayOfWeekData[1] ?? 0) > 0 ? 1 : 0) +
          ((_dayOfWeekData[2] ?? 0) > 0 ? 1 : 0) +
          ((_dayOfWeekData[3] ?? 0) > 0 ? 1 : 0) +
          ((_dayOfWeekData[4] ?? 0) > 0 ? 1 : 0) +
          ((_dayOfWeekData[5] ?? 0) > 0 ? 1 : 0);
      final weekdayAvg = weekdayCount > 0 ? weekdayTotal / weekdayCount : 0;

      if (weekendTotal > weekdayTotal * 1.3) {
        return '周末消费最高，是工作日的${(weekendTotal / 2 / weekdayAvg).toStringAsFixed(1)}倍';
      } else if (weekdayTotal > weekendTotal * 1.3) {
        return '工作日消费较高';
      } else {
        return '工作日与周末消费较为均衡';
      }
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Column(
              children: [
                Text(
                  '按星期分布',
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 16.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(7, (index) {
                    final value = _dayOfWeekData[index] ?? 0;
                    final intensity = maxValue > 0 ? (value / maxValue) : 0.0;
                    return _buildWeekdayCell(weekDays[index], value, intensity, index);
                  }),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: Colors.amber[600], size: 18),
                    SizedBox(width: 8.w),
                    Text(
                      '消费洞察',
                      style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Text(
                  getInsight(),
                  style: TextStyle(fontSize: 13.sp, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayCell(String label, double value, double intensity, int index) {
    final isWeekend = index == 0 || index == 6;
    final color = _getHeatColor(intensity);

    return Column(
      children: [
        Container(
          width: 36.w,
          height: 36.w,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8.r),
            border: isWeekend ? Border.all(color: Colors.orange, width: 2) : null,
          ),
          child: Center(
            child: Text(
              value > 0 ? '¥${(value / 1000).toStringAsFixed(1)}k' : '-',
              style: TextStyle(
                fontSize: 9.sp,
                color: intensity > 0.5 ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        SizedBox(height: 6.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            color: isWeekend ? Colors.orange : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildDayOfMonthView() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final daysInMonth = DateTime(_selectedYear, _selectedMonth + 1, 0).day;
    final maxValue = _dayOfMonthData.values.isEmpty ? 1.0 : _dayOfMonthData.values.reduce((a, b) => a > b ? a : b);

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '按日期分布',
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 16.h),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 8.w,
                    crossAxisSpacing: 8.w,
                    childAspectRatio: 1,
                  ),
                  itemCount: daysInMonth,
                  itemBuilder: (context, index) {
                    final day = index + 1;
                    final value = _dayOfMonthData[day] ?? 0;
                    final intensity = maxValue > 0 ? (value / maxValue) : 0.0;
                    return _buildDayCell(day, value, intensity);
                  },
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          _buildLegend(),
        ],
      ),
    );
  }

  Widget _buildDayCell(int day, double value, double intensity) {
    final color = _getHeatColor(intensity);
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Center(
        child: Text(
          '$day',
          style: TextStyle(
            fontSize: 12.sp,
            color: intensity > 0.5 ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildYearCalendarView() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final months = List.generate(12, (m) => m + 1);
    final maxValue = _dateData.values.isEmpty ? 1.0 : _dateData.values.reduce((a, b) => a > b ? a : b);

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_selectedYear年消费日历',
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 16.h),
                ...months.map((month) => _buildMonthRow(month, maxValue)),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          _buildLegend(),
        ],
      ),
    );
  }

  Widget _buildMonthRow(int month, double maxValue) {
    final daysInMonth = DateTime(_selectedYear, month + 1, 0).day;
    final weekDayOfFirst = DateTime(_selectedYear, month, 1).weekday;

    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${month}月',
            style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
          ),
          SizedBox(height: 4.h),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (int i = 1; i < weekDayOfFirst; i++)
                  Container(
                    width: 16.w,
                    height: 16.w,
                    margin: EdgeInsets.only(right: 2.w),
                  ),
                for (int day = 1; day <= daysInMonth; day++)
                  Container(
                    width: 16.w,
                    height: 16.w,
                    margin: EdgeInsets.only(right: 2.w),
                    decoration: BoxDecoration(
                      color: _getDayColor(month, day, maxValue),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getDayColor(int month, int day, double maxValue) {
    final dateStr = '$_selectedYear-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
    final value = _dateData[dateStr] ?? 0;
    final intensity = maxValue > 0 ? (value / maxValue) : 0.0;
    return _getHeatColor(intensity);
  }

  Widget _buildLegend() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('低', style: TextStyle(fontSize: 11.sp, color: Colors.grey[500])),
          SizedBox(width: 8.w),
          ...List.generate(5, (index) {
            return Container(
              width: 24.w,
              height: 16.w,
              margin: EdgeInsets.only(right: 2.w),
              decoration: BoxDecoration(
                color: _getHeatColor(index / 4),
                borderRadius: BorderRadius.circular(2.r),
              ),
            );
          }),
          SizedBox(width: 8.w),
          Text('高', style: TextStyle(fontSize: 11.sp, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Color _getHeatColor(double intensity) {
    if (intensity <= 0) return Colors.grey[100]!;
    if (intensity < 0.25) return const Color(0xFFE8F5E9);
    if (intensity < 0.5) return const Color(0xFFA5D6A7);
    if (intensity < 0.75) return const Color(0xFF66BB6A);
    return const Color(0xFF2E7D32);
  }
}
