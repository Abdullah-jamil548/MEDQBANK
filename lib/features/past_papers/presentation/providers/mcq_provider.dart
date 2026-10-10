import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/utils/async_tap_guard.dart';
import '../../../../domain/entities/mcq.dart';
import '../../../../domain/repositories/mcq_repository.dart';

enum OpenSetResult { opened, cancelled, failed }

class McqProvider extends ChangeNotifier {
  McqProvider(this._repository);

  final McqRepository _repository;

  List<McqSubjectInfo> subjects = const [];
  final Map<String, List<McqSetSummary>> setsBySubject = {};
  bool catalogLoading = false;
  String? error;

  /// Set id currently being opened (null when idle).
  String? openingSetId;
  bool get isOpeningSet => openingSetId != null;

  McqSetDetail? activeSet;
  int index = 0;
  String? selectedKey;
  bool revealed = false;
  int correctCount = 0;
  int answeredCount = 0;
  bool quizFinished = false;

  /// Back-compat for older UI that checked [loading].
  bool get loading => catalogLoading || isOpeningSet;

  Future<void> loadCatalog() async {
    catalogLoading = true;
    error = null;
    notifyListeners();
    try {
      subjects = await _repository.listSubjects();
      setsBySubject.clear();
      for (final s in subjects) {
        setsBySubject[s.subject] = await _repository.listSets(subject: s.subject);
      }
    } catch (e) {
      error = apiErrorMessage(e);
      subjects = const [];
      setsBySubject.clear();
    } finally {
      catalogLoading = false;
      notifyListeners();
    }
  }

  bool hasMcqsFor(String subject) {
    final sets = setsBySubject[subject];
    if (sets != null && sets.isNotEmpty) return true;
    return subjects.any((s) => s.subject.toLowerCase() == subject.toLowerCase());
  }

  List<McqSetSummary> setsFor(String subject) => setsBySubject[subject] ?? const [];

  /// Open an MCQ set. First tap starts; tap again on the same set cancels.
  Future<OpenSetResult> openSet(String setId) async {
    error = null;
    OpenSetResult result = OpenSetResult.failed;
    final key = 'mcq-open:$setId';

    // Immediate UI feedback + retap-to-cancel before awaiting the guard.
    if (AsyncTapGuard.instance.isBusyKey(key) || openingSetId == setId) {
      cancelOpen();
      return OpenSetResult.cancelled;
    }
    if (AsyncTapGuard.instance.isBusy || isOpeningSet) {
      return OpenSetResult.cancelled;
    }

    openingSetId = setId;
    notifyListeners();

    final outcome = await AsyncTapGuard.instance.run(key, (token) async {
      try {
        final detail = await _repository.getSetQuestions(setId, cancelToken: token);
        if (token.isCancelled) {
          result = OpenSetResult.cancelled;
          return;
        }
        if (detail.questions.isEmpty) {
          error = 'This set has no questions yet';
          result = OpenSetResult.failed;
          return;
        }
        activeSet = detail;
        index = 0;
        selectedKey = null;
        revealed = false;
        correctCount = 0;
        answeredCount = 0;
        quizFinished = false;
        result = OpenSetResult.opened;
      } on DioException catch (e) {
        if (CancelToken.isCancel(e)) {
          result = OpenSetResult.cancelled;
          return;
        }
        error = apiErrorMessage(e);
        activeSet = null;
        result = OpenSetResult.failed;
      } catch (e) {
        if (isAsyncTapCancel(e)) {
          result = OpenSetResult.cancelled;
          return;
        }
        error = apiErrorMessage(e);
        activeSet = null;
        result = OpenSetResult.failed;
      } finally {
        if (openingSetId == setId) {
          openingSetId = null;
          notifyListeners();
        }
      }
    });

    if (outcome == AsyncTapOutcome.cancelled) {
      openingSetId = null;
      notifyListeners();
      return OpenSetResult.cancelled;
    }
    if (outcome == AsyncTapOutcome.ignored) {
      return OpenSetResult.cancelled;
    }
    return result;
  }

  void cancelOpen() {
    if (openingSetId == null) return;
    AsyncTapGuard.instance.cancel(reason: 'user-cancel');
    openingSetId = null;
    notifyListeners();
  }

  McqQuestion? get current {
    final qs = activeSet?.questions;
    if (qs == null || qs.isEmpty || index < 0 || index >= qs.length) return null;
    return qs[index];
  }

  void selectOption(String key) {
    if (revealed || quizFinished) return;
    selectedKey = key.toUpperCase();
    notifyListeners();
  }

  void reveal() {
    final q = current;
    if (q == null || revealed || selectedKey == null) return;
    revealed = true;
    answeredCount += 1;
    if (q.answerKey != null && selectedKey == q.answerKey) {
      correctCount += 1;
    }
    notifyListeners();
  }

  void next() {
    final qs = activeSet?.questions;
    if (qs == null) return;
    if (index >= qs.length - 1) {
      quizFinished = true;
      notifyListeners();
      return;
    }
    index += 1;
    selectedKey = null;
    revealed = false;
    notifyListeners();
  }

  void resetQuiz() {
    index = 0;
    selectedKey = null;
    revealed = false;
    correctCount = 0;
    answeredCount = 0;
    quizFinished = false;
    notifyListeners();
  }

  void clearQuiz() {
    activeSet = null;
    index = 0;
    selectedKey = null;
    revealed = false;
    correctCount = 0;
    answeredCount = 0;
    quizFinished = false;
    notifyListeners();
  }
}
