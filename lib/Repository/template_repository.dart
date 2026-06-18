// ignore_for_file: always_use_package_imports

import '../Storage/storage_engine.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PHASE-23 — TemplateRepository
// Architecture: TemplateEngine → TemplateRepository → StorageEngine
// ─────────────────────────────────────────────────────────────────────────────

// ─── Storage keys ────────────────────────────────────────────────────────────
const String _kTemplatesKey = 'template_records';
const String _kArchiveKey = 'template_archive';
const String _kMetadataKey = 'template_metadata_index';
const int _kMaxCacheSize = 200;

// ─────────────────────────────────────────────────────────────────────────────
// Result type — storage failures must never propagate as exceptions.
// Every public method returns TemplateResult<T>.
// ─────────────────────────────────────────────────────────────────────────────
sealed class TemplateResult<T> {
  const TemplateResult();
}

final class TemplateSuccess<T> extends TemplateResult<T> {
  const TemplateSuccess(this.value);
  final T value;
}

final class TemplateFailure<T> extends TemplateResult<T> {
  const TemplateFailure(this.reason);
  final String reason;
}

// ─────────────────────────────────────────────────────────────────────────────
// TemplateMetadata — lightweight index record. No layout or canvas data.
// ─────────────────────────────────────────────────────────────────────────────
final class TemplateMetadata {
  const TemplateMetadata({
    required this.id,
    required this.name,
    required this.category,
    required this.aspectRatio,
    required this.createdAt,
    this.updatedAt,
    this.tags = const <String>[],
    this.isPremium = false,
    this.version = 1,
  });

