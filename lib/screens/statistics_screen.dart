import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:expense_tracker/providers/transaction_provider.dart';
import 'package:expense_tracker/database/database_helper.dart';
import 'package:expense_tracker/screens/topn_ranking_screen.dart';
import 'package:expense_tracker/screens/merchant_analysis_screen.dart';
import 'package:expense_tracker/screens/transfer_report_screen.dart';
import 'package:expense_tracker/screens/spending_heatmap_screen.dart';
import 'package:expense_tracker/screens/recurring_expense_screen.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedPeriodType = 2; // 0: 日, 1: 周, 2: 月, 3: 季度, 4: 年
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  int _selectedDay = DateTime.now().day;
  int _selectedQuarter = ((DateTime.now().month - 1) ~/ 3) + 1;
  int _selectedWeek = _getWeekOfYear(DateTime.now());

  static int _getWeekOfYear(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final daysDiff = date.difference(firstDayOfYear).inDays;
    return ((daysDiff + firstDayOfYear.weekday - 1) / 7).ceil();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildPeriodChip(String label, int index) {
    final isSelected = _selectedPeriodType == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPeriodType = index;
          // 重置为当前时间
          if (index == 0) {
            _selectedDay = DateTime.now().day;
          } else if (index == 2) {
            _selectedMonth = DateTime.now().month;
          } else if (index == 1) {
            _selectedWeek = _getWeekOfYear(DateTime.now());
          } else if (index == 3) {
            _selectedQuarter = ((DateTime.now().month - 1) ~/ 3) + 1;
          }
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4A90E2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20.r),
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

  String get _periodLabel {
    switch (_selectedPeriodType) {
      case 0:
        return '$_selectedYear年$_selectedMonth月$_selectedDay日';
      case 1:
        final start = _periodStartDate;
        final end = _periodEndDate;
        final now = DateTime.now();
        final isCurrentWeek = start.isBefore(now.add(const Duration(days: 1))) && 
                              end.isAfter(now.subtract(const Duration(days: 1)));
        final prefix = isCurrentWeek ? '本周 ' : '';
        
        if (start.year != end.year) {
          return '$prefix${start.year}.${start.month.toString().padLeft(2, '0')}.${start.day.toString().padLeft(2, '0')}~${end.year}.${end.month.toString().padLeft(2, '0')}.${end.day.toString().padLeft(2, '0')}';
        } else if (start.month != end.month) {
          return '$prefix${start.month.toString().padLeft(2, '0')}.${start.day.toString().padLeft(2, '0')}~${end.month.toString().padLeft(2, '0')}.${end.day.toString().padLeft(2, '0')}';
        } else {
          return '$prefix${start.month.toString().padLeft(2, '0')}.${start.day.toString().padLeft(2, '0')}~${end.day.toString().padLeft(2, '0')}';
        }
      case 2:
        return '$_selectedYear年$_selectedMonth月';
      case 3:
        return '$_selectedYear年第$_selectedQuarter季度';
      case 4:
        return '$_selectedYear年';
      default:
        return '$_selectedYear年$_selectedMonth月$_selectedDay日';
    }
  }

  DateTime get _periodStartDate {
    switch (_selectedPeriodType) {
      case 0:
        return DateTime(_selectedYear, _selectedMonth, _selectedDay);
      case 1:
        final firstDayOfYear = DateTime(_selectedYear, 1, 1);
        final firstWeekday = firstDayOfYear.weekday;
        final daysToAdd = (_selectedWeek - 1) * 7 - (firstWeekday - 1);
        return firstDayOfYear.add(Duration(days: daysToAdd));
      case 2:
        return DateTime(_selectedYear, _selectedMonth, 1);
      case 3:
        final startMonth = (_selectedQuarter - 1) * 3 + 1;
        return DateTime(_selectedYear, startMonth, 1);
      case 4:
        return DateTime(_selectedYear, 1, 1);
      default:
        return DateTime(_selectedYear, _selectedMonth, 1);
    }
  }

  DateTime get _periodEndDate {
    switch (_selectedPeriodType) {
      case 0:
        return DateTime(_selectedYear, _selectedMonth, _selectedDay, 23, 59, 59);
      case 1:
        final start = _periodStartDate;
        return start.add(const Duration(days: 7)).subtract(const Duration(seconds: 1));
      case 2:
        return DateTime(_selectedYear, _selectedMonth + 1, 0, 23, 59, 59);
      case 3:
        final endMonth = _selectedQuarter * 3;
        return DateTime(_selectedYear, endMonth + 1, 0, 23, 59, 59);
      case 4:
        return DateTime(_selectedYear, 12, 31, 23, 59, 59);
      default:
        return DateTime(_selectedYear, _selectedMonth + 1, 0, 23, 59, 59);
    }
  }

  void _previousPeriod() {
    setState(() {
      switch (_selectedPeriodType) {
        case 0:
          if (_selectedDay > 1) {
            _selectedDay--;
          } else {
            if (_selectedMonth > 1) {
              _selectedMonth--;
            } else {
              _selectedMonth = 12;
              _selectedYear--;
            }
            _selectedDay = DateTime(_selectedYear, _selectedMonth, 0).day;
          }
          break;
        case 2:
          if (_selectedMonth > 1) {
            _selectedMonth--;
          } else {
            _selectedMonth = 12;
            _selectedYear--;
          }
          break;
        case 1:
          if (_selectedWeek > 1) {
            _selectedWeek--;
          } else {
            _selectedWeek = 52;
            _selectedYear--;
          }
          break;
        case 3:
          if (_selectedQuarter > 1) {
            _selectedQuarter--;
          } else {
            _selectedQuarter = 4;
            _selectedYear--;
          }
          break;
        case 4:
          _selectedYear--;
          break;
      }
    });
  }

  void _nextPeriod() {
    setState(() {
      switch (_selectedPeriodType) {
        case 0:
          final daysInMonth = DateTime(_selectedYear, _selectedMonth, 0).day;
          if (_selectedDay < daysInMonth) {
            _selectedDay++;
          } else {
            _selectedDay = 1;
            if (_selectedMonth < 12) {
              _selectedMonth++;
            } else {
              _selectedMonth = 1;
              _selectedYear++;
            }
          }
          break;
        case 2:
          if (_selectedMonth < 12) {
            _selectedMonth++;
          } else {
            _selectedMonth = 1;
            _selectedYear++;
          }
          break;
        case 1:
          if (_selectedWeek < 52) {
            _selectedWeek++;
          } else {
            _selectedWeek = 1;
            _selectedYear++;
          }
          break;
        case 3:
          if (_selectedQuarter < 4) {
            _selectedQuarter++;
          } else {
            _selectedQuarter = 1;
            _selectedYear++;
          }
          break;
        case 4:
          _selectedYear++;
          break;
      }
    });
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final initialDate = DateTime(_selectedYear, _selectedMonth, _selectedDay);
    final lastDateOfMonth = DateTime(_selectedYear, _selectedMonth + 1, 0);
    final lastDate = now.isBefore(lastDateOfMonth) ? now : lastDateOfMonth;
    final effectiveInitialDate = initialDate.isAfter(lastDate) ? lastDate : initialDate;
    
    final date = await showDatePicker(
      context: context,
      initialDate: effectiveInitialDate,
      firstDate: DateTime(2000),
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF4A90E2),
            ),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() {
        _selectedYear = date.year;
        _selectedMonth = date.month;
        _selectedDay = date.day;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          // 周期选择器
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            color: const Color(0xFFF5F5F5),
            child: Column(
              children: [
                // 周期类型选择
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildPeriodChip('日', 0),
                    _buildPeriodChip('周', 1),
                    _buildPeriodChip('月', 2),
                    _buildPeriodChip('季度', 3),
                    _buildPeriodChip('年', 4),
                  ],
                ),
                SizedBox(height: 4.h),
                // 时间导航 - 点击日期可选择
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left, color: Colors.black87, size: 20),
                            onPressed: _previousPeriod,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          GestureDetector(
                            onTap: _selectedPeriodType == 0 ? _selectDate : null,
                            child: Text(
                              _periodLabel,
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: _selectedPeriodType == 0 ? const Color(0xFF4A90E2) : Colors.black87,
                                fontWeight: _selectedPeriodType == 0 ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right, color: Colors.black87, size: 20),
                            onPressed: _nextPeriod,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: _showMoreAnalysisMenu,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.more_horiz, size: 16, color: Colors.grey[600]),
                            SizedBox(width: 4.w),
                            Text(
                              '更多',
                              style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Tab切换
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                  ),
                ],
              ),
              labelColor: const Color(0xFF4A90E2),
              unselectedLabelColor: Colors.grey[600],
              labelStyle: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
              unselectedLabelStyle: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w500),
              tabs: const [
                Tab(text: '按分类'),
                Tab(text: '按归属人'),
                Tab(text: '按账户'),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _CategoryView(
                  selectedYear: _selectedYear,
                  selectedMonth: _selectedMonth,
                  selectedWeek: _selectedWeek,
                  selectedQuarter: _selectedQuarter,
                  selectedPeriodType: _selectedPeriodType,
                  startDate: _periodStartDate,
                  endDate: _periodEndDate,
                ),
                _OwnerView(
                  selectedYear: _selectedYear,
                  selectedMonth: _selectedMonth,
                  selectedWeek: _selectedWeek,
                  selectedQuarter: _selectedQuarter,
                  selectedPeriodType: _selectedPeriodType,
                  startDate: _periodStartDate,
                  endDate: _periodEndDate,
                ),
                _AccountView(
                  selectedYear: _selectedYear,
                  selectedMonth: _selectedMonth,
                  selectedWeek: _selectedWeek,
                  selectedQuarter: _selectedQuarter,
                  selectedPeriodType: _selectedPeriodType,
                  startDate: _periodStartDate,
                  endDate: _periodEndDate,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showMoreAnalysisMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.symmetric(vertical: 16.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              '更多分析',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 16.h),
            _buildMenuItem(
              'TopN消费排行',
              Icons.emoji_events,
              const Color(0xFFFF6B6B),
              () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TopNRankingScreen(
                      initialYear: _selectedYear,
                      initialMonth: _selectedMonth,
                      initialQuarter: ((_selectedMonth - 1) ~/ 3 + 1),
                    ),
                  ),
                );
              },
            ),
            _buildMenuItem(
              '商家消费分析',
              Icons.store,
              const Color(0xFF4ECDC4),
              () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MerchantAnalysisScreen(
                      initialYear: _selectedYear,
                      initialMonth: _selectedMonth,
                      initialQuarter: ((_selectedMonth - 1) ~/ 3 + 1),
                    ),
                  ),
                );
              },
            ),
            _buildMenuItem(
              '转账记录报告',
              Icons.swap_horiz,
              const Color(0xFF45B7D1),
              () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TransferReportScreen(
                      initialYear: _selectedYear,
                      initialMonth: _selectedMonth,
                      initialQuarter: ((_selectedMonth - 1) ~/ 3 + 1),
                    ),
                  ),
                );
              },
            ),
            _buildMenuItem(
              '消费热力图',
              Icons.calendar_month,
              const Color(0xFFFFBE0B),
              () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SpendingHeatmapScreen(
                      initialYear: _selectedYear,
                      initialMonth: _selectedMonth,
                    ),
                  ),
                );
              },
            ),
            _buildMenuItem(
              '周期性支出分析',
              Icons.repeat,
              const Color(0xFF9B5DE5),
              () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RecurringExpenseScreen(
                      initialYear: _selectedYear,
                      initialMonth: _selectedMonth,
                    ),
                  ),
                );
              },
            ),
            SizedBox(height: 8.h),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(String title, IconData icon, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        width: 40.w,
        height: 40.w,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Icon(icon, color: color, size: 22.w),
      ),
      title: Text(title, style: TextStyle(fontSize: 15.sp)),
      trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
      onTap: onTap,
    );
  }
}

