import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'api_endpoints.dart';
import 'auth_interceptor.dart';

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  late final Dio _productDio  = _buildDio(ApiEndpoints.productServiceBase);
  late final Dio _orderDio    = _buildDio(ApiEndpoints.orderServiceBase);
  late final Dio _deliveryDio = _buildDio(ApiEndpoints.deliveryServiceBase);

  /// Default client → ProductClientService (port 8081)
  Dio get client          => _productDio;

  /// Order/Payment client → OrderPaymentNotificationService (port 8082)
  Dio get orderClient     => _orderDio;

  /// Delivery/Inventory client → DeliveryInventoryService (port 8083)
  Dio get deliveryClient  => _deliveryDio;

  Dio _buildDio(String baseUrl) {
    final dio = Dio(
      BaseOptions(
        baseUrl:        baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: const {'Content-Type': 'application/json'},
      ),
    );
    dio.interceptors.add(AuthInterceptor(dio));
    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(
          requestBody:  true,
          responseBody: false,
          error:        true,
          logPrint: (o) => debugPrint(o.toString()),
        ),
      );
    }
    return dio;
  }
}
