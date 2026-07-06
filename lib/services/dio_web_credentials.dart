import 'package:dio/dio.dart';

import 'dio_web_credentials_stub.dart'
    if (dart.library.js_interop) 'dio_web_credentials_web.dart';

void enableDioWebCredentials(Dio dio) {
  configureDioWebCredentials(dio);
}
