import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:expense_tracker/database/database_helper.dart';
import 'package:intl/intl.dart';

class TransferReportScreen extends StatefulWidget {
  final int? initialYear;
  final int? initialMonth;
  final int? initialQuarter;

  const TransferReportScreen({
    super.key,
    this.initialYear,
    this.initialMonth,
    this.initialQuarter,
  });

  @override
  State<TransferReportScreen> createState() => _TransferReportScreenState();
}

class _TransferReportScreenState extends State<TransferReportScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late int _selectedYear;
  late int _selectedMonth;
  late int _selectedQuarter;
  late int _selectedPeriodType;
  List<Map<String, dynamic>> _transferRecords = [];
  Map<String, dynamic> _summary = {};
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
    
    final records = await DatabaseHelper.instance.getTransferRecords(
      start: _periodStartDate,
      end: _periodEndDate,
    );
    
    final summary = await DatabaseHelper.instance.getTransferSummary(
      start: _periodStartDate,
      end: _periodEndDate,
    );

    setState(() {
      _transferRecords = records;
      _summary = summary;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('转账记录报告'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF4A90E2),
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: const Color(0xFF4A90E2),
          tabs: const [
            Tab(text: '汇总'),
            Tab(text: '明细'),
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
                _buildSummaryView(),
                _buildDetailView(),
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

  Widget _buildSummaryView() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final total = _summary['total'] as double? ?? 0.0;
    final count = _summary['count'] as int? ?? 0;
    final fromAccounts = _summary['fromAccounts'] as List? ?? [];
    final toAccounts = _summary['toAccounts'] as List? ?? [];

    if (count == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.swap_horiz, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16.h),
            Text(
              '本月暂无转账记录',
              style: TextStyle(color: Colors.grey[500], fontSize: 16.sp),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCard(total, count),
          SizedBox(height: 16.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildAccountList('转出账户', fromAccounts, Icons.arrow_upward, Colors.orange),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _buildAccountList('转入账户', toAccounts, Icons.arrow_downward, Colors.green),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(double total, int count) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A90E2), Color(0xFF67B8DE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.swap_horiz, color: Colors.white, size: 28),
              SizedBox(width: 8.w),
              Text(
                '转账总额',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 16.sp,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            '¥${NumberFormat('#,##0').format(total)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            '共 $count 笔转账',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountList(String title, List<dynamic> accounts, IconData icon, Color color) {
    return Container(
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
              Icon(icon, color: color, size: 18),
              SizedBox(width: 6.w),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          if (accounts.isEmpty)
            Text(
              '暂无',
              style: TextStyle(color: Colors.grey[500], fontSize: 12.sp),
            )
          else
            ...accounts.map((account) => _buildAccountItem(
              account['name'] as String? ?? '未知',
              (account['total'] as num?)?.toDouble() ?? 0.0,
              account['icon'] as String?,
            )),
        ],
      ),
    );
  }

  Widget _buildAccountItem(String name, double amount, String? iconStr) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        children: [
          Container(
            width: 32.w,
            height: 32.w,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(
              _getAccountIcon(iconStr),
              size: 16.w,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              name,
              style: TextStyle(fontSize: 13.sp),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '¥${NumberFormat('#,##0').format(amount)}',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailView() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_transferRecords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16.h),
            Text(
              '暂无转账明细',
              style: TextStyle(color: Colors.grey[500], fontSize: 16.sp),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: _transferRecords.length,
      itemBuilder: (context, index) {
        final record = _transferRecords[index];
        return _buildTransferItem(record);
      },
    );
  }

  Widget _buildTransferItem(Map<String, dynamic> record) {
    final amount = (record['amount'] as num).toDouble();
    final fromAccount = record['from_account'] as String? ?? '未知';
    final toAccount = record['to_account'] as String? ?? '未知';
    final remark = record['remark'] as String?;
    final date = DateTime.parse(record['date'] as String);

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          Container(
            width: 44.w,
            height: 44.w,
            decoration: BoxDecoration(
              color: const Color(0xFF4A90E2).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(22.w),
            ),
            child: const Icon(Icons.swap_horiz, color: Color(0xFF4A90E2)),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        fromAccount,
                        style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.arrow_forward, size: 14, color: Colors.grey[400]),
                    Flexible(
                      child: Text(
                        toAccount,
                        style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  '${DateFormat('MM-dd HH:mm').format(date)}${remark != null && remark.isNotEmpty ? ' · $remark' : ''}',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          Text(
            '¥${NumberFormat('#,##0').format(amount)}',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF4A90E2),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getAccountIcon(String? iconStr) {
    final iconMap = {
      'credit_card': Icons.credit_card,
      'account_balance': Icons.account_balance,
      'wallet': Icons.wallet,
      'savings': Icons.savings,
      'money': Icons.money,
    };
    return iconMap[iconStr] ?? Icons.account_balance_wallet;
  }
}
