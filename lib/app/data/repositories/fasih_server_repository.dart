import 'package:injectable/injectable.dart';

import '../models/fasih_assignment.dart';
import '../providers/fasih_survey_api.dart';
import 'fasih_auth_repository.dart';

@singleton
class FasihServerRepository {
  final FasihSurveyApi _api;
  final FasihAuthRepository _auth;

  FasihServerRepository(this._api, this._auth);

  bool get isAuthenticated => _auth.isLoggedIn;

  /// Fetches assignments for [surveyPeriodId] and builds a map of
  /// `regionId → wrappedDataKeyB64` for all regions with a key configured.
  Future<({List<FasihAssignment> assignments, Map<String, String> keyMap})>
      fetchAssignmentsWithKeys(String surveyPeriodId) async {
    final assignments = await _api.getAssignments(surveyPeriodId);
    final keyMap = <String, String>{};
    for (final a in assignments) {
      final key = a.wrappedDataKey;
      if (key != null && key.isNotEmpty) {
        keyMap[a.regionId] = key;
      }
    }
    return (assignments: assignments, keyMap: keyMap);
  }
}
