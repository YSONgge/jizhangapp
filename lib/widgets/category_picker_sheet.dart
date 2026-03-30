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
}
