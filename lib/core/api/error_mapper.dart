import 'package:dio/dio.dart';

class ErrorMapper {
  static String fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'Connection timed out. Check your internet and try again.';
      case DioExceptionType.connectionError:
        return 'Unable to reach the server. Check your internet connection.';
      case DioExceptionType.cancel:
        return 'Request was cancelled.';
      case DioExceptionType.badResponse:
        return _fromResponse(e.response);
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  static String _fromResponse(Response? response) {
    if (response == null) return 'No response from server.';
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final msg = data['message'];
      if (msg is String && msg.isNotEmpty) return msg;
    }
    return switch (response.statusCode) {
      400 => 'Invalid request. Please check your input.',
      401 => 'Session expired. Please log in again.',
      403 => 'You don\'t have permission to do that.',
      404 => 'The requested resource was not found.',
      409 => 'Conflict: resource already exists.',
      422 => 'Validation failed. Please check your input.',
      429 => 'Too many requests. Please wait a moment.',
      500 => 'Server error. Please try again later.',
      503 => 'Service unavailable. Please try again later.',
      _   => 'Unexpected error (${response.statusCode}).',
    };
  }

  static String fromException(Object e) {
    if (e is DioException) return fromDio(e);
    return e.toString();
  }
}
