import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:expense_tracker/providers/transaction_provider.dart';
import 'package:expense_tracker/providers/account_provider.dart';
import 'package:expense_tracker/providers/category_provider.dart';
import 'package:expense_tracker/widgets/transaction_list_item.dart';
import 'package:expense_tracker/screens/full_screen_editor_screen.dart';
import 'package:expense_tracker/screens/voice_input_screen.dart';
import 'package:expense_tracker/screens/accounts_screen.dart';
import 'package:expense_tracker/screens/statistics_screen.dart';
import 'package:expense_tracker/screens/settings_screen.dart';
import 'package:expense_tracker/database/database_helper.dart';
import 'package:expense_tracker/data/models/transaction_type.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  String _getTitle() {
    switch (_currentIndex) {
      case 0:
        return '明细';
      case 1:
        return '报表分析';
      case 2:
        return '账户管理';
      case 3:
        return '设置';
      default:
        return '明细';
    }
  }

  Widget _getBody() {
    switch (_currentIndex) {
      case 0:
        return const _TransactionsTab();
      case 1:
        return const StatisticsScreen();
      case 2:
        return const AccountsScreen();
      case 3:
        return const SettingsScreen();
      default:
        return const _TransactionsTab();
    }
  }

  int _getNavIndex() {
    if (_currentIndex >= 2) {
      return _currentIndex + 1;
    }
    return _currentIndex;
  }

  int _getPageIndex(int navIndex) {
    if (navIndex >= 2) {
      return navIndex - 1;
    }
    return navIndex;
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final categoryProvider = context.read<CategoryProvider>();
      final accountProvider = context.read<AccountProvider>();
      final transactionProvider = context.read<TransactionProvider>();

      categoryProvider.loadCategories();
      accountProvider.loadAccounts();
      transactionProvider.loadTransactions();
    });
  }

  void _onItemTapped(int navIndex) {
    final newPageIndex = _getPageIndex(navIndex);
    setState(() {
      _currentIndex = newPageIndex;
    });
  }

  void _onMainButtonTap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FullScreenEditorScreen()),
    );
  }

  void _onMainButtonLongPress() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => VoiceInputScreen(
        onComplete: () {
          Navigator.pop(context);
        },
        onCancelled: () {
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2196F3),
        elevation: 0,
        title: Text(
          _getTitle(),
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_currentIndex == 0)
            Padding(
              padding: EdgeInsets.only(right: 16.w),
              child: Center(
                child: Consumer<TransactionProvider>(
                  builder: (context, provider, child) {
                    return Text(
                      '本月',
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14.sp),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
      body: _getBody(),
      bottomNavigationBar: SizedBox(
        height: 80.h,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            BottomNavigationBar(
              currentIndex: _getNavIndex(),
              onTap: (navIndex) {
                _onItemTapped(navIndex);
              },
              type: BottomNavigationBarType.fixed,
              selectedItemColor: Colors.blue,
              unselectedItemColor: Colors.grey,
              backgroundColor: Colors.white,
              elevation: 0,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.list),
                  label: '明细',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.bar_chart),
                  label: '报表',
                ),
                BottomNavigationBarItem(
                  icon: SizedBox.shrink(),
                  label: '',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.account_balance_wallet),
                  label: '账户',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings),
                  label: '设置',
                ),
              ],
            ),
            Positioned(
              bottom: 25.h,
              left: 0,
              right: 0,
              child: Center(
                child: Material(
                  color: Colors.transparent,
                  child: GestureDetector(
                    onTap: _onMainButtonTap,
                    child: Container(
                      width: 64.w,
                      height: 64.w,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionsTab extends StatelessWidget {
  const _TransactionsTab();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SummaryCard(),
        Expanded(
          child: Consumer<TransactionProvider>(
            builder: (context, provider, child) {
              final transactions = provider.transactions;

              if (transactions.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 80.w, color: Colors.grey[200]),
                      SizedBox(height: 16.h),
                      Text(
                        '暂无账单记录\n点击底部"+"开始记账',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16.sp, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: EdgeInsets.all(16.w),
                itemCount: transactions.length,
                itemBuilder: (context, index) {
                  final transaction = transactions[index];
                  return TransactionListItem(
                    transaction: transaction,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FullScreenEditorScreen(
                            transactionToEdit: transaction,
                          ),
                        ),
                      ).then((_) {
                        context.read<TransactionProvider>().loadTransactions();
                        context.read<AccountProvider>().loadAccounts();
                      });
                    },
                    onLongPress: () => _showTransactionOptions(context, transaction),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showTransactionOptions(BuildContext context, dynamic transaction) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('编辑'),
              onTap: () {
                Navigator.pop(context);
                _editTransaction(context, transaction);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('删除', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteTransaction(context, transaction);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _editTransaction(BuildContext context, dynamic transaction) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenEditorScreen(transactionToEdit: transaction),
      ),
    );
  }

  void _confirmDeleteTransaction(BuildContext context, dynamic transaction) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除确认'),
        content: const Text('确定要删除这条交易记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              await DatabaseHelper.instance.deleteTransaction(transaction.id);
              if (context.mounted) {
                await context.read<TransactionProvider>().loadTransactions();
                await context.read<AccountProvider>().loadAccounts();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已删除')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionProvider>(
      builder: (context, provider, child) {
        final expense = provider.getMonthExpense();
        final income = provider.getMonthIncome();
        final balance = income - expense;

        return Container(
          margin: EdgeInsets.all(16.w),
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: const Color(0xFF2196F3),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '本月结余',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                '¥${balance.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 32.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 20.h),
              Row(
                children: [
                  Expanded(
                    child: _AmountItem(
                      label: '支出',
                      amount: expense,
                      color: Colors.white,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40.h,
                    color: Colors.white.withOpacity(0.2),
                  ),
                  Expanded(
                    child: _AmountItem(
                      label: '收入',
                      amount: income,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AmountItem extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;

  const _AmountItem({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            color: color.withOpacity(0.7),
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          '¥${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
