import 'package:dio/dio.dart';

Dio createDio({String? baseUrl}) {
  return Dio(
    BaseOptions(
      baseUrl: baseUrl ?? '',
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      headers: const {
        'Accept': 'application/json',
      },
    ),
  );
}
