/// خطاهای مرتبط با تعامل با سرویس پیامکی.
class SmsException implements Exception {
  SmsException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() =>
      statusCode == null ? 'SmsException: $message' : 'SmsException($statusCode): $message';
}
