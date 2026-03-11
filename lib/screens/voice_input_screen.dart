import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/voice_input_model.dart';
import '../services/text_parser.dart';
import '../services/voice_recognition_service.dart';
import 'dart:ui';

class VoiceInputScreen extends StatefulWidget {
  final VoidCallback? onComplete;
  final VoidCallback? onCancelled;
  final Function(VoiceRecognitionResult result, Map<String, dynamic> parsedData)? onDataReady;

  const VoiceInputScreen({
    super.key,
    this.onComplete,
    this.onCancelled,
    this.onDataReady,
  });

  @override
  State<VoiceInputScreen> createState() => _VoiceInputScreenState();
}

class _VoiceInputScreenState extends State<VoiceInputScreen>
    with TickerProviderStateMixin {
  final VoiceRecognitionService _voiceService = VoiceRecognitionService();
  VoiceInputState _state = VoiceInputState.idle;
  VoiceRecognitionResult _result = VoiceRecognitionResult.empty();
  VoiceSwipeDirection _swipeDirection = VoiceSwipeDirection.none;

  late AnimationController _buttonAnimController;
  late Animation<double> _buttonAnimation;
  late Animation<double> _glowAnimation;

  late AnimationController _waveAnimController;
  late Animation<double> _waveAnimation1;
  late Animation<double> _waveAnimation2;
  late Animation<double> _waveAnimation3;

  late AnimationController _textFloatController;
  late Animation<double> _textFloatAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startRecording();
    });
  }

  void _initAnimations() {
    _buttonAnimController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _buttonAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _buttonAnimController, curve: Curves.easeInOut),
    );

    _glowAnimation = Tween<double>(begin: 0.3, end: 0.6).animate(
      CurvedAnimation(
        parent: _buttonAnimController,
        curve: Curves.easeInOut,
      ),
    );

    _waveAnimController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    _waveAnimation1 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _waveAnimController,
        curve: const Interval(0.0, 0.33, curve: Curves.easeOut),
      ),
    );

    _waveAnimation2 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _waveAnimController,
        curve: const Interval(0.33, 0.66, curve: Curves.easeOut),
      ),
    );

    _waveAnimation3 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _waveAnimController,
        curve: const Interval(0.66, 1.0, curve: Curves.easeOut),
      ),
    );

    _textFloatController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _textFloatAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textFloatController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _voiceService.stopListening();
    _buttonAnimController.dispose();
    _waveAnimController.dispose();
    _textFloatController.dispose();
    super.dispose();
  }

  void _startRecording() async {
    final hasPermission = await _voiceService.requestPermission();
    
    if (!hasPermission) {
      if (mounted) {
        final shouldOpenSettings = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('需要麦克风权限'),
            content: const Text('语音识别需要使用麦克风，请在设置中开启权限'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('去设置'),
              ),
            ],
          ),
        );
        
        if (shouldOpenSettings == true) {
          await openAppSettings();
        }
        widget.onCancelled?.call();
      }
      return;
    }

    setState(() {
      _state = VoiceInputState.recording;
    });
    _buttonAnimController.forward();
    _waveAnimController.repeat();

    _voiceService.startListening(
      onResult: (text) {
        if (mounted) {
          setState(() {
            _result = VoiceRecognitionResult(
              rawText: text,
              cleanedText: text,
              confidence: 0.9,
              timestamp: DateTime.now(),
            );
          });
          _textFloatController.forward(from: 0);
        }
      },
      onConfidence: (confidence) {},
      onError: (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('语音识别错误: $error')),
          );
          widget.onCancelled?.call();
        }
      },
      onStart: () {
        setState(() {
          _state = VoiceInputState.recording;
        });
      },
      onEnd: () {},
    );
  }

  void _stopRecording(VoiceSwipeDirection direction) {
    _swipeDirection = direction;
    _buttonAnimController.reverse();
    _waveAnimController.stop();
    _waveAnimController.reset();

    setState(() {
      _state = VoiceInputState.parsing;
    });

    _parseVoiceText();
  }

  void _parseVoiceText() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _state = VoiceInputState.confirming;
        });
        
        if (_swipeDirection == VoiceSwipeDirection.up) {
          _cancel();
        } else {
          _confirm();
        }
      }
    });
  }

  void _confirm() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_result.isEmpty) {
        widget.onComplete?.call();
        return;
      }

      final parser = TextParser();
      final parseResult = parser.parse(_result.cleanedText);

      final parsedData = {
        'amount': parseResult.amount,
        'category': parseResult.category,
        'account': parseResult.account,
        'merchant': parseResult.merchant,
        'owner': parseResult.owner ?? '本人',
        'project': parseResult.project ?? '日常',
      };

      widget.onDataReady?.call(_result, parsedData);
      widget.onComplete?.call();
    });
  }

  void _cancel() {
    Future.delayed(const Duration(milliseconds: 100), () {
      widget.onCancelled?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final centerX = screenSize.width / 2;
    final centerY = screenSize.height / 2;
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          GestureDetector(
            onTap: () => widget.onCancelled?.call(),
            child: Container(
              color: Colors.transparent,
            ),
          ),
          AnimatedBuilder(
            animation: _buttonAnimController,
            builder: (context, child) {
              final animValue = _buttonAnimController.value;
              
              final maxRadius = screenSize.width * 1.5;
              final radius = 48 + (maxRadius * animValue);
              
              return Stack(
                children: [
                  Positioned(
                    left: centerX - radius,
                    top: centerY - radius,
                    width: radius * 2,
                    height: radius * 2,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.5 + 0.1 * animValue),
                            Color(0xFFE8F5E9).withValues(alpha: 0.4 + 0.1 * animValue),
                            Color(0xFFE3F2FD).withValues(alpha: 0.4 + 0.1 * animValue),
                            Colors.white.withValues(alpha: 0.5 + 0.1 * animValue),
                          ],
                          stops: [0.0, 0.35, 0.65, 1.0],
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            height: 150,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.white.withValues(alpha: 0.6),
                                    Colors.white.withValues(alpha: 0.1),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  center: Alignment(0.3 * (1 - animValue), -0.3 * (1 - animValue)),
                                  radius: 0.8 + 0.3 * animValue,
                                  colors: [
                                    Colors.white.withValues(alpha: 0.4),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            height: 100,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Colors.white.withValues(alpha: 0.3),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                          BackdropFilter(
                            filter: ImageFilter.blur(
                              sigmaX: 3,
                              sigmaY: 3,
                            ),
                            child: Container(
                              color: Colors.white.withValues(alpha: 0.05),
                            ),
                          ),
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  center: Alignment(-0.5, -0.5),
                                  radius: 1.2,
                                  colors: [
                                    Colors.white.withValues(alpha: 0.3),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Opacity(
                      opacity: animValue,
                      child: Stack(
                        children: [
                          if (_state == VoiceInputState.recording ||
                              _state == VoiceInputState.parsing)
                            _buildRecordingContent(),
                          if (_state == VoiceInputState.confirming)
                            _buildConfirmingContent(),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingContent() {
    return GestureDetector(
      onLongPressEnd: (details) {
        _stopRecording(VoiceSwipeDirection.none);
      },
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! < 0) {
          _stopRecording(VoiceSwipeDirection.up);
        } else {
          _stopRecording(VoiceSwipeDirection.none);
        }
      },
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildRecognizedText(),
            
            SizedBox(height: 80.h),
            
            _buildMicrophoneButton(),
            
            SizedBox(height: 120.h),
            
            _buildGestureHint(),
          ],
        ),
      ),
    );
  }

  Widget _buildMicrophoneButton() {
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, child) {
            return Container(
              width: 120.w,
              height: 120.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF4A90E2).withValues(
                  alpha: 0.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4A90E2).withValues(
                      alpha: 0.4,
                    ),
                    blurRadius: 30 + (10 * _glowAnimation.value),
                    spreadRadius: 5 * _glowAnimation.value,
                  ),
                ],
              ),
            );
          },
        ),
        
        AnimatedBuilder(
          animation: _waveAnimation1,
          builder: (context, child) {
            return Container(
              width: 120.w + (100 * _waveAnimation1.value),
              height: 120.w + (100 * _waveAnimation1.value),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15 - (0.15 * _waveAnimation1.value)),
                  width: 2,
                ),
              ),
            );
          },
        ),

        AnimatedBuilder(
          animation: _waveAnimation2,
          builder: (context, child) {
            return Container(
              width: 120.w + (100 * _waveAnimation2.value),
              height: 120.w + (100 * _waveAnimation2.value),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12 - (0.12 * _waveAnimation2.value)),
                  width: 2,
                ),
              ),
            );
          },
        ),

        AnimatedBuilder(
          animation: _waveAnimation3,
          builder: (context, child) {
            return Container(
              width: 120.w + (100 * _waveAnimation3.value),
              height: 120.w + (100 * _waveAnimation3.value),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08 - (0.08 * _waveAnimation3.value)),
                  width: 2,
                ),
              ),
            );
          },
        ),
        
        AnimatedBuilder(
          animation: _buttonAnimation,
          builder: (context, child) {
            final scale = 1.0 + (0.15 * _buttonAnimation.value);
            return Transform.scale(
              scale: scale,
              child: Container(
                width: 96.w,
                height: 96.w,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4A90E2), Color(0xFF50E3C2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4A90E2).withValues(alpha: 0.5),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.mic_rounded,
                  size: 44.sp,
                  color: Colors.white,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRecognizedText() {
    return AnimatedBuilder(
      animation: _textFloatAnimation,
      builder: (context, child) {
        final translateY = -20 * (1 - _textFloatAnimation.value);
        final opacity = _textFloatAnimation.value;
        
        return Transform.translate(
          offset: Offset(0, translateY),
          child: Opacity(
            opacity: opacity,
            child: Column(
              children: [
                if (_result.isEmpty)
                  Text(
                    '正在聆听...',
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  )
                else
                  Text(
                    _result.cleanedText,
                    style: TextStyle(
                      fontSize: 32.sp,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGestureHint() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(24.r),
          ),
          child: Row(
            children: [
              Icon(
                Icons.keyboard_arrow_down,
                size: 20.sp,
                color: Colors.white.withValues(alpha: 0.8),
              ),
              SizedBox(width: 8.w),
              Text(
                '松手确认',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 16.w),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(24.r),
          ),
          child: Row(
            children: [
              Icon(
                Icons.close,
                size: 20.sp,
                color: Colors.white.withValues(alpha: 0.8),
              ),
              SizedBox(width: 8.w),
              Text(
                '上滑取消',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmingContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              Color(0xFF4A90E2),
            ),
            strokeWidth: 3,
          ),
          SizedBox(height: 16.h),
          Text(
            '正在解析...',
            style: TextStyle(
              fontSize: 16.sp,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelHint() {
    return Positioned(
      top: 120.h,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(24.r),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check,
                size: 20.sp,
                color: Colors.white,
              ),
              SizedBox(width: 8.w),
              Text(
                '已取消',
                style: TextStyle(
                  fontSize: 16.sp,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
