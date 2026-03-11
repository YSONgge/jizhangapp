import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VoiceRecognitionService {
  final SpeechToText _speechToText = SpeechToText();
  
  bool _isInitialized = false;
  bool _isListening = false;
  
  Function(String)? onResult;
  Function(double)? onConfidence;
  Function(String)? onError;
  Function()? onListeningStart;
  Function()? onListeningEnd;
  
  bool get isInitialized => _isInitialized;
  
  bool get isListening => _isListening;

  Future<int> _getAndroidSdkInt() async {
    try {
      const platform = MethodChannel('flutter/platform');
      final result = await platform.invokeMethod<int>('getSystemVersion');
      return result ?? 33;
    } catch (e) {
      return 33;
    }
  }

  Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      final status = await Permission.microphone.status;
      if (!status.isGranted) {
        final sdkInt = await _getAndroidSdkInt();
        if (sdkInt >= 33) {
          await Permission.notification.request();
          await Future.delayed(const Duration(milliseconds: 500));
        }
        
        final result = await Permission.microphone.request();
        if (!result.isGranted && !result.isLimited) {
          return false;
        }
      }
      
      _isInitialized = await _speechToText.initialize(
        onError: (error) {
          debugPrint('[VoiceRecognition] speech_to_text 错误: ${error.errorMsg}');
          onError?.call(error.errorMsg);
        },
        onStatus: (status) {
          debugPrint('[VoiceRecognition] speech_to_text 状态: $status');
          if (status == 'listening') {
            _isListening = true;
            onListeningStart?.call();
          } else if (status == 'done' || status == 'notListening') {
            _isListening = false;
            onListeningEnd?.call();
          }
        },
        debugLogging: true,
      );
      
      if (!_isInitialized) {
        for (int i = 0; i < 3; i++) {
          debugPrint('[VoiceRecognition] 初始化重试 $i 次...');
          await Future.delayed(const Duration(milliseconds: 500));
          _isInitialized = await _speechToText.initialize(
            onError: (error) => debugPrint('[VoiceRecognition] 重试错误: ${error.errorMsg}'),
            onStatus: (status) => debugPrint('[VoiceRecognition] 重试状态: $status'),
            debugLogging: true,
          );
          if (_isInitialized) break;
        }
      }
      
      return _isInitialized;
    } catch (e) {
      debugPrint('[VoiceRecognition] 初始化异常: $e');
      onError?.call('初始化失败: $e');
      return false;
    }
  }

  /// 开始录音
  Future<void> startListening({
    Function(String)? onResult,
    Function(double)? onConfidence,
    Function(String)? onError,
    Function()? onStart,
    Function()? onEnd,
  }) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        onError?.call('语音识别未初始化');
        return;
      }
    }

    if (_isListening) {
      onError?.call('已在录音中');
      return;
    }

    this.onResult = onResult;
    this.onConfidence = onConfidence;
    this.onError = onError;
    onListeningStart = onStart;
    onListeningEnd = onEnd;

    try {
      await _speechToText.listen(
        onResult: (result) {
          final recognizedWords = result.recognizedWords;
          final confidence = result.confidence;
          
          if (recognizedWords.isNotEmpty) {
            onResult?.call(recognizedWords);
          }
          
          if (confidence > 0) {
            onConfidence?.call(confidence);
          }
        },
        partialResults: true, // 启用实时流式识别
        localeId: 'zh_CN',
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        cancelOnError: false,
      );
      
      _isListening = true;
    } catch (e) {
      onError?.call('录音失败: $e');
      _isListening = false;
    }
  }

  /// 停止录音
  void stopListening() {
    if (_isListening) {
      _speechToText.stop();
      _isListening = false;
    }
  }

  /// 取消录音
  void cancelListening() {
    if (_isListening) {
      _speechToText.cancel();
      _isListening = false;
    }
  }

  /// 检查是否可用
  Future<bool> checkAvailability() async {
    try {
      final available = await _speechToText.hasPermission;
      return available;
    } catch (e) {
      return false;
    }
  }

  /// 请求权限 - 针对 ColorOS/一加手机优化
  Future<bool> requestPermission() async {
    debugPrint('[VoiceRecognition] 开始请求权限...');
    try {
      final sdkInt = await _getAndroidSdkInt();
      
      if (sdkInt >= 33) {
        await Permission.notification.request();
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      final currentStatus = await Permission.microphone.status;
      debugPrint('[VoiceRecognition] 当前麦克风权限状态: $currentStatus');
      
      if (currentStatus.isGranted || currentStatus.isLimited) {
        debugPrint('[VoiceRecognition] 麦克风已授权，初始化 speech_to_text...');
        _isInitialized = await _speechToText.initialize(
          onError: (error) {
            debugPrint('[VoiceRecognition] speech_to_text 错误: $error');
            onError?.call(error.errorMsg);
          },
          onStatus: (status) {
            debugPrint('[VoiceRecognition] speech_to_text 状态: $status');
            if (status == 'listening') {
              _isListening = true;
              onListeningStart?.call();
            } else if (status == 'done' || status == 'notListening') {
              _isListening = false;
              onListeningEnd?.call();
            }
          },
          debugLogging: true,
        );
        debugPrint('[VoiceRecognition] speech_to_text 初始化结果: $_isInitialized');
        
        if (!_isInitialized) {
          for (int i = 0; i < 3; i++) {
            debugPrint('[VoiceRecognition] 初始化重试 $i 次...');
            await Future.delayed(const Duration(milliseconds: 500));
            _isInitialized = await _speechToText.initialize(
              onError: (error) => debugPrint('[VoiceRecognition] 重试错误: $error'),
              onStatus: (status) => debugPrint('[VoiceRecognition] 重试状态: $status'),
              debugLogging: true,
            );
            if (_isInitialized) break;
          }
        }
        
        return _isInitialized;
      }
      
      debugPrint('[VoiceRecognition] 请求麦克风权限...');
      final status = await Permission.microphone.request();
      debugPrint('[VoiceRecognition] 请求后权限状态: $status');
      
      if (!status.isGranted && !status.isLimited) {
        debugPrint('[VoiceRecognition] 权限被拒绝');
        if (status.isPermanentlyDenied) {
          debugPrint('[VoiceRecognition] 权限被永久拒绝，需要手动开启');
        }
        return false;
      }
      
      await Future.delayed(const Duration(milliseconds: 300));
      
      debugPrint('[VoiceRecognition] 权限已授权，初始化 speech_to_text...');
      _isInitialized = await _speechToText.initialize(
        onError: (error) {
          debugPrint('[VoiceRecognition] speech_to_text 错误: $error');
          onError?.call(error.errorMsg);
        },
        onStatus: (status) {
          debugPrint('[VoiceRecognition] speech_to_text 状态: $status');
          if (status == 'listening') {
            _isListening = true;
            onListeningStart?.call();
          } else if (status == 'done' || status == 'notListening') {
            _isListening = false;
            onListeningEnd?.call();
          }
        },
        debugLogging: true,
      );
      
      if (!_isInitialized) {
        for (int i = 0; i < 3; i++) {
          debugPrint('[VoiceRecognition] 初始化重试 $i 次...');
          await Future.delayed(const Duration(milliseconds: 500));
          _isInitialized = await _speechToText.initialize(
            onError: (error) => debugPrint('[VoiceRecognition] 重试错误: $error'),
            onStatus: (status) => debugPrint('[VoiceRecognition] 重试状态: $status'),
            debugLogging: true,
          );
          if (_isInitialized) break;
        }
      }
      
      debugPrint('[VoiceRecognition] 初始化完成，结果: $_isInitialized');
      return _isInitialized;
    } catch (e) {
      debugPrint('[VoiceRecognition] 请求权限异常: $e');
      return false;
    }
  }
}
