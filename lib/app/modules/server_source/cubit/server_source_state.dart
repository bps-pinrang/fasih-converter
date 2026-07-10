import '../../../data/models/fasih_assignment.dart';

sealed class ServerSourceState {
  const ServerSourceState();
}

class ServerSourceInitial extends ServerSourceState {
  const ServerSourceInitial();
}

class ServerSourceLoading extends ServerSourceState {
  const ServerSourceLoading(this.message);
  final String message;
}

class ServerSourceLoaded extends ServerSourceState {
  const ServerSourceLoaded(this.assignments, this.keyMap);
  final List<FasihAssignment> assignments;
  final Map<String, String> keyMap;
}

class ServerSourceError extends ServerSourceState {
  const ServerSourceError(this.message);
  final String message;
}
