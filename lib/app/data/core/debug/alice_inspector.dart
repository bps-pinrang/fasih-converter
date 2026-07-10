import 'package:alice/alice.dart';
import 'package:alice_dio/alice_dio_adapter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

// Defaults: showNotification=true, showInspectorOnShake=true.
final Alice _alice = Alice();

/// Returns the global Alice instance only in debug builds.
Alice? get aliceInstance => kDebugMode ? _alice : null;

/// Creates and wires a new [AliceDioAdapter] into the global Alice instance.
/// Returns null in release builds.
AliceDioAdapter? createAliceDioAdapter() {
  if (!kDebugMode) return null;
  final adapter = AliceDioAdapter();
  _alice.addAdapter(adapter);
  return adapter;
}

/// Sets the navigator key for the alice inspector.
/// Call this once the root [AppRouter] is available.
void initAliceNavigatorKey(GlobalKey<NavigatorState> key) {
  if (kDebugMode) _alice.setNavigatorKey(key);
}
