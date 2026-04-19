import 'package:dio/dio.dart';

class AppException implements Exception {
  final String message;
  final int? statusCode;

  const AppException({required this.message, this.statusCode});

  factory AppException.fromDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const AppException(message: 'Connection timed out. Please try again.');
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final data       = e.response?.data;
        final msg = (data is Map && data['message'] != null)
            ? data['message'].toString()
            : 'Server error ($statusCode)';
        return AppException(message: msg, statusCode: statusCode);
      case DioExceptionType.cancel:
        return const AppException(message: 'Request was cancelled.');
      default:
        return const AppException(message: 'No internet connection.');
    }
  }

  @override
  String toString() => message;
}
