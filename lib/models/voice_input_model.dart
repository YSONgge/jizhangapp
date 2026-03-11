
/// 语音录入界面状态机
enum VoiceInputState {
  /// 空闲状态
  idle,
  /// 开始录音
  starting,
  /// 正在录音
  recording,
  /// 正在解析
  parsing,
  /// 准备确认
  confirming,
  /// 已取消
  cancelled,
}

/// 语音识别结果
class VoiceRecognitionResult {
  final String rawText;
  final String cleanedText;
  final double confidence;
  final DateTime timestamp;

  VoiceRecognitionResult({
    required this.rawText,
    required this.cleanedText,
    required this.confidence,
    required this.timestamp,
  });

  factory VoiceRecognitionResult.empty() {
    return VoiceRecognitionResult(
      rawText: '',
      cleanedText: '',
      confidence: 0.0,
      timestamp: DateTime.now(),
    );
  }

  bool get isEmpty => rawText.isEmpty;
}

/// 语音手势方向
enum VoiceSwipeDirection {
  none,
  up,  // 上滑取消
  down, // 下滑确认
}
