import 'package:flutter/material.dart';
import 'dart:async';

enum FeedbackPosition { top, bottom, center }

/// Serviço centralizado para exibir feedback (snackbars, toasts)
/// que apareçam sempre acima de modais e diálogos
class FeedbackService {
  static final FeedbackService _instance = FeedbackService._internal();
  
  static FeedbackService get instance => _instance;
  
  FeedbackService._internal();
  
  OverlayEntry? _currentEntry;
  Timer? _hideTimer;

  /// Mostrar feedback de sucesso
  static void showSuccess(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 3),
    FeedbackPosition position = FeedbackPosition.top,
  }) {
    _instance._show(
      context,
      message: message,
      type: 'success',
      duration: duration,
      position: position,
    );
  }

  /// Mostrar feedback de erro
  static void showError(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 4),
    FeedbackPosition position = FeedbackPosition.top,
  }) {
    _instance._show(
      context,
      message: message,
      type: 'error',
      duration: duration,
      position: position,
    );
  }

  /// Mostrar feedback de info
  static void showInfo(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 3),
    FeedbackPosition position = FeedbackPosition.top,
  }) {
    _instance._show(
      context,
      message: message,
      type: 'info',
      duration: duration,
      position: position,
    );
  }

  /// Mostrar feedback genérico
  static void show(
    BuildContext context, {
    required String message,
    String type = 'info', // 'success', 'error', 'info'
    Duration duration = const Duration(seconds: 3),
    FeedbackPosition position = FeedbackPosition.top,
  }) {
    _instance._show(
      context,
      message: message,
      type: type,
      duration: duration,
      position: position,
    );
  }

  void _show(
    BuildContext context, {
    required String message,
    required String type,
    required Duration duration,
    required FeedbackPosition position,
  }) {
    // Remover feedback anterior se existir
    _hideTimer?.cancel();
    _currentEntry?.remove();

    final colors = _getColors(type);
    final icon = _getIcon(type);

    final entry = OverlayEntry(
      builder: (context) => Positioned(
        top: position == FeedbackPosition.top ? 16 : null,
        bottom: position == FeedbackPosition.bottom ? 16 : null,
        left: 16,
        right: 16,
        child: SafeArea(
          bottom: position == FeedbackPosition.bottom ? false : true,
          top: position == FeedbackPosition.top ? false : true,
          child: Material(
            color: Colors.transparent,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                return Transform.translate(
                  offset: position == FeedbackPosition.top
                      ? Offset(0, -100 * (1 - value))
                      : Offset(0, 100 * (1 - value)),
                  child: Opacity(
                    opacity: value.clamp(0.0, 1.0),
                    child: child,
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: colors['background'],
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: (colors['shadow'] as Color).withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                      spreadRadius: 2,
                    ),
                  ],
                  border: Border.all(
                    color: (colors['icon'] as Color).withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (colors['icon'] as Color).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        icon,
                        color: colors['icon'],
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        message,
                        style: TextStyle(
                          color: colors['text'],
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(entry);
    _currentEntry = entry;

    // Auto remover após a duração
    _hideTimer = Timer(duration, () {
      _hideTimer?.cancel();
      _currentEntry?.remove();
      _currentEntry = null;
    });
  }

  Map<String, dynamic> _getColors(String type) {
    switch (type) {
      case 'success':
        return {
          'background': const Color(0xFF10B981),
          'text': Colors.white,
          'icon': Colors.white,
          'shadow': const Color(0xFF10B981),
        };
      case 'error':
        return {
          'background': const Color(0xFFEF4444),
          'text': Colors.white,
          'icon': Colors.white,
          'shadow': const Color(0xFFEF4444),
        };
      case 'info':
      default:
        return {
          'background': const Color(0xFF3B82F6),
          'text': Colors.white,
          'icon': Colors.white,
          'shadow': const Color(0xFF3B82F6),
        };
    }
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'success':
        return Icons.check_circle_outline;
      case 'error':
        return Icons.error_outline;
      case 'info':
      default:
        return Icons.info_outline;
    }
  }
}
