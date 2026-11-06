import 'package:drift/drift.dart';

import '../domain/saved_organization.dart';
import 'history_database.dart';

final class DriftSavedOrganizationRepository
    implements SavedOrganizationRepository {
  const DriftSavedOrganizationRepository(this.database);
  final HistoryDatabase database;

  @override
  Stream<SavedOrganization> watchOrganization() => database
      .customSelect(
        '''
    SELECT 'collection' AS kind, id AS first_value, name AS second_value, '' AS third_value FROM saved_collections
    UNION ALL SELECT 'member', entry_id, collection_id, '' FROM saved_collection_items
    UNION ALL SELECT 'tag', i.entry_id, t.id, t.name FROM saved_tag_items i JOIN saved_tags t ON t.id = i.tag_id
  ''',
        readsFrom: {
          database.savedCollections,
          database.savedCollectionItems,
          database.savedTags,
          database.savedTagItems,
        },
      )
      .watch()
      .map((rows) {
        final collections = <SavedCollection>[];
        final memberships = <String, List<String>>{};
        final tags = <String, List<String>>{};
        for (final row in rows) {
          final first = row.read<String>('first_value');
          final second = row.read<String>('second_value');
          switch (row.read<String>('kind')) {
            case 'collection':
              collections.add(SavedCollection(id: first, name: second));
            case 'member':
              memberships.putIfAbsent(first, () => []).add(second);
            case 'tag':
              tags
                  .putIfAbsent(first, () => [])
                  .add(row.read<String>('third_value'));
          }
        }
        collections.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        for (final values in tags.values) {
          values.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        }
        return SavedOrganization(
          collections: List.unmodifiable(collections),
          memberships: Map.unmodifiable(
            memberships.map(
              (key, value) => MapEntry(key, List<String>.unmodifiable(value)),
            ),
          ),
          tags: Map.unmodifiable(
            tags.map(
              (key, value) => MapEntry(key, List<String>.unmodifiable(value)),
            ),
          ),
        );
      });

  Future<void> _checkName(String name, {String? except}) async {
    final duplicate =
        await (database.select(database.savedCollections)
              ..where((row) => row.normalizedName.equals(name.toLowerCase())))
            .getSingleOrNull();
    if (duplicate != null && duplicate.id != except) {
      throw ArgumentError('A collection with that name already exists.');
    }
  }

  @override
  Future<void> createCollection(String id, String name) =>
      database.transaction(() async {
        final clean = organizationName(name);
        await _checkName(clean);
        if ((await database.select(database.savedCollections).get()).length >=
            100) {
          throw ArgumentError('The limit is 100 collections.');
        }
        await database
            .into(database.savedCollections)
            .insert(
              SavedCollectionsCompanion.insert(
                id: id,
                name: clean,
                normalizedName: clean.toLowerCase(),
              ),
            );
      });

  @override
  Future<void> renameCollection(String id, String name) =>
      database.transaction(() async {
        final clean = organizationName(name);
        await _checkName(clean, except: id);
        await (database.update(
          database.savedCollections,
        )..where((row) => row.id.equals(id))).write(
          SavedCollectionsCompanion(
            name: Value(clean),
            normalizedName: Value(clean.toLowerCase()),
          ),
        );
      });

  @override
  Future<void> deleteCollection(String id) async {
    await (database.delete(
      database.savedCollections,
    )..where((row) => row.id.equals(id))).go();
  }

  @override
  Future<void> organizeSavedItem(
    String entryId, {
    required Set<String> collectionIds,
    required List<String> tags,
  }) => database.transaction(() async {
    final item = await (database.select(
      database.historyEntries,
    )..where((row) => row.id.equals(entryId))).getSingleOrNull();
    if (item?.savedAtUtc == null) {
      throw ArgumentError('Only Saved items can be organized.');
    }
    final available = (await database.select(database.savedCollections).get())
        .map((row) => row.id)
        .toSet();
    if (!available.containsAll(collectionIds)) {
      throw ArgumentError('A selected collection no longer exists.');
    }
    final cleanTags = <String, String>{};
    for (final tag in tags) {
      if (tag.trim().isEmpty) continue;
      final name = organizationName(tag, maxLength: 40);
      if (name.contains(',')) {
        throw ArgumentError('Tags cannot contain commas.');
      }
      cleanTags.putIfAbsent(name.toLowerCase(), () => name);
    }
    if (cleanTags.length > 20) {
      throw ArgumentError('Use at most 20 tags per item.');
    }
    await (database.delete(
      database.savedCollectionItems,
    )..where((row) => row.entryId.equals(entryId))).go();
    await (database.delete(
      database.savedTagItems,
    )..where((row) => row.entryId.equals(entryId))).go();
    for (final id in collectionIds) {
      await database
          .into(database.savedCollectionItems)
          .insert(
            SavedCollectionItemsCompanion.insert(
              collectionId: id,
              entryId: entryId,
            ),
          );
    }
    for (final tag in cleanTags.entries) {
      await database
          .into(database.savedTags)
          .insert(
            SavedTagsCompanion.insert(id: tag.key, name: tag.value),
            mode: InsertMode.insertOrIgnore,
          );
      await database
          .into(database.savedTagItems)
          .insert(
            SavedTagItemsCompanion.insert(tagId: tag.key, entryId: entryId),
          );
    }
    await database.customStatement(
      'DELETE FROM saved_tags WHERE id NOT IN (SELECT tag_id FROM saved_tag_items)',
    );
  });
}
