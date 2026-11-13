import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqf;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pacer/src/local/local_store.dart';
import 'package:pacer/src/local/sqlite_local_store.dart';

/// Opens the persistent SQLite store on Android, iOS, macOS, Linux, and Windows.
Future<LocalStore> openPlatformLocalStore() async {
  if (Platform.isLinux || Platform.isWindows) {
    sqfliteFfiInit();
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    final dbPath = p.join(dir.path, 'pacer_offline_v1.db');
    return SqliteLocalStore.open(factory: databaseFactoryFfi, path: dbPath);
  }
  final dir = await sqf.getDatabasesPath();
  final dbPath = p.join(dir, 'pacer_offline_v1.db');
  return SqliteLocalStore.open(factory: sqf.databaseFactory, path: dbPath);
}

/// Opens an isolated in-memory SQLite store for headless tests.
Future<SqliteLocalStore> openInMemorySqliteStore() {
  sqfliteFfiInit();
  return SqliteLocalStore.open(
    factory: databaseFactoryFfi,
    path: inMemoryDatabasePath,
  );
}
