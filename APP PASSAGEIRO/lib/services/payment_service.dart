import 'package:troco_seguro/services/api_service.dart';
import 'package:troco_seguro/services/feedback_service.dart';
import 'package:flutter/material.dart';

/// Modelo para rastrear o estado do pagamento
class PaymentState {
  final String? qrToken;
  final QrValidationResult? validationResult;
  final String? paymentToken;
  final PaymentResult? paymentResult;
  final String? error;
  final PaymentStep currentStep;

  PaymentState({
    this.qrToken,
    this.validationResult,
    this.paymentToken,
    this.paymentResult,
    this.error,
    this.currentStep = PaymentStep.idle,
  });

  PaymentState copyWith({
    String? qrToken,
    QrValidationResult? validationResult,
    String? paymentToken,
    PaymentResult? paymentResult,
    String? error,
    PaymentStep? currentStep,
  }) {
    return PaymentState(
      qrToken: qrToken ?? this.qrToken,
      validationResult: validationResult ?? this.validationResult,
      paymentToken: paymentToken ?? this.paymentToken,
      paymentResult: paymentResult ?? this.paymentResult,
      error: error ?? this.error,
      currentStep: currentStep ?? this.currentStep,
    );
  }
}

enum PaymentStep {
  idle,
  scanningQR,
  validatingQR,
  showingValidation,
  processingPayment,
  completed,
  error,
}

/// Serviço centralizado para orquestar o fluxo de pagamento
class PaymentService {
  static final PaymentService _instance = PaymentService._internal();

  factory PaymentService() {
    return _instance;
  }

  PaymentService._internal();

  final _api = ApiService();

  /// Passo 1: Validar QR Code
  ///
  /// Recebe os dados do QR Code escaneado e valida contra o servidor
  /// Retorna as informações do taxista/receptor
  Future<QrValidationResult?> validateQrCode(
    BuildContext context,
    String qrData,
  ) async {
    try {
      FeedbackService.showInfo(
        context,
        message: 'Validando QR Code...',
        duration: const Duration(seconds: 2),
      );

      // Detect if qrData contains a hidden token (token=... or JWT-like)
      String token = '';
      try {
        final parsed = Uri.tryParse(qrData);
        if (parsed != null && parsed.queryParameters.containsKey('token')) {
          token = parsed.queryParameters['token'] ?? '';
        }
      } catch (_) {}

      if (token.isEmpty) {
        // try simple string detection
        if (qrData.contains('token=')) {
          final parts = qrData.split('token=');
          if (parts.length > 1) token = parts[1];
        } else if (qrData.startsWith('eyJ')) {
          token = qrData;
        }
      }

      // Always use resolveQrToken. If no explicit token was found,
      // pass the raw qrData as the token parameter (server should handle it).
      final tokenParam = token.isNotEmpty ? token : qrData;
      final response = await _api.resolveQrToken(tokenParam);

      if (response.isSuccess && response.data != null) {
        final result = response.data!;

        if (!result.valid) {
          if (context.mounted) {
            FeedbackService.showError(
              context,
              message: 'QR Code inválido ou expirado',
            );
          }
          return null;
        }

        if (context.mounted) {
          FeedbackService.showSuccess(
            context,
            message: 'QR Code validado com sucesso!',
            duration: const Duration(seconds: 2),
          );
        }

        return result;
      } else {
        if (context.mounted) {
          FeedbackService.showError(
            context,
            message: response.error ?? 'Erro ao validar QR Code',
          );
        }
        return null;
      }
    } catch (e) {
      if (context.mounted) {
        FeedbackService.showError(
          context,
          message: 'Erro ao validar QR Code: $e',
        );
      }
      return null;
    }
  }

  /// Passo 2: Processar Pagamento
  ///
  /// Executa a transação com os dados fornecidos
  Future<PaymentResult?> processPayment({
    required BuildContext context,
    required String driverId,
    required int amount,
    required String pin,
    required String origin,
    required String destination,
    required String paymentToken,
    double distanceKm = 0.0,
    int durationMinutes = 0,
  }) async {
    try {
      FeedbackService.showInfo(
        context,
        message: 'Processando pagamento...',
        duration: const Duration(seconds: 3),
      );

      final response = await _api.processPayment(
        driverId: driverId,
        amount: amount,
        pin: pin,
        origin: origin,
        destination: destination,
        paymentToken: paymentToken,
        distanceKm: distanceKm,
        durationMinutes: durationMinutes,
      );

      if (response.isSuccess && response.data != null) {
        final result = response.data!;

        if (context.mounted) {
          FeedbackService.showSuccess(
            context,
            message: 'Pagamento realizado com sucesso!',
            duration: const Duration(seconds: 3),
          );
        }

        return result;
      } else {
        if (context.mounted) {
          FeedbackService.showError(
            context,
            message: response.error ?? 'Erro ao processar pagamento',
            duration: const Duration(seconds: 4),
          );
        }
        return null;
      }
    } catch (e) {
      if (context.mounted) {
        FeedbackService.showError(
          context,
          message: 'Erro ao processar pagamento: $e',
          duration: const Duration(seconds: 4),
        );
      }
      return null;
    }
  }
}
