import 'dart:math' as math;
import 'package:flutter/animation.dart';

/// 橡皮筋动画曲线
///
/// 实现超出目标位置后轻微反弹的效果，增加界面的质量感
class ElasticOutCurve extends Curve {
  final double period;
  final double amplitude;

  const ElasticOutCurve([this.period = 0.4, this.amplitude = 0.1]);

  @override
  double transform(double t) {
    if (t == 0.0 || t == 1.0) {
      return t;
    }

    // 简化的弹性效果
    final p = period;
    final a = amplitude;
    
    return 1 + math.pow(math.e, -10 * t / p) * a * math.sin(t * 2.5 * math.pi);
  }
}

/// 舒缓指数曲线
///
/// 类似easeOutExpo的曲线，用于元素的快速进入
class FastOutSlowInCurve extends Curve {
  const FastOutSlowInCurve();

  @override
  double transform(double t) {
    if (t == 0.0 || t == 1.0) {
      return t;
    }

    return t < 0.5
        ? 16 * t * t * t * t * t
        : 1 - math.pow(-2 * t + 2, 5) / 2;
  }
}

/// 曲线路径动画（Arc Motion）
/// 
/// 用于元素沿曲线路径移动，而不是直线
class ArcMotion {
  /// 计算曲线上的点
  /// 
  /// [start] 起点
  /// [end] 终点
  /// [t] 动画进度 0-1
  /// [curvature] 曲线程度，0为直线，越大曲线越明显
  static Offset calculate(Offset start, Offset end, double t, {double curvature = 0.2}) {
    // 使用二次贝塞尔曲线
    final controlPoint = Offset(
      (start.dx + end.dx) / 2,
      (start.dy + end.dy) / 2 - curvature * (end - start).distance,
    );

    // 二次贝塞尔曲线公式: (1-t)²P0 + 2(1-t)tP1 + t²P2
    final dx = (1 - t) * (1 - t) * start.dx +
               2 * (1 - t) * t * controlPoint.dx +
               t * t * end.dx;
    
    final dy = (1 - t) * (1 - t) * start.dy +
               2 * (1 - t) * t * controlPoint.dy +
               t * t * end.dy;

    return Offset(dx, dy);
  }

  /// 计算路径上的所有点，用于绘制或调试
  static List<Offset> calculatePath(
    Offset start,
    Offset end, {
    int steps = 100,
    double curvature = 0.2,
  }) {
    final points = <Offset>[];
    for (int i = 0; i <= steps; i++) {
      points.add(calculate(start, end, i / steps, curvature: curvature));
    }
    return points;
  }
}