import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../providers/account_provider.dart';
import '../data/models/account.dart';

class AccountPickerSheet extends StatelessWidget {
  final String? selectedAccountId;
  final Function(Account) onAccountSelected;
  final String title;

  const AccountPickerSheet({
    super.key,
    this.selectedAccountId,
    required this.onAccountSelected,
    this.title = '选择账户',
  });

  static Future<Account?> show(
    BuildContext context, {
    String? selectedAccountId,
    String title = '选择账户',
  }) {
    return showModalBottomSheet<Account>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => AccountPickerSheet(
        selectedAccountId: selectedAccountId,
        title: title,
        onAccountSelected: (account) => Navigator.pop(context, account),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AccountProvider>(
      builder: (context, provider, child) {
        final accounts = provider.accounts;
        final groupedAccounts = _groupAccountsByType(accounts);

        return Container(
          height: MediaQuery.of(context).size.height * 0.65,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),
          child: Column(
            children: [
              Container(
                margin: EdgeInsets.only(top: 16.h),
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(20.w),
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              Expanded(
                child: groupedAccounts.isEmpty
                    ? Center(
                        child: Text(
                          '暂无账户',
                          style: TextStyle(color: Colors.grey[400], fontSize: 14.sp),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        itemCount: groupedAccounts.length,
                        itemBuilder: (context, index) {
                          final group = groupedAccounts[index];
                          return _AccountGroup(
                            group: group,
                            selectedAccountId: selectedAccountId,
                            onAccountSelected: onAccountSelected,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<_AccountGroupData> _groupAccountsByType(List<Account> accounts) {
    final Map<String, _AccountGroupData> groups = {};

    for (var account in accounts) {
      final typeInfo = _getAccountTypeInfo(account.type);
      if (!groups.containsKey(typeInfo['type'])) {
        groups[typeInfo['type'] as String] = _AccountGroupData(
          type: typeInfo['type'] as String,
          typeName: typeInfo['name'] as String,
          emoji: _getTypeEmoji(typeInfo['type'] as String),
          color: _getTypeColor(typeInfo['type'] as String),
          accounts: [],
        );
      }
      groups[typeInfo['type'] as String]!.accounts.add(account);
    }

    return groups.values.toList();
  }

  Map<String, dynamic> _getAccountTypeInfo(String accountType) {
    switch (accountType) {
      case 'cash':
        return {'type': 'cash', 'name': '现金'};
      case 'bank':
        return {'type': 'bank', 'name': '储蓄卡'};
      case 'alipay':
      case 'wechat':
      case 'online':
        return {'type': 'online', 'name': '网络支付'};
      case 'credit':
      case 'credit_card':
        return {'type': 'credit', 'name': '信用支付'};
      case 'prepaid':
        return {'type': 'prepaid', 'name': '充值/预付卡'};
      case 'invest':
        return {'type': 'invest', 'name': '投资账户'};
      case 'receivable':
        return {'type': 'receivable', 'name': '应收'};
      case 'payable':
        return {'type': 'payable', 'name': '应付'};
      default:
        return {'type': 'other', 'name': '其他'};
    }
  }

  String _getTypeEmoji(String type) {
    switch (type) {
      case 'cash':
        return '💵';
      case 'bank':
        return '🏦';
      case 'online':
        return '📱';
      case 'credit':
        return '💳';
      case 'prepaid':
        return '🎁';
      case 'invest':
        return '📈';
      case 'receivable':
        return '📥';
      case 'payable':
        return '📤';
      default:
        return '💰';
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'cash':
        return const Color(0xFFFF9800);
      case 'bank':
        return const Color(0xFF4CAF50);
      case 'online':
        return const Color(0xFF2196F3);
      case 'credit':
        return const Color(0xFFF44336);
      case 'prepaid':
        return const Color(0xFF9C27B0);
      case 'invest':
        return const Color(0xFF009688);
      case 'receivable':
        return const Color(0xFFFFC107);
      case 'payable':
        return const Color(0xFFFF5722);
      default:
        return const Color(0xFF9E9E9E);
    }
  }
}

class _AccountGroupData {
  final String type;
  final String typeName;
  final String emoji;
  final Color color;
  final List<Account> accounts;

  _AccountGroupData({
    required this.type,
    required this.typeName,
    required this.emoji,
    required this.color,
    required this.accounts,
  });
}

class _AccountGroup extends StatelessWidget {
  final _AccountGroupData group;
  final String? selectedAccountId;
  final Function(Account) onAccountSelected;

  const _AccountGroup({
    required this.group,
    this.selectedAccountId,
    required this.onAccountSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: 16.h, bottom: 12.h),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(6.w),
                decoration: BoxDecoration(
                  color: group.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  group.emoji,
                  style: TextStyle(fontSize: 16.sp),
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                group.typeName,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
        ...group.accounts.map((account) => _AccountItem(
          account: account,
          isSelected: account.id == selectedAccountId,
          accentColor: group.color,
          onTap: () => onAccountSelected(account),
        )),
      ],
    );
  }
}

class _AccountItem extends StatelessWidget {
  final Account account;
  final bool isSelected;
  final Color accentColor;
  final VoidCallback onTap;

  const _AccountItem({
    required this.account,
    required this.isSelected,
    required this.accentColor,
    required this.onTap,
  });

  String _getBrandEmoji(String accountType, String accountName) {
    final name = accountName.toLowerCase();
    final type = accountType.toLowerCase();
    
    if (name.contains('微信') || name.contains('wechat') || type == 'wechat') {
      return '💚';
    }
    if (name.contains('支付宝') || name.contains('alipay') || type == 'alipay') {
      return '🅰️';
    }
    if (name.contains('现金')) {
      return '💵';
    }
    if (name.contains('银行') || name.contains('储蓄') || type == 'bank') {
      return '🏦';
    }
    if (name.contains('信用卡') || name.contains('信用') || type == 'credit' || type == 'credit_card') {
      return '💳';
    }
    if (name.contains('花呗')) {
      return '🔴';
    }
    if (name.contains('白条')) {
      return '🟣';
    }
    if (name.contains('预付') || name.contains('充值') || type == 'prepaid') {
      return '🎁';
    }
    if (name.contains('投资') || name.contains('股票') || name.contains('基金') || type == 'invest') {
      return '📈';
    }
    if (name.contains('应收') || name.contains('借') || type == 'receivable') {
      return '📥';
    }
    if (name.contains('应付') || name.contains('欠') || type == 'payable') {
      return '📤';
    }
    return '💰';
  }

  String _getBankAbbr(String accountName) {
    final name = accountName.toLowerCase();
    
    if (name.contains('工商')) return '工行';
    if (name.contains('建设')) return '建行';
    if (name.contains('农业')) return '农行';
    if (name.contains('中国银行') || name.contains('中行')) return '中行';
    if (name.contains('招商')) return '招行';
    if (name.contains('交通')) return '交行';
    if (name.contains('民生')) return '民生';
    if (name.contains('浦发')) return '浦发';
    if (name.contains('兴业')) return '兴业';
    if (name.contains('光大')) return '光大';
    if (name.contains('中信')) return '中信';
    if (name.contains('平安')) return '平安';
    if (name.contains('邮储')) return '邮储';
    if (name.contains('农商')) return '农商';
    if (name.contains('支付宝')) return '支付宝';
    if (name.contains('微信') || name.contains('wechat')) return '微信';
    if (name.contains('云闪付')) return '云闪付';
    if (name.contains('花呗')) return '花呗';
    if (name.contains('白条')) return '白条';
    if (name.contains('信用卡')) return '信用卡';
    return '';
  }

  Color _getBankColor(String accountName) {
    final name = accountName.toLowerCase();
    
    if (name.contains('工商')) return const Color(0xFFDC143C);
    if (name.contains('建设')) return const Color(0xFF003399);
    if (name.contains('农业')) return const Color(0xFF228B22);
    if (name.contains('中国银行') || name.contains('中行')) return const Color(0xFFDC143C);
    if (name.contains('招商')) return const Color(0xFFFF6600);
    if (name.contains('交通')) return const Color(0xFF003399);
    if (name.contains('民生')) return const Color(0xFF003399);
    if (name.contains('浦发')) return const Color(0xFF003399);
    if (name.contains('兴业')) return const Color(0xFF003399);
    if (name.contains('光大')) return const Color(0xFFDC143C);
    if (name.contains('中信')) return const Color(0xFFE60000);
    if (name.contains('平安')) return const Color(0xFFFF6600);
    if (name.contains('邮储')) return const Color(0xFF008543);
    if (name.contains('农商')) return const Color(0xFF228B22);
    if (name.contains('支付宝')) return const Color(0xFF1677FF);
    if (name.contains('微信') || name.contains('wechat')) return const Color(0xFF07C160);
    if (name.contains('云闪付')) return const Color(0xFFE70012);
    if (name.contains('花呗')) return const Color(0xFF625AF4);
    if (name.contains('白条')) return const Color(0xFFE60000);
    if (name.contains('信用卡')) return const Color(0xFF625AF4);
    return const Color(0xFF999999);
  }

  Widget _buildAccountIcon(String accountName) {
    final abbr = _getBankAbbr(accountName);
    final color = _getBankColor(accountName);
    
    if (abbr.isNotEmpty) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4.r),
        ),
        child: Center(
          child: Text(
            abbr,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }
    
    return Text(
      _getBrandEmoji('', accountName),
      style: TextStyle(fontSize: 22.sp),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bankColor = _getBankColor(account.name);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: isSelected ? bankColor.withValues(alpha: 0.1) : Colors.grey[50],
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isSelected ? bankColor : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44.w,
              height: 44.w,
              decoration: BoxDecoration(
                color: bankColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Center(
                child: _buildAccountIcon(account.name),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.name,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? _getBankColor(account.name) : Colors.black87,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    '余额: ¥${account.balance.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: EdgeInsets.all(4.w),
                decoration: BoxDecoration(
                  color: bankColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check, color: Colors.white, size: 16.sp),
              ),
          ],
        ),
      ),
    );
  }
}
