import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:expense_tracker/data/models/category.dart';
import 'package:expense_tracker/data/models/transaction_type.dart';
import 'package:expense_tracker/providers/category_provider.dart';

class CategoryPickerSheet extends StatefulWidget {
  final TransactionType? type;
  final String? selectedCategoryId;
  final Function(String) onCategorySelected;

  const CategoryPickerSheet({
    super.key,
    this.type,
    this.selectedCategoryId,
    required this.onCategorySelected,
  });

  @override
  State<CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<CategoryPickerSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _expandedCategoryId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.type == TransactionType.income) {
      _tabController.index = 1;
    }
    _expandedCategoryId = widget.selectedCategoryId;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CategoryProvider>(
      builder: (context, provider, child) {
        final expenseCategories = provider.getExpenseParentCategories();
        final incomeCategories = provider.getIncomeParentCategories();

        return Container(
          height: 450.h,
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '选择分类',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (widget.selectedCategoryId != null)
                      TextButton(
                        onPressed: () {
                          widget.onCategorySelected('');
                          Navigator.pop(context);
                        },
                        child: const Text('清除'),
                      ),
                  ],
                ),
              ),
              Container(
                margin: EdgeInsets.symmetric(horizontal: 16.w),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  labelColor: Colors.red,
                  unselectedLabelColor: Colors.grey[600],
                  labelStyle: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500),
                  tabs: [
                    Tab(text: '支出'),
                    Tab(text: '收入'),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildCategoryList(expenseCategories, provider),
                    _buildCategoryList(incomeCategories, provider),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryList(List<Category> parentCategories, CategoryProvider provider) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      itemCount: parentCategories.length,
      itemBuilder: (context, index) {
        final parent = parentCategories[index];
        final children = provider.getChildCategories(parent.id);
        final isExpanded = _expandedCategoryId == parent.id;
        final isSelected = widget.selectedCategoryId == parent.id;

        return Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 12.w),
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue.withValues(alpha: 0.1) : Colors.grey[50],
                borderRadius: BorderRadius.circular(8.r),
                border: isSelected ? Border.all(color: Colors.blue, width: 1) : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 36.w,
                    height: 36.w,
                    decoration: BoxDecoration(
                      color: Color(int.parse(parent.color.replaceAll('#', '0xFF'))).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(18.r),
                    ),
                    child: Icon(
                      _getIconData(parent.icon),
                      size: 20.sp,
                      color: Color(int.parse(parent.color.replaceAll('#', '0xFF'))),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        widget.onCategorySelected(parent.id);
                        Navigator.pop(context);
                      },
                      child: Text(
                        parent.name,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                          color: isSelected ? Colors.blue : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  if (children.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _expandedCategoryId = isExpanded ? null : parent.id;
                        });
                      },
                      child: Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.grey[400],
                        size: 20.sp,
                      ),
                    ),
                ],
              ),
            ),
            if (isExpanded && children.isNotEmpty)
              Container(
                padding: EdgeInsets.only(left: 20.w, top: 8.h, bottom: 8.h),
                child: Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children: children.map((child) {
                    final isChildSelected = widget.selectedCategoryId == child.id;
                    return GestureDetector(
                      onTap: () {
                        widget.onCategorySelected(child.id);
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                        decoration: BoxDecoration(
                          color: isChildSelected ? Colors.blue : Colors.grey[100],
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        child: Text(
                          child.name,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: isChildSelected ? Colors.white : Colors.grey[700],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            SizedBox(height: 8.h),
          ],
        );
      },
    );
  }

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
}
