import '../../domain/entities/college.dart';
import '../../domain/repositories/college_repository.dart';
import '../datasources/mock_college_data_source.dart';

class CollegeRepositoryImpl implements CollegeRepository {
  @override
  Future<List<College>> search(String query) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return MockCollegeDataSource.colleges;

    return MockCollegeDataSource.colleges.where((college) {
      return college.name.toLowerCase().contains(normalized) ||
          college.city.toLowerCase().contains(normalized);
    }).toList();
  }
}
