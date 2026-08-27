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
  IntColumn get source => integer()();
  DateTimeColumn get createdAtUtc => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [HistoryEntries])
final class HistoryDatabase extends _$HistoryDatabase {
  HistoryDatabase() : super(driftDatabase(name: 'dali_qr_history'));

  HistoryDatabase.forTesting(super.connection);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
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
    },
  );
}
