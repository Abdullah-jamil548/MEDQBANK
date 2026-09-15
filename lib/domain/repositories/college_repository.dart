import '../entities/college.dart';

abstract class CollegeRepository {
  Future<List<College>> search(String query);
}
