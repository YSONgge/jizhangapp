import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:expense_tracker/providers/category_provider.dart';
import 'package:expense_tracker/data/models/category.dart';
import 'package:uuid/uuid.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  void _showAddCategoryDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddCustomCategorySheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2196F3),
        title: const Text('分类管理', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddCategoryDialog(context),
          ),
        ],
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
  _CategoryGroup(name: '投资收益', icon: Icons.trending_up, parentId: 'cat_inc_inv'),
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
    final color = Color(int.parse(category.color.replaceAll('#', '0xFF')));
    return GestureDetector(
      onLongPress: category.isCustom ? () => _showCategoryOptions(context) : null,
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getIconData(category.icon),
              size: 32.sp,
              color: Colors.grey[600],
            ),
            SizedBox(height: 6.h),
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
      ),
    );
  }

  void _showCategoryOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.symmetric(vertical: 16.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              category.name,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 16.h),
            ListTile(
              leading: Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(Icons.edit, color: Colors.blue),
              ),
              title: Text('编辑分类', style: TextStyle(fontSize: 14.sp)),
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => AddCustomCategorySheet(category: category),
                );
              },
            ),
            SizedBox(height: 8.h),
          ],
        ),
      ),
    );
  }

  IconData _getIconData(String iconName) {
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

class AddCustomCategorySheet extends StatefulWidget {
  final Category? category;

  const AddCustomCategorySheet({super.key, this.category});

  @override
  State<AddCustomCategorySheet> createState() => _AddCustomCategorySheetState();
}

class _AddCustomCategorySheetState extends State<AddCustomCategorySheet> {
  final _uuid = const Uuid();
  String? _selectedParentId;
  String _categoryName = '';
  String _selectedIcon = 'category';
  Color _selectedColor = const Color(0xFF4ECDC4);

  bool get isEditing => widget.category != null;

  final List<Map<String, dynamic>> _parentCategories = [
    {'id': 'cat_food', 'name': '食品酒水', 'icon': 'restaurant'},
    {'id': 'cat_home', 'name': '居家生活', 'icon': 'home'},
    {'id': 'cat_comm', 'name': '交流通讯', 'icon': 'phone'},
    {'id': 'cat_ent', 'name': '休闲娱乐', 'icon': 'sports'},
    {'id': 'cat_social', 'name': '人情费用', 'icon': 'gift'},
    {'id': 'cat_baby', 'name': '宝宝费用', 'icon': 'child'},
    {'id': 'cat_travel', 'name': '出差旅游', 'icon': 'flight'},
    {'id': 'cat_traffic', 'name': '行车交通', 'icon': 'directions_car'},
    {'id': 'cat_shop', 'name': '购物消费', 'icon': 'shopping_cart'},
    {'id': 'cat_medical', 'name': '医疗教育', 'icon': 'medical'},
    {'id': 'cat_other', 'name': '其他杂项', 'icon': 'more'},
    {'id': 'cat_finance', 'name': '金融保险', 'icon': 'finance'},
    {'id': 'cat_inc_wage', 'name': '工资收入', 'icon': 'salary'},
    {'id': 'cat_inc_bus', 'name': '经营收入', 'icon': 'savings'},
    {'id': 'cat_inc_pt', 'name': '兼职副业', 'icon': 'laptop'},
    {'id': 'cat_inc_refund', 'name': '退款返还', 'icon': 'money'},
    {'id': 'cat_inc_other', 'name': '其他收入', 'icon': 'finance'},
  ];

  final List<String> _availableIcons = [
    'restaurant', 'home', 'phone', 'shopping_cart', 'directions_car',
    'flight', 'medical', 'school', 'sports', 'gift',
    'child', 'finance', 'salary', 'money', 'savings',
    'laptop', 'coffee', 'fitness', 'pets', 'movie',
    'music', 'cake', 'hospital', 'more',
  ];

  final List<Color> _availableColors = [
    const Color(0xFFFFB3BA),
    const Color(0xFFFFDFBA),
    const Color(0xFFFFFFBA),
    const Color(0xFFBAFFC9),
    const Color(0xFFBAE1FF),
    const Color(0xFFE0BBE4),
    const Color(0xFFFFB3E6),
    const Color(0xFFB3FFDF),
    const Color(0xFFFFE0B2),
    const Color(0xFFD4B3FF),
  ];

  IconData _getIconData(String iconName) {
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

  String _colorToHex(Color color) {
    final r = color.red;
    final g = color.green;
    final b = color.blue;
    final hex = (r << 16 | g << 8 | b).toRadixString(16).padLeft(6, '0');
    return '#$hex'.toUpperCase();
  }

  Color _hexToColor(String hex) {
    final hexCode = hex.replaceAll('#', '');
    return Color(int.parse('FF$hexCode', radix: 16));
  }

  @override
  void initState() {
    super.initState();
    if (isEditing && widget.category != null) {
      _categoryName = widget.category!.name;
      _selectedIcon = widget.category!.icon;
      _selectedColor = _hexToColor(widget.category!.color);
      _selectedParentId = widget.category!.parentId;
    }
  }

  String _getParentCategoryName(String? parentId) {
    if (parentId == null) return '未分类';
    for (var cat in _parentCategories) {
      if (cat['id'] == parentId) {
        return cat['name'];
      }
    }
    return '未分类';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: EdgeInsets.only(bottom: 16.h),
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            Text(
              isEditing ? '编辑分类' : '添加自定义分类',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20.h),
            Text('所属分类', style: TextStyle(fontSize: 14.sp, color: Colors.grey[600])),
            SizedBox(height: 8.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: DropdownButton<String>(
                value: _selectedParentId,
                hint: Text('请选择一级分类', style: TextStyle(color: Colors.grey[400])),
                isExpanded: true,
                underline: const SizedBox(),
                items: _parentCategories.map((cat) {
                  return DropdownMenuItem<String>(
                    value: cat['id'],
                    child: Row(
                      children: [
                        Icon(_getIconData(cat['icon']), size: 20, color: Colors.grey[600]),
                        SizedBox(width: 8.w),
                        Text(cat['name']),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedParentId = value;
                  });
                },
              ),
            ),
            SizedBox(height: 16.h),
            Text('分类名称', style: TextStyle(fontSize: 14.sp, color: Colors.grey[600])),
            SizedBox(height: 8.h),
            TextField(
              decoration: InputDecoration(
                hintText: '请输入分类名称',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
              ),
              onChanged: (value) {
                setState(() {
                  _categoryName = value;
                });
              },
            ),
            SizedBox(height: 16.h),
            Text('选择图标', style: TextStyle(fontSize: 14.sp, color: Colors.grey[600])),
            SizedBox(height: 8.h),
            Container(
              height: 120.h,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: GridView.builder(
                padding: EdgeInsets.all(8.w),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 12.h,
                  crossAxisSpacing: 12.w,
                ),
                itemCount: _availableIcons.length,
                itemBuilder: (context, index) {
                  final icon = _availableIcons[index];
                  final isSelected = icon == _selectedIcon;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedIcon = icon;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? _selectedColor.withValues(alpha: 0.15) : Colors.grey[50],
                        borderRadius: BorderRadius.circular(12.r),
                        border: isSelected ? Border.all(color: _selectedColor, width: 2) : Border.all(color: Colors.grey[200]!),
                      ),
                      child: Icon(
                        _getIconData(icon),
                        color: isSelected ? _selectedColor : Colors.grey[500],
                        size: 28.sp,
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 16.h),
            Text('选择颜色', style: TextStyle(fontSize: 14.sp, color: Colors.grey[600])),
            SizedBox(height: 8.h),
            Wrap(
              spacing: 16.w,
              runSpacing: 16.h,
              children: _availableColors.map((color) {
                final isSelected = color == _selectedColor;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedColor = color;
                    });
                  },
                  child: Container(
                    width: 44.w,
                    height: 44.w,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                      boxShadow: isSelected ? [
                        BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8, spreadRadius: 2),
                      ] : null,
                    ),
                    child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 24.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                onPressed: _categoryName.isNotEmpty ? _saveCategory : null,
                child: Text(isEditing ? '保存修改' : '保存', style: TextStyle(fontSize: 16.sp)),
              ),
            ),
            SizedBox(height: 16.h),
          ],
        ),
      ),
    );
  }

  Future<void> _saveCategory() async {
    if (_categoryName.isEmpty) return;

    final provider = context.read<CategoryProvider>();

    try {
      if (isEditing) {
        final updatedCategory = widget.category!.copyWith(
          name: _categoryName,
          icon: _selectedIcon,
          color: _colorToHex(_selectedColor),
        );
        await provider.updateCustomCategory(updatedCategory);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('修改成功')),
          );
        }
      } else {
        if (_selectedParentId == null) return;
        final customCategory = Category(
          id: 'custom_${_uuid.v4()}',
          name: _categoryName,
          icon: _selectedIcon,
          color: _colorToHex(_selectedColor),
          sortOrder: 0,
          parentId: _selectedParentId,
          isCustom: true,
        );
        await provider.addCustomCategory(customCategory);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('添加成功')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    }
  }
}
