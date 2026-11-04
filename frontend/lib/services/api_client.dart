import 'package:dio/dio.dart';

import '../models/json_utils.dart';
import 'config.dart';

/// Thrown when the backend rejects a request with a structured error body.
class ApiException implements Exception {
  ApiException(this.message, {this.status, this.fields = const {}});
  final String message;
  final int? status;
  final Map<String, String> fields;

  /// True when the server never answered (offline, CORS, DNS, timeout).
  bool get unreachable => status == null;

  @override
  String toString() => 'ApiException($status): $message';
}

class ApiClient {
  ApiClient({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: AppConfig.apiBaseUrl,
              connectTimeout: const Duration(seconds: 4),
              receiveTimeout: const Duration(seconds: 8),
              sendTimeout: const Duration(seconds: 8),
              headers: {'Accept': 'application/json'},
            ));

  final Dio _dio;

  Future<Json> getJson(String path, {Map<String, dynamic>? query}) async {
    final res = await _send(() => _dio.get<dynamic>(path, queryParameters: query));
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Json> postJson(String path, Json body) async {
    final res = await _send(() => _dio.post<dynamic>(path, data: body));
    return Map<String, dynamic>.from(res as Map);
  }

  Future<dynamic> _send(Future<Response<dynamic>> Function() call) async {
    try {
      return (await call()).data;
    } on DioException catch (e) {
      final res = e.response;
      if (res == null) throw ApiException('Server unreachable: ${e.message ?? e.type.name}');
      final data = res.data;
      var msg = 'Request failed (${res.statusCode})';
      var fields = <String, String>{};
      if (data is Map) {
        msg = data['error']?.toString() ?? msg;
        if (data['fields'] is Map) {
          fields = (data['fields'] as Map).map((k, v) => MapEntry('$k', '$v'));
        }
      }
      throw ApiException(msg, status: res.statusCode, fields: fields);
    }
  }
}
