import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:expense_tracker/providers/transaction_provider.dart';
import 'package:expense_tracker/providers/account_provider.dart';
import 'package:expense_tracker/screens/accounts_screen.dart';
import 'package:expense_tracker/screens/categories_screen.dart';
import 'package:expense_tracker/screens/owners_screen.dart';
import 'package:expense_tracker/screens/merchants_screen.dart';
import 'package:expense_tracker/screens/export_screen.dart';
import 'package:expense_tracker/screens/import_screen.dart';
import 'package:expense_tracker/screens/backup_settings_screen.dart';
import 'package:expense_tracker/database/database_helper.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.h),
        children: [
          _SimpleSettingsItem(
            icon: Icons.account_balance_wallet_outlined,
            title: '账户管理',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AccountsScreen()),
              );
            },
          ),
          _SimpleSettingsItem(
            icon: Icons.category_outlined,
            title: '分类管理',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CategoriesScreen()),
              );
            },
          ),
          _SimpleSettingsItem(
            icon: Icons.person_outline,
            title: '归属人管理',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const OwnersScreen()),
              );
            },
          ),
          _SimpleSettingsItem(
            icon: Icons.store_outlined,
            title: '商家管理',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MerchantsScreen()),
              );
            },
          ),
          SizedBox(height: 16.h),
          Container(
            padding: EdgeInsets.only(left: 4.w, bottom: 8.h),
            child: Text(
              '数据管理',
              style: TextStyle(
                fontSize: 13.sp,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          _SimpleSettingsItem(
            icon: Icons.file_upload_outlined,
            title: '导出数据',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ExportScreen()),
              );
            },
          ),
          _SimpleSettingsItem(
            icon: Icons.file_download_outlined,
            title: '导入数据',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ImportScreen()),
              );
            },
          ),
          _SimpleSettingsItem(
            icon: Icons.backup_outlined,
            title: '自动备份',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BackupSettingsScreen()),
              );
            },
          ),
          SizedBox(height: 16.h),
          _SimpleSettingsItem(
            icon: Icons.cleaning_services_outlined,
            title: '清空数据',
            onTap: () => _showClearDataDialog(context),
            textColor: Colors.red[500],
          ),
          SizedBox(height: 32.h),
          _SimpleSettingsItem(
            icon: Icons.info_outline,
            title: '关于',
            subtitle: '版本 1.0.0',
            onTap: () => _showAboutDialog(context),
          ),
        ],
      ),
    );
  }

  void _showClearDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清空'),
        content: const Text('确定要删除所有记账记录吗？此操作不可恢复！'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await DatabaseHelper.instance.clearAllData();
                await context.read<TransactionProvider>().loadTransactions();
                await context.read<AccountProvider>().loadAccounts();
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('数据已清空')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('清空失败: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('确定清空'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: '智能记账',
      applicationVersion: '1.0.0',
      applicationIcon: const FlutterLogo(size: 48),
      children: const [
        Text('一款支持智能文字识别的记账应用'),
        SizedBox(height: 16),
        Text('输入自然语言，自动识别金额、分类、账户'),
      ],
    );
  }
}


class _SimpleSettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? textColor;

  const _SimpleSettingsItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16.h),
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
            Icon(icon, size: 20, color: Colors.grey[600]),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w400,
                      color: textColor ?? Colors.grey[900],
                    ),
                  ),
                  if (subtitle != null) ...[
                    SizedBox(height: 2.h),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
