import '../../../core/network/api_client.dart';
import '../domain/excuse_letter.dart';
import '../domain/excuse_letter_repository.dart';
import '../domain/excuse_teacher.dart';

class ExcuseLetterRepositoryImpl implements ExcuseLetterRepository {
  const ExcuseLetterRepositoryImpl(this._apiClient, this._useMobileApi);

  final ApiClient _apiClient;
  final bool _useMobileApi;

  @override
  Future<List<ExcuseLetter>> fetchLetters({required String accessToken}) async {
    final response = await _apiClient.get(
      'student/excuse-letters',
      token: accessToken,
    );
    final values = _useMobileApi && response is Map<String, dynamic>
        ? response['data']
        : response;
    if (values is! List) {
      throw const FormatException('Invalid excuse letter response.');
    }
    return values.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Invalid excuse letter item.');
      }
      return ExcuseLetter.fromJson(item);
    }).toList();
  }

  @override
  Future<List<ExcuseTeacher>> fetchTeachers({
    required String accessToken,
  }) async {
    final response = await _apiClient.get(
      'student/teachers',
      token: accessToken,
    );
    final values = response is Map<String, dynamic>
        ? response['data']
        : response;
    if (values is! List) {
      throw const FormatException('Invalid teacher response.');
    }
    return values.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Invalid teacher item.');
      }
      return ExcuseTeacher.fromJson(item);
    }).toList();
  }

  @override
  Future<ExcuseLetter> submitLetter({
    required String accessToken,
    required String title,
    required DateTime absentDate,
    required String reason,
    required int teacherId,
    List<int>? attachmentBytes,
    String? attachmentName,
  }) async {
    final response = await _apiClient.postMultipart(
      'student/excuse-letters',
      token: accessToken,
      fields: {
        'title': title.trim(),
        'absent_date': _dateOnly(absentDate),
        'reason': reason.trim(),
        'teacher_id': '$teacherId',
      },
      fileField: attachmentBytes == null ? null : 'attachment',
      fileBytes: attachmentBytes,
      fileName: attachmentName,
    );
    if (response is! Map<String, dynamic> ||
        response['letter'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid excuse letter response.');
    }
    return ExcuseLetter.fromJson(response['letter'] as Map<String, dynamic>);
  }

  @override
  Future<void> deleteLetter({
    required String accessToken,
    required int letterId,
  }) async {
    await _apiClient.delete(
      'student/excuse-letters/$letterId',
      token: accessToken,
    );
  }
}

String _dateOnly(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}
