import 'package:dio/browser.dart';
import 'package:dio/dio.dart';

void configureDioWebCredentials(Dio dio) {
  dio.httpClientAdapter = BrowserHttpClientAdapter()..withCredentials = true;
}
