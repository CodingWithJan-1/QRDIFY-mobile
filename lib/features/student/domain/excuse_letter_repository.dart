import 'excuse_letter.dart';
import 'excuse_teacher.dart';

abstract interface class ExcuseLetterRepository {
  Future<List<ExcuseLetter>> fetchLetters({required String accessToken});

  Future<List<ExcuseTeacher>> fetchTeachers({required String accessToken});

  Future<ExcuseLetter> submitLetter({
    required String accessToken,
    required String title,
    required DateTime absentDate,
    required String reason,
    required int teacherId,
    List<int>? attachmentBytes,
    String? attachmentName,
  });

  Future<void> deleteLetter({
    required String accessToken,
    required int letterId,
  });
}
