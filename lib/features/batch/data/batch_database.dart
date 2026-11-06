import 'package:drift/drift.dart';

/// Isolated, explicitly versioned SQL store. No generated tables or watches are
/// used: the repository refreshes after each committed transaction.
final class BatchDatabase extends GeneratedDatabase {
  BatchDatabase(super.executor);
  @override
  int get schemaVersion => 1;
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];
  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement('PRAGMA secure_delete = ON');
    },
    onCreate: (_) async {
      await customStatement('''CREATE TABLE batch_sessions (
        id TEXT PRIMARY KEY NOT NULL, name TEXT NOT NULL,
        count_duplicates INTEGER NOT NULL CHECK(count_duplicates IN (0,1)),
        created_utc INTEGER NOT NULL, updated_utc INTEGER NOT NULL)''');
      await customStatement('''CREATE TABLE batch_items (
        id TEXT PRIMARY KEY NOT NULL, session_id TEXT NOT NULL REFERENCES batch_sessions(id) ON DELETE CASCADE,
        value TEXT NOT NULL, format TEXT NOT NULL, source TEXT NOT NULL,
        quantity INTEGER NOT NULL CHECK(quantity BETWEEN 1 AND 999999),
        first_utc INTEGER NOT NULL, last_utc INTEGER NOT NULL, position INTEGER NOT NULL,
        UNIQUE(session_id, format, value))''');
      await customStatement(
        'CREATE INDEX batch_item_order ON batch_items(session_id, position)',
      );
    },
  );
}
