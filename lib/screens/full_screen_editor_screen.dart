import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../models/voice_input_model.dart';
import '../providers/category_provider.dart';
import '../providers/account_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/owner_provider.dart';
import '../providers/merchant_provider.dart';
import '../data/models/transaction_type.dart';
import '../data/models/transaction.dart' as models;
import '../data/models/category.dart' as models;
import '../data/models/account.dart' as models;
import '../services/text_parser.dart';
import '../database/database_helper.dart';
import '../widgets/account_picker_sheet.dart';
import 'voice_input_screen.dart';
import 'package:uuid/uuid.dart';

/// 全屏记账编辑页面 - 重新设计
///
/// 核心特征：
/// - 醒目的智能语义输入框
/// - Material Design 3 风格
/// - 高留白、呼吸感动画
/// - "文字即刻变账单"的智能感
class FullScreenEditorScreen extends StatefulWidget {
  /// 语音识别结果(从半屏确认进入时提供)
  final VoiceRecognitionResult? voiceResult;
  /// 解析后的数据(从半屏确认进入时提供)
  final Map<String, dynamic>? parsedData;
  /// 进入方式: 'direct'(短按+) 或 'voice'(语音录入)
  final String entryMode;
  /// 从语音确认进入时的Hero标签
  final String? heroTag;
  
  /// 要编辑的交易记录
  final models.Transaction? transactionToEdit;

  const FullScreenEditorScreen({
    super.key,
    this.voiceResult,
    this.parsedData,
    this.entryMode = 'direct',
    this.heroTag,
    this.transactionToEdit,
  });

  @override
  State<FullScreenEditorScreen> createState() => _FullScreenEditorScreenState();
}

