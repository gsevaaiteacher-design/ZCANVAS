// ignore_for_file: always_use_package_imports

import '../Storage/storage_engine.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PHASE-22 — HistoryRepository
// Architecture: HistoryEngine → HistoryRepository → StorageEngine
// ─────────────────────────────────────────────────────────────────────────────

// ─── Storage keys ────────────────────────────────────────────────────────────
const String _kHistoryKey = 'history_records';
const String _kArchiveKey = 'history_archive';
const int _kMaxHistoryEntries = 500;

// ─────────────────────────────────────────────────────────────────────────────
// Result type — storage failures must never propagate as exceptions.
// Every public method returns HistoryResult<T>.
// ─────────────────────────────────────────────────────────────────────────────
sealed class HistoryResult<T> {
  const HistoryResult();
}

final class HistorySuccess<T> extends HistoryResult<T> {
  const HistorySuccess(this.value);
  final T value;
}

final class HistoryFailure<T> extends HistoryResult<T> {
  const HistoryFailure(this.reason);
  final String reason;
}

// ─────────────────────────────────────────────────────────────────────────────
// HistoryEntry — the atom of history.
// Plain data transfer object; no logic.
// ─────────────────────────────────────────────────────────────────────────────
final class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.timestamp,
    required this.payload,
    this.label,
  });

  final String id;
  final DateTime timestamp;
  final Map<String, Object?> payload;
  final String? label;

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'payload': payload,
        if (label != null) 'label': label,
      };

  static HistoryEntry fromMap(Map<String, Object?> map) => HistoryEntry(
        id: map['id'] as String,
        timestamp: DateTime.parse(map['timestamp'] as String),
        payload: (map['payload'] as Map<Object?, Object?>)
            .cast<String, Object?>(),
        label: map['label'] as String?,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// HistoryRepository
//
// Responsibility: history persistence isolation only.
// No business logic. No rendering logic. No execution logic.
// No controller logic. No UI.
//
// Allowed callers  : HistoryEngine only.
// Allowed callees  : StorageEngine only.
// ─────────────────────────────────────────────────────────────────────────────
final class HistoryRepository {
  const HistoryRepository({required StorageEngine storage})
      : _storage = storage;

  final StorageEngine _storage;

  // ── Save ──────────────────────────────────────────────────────────────────

  /// Persists a single [HistoryEntry].
  ///
  /// Appends the entry to the current record list.
  /// Enforces the maximum entry cap by evicting the oldest entries first.
  /// Never throws; storage failure is reported via [HistoryFailure].
  Future<HistoryResult<void>> saveEntry(HistoryEntry entry) async {
    try {
      final List<HistoryEntry> current = await _loadEntries();
      current.add(entry);
      final List<HistoryEntry> capped = _applyCapLimit(current);
      await _persistEntries(capped);
      return const HistorySuccess<void>(null);
    } catch (e) {
      return HistoryFailure<void>('saveEntry failed: $e');
    }
  }

  /// Replaces the entire history record set with [entries].
  ///
  /// Use when HistoryEngine needs an atomic batch write.
  Future<HistoryResult<void>> saveAll(List<HistoryEntry> entries) async {
    try {
      final List<HistoryEntry> capped = _applyCapLimit(entries);
      await _persistEntries(capped);
      return const HistorySuccess<void>(null);
    } catch (e) {
      return HistoryFailure<void>('saveAll failed: $e');
    }
  }

  // ── Load ──────────────────────────────────────────────────────────────────

  /// Retrieves all current (non-archived) history entries in ascending
  /// chronological order (oldest first).
  ///
  /// Returns an empty list when no history has been saved yet.
  Future<HistoryResult<List<HistoryEntry>>> loadAll() async {
    try {
      final List<HistoryEntry> entries = await _loadEntries();
      return HistorySuccess<List<HistoryEntry>>(entries);
    } catch (e) {
      return HistoryFailure<List<HistoryEntry>>('loadAll failed: $e');
    }
  }

  /// Retrieves a single entry by [id].
  ///
  /// Returns [HistoryFailure] when the entry does not exist.
  Future<HistoryResult<HistoryEntry>> loadById(String id) async {
    try {
      final List<HistoryEntry> entries = await _loadEntries();
      final HistoryEntry? match =
          entries.where((e) => e.id == id).firstOrNull;
      if (match == null) {
        return HistoryFailure<HistoryEntry>('loadById: entry not found — $id');
      }
      return HistorySuccess<HistoryEntry>(match);
    } catch (e) {
      return HistoryFailure<HistoryEntry>('loadById failed: $e');
    }
  }

  /// Retrieves all entries whose [HistoryEntry.timestamp] falls inside the
  /// closed interval [[from], [to]].
  Future<HistoryResult<List<HistoryEntry>>> loadRange({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final List<HistoryEntry> entries = await _loadEntries();
      final List<HistoryEntry> range = entries
          .where((e) =>
              !e.timestamp.isBefore(from) && !e.timestamp.isAfter(to))
          .toList();
      return HistorySuccess<List<HistoryEntry>>(range);
    } catch (e) {
      return HistoryFailure<List<HistoryEntry>>('loadRange failed: $e');
    }
  }

  // ── Retrieval helpers ─────────────────────────────────────────────────────

  /// Returns the most recent entry or [HistoryFailure] when history is empty.
  Future<HistoryResult<HistoryEntry>> retrieveLatest() async {
    try {
      final List<HistoryEntry> entries = await _loadEntries();
      if (entries.isEmpty) {
        return const HistoryFailure<HistoryEntry>(
            'retrieveLatest: history is empty');
      }
      return HistorySuccess<HistoryEntry>(entries.last);
    } catch (e) {
      return HistoryFailure<HistoryEntry>('retrieveLatest failed: $e');
    }
  }

  /// Returns [count] entries before (and not including) [beforeId],
  /// ordered oldest-first.
  ///
  /// Used by HistoryEngine when walking backward.
  Future<HistoryResult<List<HistoryEntry>>> retrieveBefore({
    required String beforeId,
    required int count,
  }) async {
    try {
      final List<HistoryEntry> entries = await _loadEntries();
      final int pivot =
          entries.indexWhere((e) => e.id == beforeId);
      if (pivot < 0) {
        return HistoryFailure<List<HistoryEntry>>(
            'retrieveBefore: anchor not found — $beforeId');
      }
      final List<HistoryEntry> slice = entries
          .sublist(0, pivot)
          .reversed
          .take(count)
          .toList()
          .reversed
          .toList();
      return HistorySuccess<List<HistoryEntry>>(slice);
    } catch (e) {
      return HistoryFailure<List<HistoryEntry>>('retrieveBefore failed: $e');
    }
  }

  /// Returns [count] entries after (and not including) [afterId],
  /// ordered oldest-first.
  ///
  /// Used by HistoryEngine when walking forward.
  Future<HistoryResult<List<HistoryEntry>>> retrieveAfter({
    required String afterId,
    required int count,
  }) async {
    try {
      final List<HistoryEntry> entries = await _loadEntries();
      final int pivot =
          entries.indexWhere((e) => e.id == afterId);
      if (pivot < 0) {
        return HistoryFailure<List<HistoryEntry>>(
            'retrieveAfter: anchor not found — $afterId');
      }
      final int start = pivot + 1;
      if (start >= entries.length) {
        return const HistorySuccess<List<HistoryEntry>>(<HistoryEntry>[]);
      }
      final List<HistoryEntry> slice =
          entries.sublist(start).take(count).toList();
      return HistorySuccess<List<HistoryEntry>>(slice);
    } catch (e) {
      return HistoryFailure<List<HistoryEntry>>('retrieveAfter failed: $e');
    }
  }

  // ── Archive ───────────────────────────────────────────────────────────────

  /// Moves all current entries into the archive store and clears the active
  /// history record.
  ///
  /// Archived entries are preserved and queryable via [loadArchive].
  Future<HistoryResult<void>> archiveAll() async {
    try {
      final List<HistoryEntry> current = await _loadEntries();
      if (current.isEmpty) return const HistorySuccess<void>(null);

      final List<HistoryEntry> existingArchive = await _loadArchiveEntries();
      final List<HistoryEntry> merged = <HistoryEntry>[
        ...existingArchive,
        ...current,
      ];
      await _persistArchiveEntries(merged);
      await _persistEntries(<HistoryEntry>[]);
      return const HistorySuccess<void>(null);
    } catch (e) {
      return HistoryFailure<void>('archiveAll failed: $e');
    }
  }

  /// Moves a single entry identified by [id] from the active records to the
  /// archive. The entry is removed from active history after archiving.
  Future<HistoryResult<void>> archiveEntry(String id) async {
    try {
      final List<HistoryEntry> entries = await _loadEntries();
      final int index = entries.indexWhere((e) => e.id == id);
      if (index < 0) {
        return HistoryFailure<void>('archiveEntry: not found — $id');
      }
      final HistoryEntry target = entries.removeAt(index);
      final List<HistoryEntry> archive = await _loadArchiveEntries();
      archive.add(target);
      await _persistArchiveEntries(archive);
      await _persistEntries(entries);
      return const HistorySuccess<void>(null);
    } catch (e) {
      return HistoryFailure<void>('archiveEntry failed: $e');
    }
  }

  /// Retrieves all archived entries, oldest first.
  Future<HistoryResult<List<HistoryEntry>>> loadArchive() async {
    try {
      final List<HistoryEntry> archive = await _loadArchiveEntries();
      return HistorySuccess<List<HistoryEntry>>(archive);
    } catch (e) {
      return HistoryFailure<List<HistoryEntry>>('loadArchive failed: $e');
    }
  }

  /// Permanently deletes all archived entries.
  Future<HistoryResult<void>> clearArchive() async {
    try {
      await _persistArchiveEntries(<HistoryEntry>[]);
      return const HistorySuccess<void>(null);
    } catch (e) {
      return HistoryFailure<void>('clearArchive failed: $e');
    }
  }

  // ── Validation ────────────────────────────────────────────────────────────

  /// Validates the integrity of the stored history.
  ///
  /// Checks:
  /// • Every entry can be deserialized without error.
  /// • No duplicate IDs exist.
  /// • Timestamps are parseable ISO-8601 strings.
  ///
  /// Returns [HistorySuccess<true>] when valid;
  /// [HistoryFailure] describing the first detected violation otherwise.
  Future<HistoryResult<bool>> validateStorage() async {
    try {
      final List<Map<String, Object?>> rawList =
          await _readRawList(_kHistoryKey);
      final Set<String> seen = <String>{};
      for (int i = 0; i < rawList.length; i++) {
        final Map<String, Object?> raw = rawList[i];

        // ID presence and uniqueness
        final Object? id = raw['id'];
        if (id == null || id is! String || id.isEmpty) {
          return HistoryFailure<bool>(
              'validateStorage: entry[$i] has missing/invalid id');
        }
        if (!seen.add(id)) {
          return HistoryFailure<bool>(
              'validateStorage: duplicate id "$id" at index $i');
        }

        // Timestamp parseable
        final Object? ts = raw['timestamp'];
        if (ts == null || ts is! String) {
          return HistoryFailure<bool>(
              'validateStorage: entry[$i] has missing timestamp');
        }
        try {
          DateTime.parse(ts);
        } catch (_) {
          return HistoryFailure<bool>(
              'validateStorage: entry[$i] has unparseable timestamp "$ts"');
        }

        // Payload is a map
        if (raw['payload'] == null || raw['payload'] is! Map) {
          return HistoryFailure<bool>(
              'validateStorage: entry[$i] has missing/invalid payload');
        }
      }
      return const HistorySuccess<bool>(true);
    } catch (e) {
      return HistoryFailure<bool>('validateStorage failed: $e');
    }
  }

  // ── Clear ─────────────────────────────────────────────────────────────────

  /// Permanently deletes all active history entries.
  ///
  /// Does not affect the archive.
  Future<HistoryResult<void>> clearAll() async {
    try {
      await _persistEntries(<HistoryEntry>[]);
      return const HistorySuccess<void>(null);
    } catch (e) {
      return HistoryFailure<void>('clearAll failed: $e');
    }
  }

  /// Permanently deletes a single entry by [id] from active history.
  Future<HistoryResult<void>> deleteEntry(String id) async {
    try {
      final List<HistoryEntry> entries = await _loadEntries();
      final int before = entries.length;
      entries.removeWhere((e) => e.id == id);
      if (entries.length == before) {
        return HistoryFailure<void>('deleteEntry: not found — $id');
      }
      await _persistEntries(entries);
      return const HistorySuccess<void>(null);
    } catch (e) {
      return HistoryFailure<void>('deleteEntry failed: $e');
    }
  }

  // ── Count ─────────────────────────────────────────────────────────────────

  /// Returns the number of entries currently in active history.
  Future<HistoryResult<int>> count() async {
    try {
      final List<HistoryEntry> entries = await _loadEntries();
      return HistorySuccess<int>(entries.length);
    } catch (e) {
      return HistoryFailure<int>('count failed: $e');
    }
  }

  // ─── Private persistence helpers ─────────────────────────────────────────

  Future<List<HistoryEntry>> _loadEntries() async {
    final List<Map<String, Object?>> rawList =
        await _readRawList(_kHistoryKey);
    return rawList.map(HistoryEntry.fromMap).toList();
  }

  Future<List<HistoryEntry>> _loadArchiveEntries() async {
    final List<Map<String, Object?>> rawList =
        await _readRawList(_kArchiveKey);
    return rawList.map(HistoryEntry.fromMap).toList();
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

  Future<void> _persistEntries(List<HistoryEntry> entries) async {
    await _storage.write(
      _kHistoryKey,
      entries.map((e) => e.toMap()).toList(),
    );
  }

  Future<void> _persistArchiveEntries(List<HistoryEntry> entries) async {
    await _storage.write(
      _kArchiveKey,
      entries.map((e) => e.toMap()).toList(),
    );
  }

  // ─── Cap enforcement ──────────────────────────────────────────────────────

  List<HistoryEntry> _applyCapLimit(List<HistoryEntry> entries) {
    if (entries.length <= _kMaxHistoryEntries) return entries;
    return entries.sublist(entries.length - _kMaxHistoryEntries);
  }
}