// 趋势折线图视图
class _TrendView extends StatefulWidget {
  final int selectedYear;
  final int selectedMonth;
  final int selectedWeek;
  final int selectedQuarter;
  final int selectedPeriodType;
  final DateTime startDate;
  final DateTime endDate;

  const _TrendView({
    required this.selectedYear,
    required this.selectedMonth,
    required this.selectedWeek,
    required this.selectedQuarter,
    required this.selectedPeriodType,
    required this.startDate,
    required this.endDate,
  });

  @override
  State<_TrendView> createState() => _TrendViewState();
}

class _TrendViewState extends State<_TrendView> {
  int _showType = 0; // 0: 支出+收入, 1: 支出, 2: 收入

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _loadTrendData(),
      builder: (context, AsyncSnapshot<Map<String, dynamic>> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('加载失败: ${snapshot.error}'));
        }

        final data = snapshot.data;

        return Column(
          children: [
            // 显示类型切换
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _showType = 0),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                      decoration: BoxDecoration(
                        color: _showType == 0 ? const Color(0xFF4A90E2) : Colors.transparent,
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(color: _showType == 0 ? const Color(0xFF4A90E2) : Colors.grey[300]!),
                      ),
                      child: Text(
                        '全部',
                        style: TextStyle(fontSize: 12.sp, color: _showType == 0 ? Colors.white : Colors.grey[600]),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  GestureDetector(
                    onTap: () => setState(() => _showType = 1),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                      decoration: BoxDecoration(
                        color: _showType == 1 ? Colors.red : Colors.transparent,
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(color: _showType == 1 ? Colors.red : Colors.grey[300]!),
                      ),
                      child: Text(
                        '支出',
                        style: TextStyle(fontSize: 12.sp, color: _showType == 1 ? Colors.white : Colors.red),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  GestureDetector(
                    onTap: () => setState(() => _showType = 2),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                      decoration: BoxDecoration(
                        color: _showType == 2 ? Colors.green : Colors.transparent,
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(color: _showType == 2 ? Colors.green : Colors.grey[300]!),
                      ),
                      child: Text(
                        '收入',
                        style: TextStyle(fontSize: 12.sp, color: _showType == 2 ? Colors.white : Colors.green),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 趋势图
            Expanded(
              child: _TrendChart(
                data: data,
                showType: _showType,
                periodType: widget.selectedPeriodType,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<Map<String, dynamic>> _loadTrendData() async {
    final dailyExpense = await DatabaseHelper.instance.getDailyExpense(widget.startDate, widget.endDate);
    final dailyIncome = await DatabaseHelper.instance.getDailyIncome(widget.startDate, widget.endDate);

    return {
      'expense': dailyExpense,
      'income': dailyIncome,
      'start': widget.startDate,
      'end': widget.endDate,
    };
  }
}

class _TrendChart extends StatelessWidget {
  final Map<String, dynamic>? data;
  final int showType;
  final int periodType;

  const _TrendChart({this.data, required this.showType, required this.periodType});

  @override
  Widget build(BuildContext context) {
    final expenseData = data?['expense'] as Map<String, double>? ?? {};
    final incomeData = data?['income'] as Map<String, double>? ?? {};
    final start = data?['start'] as DateTime? ?? DateTime.now();
    final end = data?['end'] as DateTime? ?? DateTime.now();

    final List<String> labels = [];
    final List<double> expenseValues = [];
    final List<double> incomeValues = [];

    if (periodType == 0 || periodType == 1) {
      var current = start;
      while (!current.isAfter(end)) {
        final dayStr = current.toIso8601String().split('T')[0];
        labels.add('${current.day}');
        expenseValues.add(expenseData[dayStr] ?? 0.0);
        incomeValues.add(incomeData[dayStr] ?? 0.0);
        current = current.add(const Duration(days: 1));
      }
    } else if (periodType == 2) {
      var current = start;
      while (!current.isAfter(end)) {
        final dayStr = current.toIso8601String().split('T')[0];
        labels.add('${current.day}');
        expenseValues.add(expenseData[dayStr] ?? 0.0);
        incomeValues.add(incomeData[dayStr] ?? 0.0);
        current = current.add(const Duration(days: 1));
      }
    } else if (periodType == 3) {
      final months = ['1月', '2月', '3月'];
      for (var i = 0; i < 3; i++) {
        final monthExpense = expenseData.entries
            .where((e) => e.key.startsWith('${start.year}-${(start.month + i).toString().padLeft(2, '0')}'))
            .fold(0.0, (sum, e) => sum + e.value);
        final monthIncome = incomeData.entries
            .where((e) => e.key.startsWith('${start.year}-${(start.month + i).toString().padLeft(2, '0')}'))
            .fold(0.0, (sum, e) => sum + e.value);
        labels.add(months[i]);
        expenseValues.add(monthExpense);
        incomeValues.add(monthIncome);
      }
    } else {
      for (var i = 1; i <= 12; i++) {
        final monthStr = '${start.year}-${i.toString().padLeft(2, '0')}';
        labels.add('$i月');
        expenseValues.add(expenseData.entries
            .where((e) => e.key.startsWith(monthStr))
            .fold(0.0, (sum, e) => sum + e.value));
        incomeValues.add(incomeData.entries
            .where((e) => e.key.startsWith(monthStr))
            .fold(0.0, (sum, e) => sum + e.value));
      }
    }

    if (labels.isEmpty) {
      return Center(
        child: Text('暂无数据', style: TextStyle(color: Colors.grey[400])),
      );
    }

    final allValues = [...expenseValues, ...incomeValues];
    final maxValue = allValues.isEmpty ? 1000.0 : allValues.reduce((a, b) => a > b ? a : b);
    final yInterval = maxValue > 0 ? (maxValue / 4).ceil().toDouble() : 250.0;
    final chartMaxY = maxValue * 1.2;

    return Column(
      children: [
        // 图例
        Padding(
          padding: EdgeInsets.symmetric(vertical: 8.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (showType == 0 || showType == 1)
                _buildLegend('支出', const Color(0xFFE53935)),
              if (showType == 0) SizedBox(width: 32.w),
              if (showType == 0 || showType == 2)
                _buildLegend('收入', const Color(0xFF43A047)),
            ],
          ),
        ),
        // 图表
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16.w, 0, 8.w, 0),
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: yInterval,
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
                      reservedSize: 24,
                      interval: _getXInterval(labels.length),
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < labels.length) {
                          return Padding(
                            padding: EdgeInsets.only(top: 6.w),
                            child: Text(
                              labels[index],
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
                      reservedSize: 40,
                      interval: yInterval,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          _formatYAxis(value),
                          style: TextStyle(fontSize: 9.sp, color: Colors.grey[500]),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  if (showType == 0 || showType == 1)
                    _buildLineData(expenseValues, const Color(0xFFE53935)),
                  if (showType == 0 || showType == 2)
                    _buildLineData(incomeValues, const Color(0xFF43A047)),
                ],
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final isExpense = spot.barIndex == 0 || (showType == 1);
                        return LineTooltipItem(
                          '¥${spot.y.toStringAsFixed(0)}',
                          TextStyle(
                            color: isExpense ? const Color(0xFFE53935) : const Color(0xFF43A047),
                            fontWeight: FontWeight.bold,
                            fontSize: 12.sp,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                minY: 0,
                maxY: chartMaxY,
              ),
            ),
          ),
        ),
        // X轴标签
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_getDateRangeLabel(start, end), style: TextStyle(fontSize: 10.sp, color: Colors.grey[400])),
              Text('单位: 元', style: TextStyle(fontSize: 10.sp, color: Colors.grey[400])),
            ],
          ),
        ),
        SizedBox(height: 8.h),
      ],
    );
  }

  Widget _buildLegend(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20.w,
          height: 3.h,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1.5.r),
          ),
        ),
        SizedBox(width: 6.w),
        Text(label, style: TextStyle(fontSize: 12.sp, color: Colors.grey[600])),
      ],
    );
  }

  LineChartBarData _buildLineData(List<double> values, Color color) {
    return LineChartBarData(
      spots: values.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
      isCurved: false,
      color: color,
      barWidth: 2,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );
  }

  double _getXInterval(int length) {
    if (length <= 7) return 1;
    if (length <= 14) return 2;
    if (length <= 21) return 3;
    if (length <= 31) return 5;
    return (length / 7).ceilToDouble();
  }

  String _formatYAxis(double value) {
    if (value >= 10000) {
      return '${(value / 10000).toStringAsFixed(1)}万';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}千';
    }
    return value.toStringAsFixed(0);
  }

  String _getDateRangeLabel(DateTime start, DateTime end) {
    final startStr = '${start.month}/${start.day}';
    final endStr = '${end.month}/${end.day}';
    return '$startStr - $endStr';
  }
}