class _FullScreenEditorScreenState extends State<FullScreenEditorScreen>
    with TickerProviderStateMixin {
  // 表单数据
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _semanticInputController = TextEditingController();
  final TextEditingController _remarkController = TextEditingController();
  TransactionType _selectedType = TransactionType.expense;
  models.Category? _selectedCategory;
  models.Account? _selectedAccount;
  models.Account? _selectedTargetAccount;
  DateTime? _selectedDate;
  String _selectedOwner = '本人';
  String? _merchant;
  String? _project;

  // 文本解析器
  final TextParser _textParser = TextParser();

  // 动画控制器
  late AnimationController _amountControllerAnim;
  late Animation<double> _amountFadeIn;
  late AnimationController _semanticInputControllerAnim;
  late Animation<Offset> _semanticInputSlide;
  late Animation<double> _semanticInputFade;
  late AnimationController _propertyCardControllerAnim;
  late Animation<Offset> _propertyCardSlide;
  late AnimationController _micButtonControllerAnim;
  late Animation<double> _micButtonPulse;

  // 文本输入解析相关
  Timer? _debounceTimer;
  String? _lastParsedText;
  bool _isPaste = false;

  /// 显示提示消息（位置更靠上）
  void _showSnackBar(String message, {Color? backgroundColor, IconData? icon}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 20),
              SizedBox(width: 12.w),
            ],
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 14)),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(left: 16.w, right: 16.w, bottom: MediaQuery.of(context).size.height * 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _initFormData();
    _initAnimations();
    _startAnimations();
    _initTextParser();
  }

  /// 初始化文本解析器（加载用户数据）
  Future<void> _initTextParser() async {
    await TextParser.initialize();
    
    final accountProvider = context.read<AccountProvider>();
    final accounts = accountProvider.accounts.map((a) => {'name': a.name, 'id': a.id}).toList();
    
    // 获取商家和归属人数据
    final ownerProvider = context.read<OwnerProvider>();
    final merchantProvider = context.read<MerchantProvider>();
    final owners = ownerProvider.ownerNames;
    final merchants = merchantProvider.merchantNames;
    
    TextParser.updateUserData(
      accounts: accounts,
      owners: owners,
      merchants: merchants,
    );
  }

  /// 初始化表单数据
  void _initFormData() {
    // 编辑模式：加载交易数据
    if (widget.transactionToEdit != null) {
      final t = widget.transactionToEdit!;
      _amountController.text = t.amount.toStringAsFixed(2);
      _selectedType = t.type;
      _selectedDate = t.date;
      _selectedOwner = t.owner ?? '本人';
      _merchant = t.merchant;
      _project = t.project;
      _remarkController.text = t.remark;
      // 账户和分类需要异步加载
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadEditData(t);
      });
    } else if (widget.entryMode == 'voice' && widget.parsedData != null) {
      // 从语音确认进入，预填充数据
      final data = widget.parsedData!;
      final amount = data['amount'] as double?;
      if (amount != null) {
        _amountController.text = amount.toStringAsFixed(2);
      }
      _selectedCategory = _getCategoryByName(data['category'] as String?);
      _selectedAccount = _getAccountByName(data['account'] as String?);
      _selectedOwner = data['owner'] as String? ?? '本人';
      _merchant = data['merchant'] as String?;
      _semanticInputController.text = widget.voiceResult?.cleanedText ?? '';
      _remarkController.text = widget.voiceResult?.cleanedText ?? '';
    } else {
      // 直接进入，使用默认值
      _semanticInputController.text = '';
      _remarkController.text = '';
    }
  }
  
  Future<void> _loadEditData(models.Transaction t) async {
    final categoryProvider = context.read<CategoryProvider>();
    final accountProvider = context.read<AccountProvider>();
    
    // 查找分类
    if (t.categoryId != null) {
      final categories = categoryProvider.categories;
      for (var cat in categories) {
        if (cat.id == t.categoryId) {
          _selectedCategory = cat;
          break;
        }
      }
    }
    
    // 查找账户
    _selectedAccount = accountProvider.getAccountById(t.accountId);
    if (t.targetAccountId != null) {
      _selectedTargetAccount = accountProvider.getAccountById(t.targetAccountId!);
    }
    
    if (mounted) setState(() {});
  }

  models.Category? _getCategoryByName(String? name) {
    if (name == null || !mounted) return null;
    final categories = context.read<CategoryProvider>().getExpenseCategories();
    for (var cat in categories) {
      if (cat.name == name) return cat;
    }
    return null;
  }

  /// 查找分类（支持项目类型分类）
  models.Category? _findCategoryByName(String name) {
    if (!mounted) return null;

    // 先尝试在支出分类中查找
    final expenseCategories = context.read<CategoryProvider>().getExpenseCategories();
    for (var cat in expenseCategories) {
      if (cat.name == name) return cat;
    }

    // 尝试在收入分类中查找
    final incomeCategories = context.read<CategoryProvider>().getIncomeCategories();
    for (var cat in incomeCategories) {
      if (cat.name == name) return cat;
    }

    return null;
  }

  models.Account? _getAccountByName(String? name) {
    if (name == null || !mounted) return null;
    final accounts = context.read<AccountProvider>().accounts;
    for (var acc in accounts) {
      if (acc.name == name) return acc;
    }
    for (var acc in accounts) {
      if (name.contains(acc.name) || acc.name.contains(name)) return acc;
    }
    return null;
  }

  void _initAnimations() {
    // 金额淡入动画
    _amountControllerAnim = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _amountFadeIn = CurvedAnimation(
      parent: _amountControllerAnim,
      curve: Curves.easeOutCubic,
    );

    // 智能输入框滑动淡入动画
    _semanticInputControllerAnim = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _semanticInputSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _semanticInputControllerAnim,
      curve: Curves.easeOutCubic,
    ));
    _semanticInputFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _semanticInputControllerAnim,
        curve: Curves.easeOutCubic,
      ),
    );

    // 属性卡片滑动动画
    _propertyCardControllerAnim = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _propertyCardSlide = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _propertyCardControllerAnim,
      curve: Curves.easeOutCubic,
    ));

    // 麦克风按钮脉冲动画
    _micButtonControllerAnim = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _micButtonPulse = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _micButtonControllerAnim,
        curve: Curves.easeInOut,
      ),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _micButtonControllerAnim.reverse();
        } else if (status == AnimationStatus.dismissed) {
          _micButtonControllerAnim.forward();
        }
      });
  }

  void _startAnimations() {
    Future.delayed(const Duration(milliseconds: 100), () {
      _amountControllerAnim.forward();
    });
    Future.delayed(const Duration(milliseconds: 200), () {
      _semanticInputControllerAnim.forward();
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      _propertyCardControllerAnim.forward();
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      _micButtonControllerAnim.forward();
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _semanticInputController.dispose();
    _remarkController.dispose();
    _amountControllerAnim.dispose();
    _semanticInputControllerAnim.dispose();
    _propertyCardControllerAnim.dispose();
    _micButtonControllerAnim.dispose();
    super.dispose();
  }

  IconData _getIconData(String iconName) {
    final iconMap = {
      'payments': Icons.payments,
      'account_balance': Icons.account_balance,
      'account_balance_wallet': Icons.account_balance_wallet,
      'smartphone': Icons.smartphone,
      'credit_card': Icons.credit_card,
      'trending_up': Icons.trending_up,
      'savings': Icons.savings,
      'wallet': Icons.wallet,
      'attach_money': Icons.attach_money,
      'money': Icons.money,
    };
    return iconMap[iconName] ?? Icons.account_balance_wallet;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 类型切换按钮 - 居中显示
                    Center(child: _buildTypeToggleButton()),
                    
                    SizedBox(height: 24.h),
                    
                    // 金额显示区域
                    _buildAmountSection(),
                    
                    SizedBox(height: 32.h),
                    
                    // 智能语义输入框 - 核心特性
                    _buildSemanticInputSection(),
                    
                    SizedBox(height: 32.h),
                    
                    // 属性选择卡片
                    _buildPropertyCards(),
                    
                    SizedBox(height: 32.h),
                    
                    // 备注区域
                    _buildRemarkSection(),
                    
                    SizedBox(height: 120.h), // 为底部键盘和按钮留出空间
                  ],
                ),
              ),
            ),
            
            // 底部操作区域
            _buildBottomActionArea(),
          ],
        ),
      ),
    );
  }

  /// 构建AppBar
  PreferredSizeWidget _buildAppBar() {
    final isEdit = widget.transactionToEdit != null;
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Container(
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.close_rounded,
            color: Colors.grey[600],
            size: 20.sp,
          ),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        isEdit ? '编辑记录' : '记一笔',
        style: TextStyle(
          fontSize: 18.sp,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF1A1A1A),
        ),
      ),
      actions: [
        if (isEdit)
          IconButton(
            onPressed: () => _confirmDelete(context),
            icon: Icon(
              Icons.delete_outline,
              color: Colors.grey[600],
              size: 22.sp,
            ),
          ),
        SizedBox(width: 8.w),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这条记录吗？删除后不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final t = widget.transactionToEdit!;
        
        // 删除交易记录（deleteTransaction会自动处理余额回滚）
        await DatabaseHelper.instance.deleteTransaction(t.id);
        
        // 刷新数据
        await context.read<TransactionProvider>().loadTransactions();
        await context.read<AccountProvider>().loadAccounts();

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('删除成功'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('删除失败: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// 构建类型切换按钮 - 带滑动动画
  Widget _buildTypeToggleButton() {
    return Container(
      height: 44.h,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(22.r),
      ),
      padding: EdgeInsets.all(4.w),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = (constraints.maxWidth - 8.w) / 3;
          return Stack(
            children: [
              // 滑动背景
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                left: 4.w + (_getTypeIndex(_selectedType) * (tabWidth + 2.w)),
                top: 4.h,
                child: Container(
                  width: tabWidth,
                  height: 36.h,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18.r),
                    boxShadow: [
                      BoxShadow(
                        color: _getTypeColor(_selectedType).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              // 三个选项
              Row(
                children: [
                  _buildTypeTab('支出', TransactionType.expense, tabWidth),
                  _buildTypeTab('收入', TransactionType.income, tabWidth),
                  _buildTypeTab('转账', TransactionType.transfer, tabWidth),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  int _getTypeIndex(TransactionType type) {
    switch (type) {
      case TransactionType.expense:
        return 0;
      case TransactionType.income:
        return 1;
      case TransactionType.transfer:
        return 2;
      case TransactionType.adjust:
        return 0;
    }
  }

  Color _getTypeColor(TransactionType type) {
    switch (type) {
      case TransactionType.expense:
        return const Color(0xFFEF5350);
      case TransactionType.income:
        return const Color(0xFF66BB6A);
      case TransactionType.transfer:
        return const Color(0xFF42A5F5);
      case TransactionType.adjust:
        return const Color(0xFFEF5350);
    }
  }

  Widget _buildTypeTab(String label, TransactionType type, double width) {
    final isSelected = _selectedType == type;
    final color = _getTypeColor(type);
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedType = type;
            _selectedCategory = null;
          });
        },
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Container(
            key: ValueKey(type),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _getTypeIcon(type),
                  size: 16.sp,
                  color: isSelected ? color : Colors.grey[500],
                ),
                SizedBox(width: 4.w),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? color : Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getTypeIcon(TransactionType type) {
    switch (type) {
      case TransactionType.expense:
        return Icons.arrow_upward_rounded;
      case TransactionType.income:
        return Icons.arrow_downward_rounded;
      case TransactionType.transfer:
        return Icons.swap_horiz_rounded;
      case TransactionType.adjust:
        return Icons.arrow_upward_rounded;
    }
  }

  /// 构建金额显示区域
  Widget _buildAmountSection() {
    return FadeTransition(
      opacity: _amountFadeIn,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '金额',
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 12.h),
          // 使用 Hero 包裹金额区域，实现从半屏到全屏的平滑过渡
          Hero(
            tag: widget.heroTag ?? 'amount_hero',
            child: Material(
              color: Colors.transparent,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '¥',
                    style: TextStyle(
                      fontSize: 36.sp,
                      fontWeight: FontWeight.w300,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontSize: 56.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1A1A),
                        height: 1.0,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: '0.00',
                        hintStyle: TextStyle(
                          fontSize: 56.sp,
                          fontWeight: FontWeight.w300,
                          color: Colors.grey[300],
                          height: 1.0,
                        ),
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建智能语义输入框 - 核心特性
  Widget _buildSemanticInputSection() {
    return SlideTransition(
      position: _semanticInputSlide,
      child: FadeTransition(
        opacity: _semanticInputFade,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行
            Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 18.sp,
                  color: const Color(0xFF6C63FF),
                ),
                SizedBox(width: 6.w),
                Text(
                  '智能语义输入',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6C63FF),
                  ),
                ),
                const Spacer(),
                Text(
                  '✨ 智能识别',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: const Color(0xFF6C63FF),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            
            // 智能输入框
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F7),
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _semanticInputController,
                maxLines: 3,
                minLines: 2,
                keyboardType: TextInputType.text,
                textAlignVertical: TextAlignVertical.top,
                style: TextStyle(
                  fontSize: 15.sp,
                  color: const Color(0xFF1A1A1A),
                  height: 1.5,
                ),
                decoration: InputDecoration(
                  hintText: '输入或粘贴：如"给媳妇充话费300元走微信"',
                  hintStyle: TextStyle(
                    fontSize: 15.sp,
                    color: Colors.grey[400],
                    height: 1.5,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 20.w,
                    vertical: 16.h,
                  ),
                  filled: true,
                  fillColor: Colors.transparent,
                  suffixIcon: Padding(
                    padding: EdgeInsets.only(right: 12.w, bottom: 8.h),
                    child: IconButton(
                      icon: Icon(
                        Icons.paste_rounded,
                        color: const Color(0xFF6C63FF),
                        size: 22.sp,
                      ),
                      onPressed: _pasteAndParse,
                      tooltip: '粘贴并智能识别',
                    ),
                  ),
                ),
                onChanged: (value) {
                  _onTextChanged(value);
                },
              ),
            ),
            
            SizedBox(height: 8.h),
            
            // 提示文字
            Text(
              '支持智能识别金额、分类、账户等信息',
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 文本输入变化处理（区分粘贴和打字）
  void _onTextChanged(String text) {
    // 粘贴：立即解析
    if (_isPaste) {
      _isPaste = false;
      _parseAndFillForm(text);
      return;
    }

    // 打字：防抖延迟解析
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      if (text.isNotEmpty && text != _lastParsedText) {
        _lastParsedText = text;
        _parseAndFillForm(text);
      }
    });
  }

  /// 粘贴并智能识别
  Future<void> _pasteAndParse() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData?.text != null && clipboardData!.text!.isNotEmpty) {
      // 标记为粘贴操作
      _isPaste = true;
      _debounceTimer?.cancel();
      
      setState(() {
        _semanticInputController.text = clipboardData.text!;
      });
      
      // 解析文本并填充表单
      _parseAndFillForm(clipboardData.text!);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12.w),
                const Text('已粘贴，智能识别完成'),
              ],
            ),
            backgroundColor: const Color(0xFF6C63FF),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
  
  /// 解析文本并填充表单
  Future<void> _parseAndFillForm(String text) async {
    if (text.isEmpty) return;

    await TextParser.initialize();
    final accountProvider = context.read<AccountProvider>();
    final accounts = accountProvider.accounts.map((a) => {'name': a.name, 'id': a.id}).toList();
    final ownerProvider = context.read<OwnerProvider>();
    final merchantProvider = context.read<MerchantProvider>();
    final owners = ownerProvider.ownerNames;
    final merchants = merchantProvider.merchantNames;
    TextParser.updateUserData(
      accounts: accounts,
      owners: owners,
      merchants: merchants,
    );
    
    final parseResult = _textParser.parse(text);

    if (parseResult.multipleResults != null && parseResult.multipleResults!.isNotEmpty) {
      _showMultipleRecordsDialog(parseResult.multipleResults!);
      return;
    }

    if (parseResult.merchant != null) {
      final merchantProvider = context.read<MerchantProvider>();
      final merchantNames = merchantProvider.merchantNames;
      
      if (!merchantNames.contains(parseResult.merchant)) {
        await merchantProvider.addMerchant(parseResult.merchant!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已自动保存商家: ${parseResult.merchant}')),
          );
        }
      }
    }

    setState(() {
      // 更新交易类型
      _selectedType = parseResult.type;

      // 更新金额
      if (parseResult.amount != null) {
        _amountController.text = parseResult.amount!.toStringAsFixed(2);
      }

      // 更新日期
      if (parseResult.date != null) {
        _selectedDate = parseResult.date!;
      }

      // 发红包特殊处理：直接设置为支出类型，归类到人情往来
      if (text.contains('发红包') || text.contains('给红包')) {
        _selectedType = TransactionType.expense;
        _selectedOwner = '本人';
        // 寻找人情往来分类
        final socialCategory = _findCategoryByName('人情往来');
        if (socialCategory != null) {
          _selectedCategory = socialCategory;
        }
        // 更新备注
        _remarkController.text = text;
      } else {
        // 收入特殊处理：如果文本包含明确的收入关键词，确保类型为收入
        final incomeKeywords = [
          '工资到账', '发工资', '收', '收到', '到账',
          '工资', '奖金', '红包', '分红', '利息', '收益',
          '退款', '报销', '兼职', '投资', '货款', '租金',
          '房租', '服务费', '定金', '押金', '小费', '稿费',
          '还款', '会员费', '分红', '礼金', '卖废品',
          '卖二手', '卖闲置', '卖旧', '差价', '返现',
        ];

        final hasIncomeKeyword = incomeKeywords.any((keyword) => text.contains(keyword));

        if (parseResult.category != null) {
          _selectedCategory = _findCategoryByName(parseResult.category!);
        }
      }

      // 更新账户并检查是否存在
      if (parseResult.account != null) {
        final account = _getAccountByName(parseResult.account);
        if (account != null) {
          _selectedAccount = account;
        } else {
          // 账户不存在，提示用户
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.white),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          '未找到账户"${parseResult.account}"，请手动选择',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: const Color(0xFFFF9500),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          });
        }
      }

      // 更新目标账户（转账时）
      if (parseResult.targetAccount != null) {
        final targetAccount = _getAccountByName(parseResult.targetAccount);
        if (targetAccount != null) {
          _selectedTargetAccount = targetAccount;
        } else {
          // 目标账户不存在，提示用户
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.white),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          '未找到目标账户"${parseResult.targetAccount}"，请手动选择',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: const Color(0xFFFF9500),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          });
        }
      }

      // 更新归属人（非红包情况）
      if (!text.contains('发红包') && !text.contains('给红包')) {
        if (parseResult.owner != null) {
          _selectedOwner = parseResult.owner!;
        }
      }

      // 更新商家
      if (parseResult.merchant != null) {
        _merchant = parseResult.merchant;
      }

      // 更新项目
      if (parseResult.project != null) {
        _project = parseResult.project;
      }

      // 更新备注
      _remarkController.text = text;
    });
  }

  /// 显示多笔记录对话框
  void _showMultipleRecordsDialog(List<ParseResult> results) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('检测到${results.length}笔记录'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: results.asMap().entries.map((entry) {
            int index = entry.key;
            ParseResult result = entry.value;
            return ListTile(
              leading: CircleAvatar(
                child: Text('${index + 1}'),
              ),
              title: Text('¥${result.amount?.toStringAsFixed(2) ?? "0.00"}'),
              subtitle: Text(
                '${result.category ?? "未分类"} · ${_formatDate(result.date ?? DateTime.now())}',
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _saveMultipleTransactions(results);
            },
            child: const Text('全部添加'),
          ),
        ],
      ),
    );
  }

  /// 保存多笔交易
  void _saveMultipleTransactions(List<ParseResult> results) async {
    final transactionProvider = Provider.of<TransactionProvider>(context, listen: false);
    final accountProvider = Provider.of<AccountProvider>(context, listen: false);
    final now = DateTime.now();

    for (var result in results) {
      final categoryId = _getCategoryIdByName(result.category);
      final accountId = _getAccountIdByName(result.account);

      if (accountId == null) {
        continue; // 跳过没有账户的记录
      }

      final transaction = models.Transaction(
        id: const Uuid().v4(),
        type: result.type,
        amount: result.amount ?? 0.0,
        categoryId: categoryId,
        accountId: accountId,
        date: result.date ?? DateTime.now(),
        remark: result.remark,
        owner: result.owner ?? '本人',
        merchant: result.merchant,
        project: result.project,
        createdAt: now,
        updatedAt: now,
      );

      await transactionProvider.addTransaction(transaction);
    }

    await accountProvider.loadAccounts();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('成功添加${results.length}笔记录'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }

  /// 根据分类名称获取分类ID
  String? _getCategoryIdByName(String? categoryName) {
    if (categoryName == null) return null;
    final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
    final categories = categoryProvider.categories;
    for (var category in categories) {
      if (category.name == categoryName) {
        return category.id;
      }
    }
    return null;
  }

  /// 根据账户名称获取账户ID
  String? _getAccountIdByName(String? accountName) {
    if (accountName == null) return null;
    final accountProvider = Provider.of<AccountProvider>(context, listen: false);
    final accounts = accountProvider.accounts;
    for (var account in accounts) {
      if (account.name == accountName) {
        return account.id;
      }
    }
    for (var account in accounts) {
      if (accountName.contains(account.name) || account.name.contains(accountName)) {
        return account.id;
      }
    }
    return null;
  }

  /// 构建属性选择卡片
  Widget _buildPropertyCards() {
    return SlideTransition(
      position: _propertyCardSlide,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _selectedType == TransactionType.transfer
            ? _buildTransferPropertyCards()
            : _buildNormalPropertyCards(),
      ),
    );
  }

  /// 构建普通属性卡片（支出/收入）
  List<Widget> _buildNormalPropertyCards() {
    return [
      // 分类和账户
      Row(
        children: [
          Expanded(child: _buildPropertyCard(
            heroTag: 'category_hero',
            icon: Icons.category_rounded,
            label: '分类',
            value: _selectedCategory?.name ?? '未选择',
            onTap: _showCategorySelector,
            color: const Color(0xFFFF9500),
          )),
          SizedBox(width: 12.w),
          Expanded(child: _buildPropertyCard(
            heroTag: 'account_hero',
            icon: Icons.account_balance_wallet_rounded,
            label: '账户',
            value: _selectedAccount?.name ?? '未选择',
            onTap: _showAccountSelector,
            color: const Color(0xFF4A90E2),
          )),
        ],
      ),
      SizedBox(height: 12.h),
      // 日期和归属人
      Row(
        children: [
          Expanded(child: _buildPropertyCard(
            icon: Icons.calendar_today_rounded,
            label: '日期',
            value: _formatDate(_selectedDate),
            onTap: _selectDate,
            color: const Color(0xFF34C759),
          )),
          SizedBox(width: 8.w),
          GestureDetector(
            onTap: () {
              setState(() {
                _selectedDate = DateTime.now();
              });
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: const Color(0xFF34C759).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(
                  color: const Color(0xFF34C759).withOpacity(0.3),
                ),
              ),
              child: Text(
                '现在',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: const Color(0xFF34C759),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(child: _buildPropertyCard(
            heroTag: 'owner_hero',
            icon: Icons.person_rounded,
            label: '归属人',
            value: _selectedOwner,
            onTap: _showOwnerSelector,
            color: const Color(0xFF5856D6),
          )),
        ],
      ),
      SizedBox(height: 12.h),
      // 商家（单独一行，避免拥挤）
      _buildPropertyCard(
        heroTag: 'merchant_hero',
        icon: Icons.store_rounded,
        label: '商家',
        value: _merchant ?? '未选择',
        onTap: _showMerchantSelector,
        color: const Color(0xFFFF9500),
      ),
    ];
  }

  /// 构建转账属性卡片
  List<Widget> _buildTransferPropertyCards() {
    return [
      // 从账户和到账户
      Row(
        children: [
          Expanded(child: _buildPropertyCard(
            icon: Icons.arrow_circle_up_rounded,
            label: '从账户',
            value: _selectedAccount?.name ?? '未选择',
            onTap: _showAccountSelector,
            color: const Color(0xFFFF3B30),
          )),
          SizedBox(width: 12.w),
          Expanded(child: _buildPropertyCard(
            icon: Icons.arrow_circle_down_rounded,
            label: '到账户',
            value: _selectedTargetAccount?.name ?? '未选择',
            onTap: _showTargetAccountSelector,
            color: const Color(0xFF34C759),
          )),
        ],
      ),
      SizedBox(height: 12.h),
      // 日期
      Row(
        children: [
          Expanded(child: _buildPropertyCard(
            icon: Icons.calendar_today_rounded,
            label: '日期',
            value: _formatDate(_selectedDate),
            onTap: _selectDate,
            color: const Color(0xFF5856D6),
          )),
          SizedBox(width: 8.w),
          GestureDetector(
            onTap: () {
              setState(() {
                _selectedDate = DateTime.now();
              });
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: const Color(0xFF5856D6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(
                  color: const Color(0xFF5856D6).withOpacity(0.3),
                ),
              ),
              child: Text(
                '现在',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: const Color(0xFF5856D6),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(child: _buildPropertyCard(
            icon: Icons.person_rounded,
            label: '归属人',
            value: '本人',
            onTap: () {},
            color: const Color(0xFF5856D6),
            enabled: false,
          )),
        ],
      ),
    ];
  }

  /// 构建单个属性卡片
  Widget _buildPropertyCard({
    String? heroTag,
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
    required Color color,
    bool enabled = true,
  }) {
    final content = GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.5,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: color.withValues(alpha: 0.15),
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    size: 16.sp,
                    color: color,
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 16.sp,
                        color: const Color(0xFF1A1A1A),
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20.sp,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return heroTag != null
        ? Hero(
            tag: heroTag,
            child: Material(
              color: Colors.transparent,
              child: content,
            ),
          )
        : content;
  }

  /// 构建备注区域
  Widget _buildRemarkSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.edit_note_rounded,
              size: 18.sp,
              color: Colors.grey[500],
            ),
            SizedBox(width: 6.w),
            Text(
              '备注',
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: Colors.grey[200]!,
            ),
          ),
          child: TextField(
            controller: _remarkController,
            maxLines: 3,
            minLines: 2,
            keyboardType: TextInputType.text,
            textAlignVertical: TextAlignVertical.top,
            style: TextStyle(
              fontSize: 15.sp,
              color: const Color(0xFF1A1A1A),
              height: 1.5,
            ),
            decoration: InputDecoration(
              hintText: '添加备注信息...',
              hintStyle: TextStyle(
                fontSize: 15.sp,
                color: Colors.grey[300],
                height: 1.5,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16.w,
                vertical: 12.h,
              ),
              filled: true,
              fillColor: Colors.transparent,
            ),
          ),
        ),
      ],
    );
  }

  /// 构建底部操作区域
  Widget _buildBottomActionArea() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 16.h),
          child: Row(
            children: [
              // 保存按钮
              Expanded(
                child: SizedBox(
                  height: 56.h,
                  child: ElevatedButton(
                    onPressed: _saveTransaction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shadowColor: const Color(0xFF6C63FF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                    ),
                    child: Text(
                      '保存账单',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 16.w),
            ],
          ),
        ),
      ),
    );
  }

  /// 显示分类选择器（支持分级显示）
  void _showCategorySelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _CategorySelector(
        selectedType: _selectedType,
        selectedCategory: _selectedCategory,
        onCategorySelected: (category) {
          setState(() {
            _selectedCategory = category;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  /// 显示账户选择器
  void _showAccountSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => AccountPickerSheet(
        selectedAccountId: _selectedAccount?.id,
        title: '选择账户',
        onAccountSelected: (account) {
          setState(() {
            _selectedAccount = account;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  /// 显示目标账户选择器（用于转账）
  void _showTargetAccountSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => AccountPickerSheet(
        selectedAccountId: _selectedTargetAccount?.id,
        title: '选择目标账户',
        onAccountSelected: (account) {
          if (_selectedAccount?.id != account.id) {
            setState(() {
              _selectedTargetAccount = account;
            });
          }
          Navigator.pop(context);
        },
      ),
    );
  }

  /// 显示归属人选择器
  void _showOwnerSelector() {
    final ownerProvider = context.read<OwnerProvider>();
    final owners = ownerProvider.ownerNames;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.4,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(20.w),
              child: Text(
                '选择归属人',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.all(16.w),
                itemCount: owners.length,
                itemBuilder: (context, index) {
                  final owner = owners[index];
                  return ListTile(
                    title: Text(
                      owner,
                      style: TextStyle(fontSize: 16.sp),
                    ),
                    trailing: _selectedOwner == owner
                        ? const Icon(Icons.check_rounded, color: Color(0xFF4A90E2))
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedOwner = owner;
                      });
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示商家选择器
  void _showMerchantSelector() {
    final merchantProvider = context.read<MerchantProvider>();
    final merchants = merchantProvider.merchantNames;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.5,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(20.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '选择商家',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    children: [
                      if (_merchant != null && _merchant!.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _merchant = null;
                            });
                            Navigator.pop(context);
                          },
                          child: const Text('清除'),
                        ),
                      IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _showAddMerchantDialog();
                        },
                        icon: Icon(Icons.add_circle_rounded, color: Color(0xFF34C759), size: 28.w),
                        tooltip: '添加新商家',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: merchants.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '暂无商家',
                            style: TextStyle(color: Colors.grey[400], fontSize: 16.sp),
                          ),
                          SizedBox(height: 16.h),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _showAddMerchantDialog();
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('添加商家'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF34C759),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.all(16.w),
                      itemCount: merchants.length,
                      itemBuilder: (context, index) {
                        final merchant = merchants[index];
                        return ListTile(
                          title: Text(
                            merchant,
                            style: TextStyle(fontSize: 16.sp),
                          ),
                          trailing: _merchant == merchant
                              ? const Icon(Icons.check_rounded, color: Color(0xFF4A90E2))
                              : null,
                          onTap: () {
                            setState(() {
                              _merchant = merchant;
                            });
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示添加商家对话框
  void _showAddMerchantDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加商家'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '请输入商家名称',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                final merchantProvider = context.read<MerchantProvider>();
                await merchantProvider.addMerchant(name);
                if (mounted) {
                  setState(() {
                    _merchant = name;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已添加商家: $name')),
                  );
                }
              }
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF34C759),
              foregroundColor: Colors.white,
            ),
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  /// 选择日期和时间
  void _selectDate() async {
    final initialDate = _selectedDate ?? DateTime.now();
    
    // 先选择日期
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );

    if (date == null || !mounted) return;

    // 再选择时间
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );

    if (time == null || !mounted) return;

    setState(() {
      _selectedDate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  /// 格式化日期和时间
  String _formatDate(DateTime? date) {
    if (date == null) {
      return '待识别';
    }
    final now = DateTime.now();
    final timeStr = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return '今天 $timeStr';
    } else if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1) {
      return '昨天 $timeStr';
    } else {
      return '${date.month}月${date.day}日 $timeStr';
    }
  }

  /// 保存交易
  Future<void> _saveTransaction() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效金额')),
      );
      return;
    }

    // 转账验证
    if (_selectedType == TransactionType.transfer) {
      if (_selectedAccount == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请选择转出账户')),
        );
        return;
      }
      if (_selectedTargetAccount == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请选择目标账户')),
        );
        return;
      }
      if (_selectedAccount?.id == _selectedTargetAccount?.id) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('转出账户和目标账户不能相同')),
        );
        return;
      }
    } else {
      // 支出/收入验证
      if (_selectedCategory == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请选择分类')),
        );
        return;
      }
      if (_selectedAccount == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请选择账户')),
        );
        return;
      }
    }

    // 判断是编辑还是新增
    final isEdit = widget.transactionToEdit != null;
    
    // 如果没有选择日期，使用当前时间
    final finalDate = _selectedDate ?? DateTime.now();
    
    // 创建交易记录
    final transaction = models.Transaction(
      id: isEdit ? widget.transactionToEdit!.id : const Uuid().v4(),
      type: _selectedType,
      amount: amount,
      categoryId: _selectedCategory?.id ?? 'category_transfer',
      accountId: _selectedAccount!.id,
      targetAccountId: _selectedTargetAccount?.id,
      merchant: _merchant,
      owner: _selectedOwner,
      project: _project,
      remark: _remarkController.text,
      date: finalDate,
      createdAt: isEdit ? widget.transactionToEdit!.createdAt : DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      if (isEdit) {
        await DatabaseHelper.instance.updateTransaction(transaction);
      } else {
        await context.read<TransactionProvider>().addTransaction(transaction);
      }
      await context.read<AccountProvider>().loadAccounts();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEdit ? '修改成功' : '保存成功'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// 分类选择器（支持分级显示）
class _CategorySelector extends StatefulWidget {
  final TransactionType selectedType;
  final models.Category? selectedCategory;
  final Function(models.Category) onCategorySelected;

  const _CategorySelector({
    required this.selectedType,
    this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  State<_CategorySelector> createState() => _CategorySelectorState();
}

class _CategorySelectorState extends State<_CategorySelector> {
  String? _selectedParentId;

  @override
  Widget build(BuildContext context) {
    final categoryProvider = context.read<CategoryProvider>();

    // 获取父分类列表
    final parentCategories = widget.selectedType == TransactionType.expense
        ? categoryProvider.getExpenseParentCategories()
        : categoryProvider.getIncomeParentCategories();

    // 如果选择了父分类，获取其子分类
    final childCategories = _selectedParentId != null
        ? categoryProvider.getChildCategories(_selectedParentId!)
        : <models.Category>[];

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(20.w),
            child: Row(
              children: [
                if (_selectedParentId != null)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedParentId = null;
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.arrow_back_ios_new, size: 16.sp, color: Colors.grey[600]),
                          SizedBox(width: 4.w),
                          Text(
                            '返回',
                            style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ),
                const Spacer(),
                Text(
                  _selectedParentId != null ? '选择子分类' : '选择分类',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
          Expanded(
            child: _selectedParentId != null
                ? _buildChildCategoryGrid(childCategories)
                : _buildParentCategoryGrid(parentCategories, categoryProvider),
          ),
        ],
      ),
    );
  }

  /// 父分类网格
  Widget _buildParentCategoryGrid(
    List<models.Category> parentCategories,
    CategoryProvider categoryProvider,
  ) {
    return GridView.builder(
      padding: EdgeInsets.all(16.w),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 1.0,
        crossAxisSpacing: 12.w,
        mainAxisSpacing: 12.h,
      ),
      itemCount: parentCategories.length,
      itemBuilder: (context, index) {
        final category = parentCategories[index];
        final childCategories = categoryProvider.getChildCategories(category.id);
        final hasChildren = childCategories.isNotEmpty;
        final isSelected = widget.selectedCategory?.parentId == category.id ||
            widget.selectedCategory?.id == category.id;

        return GestureDetector(
          onTap: hasChildren
              ? () {
                  setState(() {
                    _selectedParentId = category.id;
                  });
                }
              : () {
                  widget.onCategorySelected(category);
                },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFFF9500).withValues(alpha: 0.1)
                  : Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? const Color(0xFFFF9500) : Colors.grey[200]!,
              ),
            ),
            child: Stack(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.category_rounded,
                      size: 24.sp,
                      color: isSelected ? const Color(0xFFFF9500) : Colors.grey[600],
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      category.name,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: isSelected ? const Color(0xFFFF9500) : Colors.grey[800],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                if (hasChildren)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      width: 16.w,
                      height: 16.w,
                      decoration: const BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.chevron_right,
                        size: 12.sp,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 子分类网格
  Widget _buildChildCategoryGrid(List<models.Category> childCategories) {
    if (childCategories.isEmpty) {
      return Center(
        child: Column(
          children: [
            Icon(Icons.inbox, size: 60.w, color: Colors.grey[300]),
            SizedBox(height: 16.h),
            Text(
              '暂无子分类',
              style: TextStyle(fontSize: 14.sp, color: Colors.grey[400]),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.all(16.w),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 1.0,
        crossAxisSpacing: 12.w,
        mainAxisSpacing: 12.h,
      ),
      itemCount: childCategories.length,
      itemBuilder: (context, index) {
        final category = childCategories[index];
        final isSelected = widget.selectedCategory?.id == category.id;

        return GestureDetector(
          onTap: () {
            widget.onCategorySelected(category);
          },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFFF9500).withValues(alpha: 0.1)
                  : Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? const Color(0xFFFF9500) : Colors.grey[200]!,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.category_rounded,
                  size: 24.sp,
                  color: isSelected ? const Color(0xFFFF9500) : Colors.grey[600],
                ),
                SizedBox(height: 8.h),
                Text(
                  category.name,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: isSelected ? const Color(0xFFFF9500) : Colors.grey[800],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
