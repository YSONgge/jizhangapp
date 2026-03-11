import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:expense_tracker/data/models/transaction.dart' as models;
import 'package:expense_tracker/data/models/transaction_type.dart';
import 'package:provider/provider.dart';
import 'package:expense_tracker/providers/category_provider.dart';
import 'package:expense_tracker/providers/account_provider.dart';

class SimpleTransactionListItem extends StatelessWidget {
  final models.Transaction transaction;

  const SimpleTransactionListItem({
    super.key,
    required this.transaction,
  });

  @override
  Widget build(BuildContext context) {
    final categoryProvider = context.watch<CategoryProvider>();
    final accountProvider = context.watch<AccountProvider>();
    final category = transaction.categoryId != null
        ? categoryProvider.getCategoryById(transaction.categoryId!)
        : null;
    final account = accountProvider.getAccountById(transaction.accountId);

    final isExpense = transaction.type == TransactionType.expense;

    return Container(
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
          // 极简图标
          Container(
            width: 48.w,
            height: 48.w,
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(24.r),
            ),
            child: Center(
              child: Icon(
                _getIconData(category?.icon ?? 'inventory_2'),
                size: 20.sp,
                color: Colors.grey[600],
              ),
            ),
          ),
          SizedBox(width: 16.w),
          // 中间信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.merchant ?? (category?.name ?? '未知分类'),
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey[900],
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  _formatTime(transaction.date),
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
          // 金额
          Text(
            '${isExpense ? '-' : '+'}¥${transaction.amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w500,
              color: isExpense ? Colors.grey[900] : Colors.green[500],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'restaurant':
        return Icons.restaurant;
      case 'directions_car':
        return Icons.directions_car;
      case 'shopping_cart':
        return Icons.shopping_cart;
      case 'home':
        return Icons.home;
      case 'sports_esports':
        return Icons.sports_esports;
      case 'medical_services':
        return Icons.medical_services;
      case 'school':
        return Icons.school;
      case 'inventory_2':
        return Icons.inventory_2;
      case 'payments':
        return Icons.payments;
      case 'work':
        return Icons.work;
      case 'trending_up':
        return Icons.trending_up;
      case 'card_giftcard':
        return Icons.card_giftcard;
      case 'attach_money':
        return Icons.attach_money;
      default:
        return Icons.category;
    }
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return '今天 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return '昨天 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays < 7) {
      return '${['一', '二', '三', '四', '五', '六', '日'][date.weekday - 1]} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.month}月${date.day}日 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
  }
}
