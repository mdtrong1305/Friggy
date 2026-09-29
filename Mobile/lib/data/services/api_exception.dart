import 'package:dio/dio.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;
  final bool isNetworkError; // true khi lỗi mạng (offline), false khi lỗi server

  ApiException({
    required this.message,
    this.statusCode,
    this.data,
    this.isNetworkError = false,
  });

  factory ApiException.fromDioException(DioException dioException) {
    switch (dioException.type) {
      case DioExceptionType.cancel:
        return ApiException(
          message: 'Yêu cầu bị hủy kết nối',
          isNetworkError: true,
        );
      case DioExceptionType.connectionTimeout:
        return ApiException(
          message: 'Hết thời gian kết nối tới máy chủ',
          isNetworkError: true,
        );
      case DioExceptionType.receiveTimeout:
        return ApiException(
          message: 'Máy chủ phản hồi quá chậm (Timeout)',
          isNetworkError: true,
        );
      case DioExceptionType.sendTimeout:
        return ApiException(
          message: 'Gửi dữ liệu quá thời gian chờ',
          isNetworkError: true,
        );
      case DioExceptionType.connectionError:
        return ApiException(
          message: 'Không thể kết nối máy chủ. Vui lòng kiểm tra mạng',
          isNetworkError: true,
        );
      case DioExceptionType.badResponse:
        final response = dioException.response;
        final statusCode = response?.statusCode;
        String errorMessage = 'Đã xảy ra lỗi hệ thống';

        if (response?.data != null && response?.data is Map) {
          final body = response!.data as Map<String, dynamic>;
          if (body['message'] != null) {
            if (body['message'] is List) {
              errorMessage = (body['message'] as List).join('\n');
            } else {
              errorMessage = body['message'].toString();
            }
          }
        } else if (statusCode == 401) {
          errorMessage = 'Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại';
        } else if (statusCode == 403) {
          errorMessage = 'Bạn không có quyền truy cập thực hiện thao tác này';
        } else if (statusCode == 404) {
          errorMessage = 'Không tìm thấy dữ liệu yêu cầu (404)';
        } else if (statusCode == 500) {
          errorMessage = 'Lỗi máy chủ nội bộ (500)';
        }

        return ApiException(
          message: errorMessage,
          statusCode: statusCode,
          data: response?.data,
          isNetworkError: false,
        );
      case DioExceptionType.unknown:
      default:
        if (dioException.error != null) {
          return ApiException(
            message: dioException.error.toString(),
            isNetworkError: true, // unknown thường là lỗi mạng
          );
        }
        return ApiException(message: 'Đã xảy ra lỗi không xác định');
    }
  }

  @override
  String toString() => message;
}
