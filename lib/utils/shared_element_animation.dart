import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../utils/animation_curves.dart';

/// 元素共享动画
/// 
/// 用于实现从半屏到全屏的元素位移动画
class SharedElementAnimation {
  /// 金额数字的共享动画
  /// 
  /// [fromPosition] 起始位置（在半屏抽屉中）
  /// [toPosition] 目标位置（在全屏页面中）
  /// [animation] 动画控制器
  /// [child] 要动画的子元素
  static Widget amountTransition({
    required Offset fromPosition,
    required Offset toPosition,
    required Animation<double> animation,
    required Widget child,
  }) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final currentPos = ArcMotion.calculate(
          fromPosition,
          toPosition,
          animation.value,
          curvature: 0.15,
        );
        
        // 金额从大变小（48sp -> 32sp）
        final fontSize = 48.sp - (16.sp * animation.value);
        // 透明度从0.8到1.0
        final opacity = 0.8 + (0.2 * animation.value);
        
        return Transform.translate(
          offset: Offset(
            currentPos.dx - fromPosition.dx,
            currentPos.dy - fromPosition.dy,
          ),
          child: Opacity(
            opacity: opacity,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 48.sp, end: 32.sp),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return DefaultTextStyle(
                  style: TextStyle(fontSize: value),
                  child: child!,
                );
              },
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }

  /// 分类图标的共享动画
  /// 
  /// 使用曲线路径移动
  static Widget categoryTransition({
    required Offset fromPosition,
    required Offset toPosition,
    required Animation<double> animation,
    required Widget child,
  }) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final currentPos = ArcMotion.calculate(
          fromPosition,
          toPosition,
          animation.value,
          curvature: 0.3,
        );
        
        return Transform.translate(
          offset: Offset(
            currentPos.dx - fromPosition.dx,
            currentPos.dy - fromPosition.dy,
          ),
          child: Opacity(
            opacity: animation.value,
            child: Transform.scale(
              scale: 1.0 - (0.1 * animation.value),
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }

  /// 麦克风按钮的收缩动画
  /// 
  /// 从底部中央移动到备注栏右侧
  static Widget microphoneTransition({
    required Offset fromPosition,
    required Offset toPosition,
    required Animation<double> animation,
    required Widget child,
  }) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final currentPos = ArcMotion.calculate(
          fromPosition,
          toPosition,
          animation.value,
          curvature: -0.2, // 反向曲线
        );
        
        // 从64缩小到40
        final size = 64.w - (24.w * animation.value);
        final opacity = 1.0 - (0.3 * animation.value);
        
        return Transform.translate(
          offset: Offset(
            currentPos.dx - fromPosition.dx,
            currentPos.dy - fromPosition.dy,
          ),
          child: SizedBox(
            width: size,
            height: size,
            child: Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: animation.value * 0.6 + 0.4,
                child: child,
              ),
            ),
          ),
        );
      },
      child: child,
    );
  }
}

/// 膨胀动画控制器
/// 
/// 管理从半屏到全屏的完整动画流程
class ExpansionAnimationController with ChangeNotifier {
  AnimationController? _controller;
  Animation<double>? _animation;
  VoidCallback? _onComplete;

  bool get isExpanded => _controller?.status == AnimationStatus.completed;

  /// 开始膨胀动画
  void startExpansion({
    required TickerProvider vsync,
    required VoidCallback onComplete,
  }) {
    _onComplete = onComplete;
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 450),
      vsync: vsync,
    );
    
    _animation = CurvedAnimation(
      parent: _controller!,
      curve: const FastOutSlowInCurve(),
    );
    
    _controller!.addListener(_onAnimationUpdate);
    _controller!.forward();
  }

  void _onAnimationUpdate() {
    if (_controller!.status == AnimationStatus.completed) {
      _onComplete?.call();
      notifyListeners();
    }
  }

  /// 反向动画（收缩）
  void reverseExpansion() {
    _controller?.reverse();
  }

  /// 获取当前动画值
  double get value => _animation?.value ?? 0.0;

  /// 释放资源
  @override
  void dispose() {
    _controller?.removeListener(_onAnimationUpdate);
    _controller?.dispose();
    _animation = null;
  }
}

/// 键盘同步动画
/// 
/// 确保键盘在抽屉膨胀到底部时同步弹起
class KeyboardSyncAnimation {
  /// 键盘弹起延迟
  /// 
  /// 在抽屉膨胀到约90%时触发键盘
  static Duration get keyboardDelay => const Duration(milliseconds: 400);

  /// 获取键盘弹起的动画进度
  /// 
  /// [expansionProgress] 抽屉膨胀进度 0-1
  static double getKeyboardProgress(double expansionProgress) {
    // 当膨胀进度超过0.8时，键盘开始弹起
    if (expansionProgress < 0.8) return 0.0;
    
    // 从0.8到1.0，键盘进度从0到1
    return (expansionProgress - 0.8) / 0.2;
  }

  /// 判断是否应该显示键盘
  /// 
  /// [expansionProgress] 抽屉膨胀进度
  static bool shouldShowKeyboard(double expansionProgress) {
    return getKeyboardProgress(expansionProgress) > 0.1;
  }
}
