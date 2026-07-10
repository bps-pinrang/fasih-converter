import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import '../core/env/app_env.dart';
import '../models/fasih_assignment.dart';
import '../repositories/fasih_auth_repository.dart';
import '../services/device_id_service.dart';

@singleton
class FasihSurveyApi {
  final FasihAuthRepository _auth;
  final DeviceIdService _deviceId;
  late final Dio _dio;

  FasihSurveyApi(this._auth, this._deviceId) {
    _dio = Dio(BaseOptions(baseUrl: AppEnv.fasihBaseUrl))
      ..interceptors.add(_AuthInterceptor(_auth, _deviceId));
  }

  /// Lists assignments for [surveyPeriodId], including wrappedDataKey per region.
  Future<List<FasihAssignment>> getAssignments(String surveyPeriodId) async {
    final response = await _dio.post<dynamic>(
      '/mobile/assignment-general/api/mobile/assign-by-selection/$surveyPeriodId',
    );
    final body = response.data;
    final list =
        body is List ? body : (body is Map ? body['data'] as List? ?? [] : []);
    return list
        .cast<Map<String, dynamic>>()
        .map(FasihAssignment.fromJson)
        .toList();
  }

  /// Fetches the encrypted answer body for a single assignment.
  Future<String> getAnswerBody(String assignmentId) async {
    final response = await _dio.get<String>(
      '/mobile/assignment-sync/api/mobile/assignment/$assignmentId/answer',
      options: Options(responseType: ResponseType.plain),
    );
    return response.data ?? '';
  }

  /// Downloads content from an S3 presigned URL (no auth headers).
  Future<String> downloadFromS3(String presignedUrl) async {
    final response = await Dio().get<String>(
      presignedUrl,
      options: Options(responseType: ResponseType.plain),
    );
    return response.data ?? '';
  }
}

class _AuthInterceptor extends Interceptor {
  final FasihAuthRepository _auth;
  final DeviceIdService _deviceId;

  _AuthInterceptor(this._auth, this._deviceId);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _auth.getValidToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    options.headers['X-Device-Id'] = _deviceId.deviceId;
    handler.next(options);
  }
}
