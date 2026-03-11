import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:expense_tracker/database/database_helper.dart';
import 'package:intl/intl.dart';

class TopNRankingScreen extends StatefulWidget {
  final int? initialYear;
  final int? initialMonth;
  final int? initialQuarter;

  const TopNRankingScreen({
    super.key,
    this.initialYear,
    this.initialMonth,
    this.initialQuarter,
  });

  @override
  State<TopNRankingScreen> createState() => _TopNRankingScreenState();
}

class _TopNRankingScreenState extends State<TopNRankingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late int _selectedYear;
  late int _selectedMonth;
  late int _selectedQuarter;
  late int _selectedPeriodType; // 0=月, 1=季度, 2=年
  List<Map<String, dynamic>> _categoryData = [];
  List<Map<String, dynamic>> _merchantData = [];
  List<Map<String, dynamic>> _projectData = [];
  List<Map<String, dynamic>> _accountData = [];
  double _totalExpense = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialYear ?? DateTime.now().year;
    _selectedMonth = widget.initialMonth ?? DateTime.now().month;
    _selectedQuarter = widget.initialQuarter ?? ((DateTime.now().month - 1) ~/ 3 + 1);
    _selectedPeriodType = 0;
    _tabController = TabController(length: 4, vsync: this);
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
    
    final categoryData = await DatabaseHelper.instance.getExpenseTopNByCategory(
      start: _periodStartDate,
      end: _periodEndDate,
      limit: 10,
    );
    
    final merchantData = await DatabaseHelper.instance.getExpenseTopNByMerchant(
      start: _periodStartDate,
      end: _periodEndDate,
      limit: 10,
    );
    
    final projectData = await DatabaseHelper.instance.getExpenseTopNByProject(
      start: _periodStartDate,
      end: _periodEndDate,
      limit: 10,
    );
    
    final accountData = await DatabaseHelper.instance.getExpenseTopNByAccount(
      start: _periodStartDate,
      end: _periodEndDate,
      limit: 10,
    );

    final totalExpense = await DatabaseHelper.instance.getTotalExpense(
      _periodStartDate,
      _periodEndDate,
    );

    setState(() {
      _categoryData = categoryData;
      _merchantData = merchantData;
      _projectData = projectData;
      _accountData = accountData;
      _totalExpense = totalExpense;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('消费排行'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF4A90E2),
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: const Color(0xFF4A90E2),
          tabs: const [
            Tab(text: '分类'),
            Tab(text: '商家'),
            Tab(text: '项目'),
            Tab(text: '账户'),
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
                _buildRankList(_categoryData, 'category'),
                _buildRankList(_merchantData, 'merchant'),
                _buildRankList(_projectData, 'project'),
                _buildRankList(_accountData, 'account'),
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

  Widget _buildRankList(List<Map<String, dynamic>> data, String type) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (data.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16.h),
            Text(
              '暂无数据',
              style: TextStyle(color: Colors.grey[500], fontSize: 16.sp),
            ),
          ],
        ),
      );
    }

    final maxAmount = (data.first['total'] as num).toDouble();

    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: data.length,
      itemBuilder: (context, index) {
        final item = data[index];
        return _buildRankItem(item, index, maxAmount, type);
      },
    );
  }

  Widget _buildRankItem(Map<String, dynamic> item, int index, double maxAmount, String type) {
    final amount = (item['total'] as num).toDouble();
    final count = item['count'] as int;
    final percentage = _totalExpense > 0 ? (amount / _totalExpense * 100) : 0.0;
    final progress = maxAmount > 0 ? amount / maxAmount : 0.0;

    String title;
    IconData icon;
    Color iconColor;

    switch (type) {
      case 'category':
        title = item['name'] as String? ?? '未知';
        icon = _getCategoryIcon(title);
        iconColor = _getCategoryColor(item['color'] as String?);
        break;
      case 'merchant':
        title = item['merchant'] as String? ?? '未知';
        icon = Icons.store;
        iconColor = Colors.blue;
        break;
      case 'project':
        title = item['project'] as String? ?? '未知';
        icon = Icons.folder;
        iconColor = Colors.orange;
        break;
      case 'account':
        title = item['name'] as String? ?? '未知';
        icon = _getAccountIcon(item['icon'] as String?);
        iconColor = Colors.green;
        break;
      default:
        title = '未知';
        icon = Icons.help_outline;
        iconColor = Colors.grey;
    }

    final rankIcon = index < 3 ? _getRankIcon(index) : null;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (rankIcon != null) ...[
                  rankIcon,
                  SizedBox(width: 12.w),
                ] else ...[
                  SizedBox(
                    width: 28.w,
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                ],
                Container(
                  width: 40.w,
                  height: 40.w,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Icon(icon, color: iconColor, size: 22.w),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        '$count笔  占支出${percentage.toStringAsFixed(1)}%',
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
                  ],
                ),
              ],
            ),
          ),
          Container(
            height: 4.h,
            margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.w),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(2.r),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: index < 3 ? iconColor : Colors.grey[400],
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _getRankIcon(int index) {
    final colors = [const Color(0xFFFFD700), const Color(0xFFC0C0C0), const Color(0xFFCD7F32)];
    final icons = [Icons.emoji_events, Icons.emoji_events, Icons.emoji_events];
    return Container(
      width: 28.w,
      height: 28.w,
      decoration: BoxDecoration(
        color: colors[index],
        shape: BoxShape.circle,
      ),
      child: Icon(icons[index], color: Colors.white, size: 16.w),
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

  Color _getCategoryColor(String? colorStr) {
    if (colorStr == null) return Colors.blue;
    try {
      return Color(int.parse(colorStr.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.blue;
    }
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
