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
      case 'restaurant': return Icons.restaurant_outlined;
      case 'home': return Icons.home_outlined;
      case 'phone':
      case 'phone_android': return Icons.phone_android_outlined;
      case 'shopping_cart': return Icons.shopping_cart_outlined;
      case 'directions_car': return Icons.directions_car_outlined;
      case 'flight': return Icons.flight_outlined;
      case 'medical':
      case 'medical_services': return Icons.medical_services_outlined;
      case 'school': return Icons.school_outlined;
      case 'sports':
      case 'sports_esports': return Icons.sports_esports_outlined;
      case 'gift':
      case 'card_giftcard': return Icons.card_giftcard_outlined;
      case 'child':
      case 'child_care': return Icons.child_care_outlined;
      case 'finance':
      case 'account_balance': return Icons.account_balance_outlined;
      case 'salary':
      case 'payments': return Icons.payments_outlined;
      case 'money':
      case 'attach_money': return Icons.attach_money_outlined;
      case 'savings': return Icons.savings_outlined;
      case 'laptop': return Icons.laptop_mac_outlined;
      case 'coffee': return Icons.coffee_outlined;
      case 'fitness':
      case 'fitness_center': return Icons.fitness_center_outlined;
      case 'pets': return Icons.pets_outlined;
      case 'movie': return Icons.movie_outlined;
      case 'music':
      case 'music_note': return Icons.music_note_outlined;
      case 'cake': return Icons.cake_outlined;
      case 'hospital':
      case 'local_hospital': return Icons.local_hospital_outlined;
      case 'more':
      case 'more_horiz': return Icons.more_horiz_outlined;
      case 'store': return Icons.store_outlined;
      case 'work': return Icons.work_outlined;
      case 'trending_up': return Icons.trending_up_outlined;
      case 'receipt_long': return Icons.receipt_long_outlined;
      case 'tv': return Icons.tv_outlined;
      case 'wifi': return Icons.wifi_outlined;
      case 'casino': return Icons.casino_outlined;
      case 'theater_comedy': return Icons.theater_comedy_outlined;
      case 'mic': return Icons.mic_outlined;
      case 'celebration': return Icons.celebration_outlined;
      case 'event': return Icons.event_outlined;
      case 'favorite': return Icons.favorite_outlined;
      case 'elderly': return Icons.elderly_outlined;
      case 'pregnant_woman': return Icons.pregnant_woman_outlined;
      case 'hotel': return Icons.hotel_outlined;
      case 'luggage': return Icons.luggage_outlined;
      case 'subway': return Icons.subway_outlined;
      case 'directions_bus': return Icons.directions_bus_outlined;
      case 'local_police': return Icons.local_police_outlined;
      case 'local_parking': return Icons.local_parking_outlined;
      case 'build': return Icons.build_outlined;
      case 'badge': return Icons.badge_outlined;
      case 'pedal_bike': return Icons.pedal_bike_outlined;
      case 'local_gas_station': return Icons.local_gas_station_outlined;
      case 'train': return Icons.train_outlined;
      case 'local_taxi': return Icons.local_taxi_outlined;
      case 'devices': return Icons.devices_outlined;
      case 'face': return Icons.face_outlined;
      case 'soap': return Icons.soap_outlined;
      case 'checkroom': return Icons.checkroom_outlined;
      case 'local_mall': return Icons.local_mall_outlined;
      case 'menu_book': return Icons.menu_book_outlined;
      case 'kitchen': return Icons.kitchen_outlined;
      case 'diamond': return Icons.diamond_outlined;
      case 'chair': return Icons.chair_outlined;
      case 'cleaning_services': return Icons.cleaning_services_outlined;
      case 'shopping_bag': return Icons.shopping_bag_outlined;
      case 'local_shipping': return Icons.local_shipping_outlined;
      case 'refund': return Icons.currency_exchange_outlined;
      case 'bed': return Icons.bed_outlined;
      case 'medication': return Icons.medication_outlined;
      case 'health_and_safety': return Icons.health_and_safety_outlined;
      case 'money_off': return Icons.money_off_outlined;
      case 'report_problem': return Icons.report_problem_outlined;
      case 'trending_down': return Icons.trending_down_outlined;
      case 'security': return Icons.security_outlined;
      case 'percent': return Icons.percent_outlined;
      case 'description': return Icons.description_outlined;
      case 'receipt': return Icons.receipt_outlined;
      case 'gavel': return Icons.gavel_outlined;
      case 'account_balance_wallet': return Icons.account_balance_wallet_outlined;
      case 'schedule': return Icons.schedule_outlined;
      case 'support_agent': return Icons.support_agent_outlined;
      case 'chat': return Icons.chat_outlined;
      case 'show_chart': return Icons.show_chart_outlined;
      case 'candlestick_chart': return Icons.candlestick_chart_outlined;
      case 'monetization_on': return Icons.monetization_on_outlined;
      case 'smartphone': return Icons.smartphone_outlined;
      case 'edit_note': return Icons.edit_note_outlined;
      case 'redeem': return Icons.redeem_outlined;
      case 'auto_awesome': return Icons.auto_awesome_outlined;
      default: return Icons.category_outlined;
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

