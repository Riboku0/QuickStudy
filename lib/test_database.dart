
import 'database/app_database.dart';

Future<void> main() async {
  final id = await AppDatabase.insertLecture(
    name: 'Test Lecture',
    filePath: '/test/lecture.pdf',
    fileType: 'pdf',
    dateAdded: DateTime.now().toIso8601String(),
  );

  print('Saved lecture ID: $id');

  final lectures = await AppDatabase.getLectures();

  print('Saved lectures: $lectures');
}
