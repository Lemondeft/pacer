import 'package:pacer/src/local/local_store.dart';
import 'package:pacer/src/local/memory_local_store.dart';

/// Web/non-IO store factory: avoids `dart:io`/`dart:ffi` while providing full
/// offline-first runtime semantics for the session.
Future<LocalStore> openPlatformLocalStore() async => MemoryLocalStore();
