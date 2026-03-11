import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:expense_tracker/database/database_helper.dart';
import 'package:intl/intl.dart';

class RecurringExpenseScreen extends StatefulWidget {
  final int? initialYear;
  final int? initialMonth;

  const RecurringExpenseScreen({
    super.key,
    this.initialYear,
    this.initialMonth,
  });

  @override
  State<RecurringExpenseScreen> createState() => _RecurringExpenseScreenState();
}

class _RecurringExpenseScreenState extends State<RecurringExpenseScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late int _selectedYear;
  late int _selectedMonth;
  List<Map<String, dynamic>> _recurringData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialYear ?? DateTime.now().year;
    _selectedMonth = widget.initialMonth ?? DateTime.now().month;
    _tabController = TabController(length: 2, vsync: this);
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
    
    final start = DateTime(_selectedYear - 1, _selectedMonth, 1);
    final end = DateTime(_selectedYear, _selectedMonth + 1, 0, 23, 59, 59);
    
    final recurringData = await DatabaseHelper.instance.getRecurringExpenses(
      start: start,
      end: end,
    );

    setState(() {
      _recurringData = recurringData;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('周期性支出分析'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF4A90E2),
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: const Color(0xFF4A90E2),
          tabs: const [
            Tab(text: '固定支出'),
            Tab(text: '详情'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildPeriodSelector(),
          if (_recurringData.isNotEmpty) _buildSummary(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFixedExpenseList(),
                _buildDetailList(),
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

  Widget _buildSummary() {
    final totalMonthly = _recurringData.fold(0.0, (sum, item) => sum + (item['avg_amount'] as num).toDouble());
    final annualEstimate = totalMonthly * 12;

    return Container(
      color: Colors.white,
      margin: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 0),
      padding: EdgeInsets.all(16.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem(
            '本月固定支出',
            '¥${NumberFormat('#,##0').format(totalMonthly)}',
            Icons.calendar_today,
            Colors.blue,
          ),
          Container(
            width: 1,
            height: 40.h,
            color: Colors.grey[200],
          ),
          _buildSummaryItem(
            '全年预估',
            '¥${NumberFormat('#,##0').format(annualEstimate)}',
            Icons.trending_up,
            Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24.w),
        SizedBox(height: 4.h),
        Text(
          value,
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12.sp, color: Colors.grey[500]),
        ),
      ],
    );
  }

  Widget _buildFixedExpenseList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_recurringData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.repeat, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16.h),
            Text(
              '暂未识别到周期性支出',
              style: TextStyle(color: Colors.grey[500], fontSize: 16.sp),
            ),
            SizedBox(height: 8.h),
            Text(
              '记录至少3笔相同分类的消费后可识别',
              style: TextStyle(color: Colors.grey[400], fontSize: 12.sp),
            ),
          ],
        ),
      );
    }

    final totalAmount = _recurringData.fold(0.0, (sum, item) => sum + (item['avg_amount'] as num).toDouble());
    final maxAmount = _recurringData.isNotEmpty 
        ? (_recurringData.first['avg_amount'] as num).toDouble() 
        : 1.0;

    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: _recurringData.length,
      itemBuilder: (context, index) {
        final item = _recurringData[index];
        return _buildFixedExpenseItem(item, index, totalAmount, maxAmount);
      },
    );
  }

  Widget _buildFixedExpenseItem(Map<String, dynamic> item, int index, double totalAmount, double maxAmount) {
    final categoryName = item['category_name'] as String? ?? '未分类';
    final avgAmount = (item['avg_amount'] as num).toDouble();
    final count = item['count'] as int;
    final minAmount = (item['min_amount'] as num).toDouble();
    final maxAmountItem = (item['max_amount'] as num).toDouble();
    final merchant = item['merchant'] as String?;
    final project = item['project'] as String?;
    
    final progress = totalAmount > 0 ? avgAmount / totalAmount : 0.0;
    final variance = maxAmountItem > 0 ? (maxAmountItem - minAmount) / maxAmountItem : 0.0;

    String subtitle = '';
    if (merchant != null && merchant.isNotEmpty) {
      subtitle = merchant;
    } else if (project != null && project.isNotEmpty) {
      subtitle = project;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
      ),
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
                  child: Icon(
                    _getCategoryIcon(categoryName),
                    color: Colors.blue,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        categoryName,
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
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
                      '¥${NumberFormat('#,##0').format(avgAmount)}/月',
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
                  '${(progress * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: Colors.grey[400]),
                SizedBox(width: 4.w),
                Text(
                  '金额波动: ${(variance * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Colors.grey[500],
                  ),
                ),
                if (variance < 0.1) ...[
                  SizedBox(width: 8.w),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                    child: Text(
                      '稳定',
                      style: TextStyle(fontSize: 10.sp, color: Colors.green),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_recurringData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.list_alt, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16.h),
            Text(
              '暂无详情',
              style: TextStyle(color: Colors.grey[500], fontSize: 16.sp),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: _recurringData.length,
      itemBuilder: (context, index) {
        final item = _recurringData[index];
        return _buildDetailItem(item);
      },
    );
  }

  Widget _buildDetailItem(Map<String, dynamic> item) {
    final categoryName = item['category_name'] as String? ?? '未分类';
    final avgAmount = (item['avg_amount'] as num).toDouble();
    final count = item['count'] as int;
    final minAmount = (item['min_amount'] as num).toDouble();
    final maxAmount = (item['max_amount'] as num).toDouble();

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_getCategoryIcon(categoryName), color: Colors.blue, size: 20),
                SizedBox(width: 8.w),
                Text(
                  categoryName,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            _buildDetailRow('平均金额', '¥${NumberFormat('#,##0').format(avgAmount)}'),
            _buildDetailRow('出现次数', '$count次'),
            _buildDetailRow('最低金额', '¥${NumberFormat('#,##0').format(minAmount)}'),
            _buildDetailRow('最高金额', '¥${NumberFormat('#,##0').format(maxAmount)}'),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13.sp, color: Colors.grey[600]),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String name) {
    final iconMap = {
      '食品酒水': Icons.restaurant,
      '居家生活': Icons.home,
      '交流通讯': Icons.phone_android,
      '休闲娱乐': Icons.movie,
      '人情费用': Icons.card_giftcard,
      '宝宝费用': Icons.child_care,
      '出差旅游': Icons.flight,
      '行车交通': Icons.directions_car,
      '购物消费': Icons.shopping_bag,
      '医疗教育': Icons.medical_services,
      '其他杂项': Icons.more_horiz,
      '金融保险': Icons.account_balance,
    };
    return iconMap[name] ?? Icons.category;
  }
}
