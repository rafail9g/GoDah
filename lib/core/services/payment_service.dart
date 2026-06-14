import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class PaymentService {
  PaymentService._();
  static final PaymentService instance = PaymentService._();

  static const String _configuredBaseUrl = String.fromEnvironment(
    'PAYMENT_API_BASE_URL',
    defaultValue: 'https://api-godah-production.up.railway.app',
  );

  static String get _baseUrl => _configuredBaseUrl.replaceFirst(
        RegExp(r'/+$'),
        '',
      );

  Uri _endpoint(String path) => Uri.parse('$_baseUrl$path');

  Future<PaymentCreateResult?> createPayment({
    required String orderId,
    required double amount,
    required String customerName,
    required String customerEmail,
  }) async {
    try {
      final response = await http.post(
        _endpoint('/payments/create'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'order_id': orderId,
          'amount': amount.toInt(),
          'user_name': customerName,
          'user_email': customerEmail,
        }),
      );

      debugPrint('createPayment status: ${response.statusCode}');
      debugPrint('createPayment body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        return PaymentCreateResult(
          redirectUrl: data['redirect_url'] as String,
          midtransOrderId: data['midtrans_order_id'] as String,
          orderId: orderId,
        );
      }

      return null;
    } catch (e) {
      debugPrint('createPayment error: $e');
      return null;
    }
  }

  Future<bool> markPaidManual({
    required String midtransOrderId,
    String paymentType = 'bank_transfer',
  }) async {
    try {
      final response = await http.post(
        _endpoint('/payments/mark-paid-manual'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'midtrans_order_id': midtransOrderId,
          'payment_type': paymentType,
        }),
      );

      debugPrint('markPaidManual status: ${response.statusCode}');
      debugPrint('markPaidManual body: ${response.body}');

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('markPaidManual error: $e');
      return false;
    }
  }

  Future<String?> syncPaymentStatus({
    required String midtransOrderId,
  }) async {
    try {
      final response = await http.post(
        _endpoint('/payments/check-status'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'midtrans_order_id': midtransOrderId,
        }),
      );

      debugPrint('syncPaymentStatus status: ${response.statusCode}');
      debugPrint('syncPaymentStatus body: ${response.body}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final data = json['data'];
        return json['payment_status'] as String? ??
            (data is Map<String, dynamic> ? data['status'] as String? : null);
      }

      return null;
    } catch (e) {
      debugPrint('syncPaymentStatus error: $e');
      return null;
    }
  }

  Future<String?> checkPaymentStatus(String orderId) async {
    try {
      final response = await http.get(
        _endpoint('/payments/order/$orderId'),
        headers: {'Accept': 'application/json'},
      );

      debugPrint('checkStatus status: ${response.statusCode}');
      debugPrint('checkStatus body: ${response.body}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final data = json['data'] as Map<String, dynamic>;
        return data['status'] as String?;
      }

      return null;
    } catch (e) {
      debugPrint('checkStatus error: $e');
      return null;
    }
  }
}

class PaymentCreateResult {
  final String redirectUrl;
  final String midtransOrderId;
  final String orderId;

  const PaymentCreateResult({
    required this.redirectUrl,
    required this.midtransOrderId,
    required this.orderId,
  });
}
