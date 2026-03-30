import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:expense_tracker/data/models/transaction.dart' as models;
import 'package:expense_tracker/data/models/transaction_type.dart';
import 'package:provider/provider.dart';
import 'package:expense_tracker/providers/category_provider.dart';
import 'package:expense_tracker/providers/account_provider.dart';
import 'package:intl/intl.dart';

class TransactionListItem extends StatelessWidget {
  final models.Transaction transaction;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const TransactionListItem({
    super.key,
    required this.transaction,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            _CategoryIcon(transaction: transaction),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _CategoryName(transaction: transaction),
                      if (transaction.merchant != null) ...[
                        SizedBox(width: 4.w),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                          child: Text(
                            transaction.merchant!,
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                      SizedBox(width: 4.w),
                      Text(
                        DateFormat('MM-dd HH:mm').format(transaction.date),
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  _TransactionDetails(transaction: transaction),
                ],
              ),
            ),
            _AmountText(transaction: transaction),
          ],
        ),
      ),
    );
  }
}

class _CategoryIcon extends StatelessWidget {
  final models.Transaction transaction;

  const _CategoryIcon({required this.transaction});

  static IconData _getIconData(String iconName) {
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

  @override
  Widget build(BuildContext context) {
    final categoryProvider = context.watch<CategoryProvider>();
    final category = categoryProvider.getCategoryById(transaction.categoryId ?? '');
    final isTransfer = transaction.type == TransactionType.transfer;

    IconData icon;
    Color iconColor;
    
    if (isTransfer) {
      icon = Icons.swap_horiz;
      iconColor = Colors.blue;
    } else {
      icon = _getIconData(category?.icon ?? 'inventory_2');
      iconColor = category != null 
          ? Color(int.parse(category.color.replaceAll('#', '0xFF')))
          : Colors.grey[600]!;
    }

    return Container(
      width: 44.w,
      height: 44.w,
      decoration: BoxDecoration(
        color: isTransfer 
            ? Colors.blue.withValues(alpha: 0.15)
            : (category != null
                ? Color(int.parse(category.color.replaceAll('#', '0xFF'))).withValues(alpha: 0.15)
                : Colors.grey[200]),
        borderRadius: BorderRadius.circular(22.r),
      ),
      child: Center(
        child: Icon(
          icon,
          size: 22.sp,
          color: iconColor,
        ),
      ),
    );
  }
}

class _CategoryName extends StatelessWidget {
  final models.Transaction transaction;

  const _CategoryName({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final categoryProvider = context.watch<CategoryProvider>();
    final isTransfer = transaction.type == TransactionType.transfer;
    
    String displayName;
    if (isTransfer) {
      displayName = '转账';
    } else {
      final category = categoryProvider.getCategoryById(transaction.categoryId ?? '');
      displayName = category?.name ?? '未知分类';
    }

    return Text(
      displayName,
      style: TextStyle(
        fontSize: 16.sp,
        fontWeight: FontWeight.w500,
        color: Colors.grey[800],
      ),
    );
  }
}

class _TransactionDetails extends StatelessWidget {
  final models.Transaction transaction;

  const _TransactionDetails({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final accountProvider = context.watch<AccountProvider>();
    final account = accountProvider.getAccountById(transaction.accountId);
    final isTransfer = transaction.type == TransactionType.transfer;
    final targetAccount = transaction.targetAccountId != null 
        ? accountProvider.getAccountById(transaction.targetAccountId!) 
        : null;

    return Row(
      children: [
        Icon(Icons.account_balance_wallet, size: 12.sp, color: Colors.grey[500]),
        SizedBox(width: 4.w),
        if (isTransfer && targetAccount != null) ...[
          Text(
            account?.name ?? '未知账户',
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.grey[500],
            ),
          ),
          Icon(Icons.arrow_forward, size: 12.sp, color: Colors.grey[400]),
          Text(
            targetAccount.name,
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.grey[500],
            ),
          ),
        ] else ...[
          Text(
            account?.name ?? '未知账户',
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.grey[500],
            ),
          ),
        ],
        if (transaction.remark.isNotEmpty) ...[
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              '· ${transaction.remark}',
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.grey[500],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}

class _AmountText extends StatelessWidget {
  final models.Transaction transaction;

  const _AmountText({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isExpense = transaction.type == TransactionType.expense;
    final isTransfer = transaction.type == TransactionType.transfer;
    final color = isTransfer ? Colors.grey[700] : (isExpense ? Colors.red : Colors.green);
    final prefix = isTransfer ? '' : (isExpense ? '-' : '+');

    return Text(
      '$prefix¥${transaction.amount.toStringAsFixed(2)}',
      style: TextStyle(
        fontSize: 18.sp,
        fontWeight: FontWeight.bold,
        color: color,
      ),
    );
  }
}

