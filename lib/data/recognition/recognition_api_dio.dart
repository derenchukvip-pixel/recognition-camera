import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../core/config/app_config.dart';
import '../../core/error/app_error.dart';
import '../../core/network/dio_client.dart';
import '../../domain/models/recognition_result.dart';
import 'recognition_api.dart';

class RecognitionApiDio implements RecognitionApi {
  RecognitionApiDio({Dio? dio})
      : _dio = dio ?? createDio(baseUrl: AppConfig.recognitionBaseUrl);

  final Dio _dio;

  @override
  Future<RecognitionResult> analyzeImage(File imageFile) async {
    try {
      final fileName = imageFile.path.split(Platform.pathSeparator).last;
      final formData = FormData.fromMap({
        'file':
            await MultipartFile.fromFile(imageFile.path, filename: fileName),
      });

      final response = await _dio.post(
        AppConfig.recognitionAnalyzePath,
        data: formData,
        options: Options(responseType: ResponseType.json),
      );

      final data = response.data;
      if (data is String) {
        return RecognitionResult.fromResponse(data);
      }
      if (data is Map<String, dynamic>) {
        final resultText = data['result']?.toString() ?? jsonEncode(data);
        return RecognitionResult(
          message: resultText,
          rawResponse: jsonEncode(data),
        );
      }
      return RecognitionResult(
        message: data.toString(),
        rawResponse: data.toString(),
      );
    } on DioException catch (error) {
      throw AppException(mapToUserMessage(error));
    } catch (error) {
      throw AppException(mapToUserMessage(error));
    }
  }
}
