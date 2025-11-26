// lib/services/sms_exception.dart

class SmsException implements Exception {
  final String message;
  final int? statusCode;
  final String? body;
  final StackTrace? stackTrace;

  const SmsException(
    this.message, {
    this.statusCode,
    this.body,
    this.stackTrace,
  });

  @override
  String toString() {
    final codePart = statusCode != null ? ' (HTTP $statusCode)' : '';
    final bodyPart = body != null ? '\nResponse Body: $body' : '';
    return 'SmsException$codePart: $message$bodyPart';
  }
}
