import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

import '../../core/network/api_client.dart';
import '../../domain/entities/mcq.dart';
import '../../domain/repositories/mcq_repository.dart';

void _throwIfCancelled(CancelToken? cancelToken, String setId) {
  if (cancelToken == null || !cancelToken.isCancelled) return;
  throw DioException(
    requestOptions: RequestOptions(path: '/mcqs/sets/$setId/questions'),
    type: DioExceptionType.cancel,
    error: 'cancelled',
  );
}

class McqRepositoryImpl implements McqRepository {
  McqRepositoryImpl(this._api);

  final ApiClient _api;

  static const _bundledAssets = <String>[
    'assets/mcqs/embryology_mcqs.json',
    'assets/mcqs/embryology_scan_mcqs.json',
    'assets/mcqs/anatomy_topic_wise_mcqs.json',
    'assets/mcqs/general_anatomy_key_mcqs.json',
    'assets/mcqs/histology_key_mcqs.json',
    'assets/mcqs/lower_limb_mcqs.json',
  ];

  /// Prefer matching asset by set_id so we don't parse every JSON.
  static const _bundledBySetId = <String, String>{
    'embryology-past-papers-mcqs': 'assets/mcqs/embryology_mcqs.json',
    'embryology-past-papers-scan-mcqs': 'assets/mcqs/embryology_scan_mcqs.json',
    'anatomy-topic-wise-past-papers': 'assets/mcqs/anatomy_topic_wise_mcqs.json',
    'anatomy-general-key-scan-mcqs': 'assets/mcqs/general_anatomy_key_mcqs.json',
    'histology-key-scan-mcqs': 'assets/mcqs/histology_key_mcqs.json',
    'anatomy-lower-limb-scan-mcqs': 'assets/mcqs/lower_limb_mcqs.json',
  };

  Future<McqSetDetail?> _bundledSetById(String setId) async {
    final asset = _bundledBySetId[setId];
    if (asset == null) return null;
    try {
      final raw = await rootBundle.loadString(asset);
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return McqSetDetail.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<List<McqSetDetail>> _bundledSets() async {
    final out = <McqSetDetail>[];
    for (final asset in _bundledAssets) {
      try {
        final raw = await rootBundle.loadString(asset);
        final json = jsonDecode(raw) as Map<String, dynamic>;
        out.add(McqSetDetail.fromJson(json));
      } catch (_) {
        // skip missing/invalid bundled set
      }
    }
    return out;
  }

  @override
  Future<List<McqSubjectInfo>> listSubjects() async {
    try {
      final res = await _api.get<List<dynamic>>('/mcqs/subjects');
      final list = (res.data ?? [])
          .whereType<Map>()
          .map((e) => McqSubjectInfo.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (list.isNotEmpty) return list;
    } catch (_) {
      // fall through to bundled sets
    }
    final bundled = await _bundledSets();
    final bySubject = <String, ({int sets, int questions})>{};
    for (final set in bundled) {
      final key = set.summary.subject;
      final prev = bySubject[key];
      bySubject[key] = (
        sets: (prev?.sets ?? 0) + 1,
        questions: (prev?.questions ?? 0) + set.questions.length,
      );
    }
    return bySubject.entries
        .map(
          (e) => McqSubjectInfo(
            subject: e.key,
            setCount: e.value.sets,
            questionCount: e.value.questions,
          ),
        )
        .toList();
  }

  @override
  Future<List<McqSetSummary>> listSets({String? subject}) async {
    try {
      final res = await _api.get<List<dynamic>>(
        '/mcqs/sets',
        queryParameters: {if (subject != null && subject.isNotEmpty) 'subject': subject},
      );
      final list = (res.data ?? [])
          .whereType<Map>()
          .map((e) => McqSetSummary.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (list.isNotEmpty) return list;
    } catch (_) {
      // fall through
    }
    final bundled = await _bundledSets();
    return bundled
        .where(
          (s) =>
              subject == null ||
              subject.isEmpty ||
              s.summary.subject.toLowerCase() == subject.toLowerCase(),
        )
        .map(
          (s) => McqSetSummary(
            id: s.summary.id,
            subject: s.summary.subject,
            title: s.summary.title,
            sourcePdf: s.summary.sourcePdf,
            topic: s.summary.topic,
            questionCount: s.questions.length,
          ),
        )
        .toList();
  }

  @override
  Future<McqSetDetail> getSetQuestions(
    String setId, {
    CancelToken? cancelToken,
  }) async {
    // Bundled pilots open from assets first (fast, one tap). API is fallback.
    final known = await _bundledSetById(setId);
    _throwIfCancelled(cancelToken, setId);
    if (known != null) return known;

    try {
      final res = await _api
          .get<Map<String, dynamic>>(
            '/mcqs/sets/$setId/questions',
            cancelToken: cancelToken,
          )
          .timeout(const Duration(seconds: 8));
      _throwIfCancelled(cancelToken, setId);
      final data = res.data;
      if (data != null && data.isNotEmpty) {
        return McqSetDetail.fromJson(Map<String, dynamic>.from(data));
      }
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) rethrow;
    } catch (_) {
      _throwIfCancelled(cancelToken, setId);
    }

    final bundled = await _bundledSets();
    _throwIfCancelled(cancelToken, setId);
    for (final set in bundled) {
      if (set.summary.id == setId) return set;
    }
    throw StateError('MCQ set not found: $setId');
  }
}
