import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../data/repositories/fasih_server_repository.dart';
import 'server_source_state.dart';

@injectable
class ServerSourceCubit extends Cubit<ServerSourceState> {
  final FasihServerRepository _repo;

  ServerSourceCubit(this._repo) : super(const ServerSourceInitial());

  Future<void> load(String surveyPeriodId) async {
    emit(const ServerSourceLoading('Mengambil data dari server...'));
    try {
      final result = await _repo.fetchAssignmentsWithKeys(surveyPeriodId);
      emit(ServerSourceLoaded(result.assignments, result.keyMap));
    } catch (e) {
      emit(ServerSourceError(e.toString()));
    }
  }
}