  final String id;
  final String name;
  final String category;
  final String aspectRatio;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<String> tags;
  final bool isPremium;
  final int version;

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'name': name,
        'category': category,
        'aspect_ratio': aspectRatio,
        'created_at': createdAt.toIso8601String(),
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
        'tags': tags,
        'is_premium': isPremium,
        'version': version,
      };

  static TemplateMetadata fromMap(Map<String, Object?> m) => TemplateMetadata(
        id: m['id'] as String,
        name: m['name'] as String,
        category: m['category'] as String,
        aspectRatio: m['aspect_ratio'] as String,
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: m['updated_at'] != null
            ? DateTime.parse(m['updated_at'] as String)
            : null,
        tags: (m['tags'] as List<Object?>?)
                ?.whereType<String>()
                .toList() ??
            const <String>[],
        isPremium: (m['is_premium'] as bool?) ?? false,
        version: (m['version'] as int?) ?? 1,
      );

  TemplateMetadata copyWith({
    String? name,
    String? category,
    String? aspectRatio,
    DateTime? updatedAt,
    List<String>? tags,
    bool? isPremium,
    int? version,
  }) =>
      TemplateMetadata(
        id: id,
        name: name ?? this.name,
        category: category ?? this.category,
        aspectRatio: aspectRatio ?? this.aspectRatio,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        tags: tags ?? this.tags,
        isPremium: isPremium ?? this.isPremium,
        version: version ?? this.version,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// TemplateRecord — full template record including payload.
// Payload is opaque to TemplateRepository (bytes owned by TemplateEngine).
// ─────────────────────────────────────────────────────────────────────────────
final class TemplateRecord {
  const TemplateRecord({
    required this.metadata,
    required this.payload,
  });

  final TemplateMetadata metadata;

  /// Opaque payload authored and understood only by TemplateEngine.
  final Map<String, Object?> payload;

  Map<String, Object?> toMap() => <String, Object?>{
        'metadata': metadata.toMap(),
        'payload': payload,
      };

  static TemplateRecord fromMap(Map<String, Object?> m) => TemplateRecord(
        metadata: TemplateMetadata.fromMap(
          (m['metadata'] as Map<Object?, Object?>).cast<String, Object?>(),
        ),
        payload: (m['payload'] as Map<Object?, Object?>).cast<String, Object?>(),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// TemplateRepository
//
// Responsibility: template persistence isolation only.
// No generation. No rendering. No execution. No UI. No business logic.
//
// Allowed callers  : TemplateEngine only.
// Allowed callees  : StorageEngine only.
//
// Cache ownership  : template cache, metadata cache, index cache, lookup cache.
// Forbidden caches : canvas cache, history cache, layer cache.
// ─────────────────────────────────────────────────────────────────────────────
final class TemplateRepository {
  TemplateRepository({required StorageEngine storage}) : _storage = storage;

  final StorageEngine _storage;

  // ── In-memory caches (template-scoped only) ───────────────────────────────
  final Map<String, TemplateRecord> _templateCache = <String, TemplateRecord>{};
  final Map<String, TemplateMetadata> _metadataCache =
      <String, TemplateMetadata>{};
  final Map<String, List<String>> _indexCache =
      <String, List<String>>{}; // category → [ids]
  final Map<String, TemplateRecord> _lookupCache =
      <String, TemplateRecord>{}; // arbitrary key → record

  // ─────────────────────────────────────────────────────────────────────────
  // SAVE
  // ─────────────────────────────────────────────────────────────────────────

  /// Persists a new [TemplateRecord].
  ///
  /// Validates the payload before writing. Returns [TemplateFailure] when
  /// validation fails or storage is unavailable.
  Future<TemplateResult<void>> save(TemplateRecord record) async {
    try {
      final TemplateResult<bool> validation =
          _validateRecord(record);
      if (validation is TemplateFailure<bool>) {
        return TemplateFailure<void>(
            'save: validation failed — ${(validation).reason}');
      }

      final List<TemplateRecord> records = await _loadRecords();
      final bool exists =
          records.any((r) => r.metadata.id == record.metadata.id);
      if (exists) {
        return TemplateFailure<void>(
            'save: id already exists — ${record.metadata.id}. Use update instead.');
      }

      records.add(record);
      await _persistRecords(records);
      _invalidateCacheFor(record.metadata.id);
      _invalidateIndexCache(record.metadata.category);
      return const TemplateSuccess<void>(null);
    } catch (e) {
      return TemplateFailure<void>('save failed: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LOAD
  // ─────────────────────────────────────────────────────────────────────────

  /// Loads a single [TemplateRecord] by [id].
  ///
  /// Checks the in-memory template cache first; falls through to storage.
  Future<TemplateResult<TemplateRecord>> loadById(String id) async {
    try {
      if (_templateCache.containsKey(id)) {
        return TemplateSuccess<TemplateRecord>(_templateCache[id]!);
      }
      final List<TemplateRecord> records = await _loadRecords();
      final TemplateRecord? match =
          records.where((r) => r.metadata.id == id).firstOrNull;
      if (match == null) {
        return TemplateFailure<TemplateRecord>('loadById: not found — $id');
      }
      _cacheRecord(match);
      return TemplateSuccess<TemplateRecord>(match);
    } catch (e) {
      return TemplateFailure<TemplateRecord>('loadById failed: $e');
    }
  }

  /// Loads all [TemplateRecord]s in storage.
  Future<TemplateResult<List<TemplateRecord>>> loadAll() async {
    try {
      final List<TemplateRecord> records = await _loadRecords();
      return TemplateSuccess<List<TemplateRecord>>(records);
    } catch (e) {
      return TemplateFailure<List<TemplateRecord>>('loadAll failed: $e');
    }
  }

  /// Loads all templates belonging to [category].
  ///
  /// Results are cached in the index cache keyed by category.
  Future<TemplateResult<List<TemplateRecord>>> loadByCategory(
      String category) async {
    try {
      final List<TemplateRecord> records = await _loadRecords();
      final List<TemplateRecord> filtered =
          records.where((r) => r.metadata.category == category).toList();
      _indexCache[category] = filtered.map((r) => r.metadata.id).toList();
      return TemplateSuccess<List<TemplateRecord>>(filtered);
    } catch (e) {
      return TemplateFailure<List<TemplateRecord>>(
          'loadByCategory failed: $e');
    }
  }

  /// Loads all templates matching any of the provided [tags].
  Future<TemplateResult<List<TemplateRecord>>> loadByTags(
      List<String> tags) async {
    try {
      final List<TemplateRecord> records = await _loadRecords();
      final List<TemplateRecord> filtered = records
          .where((r) =>
              r.metadata.tags.any((tag) => tags.contains(tag)))
          .toList();
      return TemplateSuccess<List<TemplateRecord>>(filtered);
    } catch (e) {
      return TemplateFailure<List<TemplateRecord>>('loadByTags failed: $e');
    }
  }

  /// Loads the most recently created [limit] templates.
  Future<TemplateResult<List<TemplateRecord>>> loadRecent(int limit) async {
    try {
      final List<TemplateRecord> records = await _loadRecords();
      final List<TemplateRecord> sorted = List<TemplateRecord>.from(records)
        ..sort((a, b) =>
            b.metadata.createdAt.compareTo(a.metadata.createdAt));
      return TemplateSuccess<List<TemplateRecord>>(
          sorted.take(limit).toList());
    } catch (e) {
      return TemplateFailure<List<TemplateRecord>>('loadRecent failed: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UPDATE
  // ─────────────────────────────────────────────────────────────────────────

  /// Replaces an existing record identified by [record.metadata.id].
  ///
  /// Returns [TemplateFailure] when the record does not exist.
  Future<TemplateResult<void>> update(TemplateRecord record) async {
    try {
      final TemplateResult<bool> validation = _validateRecord(record);
      if (validation is TemplateFailure<bool>) {
        return TemplateFailure<void>(
            'update: validation failed — ${(validation).reason}');
      }

      final List<TemplateRecord> records = await _loadRecords();
      final int index =
          records.indexWhere((r) => r.metadata.id == record.metadata.id);
      if (index < 0) {
        return TemplateFailure<void>(
            'update: not found — ${record.metadata.id}');
      }
      records[index] = record;
      await _persistRecords(records);
      _invalidateCacheFor(record.metadata.id);
      _invalidateIndexCache(record.metadata.category);
      return const TemplateSuccess<void>(null);
    } catch (e) {
      return TemplateFailure<void>('update failed: $e');
    }
  }

  /// Updates only the [TemplateMetadata] for an existing template.
  ///
  /// The opaque payload is preserved unchanged.
  Future<TemplateResult<void>> updateMetadata(
      String id, TemplateMetadata metadata) async {
    try {
      final List<TemplateRecord> records = await _loadRecords();
      final int index = records.indexWhere((r) => r.metadata.id == id);
      if (index < 0) {
        return TemplateFailure<void>('updateMetadata: not found — $id');
      }
      records[index] = TemplateRecord(
        metadata: metadata,
        payload: records[index].payload,
      );
      await _persistRecords(records);
      _invalidateCacheFor(id);
      _invalidateIndexCache(metadata.category);
      return const TemplateSuccess<void>(null);
    } catch (e) {
      return TemplateFailure<void>('updateMetadata failed: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DELETE
  // ─────────────────────────────────────────────────────────────────────────

  /// Permanently removes a template by [id] from active storage.
  Future<TemplateResult<void>> delete(String id) async {
    try {
      final List<TemplateRecord> records = await _loadRecords();
      final int before = records.length;
      String? category;
      records.removeWhere((r) {
        if (r.metadata.id == id) {
          category = r.metadata.category;
          return true;
        }
        return false;
      });
      if (records.length == before) {
        return TemplateFailure<void>('delete: not found — $id');
      }
      await _persistRecords(records);
      _invalidateCacheFor(id);
      if (category != null) _invalidateIndexCache(category!);
      return const TemplateSuccess<void>(null);
    } catch (e) {
      return TemplateFailure<void>('delete failed: $e');
    }
  }

  /// Permanently removes all templates in the given [category].
  Future<TemplateResult<int>> deleteByCategory(String category) async {
    try {
      final List<TemplateRecord> records = await _loadRecords();
      final int before = records.length;
      records.removeWhere((r) => r.metadata.category == category);
      final int removed = before - records.length;
      await _persistRecords(records);
      _indexCache.remove(category);
      _templateCache
          .removeWhere((_, r) => r.metadata.category == category);
      _metadataCache
          .removeWhere((_, m) => m.category == category);
      return TemplateSuccess<int>(removed);
    } catch (e) {
      return TemplateFailure<int>('deleteByCategory failed: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ARCHIVE
  // ─────────────────────────────────────────────────────────────────────────

  /// Moves a single template by [id] into the archive store.
  ///
  /// Removes the entry from active storage after archiving.
  Future<TemplateResult<void>> archiveById(String id) async {
    try {
      final List<TemplateRecord> records = await _loadRecords();
      final int index = records.indexWhere((r) => r.metadata.id == id);
      if (index < 0) {
        return TemplateFailure<void>('archiveById: not found — $id');
      }
      final TemplateRecord target = records.removeAt(index);
      final List<TemplateRecord> archive = await _loadArchive();
      archive.add(target);
      await _persistArchive(archive);
      await _persistRecords(records);
      _invalidateCacheFor(id);
      _invalidateIndexCache(target.metadata.category);
      return const TemplateSuccess<void>(null);
    } catch (e) {
      return TemplateFailure<void>('archiveById failed: $e');
    }
  }

  /// Moves all active templates into the archive.
  Future<TemplateResult<void>> archiveAll() async {
    try {
      final List<TemplateRecord> records = await _loadRecords();
      if (records.isEmpty) return const TemplateSuccess<void>(null);
      final List<TemplateRecord> archive = await _loadArchive();
      archive.addAll(records);
      await _persistArchive(archive);
      await _persistRecords(<TemplateRecord>[]);
      _clearAllCaches();
      return const TemplateSuccess<void>(null);
    } catch (e) {
      return TemplateFailure<void>('archiveAll failed: $e');
    }
  }

  /// Retrieves all archived templates.
  Future<TemplateResult<List<TemplateRecord>>> loadArchive() async {
    try {
      final List<TemplateRecord> archive = await _loadArchive();
      return TemplateSuccess<List<TemplateRecord>>(archive);
    } catch (e) {
      return TemplateFailure<List<TemplateRecord>>('loadArchive failed: $e');
    }
  }

  /// Permanently clears the archive store.
  Future<TemplateResult<void>> clearArchive() async {
    try {
      await _persistArchive(<TemplateRecord>[]);
      return const TemplateSuccess<void>(null);
    } catch (e) {
      return TemplateFailure<void>('clearArchive failed: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // METADATA RETRIEVAL
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns the [TemplateMetadata] for a single template by [id].
  ///
  /// Checks the in-memory metadata cache before going to storage.
  Future<TemplateResult<TemplateMetadata>> loadMetadataById(
      String id) async {
    try {
      if (_metadataCache.containsKey(id)) {
        return TemplateSuccess<TemplateMetadata>(_metadataCache[id]!);
      }
      final List<TemplateRecord> records = await _loadRecords();
      final TemplateRecord? match =
          records.where((r) => r.metadata.id == id).firstOrNull;
      if (match == null) {
        return TemplateFailure<TemplateMetadata>(
            'loadMetadataById: not found — $id');
      }
      _metadataCache[id] = match.metadata;
      return TemplateSuccess<TemplateMetadata>(match.metadata);
    } catch (e) {
      return TemplateFailure<TemplateMetadata>('loadMetadataById failed: $e');
    }
  }

  /// Returns [TemplateMetadata] for every active template.
  ///
  /// Persisted as a flat metadata index for fast catalog access.
  Future<TemplateResult<List<TemplateMetadata>>> loadAllMetadata() async {
    try {
      final List<TemplateRecord> records = await _loadRecords();
      final List<TemplateMetadata> metaList =
          records.map((r) => r.metadata).toList();
      for (final TemplateMetadata m in metaList) {
        _metadataCache[m.id] = m;
      }
      return TemplateSuccess<List<TemplateMetadata>>(metaList);
    } catch (e) {
      return TemplateFailure<List<TemplateMetadata>>(
          'loadAllMetadata failed: $e');
    }
  }

  /// Returns all distinct categories present in active storage.
  Future<TemplateResult<List<String>>> loadCategories() async {
    try {
      final List<TemplateRecord> records = await _loadRecords();
      final Set<String> categories =
          records.map((r) => r.metadata.category).toSet();
      return TemplateSuccess<List<String>>(categories.toList()..sort());
    } catch (e) {
      return TemplateFailure<List<String>>('loadCategories failed: $e');
    }
  }

  /// Returns the total number of active templates.
  Future<TemplateResult<int>> count() async {
    try {
      final List<TemplateRecord> records = await _loadRecords();
      return TemplateSuccess<int>(records.length);
    } catch (e) {
      return TemplateFailure<int>('count failed: $e');
    }
  }

  /// Returns the count of templates per category.
  Future<TemplateResult<Map<String, int>>> countByCategory() async {
    try {
      final List<TemplateRecord> records = await _loadRecords();
      final Map<String, int> counts = <String, int>{};
      for (final TemplateRecord r in records) {
        counts[r.metadata.category] =
            (counts[r.metadata.category] ?? 0) + 1;
      }
      return TemplateSuccess<Map<String, int>>(counts);
    } catch (e) {
      return TemplateFailure<Map<String, int>>('countByCategory failed: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // VALIDATION
  // ─────────────────────────────────────────────────────────────────────────

  /// Validates a [TemplateRecord] without persisting it.
  ///
  /// Returns [TemplateSuccess<true>] when valid.
  /// Returns [TemplateFailure] describing the first violation found.
  TemplateResult<bool> validateRecord(TemplateRecord record) =>
      _validateRecord(record);

  /// Validates the integrity of all records currently in storage.
  ///
  /// Checks for:
  /// • Missing required fields (id, name, category, aspect_ratio, created_at)
  /// • Unparseable timestamps
  /// • Duplicate IDs
  /// • Empty payloads
  Future<TemplateResult<bool>> validateStorage() async {
    try {
      final List<Map<String, Object?>> rawList =
          await _readRawList(_kTemplatesKey);
      final Set<String> seen = <String>{};

      for (int i = 0; i < rawList.length; i++) {
        final Map<String, Object?> raw = rawList[i];

        final Object? rawMeta = raw['metadata'];
        if (rawMeta == null || rawMeta is! Map) {
          return TemplateFailure<bool>(
              'validateStorage: entry[$i] missing metadata block');
        }
        final Map<String, Object?> meta =
            (rawMeta as Map<Object?, Object?>).cast<String, Object?>();

        for (final String field in const <String>[
          'id',
          'name',
          'category',
          'aspect_ratio',
          'created_at',
        ]) {
          final Object? v = meta[field];
          if (v == null || v is! String || (v).isEmpty) {
            return TemplateFailure<bool>(
                'validateStorage: entry[$i] missing or empty "$field"');
          }
        }

        final String id = meta['id'] as String;
        if (!seen.add(id)) {
          return TemplateFailure<bool>(
              'validateStorage: duplicate id "$id" at index $i');
        }

        try {
          DateTime.parse(meta['created_at'] as String);
        } catch (_) {
          return TemplateFailure<bool>(
              'validateStorage: entry[$i] unparseable created_at');
        }

        if (raw['payload'] == null || raw['payload'] is! Map) {
          return TemplateFailure<bool>(
              'validateStorage: entry[$i] missing or invalid payload');
        }
      }

      return const TemplateSuccess<bool>(true);
    } catch (e) {
      return TemplateFailure<bool>('validateStorage failed: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CACHE MANAGEMENT (template-scoped only)
  // ─────────────────────────────────────────────────────────────────────────

  /// Warms the metadata cache from storage.
  ///
  /// Call once at boot so metadata lookups are served from memory.
  Future<TemplateResult<void>> warmCache() async {
    try {
      final List<TemplateRecord> records = await _loadRecords();
      for (final TemplateRecord r in records) {
        _cacheRecord(r);
      }
      return const TemplateSuccess<void>(null);
    } catch (e) {
      return TemplateFailure<void>('warmCache failed: $e');
    }
  }

  /// Clears all in-memory caches owned by this repository.
  ///
  /// Does not touch storage. Use when memory pressure requires eviction.
  void evictCache() => _clearAllCaches();

  /// Returns the number of entries currently held in the template cache.
  int get cacheSize => _templateCache.length;

  // ─────────────────────────────────────────────────────────────────────────
  // CLEAR
  // ─────────────────────────────────────────────────────────────────────────

  /// Permanently deletes all active templates. Does not affect the archive.
  Future<TemplateResult<void>> clearAll() async {
    try {
      await _persistRecords(<TemplateRecord>[]);
      _clearAllCaches();
      return const TemplateSuccess<void>(null);
    } catch (e) {
      return TemplateFailure<void>('clearAll failed: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Private — internal helpers
  // ─────────────────────────────────────────────────────────────────────────

  TemplateResult<bool> _validateRecord(TemplateRecord record) {
    final TemplateMetadata m = record.metadata;
    if (m.id.isEmpty) {
      return const TemplateFailure<bool>('id must not be empty');
    }
    if (m.name.isEmpty) {
      return const TemplateFailure<bool>('name must not be empty');
    }
    if (m.category.isEmpty) {
      return const TemplateFailure<bool>('category must not be empty');
    }
    if (m.aspectRatio.isEmpty) {
      return const TemplateFailure<bool>('aspect_ratio must not be empty');
    }
    if (record.payload.isEmpty) {
      return const TemplateFailure<bool>('payload must not be empty');
    }
    return const TemplateSuccess<bool>(true);
  }

  Future<List<TemplateRecord>> _loadRecords() async {
    final List<Map<String, Object?>> rawList =
        await _readRawList(_kTemplatesKey);
    return rawList.map(TemplateRecord.fromMap).toList();
  }

  Future<List<TemplateRecord>> _loadArchive() async {
    final List<Map<String, Object?>> rawList =
        await _readRawList(_kArchiveKey);
    return rawList.map(TemplateRecord.fromMap).toList();
  }

  Future<List<Map<String, Object?>>> _readRawList(String key) async {
    final Object? raw = await _storage.read(key);
    if (raw == null) return <Map<String, Object?>>[];
    if (raw is! List) return <Map<String, Object?>>[];
    return raw
        .whereType<Map<Object?, Object?>>()
        .map((m) => m.cast<String, Object?>())
        .toList();
  }

  Future<void> _persistRecords(List<TemplateRecord> records) async {
    await _storage.write(
      _kTemplatesKey,
      records.map((r) => r.toMap()).toList(),
    );
  }

  Future<void> _persistArchive(List<TemplateRecord> archive) async {
    await _storage.write(
      _kArchiveKey,
      archive.map((r) => r.toMap()).toList(),
    );
  }

  void _cacheRecord(TemplateRecord record) {
    if (_templateCache.length >= _kMaxCacheSize) {
      // Evict oldest entry (insertion order) when cap is reached.
      _templateCache.remove(_templateCache.keys.first);
    }
    _templateCache[record.metadata.id] = record;
    _metadataCache[record.metadata.id] = record.metadata;
  }

  void _invalidateCacheFor(String id) {
    _templateCache.remove(id);
    _metadataCache.remove(id);
    _lookupCache.removeWhere((_, r) => r.metadata.id == id);
  }

  void _invalidateIndexCache(String category) {
    _indexCache.remove(category);
  }

  void _clearAllCaches() {
    _templateCache.clear();
    _metadataCache.clear();
    _indexCache.clear();
    _lookupCache.clear();
  }
}
