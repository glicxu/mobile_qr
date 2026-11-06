import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'history_database.g.dart';

class HistoryEntries extends Table {
  TextColumn get id => text()();
  IntColumn get activityKind => integer()();
  IntColumn get payloadKind => integer()();
  TextColumn get rawPayload => text()();
  TextColumn get displayHost => text().nullable()();
  TextColumn get title => text().nullable()();
  TextColumn get note => text().nullable()();
  BoolColumn get isInHistory => boolean().withDefault(const Constant(true))();
  DateTimeColumn get savedAtUtc => dateTime().nullable()();
  TextColumn get verificationCode => text().nullable()();
  TextColumn get registrableDomain => text().nullable()();
  BlobColumn get qrPngBytes => blob().nullable()();
  TextColumn get codeFormat => text().withDefault(const Constant('qrCode'))();
  IntColumn get source => integer()();
  DateTimeColumn get createdAtUtc => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('SavedCollectionRow')
class SavedCollections extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get normalizedName => text().unique()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

class SavedCollectionItems extends Table {
  TextColumn get collectionId =>
      text().references(SavedCollections, #id, onDelete: KeyAction.cascade)();
  TextColumn get entryId =>
      text().references(HistoryEntries, #id, onDelete: KeyAction.cascade)();
  @override
  Set<Column<Object>> get primaryKey => {collectionId, entryId};
}

class SavedTags extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

class SavedTagItems extends Table {
  TextColumn get tagId =>
      text().references(SavedTags, #id, onDelete: KeyAction.cascade)();
  TextColumn get entryId =>
      text().references(HistoryEntries, #id, onDelete: KeyAction.cascade)();
  @override
  Set<Column<Object>> get primaryKey => {tagId, entryId};
}

@DriftDatabase(
  tables: [
    HistoryEntries,
    SavedCollections,
    SavedCollectionItems,
    SavedTags,
    SavedTagItems,
  ],
)
final class HistoryDatabase extends _$HistoryDatabase {
  HistoryDatabase() : super(driftDatabase(name: 'dali_qr_history'));

  HistoryDatabase.forTesting(super.connection);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (_) => customStatement('PRAGMA foreign_keys = ON'),
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.addColumn(
          historyEntries,
          historyEntries.verificationCode,
        );
        await migrator.addColumn(
          historyEntries,
          historyEntries.registrableDomain,
        );
        await migrator.addColumn(historyEntries, historyEntries.qrPngBytes);
      }
      if (from < 3) {
        await migrator.addColumn(historyEntries, historyEntries.title);
        await migrator.addColumn(historyEntries, historyEntries.note);
      }
      if (from < 4) {
        await migrator.addColumn(historyEntries, historyEntries.isInHistory);
        await migrator.addColumn(historyEntries, historyEntries.savedAtUtc);
      }
      if (from < 5) {
        await migrator.addColumn(historyEntries, historyEntries.codeFormat);
      }
      if (from < 6) {
        await migrator.createTable(savedCollections);
        await migrator.createTable(savedCollectionItems);
        await migrator.createTable(savedTags);
        await migrator.createTable(savedTagItems);
      }
    },
  );
}
