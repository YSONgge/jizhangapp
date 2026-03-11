import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:expense_tracker/providers/transaction_provider.dart';
import 'package:expense_tracker/providers/category_provider.dart';
import 'package:expense_tracker/providers/account_provider.dart';
import 'package:expense_tracker/data/models/transaction.dart';
import 'package:expense_tracker/data/models/transaction_type.dart';
import 'package:expense_tracker/data/models/category.dart';
import 'package:expense_tracker/widgets/account_picker_sheet.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  TransactionType _type = TransactionType.expense;
  double _amount = 0.0;
  String _categoryId = '';
  String _accountId = '';
  String _remark = '';
  DateTime _dateTime = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2196F3),
        elevation: 0,
        title: const Text(
          '记一笔',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          _TypeSelector(
            selectedType: _type,
            onTypeChanged: (type) {
              setState(() {
                _type = type;
              });
            },
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16.w),
              child: Column(
                children: [
                  _AmountInput(
                    amount: _amount,
                    onChanged: (value) {
                      setState(() {
                        _amount = value;
                      });
                    },
                  ),
                  SizedBox(height: 16.h),
                  _FieldCard(
                    label: '分类',
                    value: _getSelectedCategoryName(),
                    icon: Icons.category,
                    onTap: () => _showCategoryPicker(),
                  ),
                  SizedBox(height: 12.h),
                  _FieldCard(
                    label: '账户',
                    value: _getSelectedAccountName(),
                    icon: Icons.account_balance_wallet,
                    onTap: () => _showAccountPicker(),
                  ),
                  SizedBox(height: 12.h),
                  _FieldCard(
                    label: '日期',
                    value: _formatDateTime(_dateTime),
                    icon: Icons.calendar_today,
                    onTap: () => _showDateTimePicker(),
                  ),
                  SizedBox(height: 12.h),
                  _RemarkInput(
                    remark: _remark,
                    onChanged: (value) {
                      setState(() {
                        _remark = value;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          _SaveButton(
            onTap: () => _saveTransaction(),
          ),
        ],
      ),
    );
  }

  String _getSelectedCategoryName() {
    final provider = context.read<CategoryProvider>();
    final category = provider.getCategoryById(_categoryId);
    return category?.name ?? '选择分类';
  }

  String _getSelectedAccountName() {
    final provider = context.read<AccountProvider>();
    final account = provider.getAccountById(_accountId);
    return account?.name ?? '选择账户';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _showCategoryPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CategoryPicker(
        type: _type,
        selectedCategoryId: _categoryId,
        onCategorySelected: (categoryId) {
          setState(() {
            _categoryId = categoryId;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showAccountPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AccountPickerSheet(
        selectedAccountId: _accountId,
        onAccountSelected: (account) {
          setState(() {
            _accountId = account.id;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showDateTimePicker() async {
    // 先选择日期
    final date = await showDatePicker(
      context: context,
      initialDate: _dateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    
    if (date == null || !mounted) return;
    
    // 再选择时间
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
    );
    
    if (time == null || !mounted) return;
    
    setState(() {
      _dateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _saveTransaction() {
    if (_amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入金额')),
      );
      return;
    }

    if (_categoryId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择分类')),
      );
      return;
    }

    if (_accountId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择账户')),
      );
      return;
    }

    final now = DateTime.now();
    final transaction = Transaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: _type,
      amount: _amount,
      categoryId: _categoryId,
      accountId: _accountId,
      date: _dateTime,
      remark: _remark,
      createdAt: now,
      updatedAt: now,
    );

    context.read<TransactionProvider>().addTransaction(transaction);
    Navigator.pop(context);
  }
}

class _TypeSelector extends StatelessWidget {
  final TransactionType selectedType;
  final Function(TransactionType) onTypeChanged;

  const _TypeSelector({
    required this.selectedType,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(vertical: 16.h),
      child: Row(
        children: [
          Expanded(
            child: _TypeButton(
              label: '支出',
              isSelected: selectedType == TransactionType.expense,
              color: Colors.red,
              onTap: () => onTypeChanged(TransactionType.expense),
            ),
          ),
          Expanded(
            child: _TypeButton(
              label: '收入',
              isSelected: selectedType == TransactionType.income,
              color: Colors.green,
              onTap: () => onTypeChanged(TransactionType.income),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _TypeButton({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 8.w),
        padding: EdgeInsets.symmetric(vertical: 12.h),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.grey[100],
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[600],
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _AmountInput extends StatelessWidget {
  final double amount;
  final Function(double) onChanged;

  const _AmountInput({
    required this.amount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '金额',
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Text(
                '¥',
                style: TextStyle(
                  fontSize: 32.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Expanded(
                child: TextField(
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(
                    fontSize: 32.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: '0.00',
                  ),
                  onChanged: (value) {
                    final amount = double.tryParse(value) ?? 0.0;
                    onChanged(amount);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FieldCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _FieldCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          children: [
            Icon(icon, size: 24.sp, color: Colors.grey[600]),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}

class _RemarkInput extends StatelessWidget {
  final String remark;
  final Function(String) onChanged;

  const _RemarkInput({
    required this.remark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: TextField(
        maxLines: 3,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: '添加备注...',
          hintStyle: TextStyle(
            color: Colors.grey[400],
            fontSize: 14.sp,
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SaveButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 16.h),
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text(
              '保存',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryPicker extends StatelessWidget {
  final TransactionType type;
  final String selectedCategoryId;
  final Function(String) onCategorySelected;

  const _CategoryPicker({
    required this.type,
    required this.selectedCategoryId,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<CategoryProvider>(
      builder: (context, provider, child) {
        final categories = provider.categories
            .where((c) => c.parentId == null)
            .toList();

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                  '选择分类',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Flexible(
                child: GridView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    childAspectRatio: 0.8,
                    mainAxisSpacing: 12.h,
                    crossAxisSpacing: 12.w,
                  ),
                  itemCount: categories.length,
                  shrinkWrap: true,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final isSelected = category.id == selectedCategoryId;
                    return _CategoryItem(
                      category: category,
                      isSelected: isSelected,
                      onTap: () => onCategorySelected(category.id),
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
}

class _CategoryItem extends StatelessWidget {
  final Category category;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryItem({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 50.w,
            height: 50.w,
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.blue
                  : Color(int.parse(category.color.replaceAll('#', '0xFF'))).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(25.r),
            ),
            child: Icon(
              _getIconData(category.icon),
              color: isSelected
                  ? Colors.white
                  : Color(int.parse(category.color.replaceAll('#', '0xFF'))),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            category.name,
            style: TextStyle(
              fontSize: 12.sp,
              color: isSelected ? Colors.blue : Colors.grey[700],
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
      default:
        return Icons.category;
    }
  }
}
