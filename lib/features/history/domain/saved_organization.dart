final class SavedCollection {
  const SavedCollection({required this.id, required this.name});
  final String id;
  final String name;
}

final class SavedOrganization {
  const SavedOrganization({
    this.collections = const [],
    this.memberships = const {},
    this.tags = const {},
  });
  final List<SavedCollection> collections;
  final Map<String, List<String>> memberships;
  final Map<String, List<String>> tags;
}

abstract interface class SavedOrganizationRepository {
  Stream<SavedOrganization> watchOrganization();
  Future<void> createCollection(String id, String name);
  Future<void> renameCollection(String id, String name);
  Future<void> deleteCollection(String id);
  Future<void> organizeSavedItem(
    String entryId, {
    required Set<String> collectionIds,
    required List<String> tags,
  });
}

String organizationName(String value, {int maxLength = 60}) {
  final name = value.trim();
  if (name.isEmpty ||
      name.length > maxLength ||
      RegExp(r'[\x00-\x1f\x7f-\x9f]').hasMatch(name)) {
    throw ArgumentError(
      'Use a name of 1–$maxLength characters without line breaks or control characters.',
    );
  }
  return name;
}
