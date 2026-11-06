import 'package:drift/drift.dart';

/// Separate namespace; existing History/Saved schema and retention are untouched.
final class PaymentsDatabase extends GeneratedDatabase {
  PaymentsDatabase(super.executor);
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
      await customStatement(
        '''CREATE TABLE payment_profiles (
        id TEXT PRIMARY KEY NOT NULL, label TEXT NOT NULL, link TEXT NOT NULL,
        notes TEXT NOT NULL, created_utc INTEGER NOT NULL, updated_utc INTEGER NOT NULL)''',
      );
      await customStatement('''CREATE TABLE payment_templates (
        id TEXT PRIMARY KEY NOT NULL,
        profile_id TEXT NOT NULL REFERENCES payment_profiles(id) ON DELETE RESTRICT,
        label TEXT NOT NULL, link TEXT NOT NULL,
        state TEXT NOT NULL CHECK(state IN ('draft','ready','archived')),
        created_utc INTEGER NOT NULL, updated_utc INTEGER NOT NULL)''');
      await customStatement(
        'CREATE INDEX payment_template_profile ON payment_templates(profile_id)',
      );
    },
  );
}
