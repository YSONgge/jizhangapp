import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:expense_tracker/providers/account_provider.dart';
import 'package:expense_tracker/data/models/account.dart';
import 'package:expense_tracker/data/models/transaction.dart' as models;
import 'package:expense_tracker/data/models/transaction_type.dart';
import 'package:expense_tracker/database/database_helper.dart';
import 'package:intl/intl.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  bool _isAmountHidden = false;

  String _formatAmount(double amount) {
    if (_isAmountHidden) {
      return '******';
    }
    return '¥${amount.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Consumer<AccountProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.accounts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.account_balance_wallet_outlined, size: 80.w, color: Colors.grey[200]),
                  SizedBox(height: 16.h),
                  Text('暂无账户', style: TextStyle(fontSize: 16.sp, color: Colors.grey[400])),
                ],
              ),
            );
          }

          final accountsByCategory = <String, List<Account>>{};
          for (var account in provider.accounts) {
            final category = account.category;
            if (!accountsByCategory.containsKey(category)) {
              accountsByCategory[category] = [];
            }
            accountsByCategory[category]!.add(account);
          }

          final categoryOrder = ['现金', '金融', '虚拟', '信用卡', '投资', '预付', '应收', '应付'];

          final sortedCategories = categoryOrder
              .where((c) => accountsByCategory.containsKey(c))
              .toList();

          return Column(
            children: [
              // ========== 资产总览模块 ==========
              Container(
                margin: EdgeInsets.all(16.w),
                child: Column(
                  children: [
                    // 净资产卡片
                    Container(
                      padding: EdgeInsets.all(20.w),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2196F3), Color(0xFF64B5F6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '净资产',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            _formatAmount(provider.netAssets),
                            style: TextStyle(
                              fontSize: 36.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 12.h),
                    // 资产和负债
                    Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildAssetItem('总资产', _isAmountHidden ? 0.0 : provider.totalAssets, const Color(0xFF2196F3)),
                          ),
                          Container(width: 1, height: 40.h, color: Colors.grey[200]),
                          Expanded(
                            child: _buildAssetItem('总负债', _isAmountHidden ? 0.0 : provider.totalDebts, Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ========== 账户列表模块 ==========
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '账户列表',
                      style: TextStyle(
                        fontSize: 16.sp,
                        color: Colors.grey[800],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            _isAmountHidden ? Icons.visibility_off : Icons.visibility,
                            color: Colors.grey[600],
                            size: 20.w,
                          ),
                          onPressed: () {
                            setState(() {
                              _isAmountHidden = !_isAmountHidden;
                            });
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.add_circle, color: const Color(0xFF2196F3), size: 24.w),
                          onPressed: () {
                            _showAddAccountDialog(context);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8.h),

              // 账户列表 - 按分类显示
              Expanded(
                child: ListView.builder(
                  itemCount: sortedCategories.length,
                  itemBuilder: (context, index) {
                    final category = sortedCategories[index];
                    final accounts = accountsByCategory[category]!;
                    return _buildCategorySection(category, accounts);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAssetItem(String label, double amount, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
        ),
        SizedBox(height: 4.h),
        Text(
          _formatAmount(amount),
          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600, color: color),
        ),
      ],
    );
  }

  Widget _buildCategorySection(String category, List<Account> accounts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          child: Text(
            category,
            style: TextStyle(fontSize: 14.sp, color: Colors.grey[600], fontWeight: FontWeight.w500),
          ),
        ),
        ...accounts.map((account) => _buildAccountTile(account)),
      ],
    );
  }

  Widget _buildAccountTile(Account account) {
    IconData iconData;
    switch (account.icon) {
      case 'payments':
        iconData = Icons.payments;
        break;
      case 'account_balance':
        iconData = Icons.account_balance;
        break;
      case 'smartphone':
        iconData = Icons.smartphone;
        break;
      case 'chat':
        iconData = Icons.chat;
        break;
      default:
        iconData = Icons.account_balance_wallet;
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: ListTile(
        leading: Icon(iconData, color: const Color(0xFF2196F3)),
        title: Text(account.name),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatAmount(account.balance),
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
                color: account.balance >= 0 ? Colors.black87 : Colors.red,
              ),
            ),
            SizedBox(width: 4.w),
            Icon(Icons.chevron_right, color: Colors.grey[400], size: 20.w),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => _AccountDetailScreen(account: account)),
          );
        },
      ),
    );
  }

  void _showAddAccountDialog(BuildContext context) {
    final nameController = TextEditingController();
    String selectedCategory = '现金';
    String selectedType = 'cash';
    String selectedIcon = 'payments';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('添加账户'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: '账户名称'),
                ),
                SizedBox(height: 16.h),
                const Text('账户分类'),
                SizedBox(height: 8.h),
                Wrap(
                  spacing: 8,
                  children: ['现金', '金融', '虚拟', '信用卡', '投资'].map((cat) {
                    return ChoiceChip(
                      label: Text(cat),
                      selected: selectedCategory == cat,
                      onSelected: (selected) {
                        setDialogState(() {
                          selectedCategory = cat;
                          switch (cat) {
                            case '现金':
                              selectedType = 'cash';
                              selectedIcon = 'payments';
                              break;
                            case '金融':
                              selectedType = 'bank';
                              selectedIcon = 'account_balance';
                              break;
                            case '虚拟':
                              selectedType = 'alipay';
                              selectedIcon = 'smartphone';
                              break;
                            case '信用卡':
                              selectedType = 'credit';
                              selectedIcon = 'credit_card';
                              break;
                            case '投资':
                              selectedType = 'invest';
                              selectedIcon = 'trending_up';
                              break;
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty) {
                  final accountProvider = context.read<AccountProvider>();
                  final newAccount = Account(
                    id: 'acc_${DateTime.now().millisecondsSinceEpoch}',
                    name: nameController.text,
                    type: selectedType,
                    category: selectedCategory,
                    balance: 0,
                    icon: selectedIcon,
                  );
                  await DatabaseHelper.instance.insertAccount(newAccount);
                  await accountProvider.loadAccounts();
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountDetailScreen extends StatefulWidget {
  final Account account;

  const _AccountDetailScreen({required this.account});

  @override
  State<_AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends State<_AccountDetailScreen> {
  late Account _account;
  List<models.Transaction> _transactions = [];
  List<Map<String, dynamic>> _balanceChanges = [];
  bool _isLoading = true;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _account = widget.account;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final transactions = await DatabaseHelper.instance.getTransactionsByAccount(_account.id);
    final accounts = await DatabaseHelper.instance.getAllAccounts();
    final balanceChanges = await DatabaseHelper.instance.getBalanceChanges(_account.id);
    var updatedAccount = _account;
    for (var a in accounts) {
      if (a.id == _account.id) {
        updatedAccount = a;
        break;
      }
    }
    setState(() {
      _account = updatedAccount;
      _transactions = transactions;
      _balanceChanges = balanceChanges;
      _isLoading = false;
    });
  }

  String _getTransferLabel(models.Transaction t, String accountId, AccountProvider accountProvider) {
    if (t.type != TransactionType.transfer) {
      return t.categoryId ?? '支出';
    }
    if (t.accountId == accountId) {
      final targetAccount = accountProvider.getAccountById(t.targetAccountId ?? '');
      return '转出 → ${targetAccount?.name ?? t.targetAccountId}';
    } else {
      final fromAccount = accountProvider.getAccountById(t.accountId);
      return '转入 ← ${fromAccount?.name ?? t.accountId}';
    }
  }

  String _getAmountText(models.Transaction t, String accountId) {
    if (t.type == TransactionType.transfer) {
      if (t.accountId == accountId) {
        return '-¥${t.amount.toStringAsFixed(2)}';
      } else {
        return '+¥${t.amount.toStringAsFixed(2)}';
      }
    }
    return '${t.type == TransactionType.expense ? '-' : '+'}¥${t.amount.toStringAsFixed(2)}';
  }

  Color _getAmountColor(models.Transaction t, String accountId) {
    if (t.type == TransactionType.transfer) {
      if (t.accountId == accountId) {
        return Colors.orange;
      } else {
        return Colors.green;
      }
    }
    return t.type == TransactionType.expense ? Colors.red : Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AccountProvider>(
      builder: (context, accountProvider, child) {
        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          appBar: AppBar(
            backgroundColor: const Color(0xFF2196F3),
            title: Text(_account.name, style: const TextStyle(color: Colors.white)),
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onSelected: (value) {
                  if (value == 'edit') {
                    _showEditAccountDialog();
                  } else if (value == 'delete') {
                    _showDeleteConfirmDialog();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('编辑账户')),
                  const PopupMenuItem(value: 'delete', child: Text('删除账户')),
                ],
              ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
              children: [
                Container(
                  margin: EdgeInsets.all(16.w),
                  padding: EdgeInsets.all(20.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '账户余额',
                        style: TextStyle(fontSize: 14.sp, color: Colors.white.withOpacity(0.8)),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        '¥${_account.balance.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 32.sp, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('最近明细', style: TextStyle(fontSize: 14.sp, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                      TextButton.icon(
                        onPressed: _showEditBalanceDialog,
                        icon: Icon(Icons.edit, size: 16.w),
                        label: Text('修改余额', style: TextStyle(fontSize: 14.sp)),
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 16.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedTab = 0),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: _selectedTab == 0 ? const Color(0xFF2196F3) : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                            ),
                            child: Text(
                              '交易记录',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: _selectedTab == 0 ? const Color(0xFF2196F3) : Colors.grey[600],
                                fontWeight: _selectedTab == 0 ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedTab = 1),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: _selectedTab == 1 ? const Color(0xFF2196F3) : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                            ),
                            child: Text(
                              '余额变更',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: _selectedTab == 1 ? const Color(0xFF2196F3) : Colors.grey[600],
                                fontWeight: _selectedTab == 1 ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8.h),
                Expanded(
                  child: _selectedTab == 0
                      ? (_transactions.isEmpty
                          ? Center(child: Text('暂无交易记录', style: TextStyle(color: Colors.grey[400])))
                          : ListView.builder(
                              itemCount: _transactions.length,
                              itemBuilder: (context, index) {
                                final t = _transactions[index];
                                return Container(
                                  margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                                  padding: EdgeInsets.all(12.w),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(t.remark.isNotEmpty ? t.remark : (t.type == TransactionType.transfer ? _getTransferLabel(t, _account.id, context.read<AccountProvider>()) : t.categoryId ?? '支出'),
                                                style: TextStyle(fontSize: 14.sp, color: Colors.black87)),
                                            SizedBox(height: 4.h),
                                            Text(
                                              DateFormat('yyyy-MM-dd HH:mm').format(t.date),
                                              style: TextStyle(fontSize: 12.sp, color: Colors.grey[400]),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        _getAmountText(t, _account.id),
                                        style: TextStyle(
                                          fontSize: 16.sp,
                                          fontWeight: FontWeight.w500,
                                          color: _getAmountColor(t, _account.id),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ))
                      : (_balanceChanges.isEmpty
                          ? Center(child: Text('暂无余额变更记录', style: TextStyle(color: Colors.grey[400])))
                          : ListView.builder(
                              itemCount: _balanceChanges.length,
                              itemBuilder: (context, index) {
                                final change = _balanceChanges[index];
                                final changeAmount = change['change_amount'] as double;
                                return Container(
                                  margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                                  padding: EdgeInsets.all(12.w),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(change['reason'] ?? '余额调整',
                                                style: TextStyle(fontSize: 14.sp, color: Colors.black87)),
                                            SizedBox(height: 4.h),
                                            Text(
                                              '${change['old_balance']} → ${change['new_balance']}',
                                              style: TextStyle(fontSize: 12.sp, color: Colors.grey[400]),
                                            ),
                                            SizedBox(height: 2.h),
                                            Text(
                                              DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(change['created_at'])),
                                              style: TextStyle(fontSize: 12.sp, color: Colors.grey[400]),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '${changeAmount >= 0 ? '+' : ''}¥${changeAmount.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 16.sp,
                                          fontWeight: FontWeight.w500,
                                          color: changeAmount >= 0 ? Colors.green : Colors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            )),
                ),
              ],
            ),
        );
      },
    );
  }

  void _showEditBalanceDialog() {
    final controller = TextEditingController(text: _account.balance.toStringAsFixed(2));
    final accountProvider = Provider.of<AccountProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('修改余额'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '新余额',
            hintText: '请输入新的账户余额',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              try {
                final newBalance = double.tryParse(controller.text) ?? _account.balance;
                final oldBalance = _account.balance;
                if (newBalance != oldBalance) {
                  await DatabaseHelper.instance.updateAccountBalanceDirect(_account.id, newBalance);
                  await DatabaseHelper.instance.insertBalanceChange(
                    accountId: _account.id,
                    oldBalance: oldBalance,
                    newBalance: newBalance,
                    reason: '手动调整余额',
                  );
                }
                await accountProvider.loadAccounts();
                if (mounted) {
                  Navigator.pop(dialogContext);
                  _loadData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('余额修改成功')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('保存失败: $e')),
                  );
                }
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showEditAccountDialog() {
    final nameController = TextEditingController(text: _account.name);
    String selectedCategory = _account.category;
    String selectedType = _account.type;
    String selectedIcon = _account.icon;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('编辑账户'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: '账户名称'),
                ),
                SizedBox(height: 16.h),
                const Text('账户分类'),
                SizedBox(height: 8.h),
                Wrap(
                  spacing: 8,
                  children: ['现金', '金融', '虚拟', '信用卡', '投资'].map((cat) {
                    return ChoiceChip(
                      label: Text(cat),
                      selected: selectedCategory == cat,
                      onSelected: (selected) {
                        setDialogState(() {
                          selectedCategory = cat;
                          switch (cat) {
                            case '现金':
                              selectedType = 'cash';
                              selectedIcon = 'payments';
                              break;
                            case '金融':
                              selectedType = 'bank';
                              selectedIcon = 'account_balance';
                              break;
                            case '虚拟':
                              selectedType = 'alipay';
                              selectedIcon = 'smartphone';
                              break;
                            case '信用卡':
                              selectedType = 'credit';
                              selectedIcon = 'credit_card';
                              break;
                            case '投资':
                              selectedType = 'invest';
                              selectedIcon = 'trending_up';
                              break;
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('取消')),
            TextButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty) {
                  final updatedAccount = Account(
                    id: _account.id,
                    name: nameController.text,
                    type: selectedType,
                    category: selectedCategory,
                    balance: _account.balance,
                    icon: selectedIcon,
                  );
                  await DatabaseHelper.instance.updateAccount(updatedAccount);
                  if (mounted) {
                    await context.read<AccountProvider>().loadAccounts();
                    Navigator.pop(dialogContext);
                    _loadData();
                  }
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmDialog() async {
    // 检查是否只剩1个账户
    final accounts = await DatabaseHelper.instance.getAllAccounts();
    if (accounts.length <= 1) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('至少需要保留1个账户')),
        );
      }
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除账户'),
        content: Text('确定要删除账户"${_account.name}"吗？\n\n注意：删除后该账户的交易记录将变为"未知账户"。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              await DatabaseHelper.instance.deleteAccount(_account.id);
              if (mounted) {
                await context.read<AccountProvider>().loadAccounts();
                Navigator.pop(dialogContext);
                Navigator.pop(context);
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
