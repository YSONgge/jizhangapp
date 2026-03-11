import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:expense_tracker/providers/category_provider.dart';
import 'package:expense_tracker/data/models/category.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2196F3),
        title: const Text('分类管理', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Consumer<CategoryProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            children: [
              _buildCategorySection(context, '支出分类', _expenseCategories, provider),
              SizedBox(height: 24.h),
              _buildCategorySection(context, '收入分类', _incomeCategories, provider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCategorySection(
    BuildContext context,
    String title,
    List<_CategoryGroup> groups,
    CategoryProvider provider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 16.h),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...groups.map((group) {
          final categories = provider.categories
              .where((cat) => cat.parentId == group.parentId)
              .toList()
              ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
          
          if (categories.isEmpty) return const SizedBox.shrink();
          
          return _CategoryGroupSection(
            group: group,
            categories: categories,
          );
        }),
      ],
    );
  }
}

class _CategoryGroup {
  final String name;
  final IconData icon;
  final String parentId;

  const _CategoryGroup({
    required this.name,
    required this.icon,
    required this.parentId,
  });
}

// 支出类目分组（PRD 12个一级分类）
const List<_CategoryGroup> _expenseCategories = [
  _CategoryGroup(name: '食品酒水', icon: Icons.restaurant, parentId: 'cat_food'),
  _CategoryGroup(name: '居家生活', icon: Icons.home, parentId: 'cat_home'),
  _CategoryGroup(name: '交流通讯', icon: Icons.phone, parentId: 'cat_comm'),
  _CategoryGroup(name: '休闲娱乐', icon: Icons.sports_esports, parentId: 'cat_ent'),
  _CategoryGroup(name: '人情费用', icon: Icons.card_giftcard, parentId: 'cat_social'),
  _CategoryGroup(name: '宝宝费用', icon: Icons.child_care, parentId: 'cat_baby'),
  _CategoryGroup(name: '出差旅游', icon: Icons.flight, parentId: 'cat_travel'),
  _CategoryGroup(name: '行车交通', icon: Icons.directions_car, parentId: 'cat_traffic'),
  _CategoryGroup(name: '购物消费', icon: Icons.shopping_cart, parentId: 'cat_shop'),
  _CategoryGroup(name: '医疗教育', icon: Icons.medical_services, parentId: 'cat_medical'),
  _CategoryGroup(name: '其他杂项', icon: Icons.more_horiz, parentId: 'cat_other'),
  _CategoryGroup(name: '金融保险', icon: Icons.account_balance, parentId: 'cat_finance'),
];

// 收入类目分组（PRD 6个一级分类）
const List<_CategoryGroup> _incomeCategories = [
  _CategoryGroup(name: '工资收入', icon: Icons.payments, parentId: 'cat_inc_wage'),
  _CategoryGroup(name: '经营收入', icon: Icons.store, parentId: 'cat_inc_bus'),
  _CategoryGroup(name: '投资收益', icon: Icons.trending_up, parentId: 'cat_inv'),
  _CategoryGroup(name: '兼职副业', icon: Icons.work, parentId: 'cat_inc_pt'),
  _CategoryGroup(name: '退款返还', icon: Icons.receipt_long, parentId: 'cat_inc_refund'),
  _CategoryGroup(name: '其他收入', icon: Icons.attach_money, parentId: 'cat_inc_other'),
];

class _CategoryGroupSection extends StatelessWidget {
  final _CategoryGroup group;
  final List<Category> categories;

  const _CategoryGroupSection({
    required this.group,
    required this.categories,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 24.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 分组标题
          _GroupHeader(
            icon: group.icon,
            name: group.name,
            count: categories.length,
          ),
          SizedBox(height: 12.h),
          // 分类网格
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 1.2,
              crossAxisSpacing: 12.w,
              mainAxisSpacing: 12.h,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return _CategoryCard(category: category);
            },
          ),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final IconData icon;
  final String name;
  final int count;