// 按分类统计视图
class _CategoryView extends StatefulWidget {
  final int selectedYear;
  final int selectedMonth;
  final int selectedWeek;
  final int selectedQuarter;
  final int selectedPeriodType;
  final DateTime startDate;
  final DateTime endDate;

  const _CategoryView({
    required this.selectedYear,
    required this.selectedMonth,
    required this.selectedWeek,
    required this.selectedQuarter,
    required this.selectedPeriodType,
    required this.startDate,
    required this.endDate,
  });

  @override
  State<_CategoryView> createState() => _CategoryViewState();
}

class _CategoryViewState extends State<_CategoryView> {
  int _chartType = 0; // 0: 饼图, 1: 条形图, 2: 列表
  int _transactionType = 0; // 0: 支出, 1: 收入

  String _getPeriodLabel() {
    switch (widget.selectedPeriodType) {
      case 0:
        return '本日';
      case 1:
        return '本周';
      case 2:
        return '本月';
      case 3:
        return '本季度';
      case 4:
        return '本年';
      default:
        return '本月';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _loadStatisticsData(),
      builder: (context, AsyncSnapshot<Map<String, dynamic>> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('加载失败: ${snapshot.error}'));
        }

        final data = snapshot.data;

        return Column(
          children: [
            // 支出/收入 和 图表类型切换（一行）
            Padding(
              padding: EdgeInsets.only(top: 6.h, bottom: 4.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 支出按钮
                  GestureDetector(
                    onTap: () => setState(() => _transactionType = 0),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: _transactionType == 0 ? Colors.red : Colors.transparent,
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(color: _transactionType == 0 ? Colors.red : Colors.grey[300]!),
                      ),
                      child: Text(
                        '支出',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: _transactionType == 0 ? Colors.white : Colors.grey[600],
                          fontWeight: _transactionType == 0 ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  // 收入按钮
                  GestureDetector(
                    onTap: () => setState(() => _transactionType = 1),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: _transactionType == 1 ? Colors.green : Colors.transparent,
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(color: _transactionType == 1 ? Colors.green : Colors.grey[300]!),
                      ),
                      child: Text(
                        '收入',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: _transactionType == 1 ? Colors.white : Colors.grey[600],
                          fontWeight: _transactionType == 1 ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  // 饼图按钮
                  _ChartTypeButton('饼图', 0, Icons.pie_chart),
                  SizedBox(width: 8.w),
                  // 列表按钮
                  _ChartTypeButton('列表', 2, Icons.list),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                child: Column(
                  children: [
                    if (_chartType == 0)
                      _SimplePieChart(data: data, transactionType: _transactionType, selectedPeriodType: widget.selectedPeriodType)
                    else if (_chartType == 1)
                      _BarChart(data: data, transactionType: _transactionType)
                    else
                      _CategoryListView(data: data, transactionType: _transactionType, selectedPeriodType: widget.selectedPeriodType),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _ChartTypeButton(String label, int index, IconData icon) {
    final isSelected = _chartType == index;
    return GestureDetector(
      onTap: () => setState(() => _chartType = index),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2196F3) : Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: isSelected ? const Color(0xFF2196F3) : Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14.sp, color: isSelected ? Colors.white : Colors.grey[600]),
            SizedBox(width: 4.w),
            Text(label, style: TextStyle(fontSize: 11.sp, color: isSelected ? Colors.white : Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _loadStatisticsData() async {
    final start = widget.startDate;
    final end = widget.endDate;

    final totalExpense = await DatabaseHelper.instance.getTotalExpense(start, end);
    final totalIncome = await DatabaseHelper.instance.getTotalIncome(start, end);
    final expenseCategoryData = await DatabaseHelper.instance.getExpenseByCategory(start, end);
    final incomeCategoryData = await DatabaseHelper.instance.getIncomeByCategory(start, end);

    return {
      'totalExpense': totalExpense,
      'totalIncome': totalIncome,
      'expenseCategoryData': expenseCategoryData,
      'incomeCategoryData': incomeCategoryData,
      'start': start,
      'end': end,
    };
  }
}

// 按归属人统计视图
class _OwnerView extends StatefulWidget {
  final int selectedYear;
  final int selectedMonth;
  final int selectedWeek;
  final int selectedQuarter;
  final int selectedPeriodType;
  final DateTime startDate;
  final DateTime endDate;

  const _OwnerView({
    required this.selectedYear,
    required this.selectedMonth,
    required this.selectedWeek,
    required this.selectedQuarter,
    required this.selectedPeriodType,
    required this.startDate,
    required this.endDate,
  });

  @override
  State<_OwnerView> createState() => _OwnerViewState();
}

class _OwnerViewState extends State<_OwnerView> {
  final Map<String, bool> _expandedExpenseOwners = {};
  final Map<String, bool> _expandedIncomeOwners = {};
  Map<String, List<Map<String, dynamic>>> _expenseDetailsCache = {};
  Map<String, List<Map<String, dynamic>>> _incomeDetailsCache = {};

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionProvider>(
      builder: (context, provider, child) {
        final start = widget.startDate;
        final end = widget.endDate;

        final expenseByOwner = provider.getExpenseByOwner(start, end);
        final incomeByOwner = provider.getIncomeByOwner(start, end);

        final totalExpense = expenseByOwner.values.fold(0.0, (sum, v) => sum + v);
        final totalIncome = incomeByOwner.values.fold(0.0, (sum, v) => sum + v);

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _SummaryItem('总支出', totalExpense, Colors.red),
                    _SummaryItem('总收入', totalIncome, Colors.green),
                  ],
                ),
              ),
              SizedBox(height: 24.h),
              _OwnerExpenseCard(
                expenseByOwner, 
                totalExpense, 
                start, 
                end,
                _expandedExpenseOwners,
                _expenseDetailsCache,
                (key) => setState(() {}),
              ),
              SizedBox(height: 16.h),
              _OwnerIncomeCard(
                incomeByOwner, 
                totalIncome,
                start,
                end,
                _expandedIncomeOwners,
                _incomeDetailsCache,
                (key) => setState(() {}),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _SummaryItem(String label, double amount, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            color: Colors.grey[500],
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          '¥${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _OwnerExpenseCard(Map<String, double> data, double total, DateTime start, DateTime end, Map<String, bool> expandedMap, Map<String, List<Map<String, dynamic>>> cache, Function(String) onToggle) {
    final sortedEntries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return _OwnerCard(
      title: '支出归属人统计',
      icon: Icons.trending_down,
      color: Colors.red,
      data: sortedEntries,
      total: total,
      start: start,
      end: end,
      expandedMap: expandedMap,
      cache: cache,
      onToggle: onToggle,
      isExpense: true,
    );
  }

  Widget _OwnerIncomeCard(Map<String, double> data, double total, DateTime start, DateTime end, Map<String, bool> expandedMap, Map<String, List<Map<String, dynamic>>> cache, Function(String) onToggle) {
    final sortedEntries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return _OwnerCard(
      title: '收入归属人统计',
      icon: Icons.trending_up,
      color: Colors.green,
      data: sortedEntries,
      total: total,
      start: start,
      end: end,
      expandedMap: expandedMap,
      cache: cache,
      onToggle: onToggle,
      isExpense: false,
    );
  }

  Widget _OwnerCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<MapEntry<String, double>> data,
    required double total,
    required DateTime start,
    required DateTime end,
    required Map<String, bool> expandedMap,
    required Map<String, List<Map<String, dynamic>>> cache,
    required Function(String) onToggle,
    required bool isExpense,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20.sp, color: color),
              SizedBox(width: 8.w),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[900],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          if (data.isEmpty)
            Center(
              child: Text(
                '暂无数据',
                style: TextStyle(fontSize: 14.sp, color: Colors.grey[400]),
              ),
            )
          else
            ...data.asMap().entries.map((entry) {
              final ownerData = entry.value;
              final percentage = total > 0 ? ownerData.value / total : 0.0;
              final isExpanded = expandedMap[ownerData.key] ?? false;

              return Column(
                children: [
                  GestureDetector(
                    onTap: () async {
                      if (!isExpanded && !cache.containsKey(ownerData.key)) {
                        List<Map<String, dynamic>> details;
                        if (isExpense) {
                          details = await DatabaseHelper.instance.getExpenseDetailsByOwner(
                            start: start,
                            end: end,
                            owner: ownerData.key,
                          );
                        } else {
                          details = await DatabaseHelper.instance.getIncomeDetailsByOwner(
                            start: start,
                            end: end,
                            owner: ownerData.key,
                          );
                        }
                        cache[ownerData.key] = details;
                      }
                      expandedMap[ownerData.key] = !isExpanded;
                      onToggle(ownerData.key);
                    },
                    child: Container(
                      margin: EdgeInsets.only(bottom: 12.h),
                      child: Row(
                        children: [
                          Container(
                            width: 40.w,
                            height: 40.w,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20.r),
                            ),
                            child: Center(
                              child: Icon(Icons.person, size: 20.sp, color: color),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ownerData.key,
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[900],
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  '¥${ownerData.value.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Text(
                              '${(percentage * 100).toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: color,
                              ),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Icon(
                            isExpanded ? Icons.expand_less : Icons.expand_more,
                            color: Colors.grey[400],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isExpanded && cache.containsKey(ownerData.key))
                    _buildDetailList(cache[ownerData.key]!, color),
                ],
              );
            }),
        ],
      ),
    );
  }

  Widget _buildDetailList(List<Map<String, dynamic>> details, Color color) {
    if (details.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(bottom: 12.h, left: 52.w),
        child: Text(
          '暂无明细',
          style: TextStyle(fontSize: 12.sp, color: Colors.grey[400]),
        ),
      );
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12.h, left: 20.w),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        children: details.take(10).map((detail) {
          final date = DateTime.parse(detail['date'] as String);
          final amount = (detail['amount'] as num).toDouble();
          final merchant = detail['merchant'] as String?;
          final categoryName = detail['category_name'] as String?;
          final remark = detail['remark'] as String?;
          
          return Container(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 0.5)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${date.month}-${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                      ),
                      if (categoryName != null)
                        Text(
                          categoryName,
                          style: TextStyle(fontSize: 12.sp, color: Colors.grey[500]),
                        ),
                      if (merchant != null && merchant.isNotEmpty)
                        Text(
                          merchant,
                          style: TextStyle(fontSize: 12.sp, color: Colors.grey[500]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    remark ?? '',
                    style: TextStyle(fontSize: 11.sp, color: Colors.grey[400]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
                ),
                SizedBox(width: 8.w),
                Text(
                  '¥${amount.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: color),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// 按账户统计视图
class _AccountView extends StatefulWidget {
  final int selectedYear;
  final int selectedMonth;
  final int selectedWeek;
  final int selectedQuarter;
  final int selectedPeriodType;
  final DateTime startDate;
  final DateTime endDate;

  const _AccountView({
    required this.selectedYear,
    required this.selectedMonth,
    required this.selectedWeek,
    required this.selectedQuarter,
    required this.selectedPeriodType,
    required this.startDate,
    required this.endDate,
  });

  @override
  State<_AccountView> createState() => _AccountViewState();
}

class _AccountViewState extends State<_AccountView> {
  final Map<String, bool> _expandedExpenseAccounts = {};
  final Map<String, bool> _expandedIncomeAccounts = {};
  Map<String, List<Map<String, dynamic>>> _expenseDetailsCache = {};
  Map<String, List<Map<String, dynamic>>> _incomeDetailsCache = {};

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _loadAccountData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final expenseByAccount = snapshot.data?[0] as Map<String, double>? ?? {};
        final incomeByAccount = snapshot.data?[1] as Map<String, double>? ?? {};

        final totalExpense = expenseByAccount.values.fold(0.0, (sum, v) => sum + v);
        final totalIncome = incomeByAccount.values.fold(0.0, (sum, v) => sum + v);

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _SummaryItem('总支出', totalExpense, Colors.red),
                    _SummaryItem('总收入', totalIncome, Colors.green),
                  ],
                ),
              ),
              SizedBox(height: 24.h),
              _AccountExpenseCard(expenseByAccount, totalExpense, widget.startDate, widget.endDate, _expandedExpenseAccounts, _expenseDetailsCache, (key) => setState(() {})),
              SizedBox(height: 16.h),
              _AccountIncomeCard(incomeByAccount, totalIncome, widget.startDate, widget.endDate, _expandedIncomeAccounts, _incomeDetailsCache, (key) => setState(() {})),
            ],
          ),
        );
      },
    );
  }

  Future<List<dynamic>> _loadAccountData() async {
    final start = widget.startDate;
    final end = widget.endDate;
    final expenseByAccount = await DatabaseHelper.instance.getExpenseByAccount(start, end);
    final incomeByAccount = await DatabaseHelper.instance.getIncomeByAccount(start, end);
    return [expenseByAccount, incomeByAccount];
  }

  Widget _SummaryItem(String label, double amount, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 14.sp, color: Colors.grey[500], fontWeight: FontWeight.w500)),
        SizedBox(height: 8.h),
        Text('¥${amount.toStringAsFixed(2)}', style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }

  Widget _AccountExpenseCard(Map<String, double> data, double total, DateTime start, DateTime end, Map<String, bool> expandedMap, Map<String, List<Map<String, dynamic>>> cache, Function(String) onToggle) {
    final sortedEntries = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return _AccountCard(title: '支出账户统计', icon: Icons.trending_down, color: Colors.red, data: sortedEntries, total: total, start: start, end: end, expandedMap: expandedMap, cache: cache, onToggle: onToggle, isExpense: true);
  }

  Widget _AccountIncomeCard(Map<String, double> data, double total, DateTime start, DateTime end, Map<String, bool> expandedMap, Map<String, List<Map<String, dynamic>>> cache, Function(String) onToggle) {
    final sortedEntries = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return _AccountCard(title: '收入账户统计', icon: Icons.trending_up, color: Colors.green, data: sortedEntries, total: total, start: start, end: end, expandedMap: expandedMap, cache: cache, onToggle: onToggle, isExpense: false);
  }

  Widget _AccountCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<MapEntry<String, double>> data,
    required double total,
    required DateTime start,
    required DateTime end,
    required Map<String, bool> expandedMap,
    required Map<String, List<Map<String, dynamic>>> cache,
    required Function(String) onToggle,
    required bool isExpense,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20.sp, color: color),
              SizedBox(width: 8.w),
              Text(title, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: Colors.grey[900])),
            ],
          ),
          SizedBox(height: 16.h),
          if (data.isEmpty)
            Center(child: Text('暂无数据', style: TextStyle(fontSize: 14.sp, color: Colors.grey[400])))
          else
            ...data.asMap().entries.map((entry) {
              final accountData = entry.value;
              final percentage = total > 0 ? accountData.value / total : 0.0;
              final isExpanded = expandedMap[accountData.key] ?? false;

              return Column(
                children: [
                  GestureDetector(
                    onTap: () async {
                      if (!isExpanded && !cache.containsKey(accountData.key)) {
                        List<Map<String, dynamic>> details;
                        if (isExpense) {
                          details = await DatabaseHelper.instance.getExpenseDetailsByAccount(
                            start: start,
                            end: end,
                            accountName: accountData.key,
                          );
                        } else {
                          details = await DatabaseHelper.instance.getIncomeDetailsByAccount(
                            start: start,
                            end: end,
                            accountName: accountData.key,
                          );
                        }
                        cache[accountData.key] = details;
                      }
                      expandedMap[accountData.key] = !isExpanded;
                      onToggle(accountData.key);
                    },
                    child: Container(
                      margin: EdgeInsets.only(bottom: 12.h),
                      child: Row(
                        children: [
                          Container(
                            width: 40.w,
                            height: 40.w,
                            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20.r)),
                            child: Center(child: Icon(Icons.account_balance_wallet, size: 20.sp, color: color)),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(accountData.key, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500, color: Colors.grey[900])),
                                SizedBox(height: 4.h),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4.r),
                                  child: LinearProgressIndicator(
                                    value: percentage,
                                    backgroundColor: Colors.grey[200],
                                    valueColor: AlwaysStoppedAnimation<Color>(color),
                                    minHeight: 6.h,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('¥${accountData.value.toStringAsFixed(2)}', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: Colors.grey[900])),
                              SizedBox(height: 4.h),
                              Text('${(percentage * 100).toStringAsFixed(1)}%', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: color)),
                            ],
                          ),
                          SizedBox(width: 8.w),
                          Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.grey[400]),
                        ],
                      ),
                    ),
                  ),
                  if (isExpanded && cache.containsKey(accountData.key))
                    _buildAccountDetailList(cache[accountData.key]!, color),
                ],
              );
            }),
        ],
      ),
    );
  }

  Widget _buildAccountDetailList(List<Map<String, dynamic>> details, Color color) {
    if (details.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(bottom: 12.h, left: 52.w),
        child: Text('暂无明细', style: TextStyle(fontSize: 12.sp, color: Colors.grey[400])),
      );
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12.h, left: 20.w),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        children: details.take(10).map((detail) {
          final date = DateTime.parse(detail['date'] as String);
          final amount = (detail['amount'] as num).toDouble();
          final merchant = detail['merchant'] as String?;
          final categoryName = detail['category_name'] as String?;
          final accountName = detail['account_name'] as String?;
          
          return Container(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 0.5)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${date.month}-${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                      ),
                      if (categoryName != null)
                        Text(
                          categoryName,
                          style: TextStyle(fontSize: 12.sp, color: Colors.grey[500]),
                        ),
                      if (merchant != null && merchant.isNotEmpty)
                        Text(
                          merchant,
                          style: TextStyle(fontSize: 12.sp, color: Colors.grey[500]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    accountName ?? '',
                    style: TextStyle(fontSize: 11.sp, color: Colors.grey[400]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
                ),
                SizedBox(width: 8.w),
                Text(
                  '¥${amount.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: color),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SimpleSummaryCards extends StatelessWidget {
  const _SimpleSummaryCards();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _SimpleSummaryItem('支出分类占比', 0.0, 'expense'),
        ],
      ),
    );
  }

  Widget _SimpleSummaryItem(String label, double amount, String type) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _SimplePieChart extends StatelessWidget {
  final Map<String, dynamic>? data;
  final int transactionType;
  final int selectedPeriodType;

  const _SimplePieChart({this.data, required this.transactionType, required this.selectedPeriodType});

  String _getPeriodLabel() {
    switch (selectedPeriodType) {
      case 0:
        return '本日';
      case 1:
        return '本周';
      case 2:
        return '本月';
      case 3:
        return '本季度';
      case 4:
        return '本年';
      default:
        return '本月';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isExpense = transactionType == 0;
    final categoryData = isExpense 
        ? (data?['expenseCategoryData'] as Map<String, double>? ?? {})
        : (data?['incomeCategoryData'] as Map<String, double>? ?? {});
    final total = isExpense 
        ? (data?['totalExpense'] as double? ?? 0.0)
        : (data?['totalIncome'] as double? ?? 0.0);

    if (categoryData.isEmpty || total == 0) {
      return Center(
        child: Column(
          children: [
            Icon(Icons.pie_chart_outline, size: 80.w, color: Colors.grey[200]),
            SizedBox(height: 16.h),
            Text(
              isExpense ? '暂无支出数据' : '暂无收入数据',
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      );
    }

    final colors = [
      const Color(0xFFFF6B6B),
      const Color(0xFF4ECDC4),
      const Color(0xFF95E1D3),
      const Color(0xFFAA96DA),
      const Color(0xFFFCBAD3),
      const Color(0xFFFFD93D),
      const Color(0xFF6BCB77),
      const Color(0xFF4D96FF),
      const Color(0xFFFF9F43),
      const Color(0xFFEE5A24),
    ];

    final sortedEntries = categoryData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final sections = sortedEntries.asMap().entries.map((entry) {
      final index = entry.key;
      final category = entry.value;
      final percentage = total > 0 ? category.value / total : 0.0;
      final color = colors[index % colors.length];

      return PieChartSectionData(
        value: category.value,
        title: '${(percentage * 100).toStringAsFixed(0)}%',
        color: color,
        radius: 60,
        titleStyle: TextStyle(
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      );
    }).toList();

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(isExpense ? '支出分类' : '收入分类', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${isExpense ? _getPeriodLabel() + '支出' : _getPeriodLabel() + '收入'}: ¥${total.toStringAsFixed(2)}', style: TextStyle(fontSize: 14.sp, color: isExpense ? Colors.red : Colors.green, fontWeight: FontWeight.w500)),
            ],
          ),
          SizedBox(height: 16.h),
          SizedBox(
            height: 220.h,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sections: sections,
                    centerSpaceRadius: 50,
                    sectionsSpace: 2,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(isExpense ? '总支出' : '总收入', style: TextStyle(fontSize: 12.sp, color: Colors.grey[500])),
                    Text('¥${total.toStringAsFixed(2)}', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700, color: Colors.grey[800])),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          Wrap(
            spacing: 16.w,
            runSpacing: 8.h,
            children: sortedEntries.asMap().entries.map((entry) {
              final index = entry.key;
              final category = entry.value;
              final percentage = total > 0 ? category.value / total : 0.0;
              final color = colors[index % colors.length];

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10.w,
                    height: 10.w,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                  SizedBox(width: 4.w),
                  Text(category.key, style: TextStyle(fontSize: 12.sp, color: Colors.grey[600])),
                  SizedBox(width: 2.w),
                  Text('¥${category.value.toStringAsFixed(2)}', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w500, color: Colors.grey[800])),
                  Text('(${(percentage * 100).toStringAsFixed(0)}%)', style: TextStyle(fontSize: 11.sp, color: Colors.grey[400])),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _CategoryListView extends StatelessWidget {
  final Map<String, dynamic>? data;
  final int transactionType;
  final int selectedPeriodType;

  const _CategoryListView({this.data, required this.transactionType, required this.selectedPeriodType});

  String _getPeriodLabel() {
    switch (selectedPeriodType) {
      case 0:
        return '本日';
      case 1:
        return '本周';
      case 2:
        return '本月';
      case 3:
        return '本季度';
      case 4:
        return '本年';
      default:
        return '本月';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isExpense = transactionType == 0;
    final categoryData = isExpense 
        ? (data?['expenseCategoryData'] as Map<String, double>? ?? {})
        : (data?['incomeCategoryData'] as Map<String, double>? ?? {});
    final total = isExpense 
        ? (data?['totalExpense'] as double? ?? 0.0)
        : (data?['totalIncome'] as double? ?? 0.0);

    final sortedCategories = categoryData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final colors = [
      const Color(0xFFFF6B6B),
      const Color(0xFF4ECDC4),
      const Color(0xFF95E1D3),
      const Color(0xFFAA96DA),
      const Color(0xFFFCBAD3),
      const Color(0xFFFFD93D),
      const Color(0xFF6BCB77),
      const Color(0xFF4D96FF),
    ];

    if (sortedCategories.isEmpty) {
      return Center(
        child: Column(
          children: [
            Icon(Icons.list_alt, size: 80.w, color: Colors.grey[200]),
            SizedBox(height: 16.h),
            Text('暂无数据', style: TextStyle(fontSize: 14.sp, color: Colors.grey[400])),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Text('分类详情', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text(isExpense ? '${_getPeriodLabel()}支出: ¥${total.toStringAsFixed(2)}' : '${_getPeriodLabel()}收入: ¥${total.toStringAsFixed(2)}', style: TextStyle(fontSize: 14.sp, color: isExpense ? Colors.red : Colors.green)),
                ],
              ),
              SizedBox(height: 16.h),
              ...sortedCategories.asMap().entries.map((entry) {
                final index = entry.key;
                final category = entry.value;
                final percentage = total > 0 ? category.value / total : 0.0;
                final color = colors[index % colors.length];

                return Container(
                  margin: EdgeInsets.only(bottom: 12.h),
                  child: Row(
                    children: [
                      Container(
                        width: 12.w,
                        height: 12.w,
                        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3.r)),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(category.key, style: TextStyle(fontSize: 14.sp, color: Colors.grey[900])),
                                Text('¥${category.value.toStringAsFixed(2)}', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500, color: Colors.grey[900])),
                              ],
                            ),
                            SizedBox(height: 6.h),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4.r),
                              child: LinearProgressIndicator(
                                value: percentage,
                                backgroundColor: Colors.grey[200],
                                valueColor: AlwaysStoppedAnimation<Color>(color),
                                minHeight: 8.h,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Text('${(percentage * 100).toStringAsFixed(1)}%', style: TextStyle(fontSize: 13.sp, color: Colors.grey[400])),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}

class _BarChart extends StatelessWidget {
  final Map<String, dynamic>? data;
  final int transactionType;

  const _BarChart({this.data, required this.transactionType});

  @override
  Widget build(BuildContext context) {
    final isExpense = transactionType == 0;
    final categoryData = isExpense 
        ? (data?['expenseCategoryData'] as Map<String, double>? ?? {})
        : (data?['incomeCategoryData'] as Map<String, double>? ?? {});
    final total = isExpense 
        ? (data?['totalExpense'] as double? ?? 0.0)
        : (data?['totalIncome'] as double? ?? 0.0);

    final sortedCategories = categoryData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final colors = [
      const Color(0xFFFF6B6B),
      const Color(0xFF4ECDC4),
      const Color(0xFF95E1D3),
      const Color(0xFFAA96DA),
      const Color(0xFFFCBAD3),
      const Color(0xFFFFD93D),
      const Color(0xFF6BCB77),
      const Color(0xFF4D96FF),
    ];

    if (sortedCategories.isEmpty) {
      return Center(
        child: Column(
          children: [
            Icon(Icons.bar_chart, size: 80.w, color: Colors.grey[200]),
            SizedBox(height: 16.h),
            Text('暂无数据', style: TextStyle(fontSize: 14.sp, color: Colors.grey[400])),
          ],
        ),
      );
    }

    final maxValue = sortedCategories.first.value;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        children: [
          Text('支出分类 (条形图)', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600)),
          SizedBox(height: 24.h),
          ...sortedCategories.asMap().entries.map((entry) {
            final index = entry.key;
            final category = entry.value;
            final percentage = maxValue > 0 ? category.value / maxValue : 0.0;
            final color = colors[index % colors.length];

            return Container(
              margin: EdgeInsets.only(bottom: 16.h),
              child: Row(
                children: [
                  SizedBox(
                    width: 60.w,
                    child: Text(category.key, style: TextStyle(fontSize: 12.sp, color: Colors.grey[700]), overflow: TextOverflow.ellipsis),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          height: 24.h,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: percentage,
                          child: Container(
                            height: 24.h,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8.w),
                  SizedBox(
                    width: 70.w,
                    child: Text('¥${category.value.toStringAsFixed(2)}', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w500), textAlign: TextAlign.right),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SimpleCategoryList extends StatelessWidget {
  final Map<String, dynamic>? data;
  final int transactionType;

  const _SimpleCategoryList({this.data, required this.transactionType});

  @override
  Widget build(BuildContext context) {
    final isExpense = transactionType == 0;
    final categoryData = isExpense 
        ? (data?['expenseCategoryData'] as Map<String, double>? ?? {})
        : (data?['incomeCategoryData'] as Map<String, double>? ?? {});
    final total = isExpense 
        ? (data?['totalExpense'] as double? ?? 0.0)
        : (data?['totalIncome'] as double? ?? 0.0);

    final sortedCategories = categoryData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final colors = [
      const Color(0xFFFF6B6B),
      const Color(0xFF4ECDC4),
      const Color(0xFF95E1D3),
      const Color(0xFFAA96DA),
      const Color(0xFFFCBAD3),
      const Color(0xFFFFD93D),
      const Color(0xFF6BCB77),
      const Color(0xFF4D96FF),
    ];

    if (sortedCategories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4.w, bottom: 16.h),
          child: Text(
            '分类详情',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: Colors.grey[900],
            ),
          ),
        ),
        ...sortedCategories.asMap().entries.map((entry) {
          final index = entry.key;
          final category = entry.value;
          final percentage = total > 0 ? category.value / total : 0.0;
          final color = colors[index % colors.length];

          return Container(
            padding: EdgeInsets.symmetric(vertical: 14.h),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey[50]!,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 10.w,
                  height: 10.w,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    category.key,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.grey[900],
                    ),
                  ),
                ),
                Text(
                  '¥${category.value.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[900],
                  ),
                ),
                SizedBox(width: 12.w),
                Text(
                  '${(percentage * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
