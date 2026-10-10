import 'package:dio/dio.dart';

import '../entities/mcq.dart';

abstract class McqRepository {
  Future<List<McqSubjectInfo>> listSubjects();
  Future<List<McqSetSummary>> listSets({String? subject});
  Future<McqSetDetail> getSetQuestions(
    String setId, {
    CancelToken? cancelToken,
  });
}