  const _GroupHeader({
    required this.icon,
    required this.name,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20.sp, color: Colors.grey[600]),
          SizedBox(width: 8.w),
          Text(
            name,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const Spacer(),
          Text(
            '$count项',
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final Category category;

  const _CategoryCard({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Color(int.parse(category.color.replaceAll('#', '0xFF'))).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: Color(int.parse(category.color.replaceAll('#', '0xFF'))).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getIconData(category.icon),
            size: 32.sp,
            color: Color(int.parse(category.color.replaceAll('#', '0xFF'))),
          ),
          SizedBox(height: 4.h),
          Text(
            category.name,
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.grey[700],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
      case 'phone':
        return Icons.phone;
      case 'wifi':
        return Icons.wifi;
      case 'tv':
        return Icons.tv;
      case 'casino':
        return Icons.casino;
      case 'theater_comedy':
        return Icons.theater_comedy;
      case 'mic':
        return Icons.mic;
      case 'movie':
        return Icons.movie;
      case 'music_note':
        return Icons.music_note;
      case 'celebration':
        return Icons.celebration;
      case 'event':
        return Icons.event;
      case 'child_care':
        return Icons.child_care;
      case 'cake':
        return Icons.cake;
      case 'favorite':
        return Icons.favorite;
      case 'elderly':
        return Icons.elderly;
      case 'pregnant_woman':
        return Icons.pregnant_woman;
      case 'flight':
        return Icons.flight;
      case 'hotel':
        return Icons.hotel;
      case 'luggage':
        return Icons.luggage;
      case 'subway':
        return Icons.subway;
      case 'directions_bus':
        return Icons.directions_bus;
      case 'build':
        return Icons.build;
      case 'local_police':
        return Icons.local_police;
      case 'local_parking':
        return Icons.local_parking;
      case 'badge':
        return Icons.badge;
      case 'pedal_bike':
        return Icons.pedal_bike;
      case 'local_gas_station':
        return Icons.local_gas_station;
      case 'train':
        return Icons.train;
      case 'local_taxi':
        return Icons.local_taxi;
      case 'devices':
        return Icons.devices;
      case 'face':
        return Icons.face;
      case 'soap':
        return Icons.soap;
      case 'checkroom':
        return Icons.checkroom;
      case 'local_mall':
        return Icons.local_mall;
      case 'menu_book':
        return Icons.menu_book;
      case 'kitchen':
        return Icons.kitchen;
      case 'diamond':
        return Icons.diamond;
      case 'pets':
        return Icons.pets;
      case 'chair':
        return Icons.chair;
      case 'bed':
        return Icons.bed;
      case 'money_off':
        return Icons.money_off;
      case 'report_problem':
        return Icons.report_problem;
      case 'more_horiz':
        return Icons.more_horiz;
      case 'account_balance':
        return Icons.account_balance;
      case 'schedule':
        return Icons.schedule;
      case 'store':
        return Icons.store;
      case 'support_agent':
        return Icons.support_agent;
      case 'chat':
        return Icons.chat;
      case 'percent':
        return Icons.percent;
      case 'show_chart':
        return Icons.show_chart;
      case 'candlestick_chart':
        return Icons.candlestick_chart;
      case 'account_balance_wallet':
        return Icons.account_balance_wallet;
      case 'monetization_on':
        return Icons.monetization_on;
      case 'edit_note':
        return Icons.edit_note;
      case 'receipt_long':
        return Icons.receipt_long;
      case 'gavel':
        return Icons.gavel;
      case 'redeem':
        return Icons.redeem;
      case 'auto_awesome':
        return Icons.auto_awesome;
      case 'smartphone':
        return Icons.smartphone;
      case 'payment':
        return Icons.payment;
      case 'shopping_bag':
        return Icons.shopping_bag;
      case 'shopping':
        return Icons.shopping_cart;
      case 'directions':
        return Icons.directions;
      case 'local_shipping':
        return Icons.local_shipping;
      case 'description':
        return Icons.description;
      case 'health_and_safety':
        return Icons.health_and_safety;
      case 'medication':
        return Icons.medication;
      case 'local_hospital':
        return Icons.local_hospital;
      case 'security':
        return Icons.security;
      default:
        return Icons.category;
    }
  }
}
