import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/voice_input_model.dart';

/// 半屏确认抽屉
///
/// PRD规范:
/// - "一条已完成账单的压缩确认态"
/// - 显示AI解析后的金额、分类、日期、账户
/// - 点击【确认保存】立即完成记账
/// - 点击任意字段展开为全屏录入页
class VoiceConfirmBottomSheet extends StatefulWidget {
  final VoiceRecognitionResult voiceResult;
  final Map<String, dynamic> parsedData;
  final VoidCallback onSave;
  final VoidCallback onEdit;

  const VoiceConfirmBottomSheet({
    super.key,
    required this.voiceResult,
    required this.parsedData,
    required this.onSave,
    required this.onEdit,
  });

  @override
  State<VoiceConfirmBottomSheet> createState() => _VoiceConfirmBottomSheetState();
}

class _VoiceConfirmBottomSheetState extends State<VoiceConfirmBottomSheet>
    with TickerProviderStateMixin {
  late AnimationController _sheetController;
  late Animation<double> _sheetAnimation;
  
  late AnimationController _contentController;
  late Animation<double> _contentOpacity;
  late Animation<double> _contentOffset;
  
  late AnimationController _buttonController;
  late Animation<double> _buttonWidth;
  late Animation<double> _deleteOpacity;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    
    // 启动动画序列
    _sheetController.forward().then((_) {
      _contentController.forward();
      _buttonController.forward();
    });
  }

  void _initAnimations() {
    // 抽屉升起动画（带橡皮筋效果）
    _sheetController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _sheetAnimation = CurvedAnimation(
      parent: _sheetController,
      curve: const ElasticOutCurve(0.8),
    );

    // 内容渐显动画
    _contentController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    
    _contentOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: Curves.easeOutExpo,
      ),
    );
    
    _contentOffset = Tween<double>(begin: 40.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: Curves.easeOutExpo,
      ),
    );

    // 按钮展开动画
    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _buttonWidth = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _buttonController,
        curve: Curves.easeOut,
      ),
    );
    
    _deleteOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _buttonController,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void dispose() {
    _sheetController.dispose();
    _contentController.dispose();
    _buttonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final sheetHeight = screenHeight * 0.6;

    return Container(
      color: Colors.black54,
      child: Stack(
        children: [
          // 背景遮罩
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                Navigator.pop(context);
              },
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),
          
          // 底部抽屉
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedBuilder(
              animation: _sheetAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, (1 - _sheetAnimation.value) * sheetHeight),
                  child: Container(
                    height: sheetHeight,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                    ),
                    child: Stack(
                      children: [
                        // 主要内容
                        Column(
                          children: [
                            SizedBox(height: 16.h),
                            
                            // 拖动指示器
                            _buildDragIndicator(),
                            
                            SizedBox(height: 24.h),
                            
                            // 核心信息区
                            _buildContentSection(),
                            
                            const Spacer(),
                            
                            // 底部操作栏
                            _buildBottomActionBar(),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDragIndicator() {
    return Center(
      child: Container(
        width: 40.w,
        height: 4.h,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildContentSection() {
    final amount = widget.parsedData['amount'] as double?;
    final category = widget.parsedData['category'] as String?;
    final account = widget.parsedData['account'] as String?;
    final owner = widget.parsedData['owner'] as String? ?? '本人';

    return AnimatedBuilder(
      animation: Listenable.merge([_contentOpacity, _contentOffset]),
      builder: (context, child) {
        return Opacity(
          opacity: _contentOpacity.value,
          child: Transform.translate(
            offset: Offset(0, _contentOffset.value),
            child: GestureDetector(
              onTap: widget.onEdit,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 32.w),
                child: Column(
                  children: [
                    // 金额显示（带Hero用于过渡动画）
                    Hero(
                      tag: 'amount_hero',
                      child: Material(
                        color: Colors.transparent,
                        child: Text(
                          amount != null ? '¥${amount.toStringAsFixed(2)}' : '¥0.00',
                          style: TextStyle(
                            fontSize: 48.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[900],
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 32.h),

                    // 分类、账户、归属人（每个字段都支持点击）
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (category != null)
                          _buildInfoItem(
                            heroTag: 'category_hero',
                            icon: Icons.restaurant,
                            label: category,
                            color: const Color(0xFFFF9500),
                          ),
                        if (category != null) SizedBox(width: 16.w),
                        if (account != null)
                          _buildInfoItem(
                            heroTag: 'account_hero',
                            icon: Icons.account_balance_wallet,
                            label: account,
                            color: const Color(0xFF4CD964),
                          ),
                        if (account != null) SizedBox(width: 16.w),
                        _buildInfoItem(
                          heroTag: 'owner_hero',
                          icon: Icons.person,
                          label: owner,
                          color: const Color(0xFF007AFF),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoItem({
    String? heroTag,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    final content = Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 20.sp,
            color: color,
          ),
          SizedBox(width: 8.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 14.sp,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );

    return GestureDetector(
      onTap: widget.onEdit,
      child: heroTag != null
          ? Hero(
              tag: heroTag,
              child: Material(
                color: Colors.transparent,
                child: content,
              ),
            )
          : content,
    );
  }

  Widget _buildBottomActionBar() {
    final screenWidth = MediaQuery.of(context).size.width;
    final micButtonSize = 64.w;

    return Container(
      height: 120.h,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 蓝色确认按钮（展开动画）
          AnimatedBuilder(
            animation: _buttonWidth,
            builder: (context, child) {
              final maxWidth = screenWidth - micButtonSize - 48.w;
              return Positioned(
                left: 16.w,
                child: SizedBox(
                  width: maxWidth * _buttonWidth.value,
                  height: 56.h,
                  child: ElevatedButton(
                    onPressed: widget.onSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007AFF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Center(
                      child: Opacity(
                        opacity: _buttonWidth.value,
                        child: Text(
                          '确认保存',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          
          // 删除/重录按钮（淡入动画）
          AnimatedBuilder(
            animation: _deleteOpacity,
            builder: (context, child) {
              return Positioned(
                right: 16.w,
                child: Opacity(
                  opacity: _deleteOpacity.value,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 48.w,
                      height: 48.w,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.delete_outline,
                        size: 24.sp,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          
          // 麦克风按钮（与首页位置重合）
          Container(
            width: micButtonSize,
            height: micButtonSize,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4A90E2), Color(0xFF50E3C2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4A90E2).withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.mic,
              color: Colors.white,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateDay = DateTime(date.year, date.month, date.day);
    final timeStr = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    
    if (dateDay == today) {
      return '今天 $timeStr';
    } else if (dateDay == today.subtract(const Duration(days: 1))) {
      return '昨天 $timeStr';
    } else {
      return '${date.month}月${date.day}日 $timeStr';
    }
  }
}
