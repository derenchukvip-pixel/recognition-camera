import 'dart:io';

import 'package:dio/dio.dart';

class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

String mapToUserMessage(Object error) {
  if (error is AppException) {
    return error.message;
  }
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timed out. Please try again.';
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode;
        if (status != null && status >= 500) {
          return 'Server is temporarily unavailable. Please try again later.';
        }
        if (status == 404) {
          return 'Service endpoint not found. Please update the app.';
        }
        return 'Service returned an error. Please try again.';
      case DioExceptionType.connectionError:
        return 'No internet connection. Check your network and retry.';
      case DioExceptionType.cancel:
        return 'Request was cancelled. Please try again.';
      case DioExceptionType.badCertificate:
        return 'Secure connection failed. Please try again.';
      case DioExceptionType.unknown:
        return 'Unexpected network error. Please try again.';
    }
  }
  if (error is SocketException) {
    return 'No internet connection. Check your network and retry.';
  }
  if (error is FormatException) {
    return 'Received malformed data. Please try again later.';
  }
  return 'Something went wrong. Please try again.';
}
