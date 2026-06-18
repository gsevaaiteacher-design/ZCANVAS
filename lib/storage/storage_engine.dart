// ignore_for_file: avoid_catches_without_on_clauses

// ============================================================
// StorageEngine — Phase-3 Persistence Authority
// ============================================================
// OWNS: data persistence, local cache, autosave, recovery.
// MUST NOT: touch LayerEngine, HistoryEngine, RenderEngine,
//           EditorController, ExportEngine, UI, or network.
// ============================================================

enum StorageDomain {
  design,
  autosave,
  recovery,
  settings,
  historySnapshot,
  cache,
}

enum StorageRecordType {
  design,
  autosave,
  recovery,
  settings,
  historySnapshot,
  cache,
}

// ── Mandatory record envelope ────────────────────────────────
class StorageRecord {
  final String recordId;
  final StorageRecordType recordType;
  final int schemaVersion;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String sourceVersion;
  final bool futureMigrationFlag;
  final Map<String, dynamic> payload;

  const StorageRecord({
    required this.recordId,
    required this.recordType,
    required this.schemaVersion,
    required this.createdAt,
    required this.updatedAt,
    required this.sourceVersion,
    required this.futureMigrationFlag,
    required this.payload,
  });

  Map<String, dynamic> toMap() => {
        'recordId': recordId,
        'recordType': recordType.name,
        'schemaVersion': schemaVersion,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'sourceVersion': sourceVersion,
        'futureMigrationFlag': futureMigrationFlag,
        'payload': payload,
      };

  factory StorageRecord.fromMap(Map<String, dynamic> map) {
    return StorageRecord(
      recordId: map['recordId'] as String,
      recordType: StorageRecordType.values.firstWhere(
        (e) => e.name == map['recordType'],
        orElse: () => StorageRecordType.design,
      ),
      schemaVersion: map['schemaVersion'] as int,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      sourceVersion: map['sourceVersion'] as String,
      futureMigrationFlag: map['futureMigrationFlag'] as bool? ?? false,
      payload: Map<String, dynamic>.from(map['payload'] as Map),
    );
  }
}

// ── Storage stats ────────────────────────────────────────────
class StorageStats {
  final int designCount;
  final int autosaveCount;
  final int recoveryCount;
  final int historySnapshotCount;
  final int settingsCount;
  final int cacheCount;
  final DateTime reportedAt;

  const StorageStats({
    required this.designCount,
    required this.autosaveCount,
    required this.recoveryCount,
    required this.historySnapshotCount,
    required this.settingsCount,
    required this.cacheCount,
    required this.reportedAt,
  });

  int get totalRecords =>
      designCount +
      autosaveCount +
      recoveryCount +
      historySnapshotCount +
      settingsCount +
      cacheCount;
}

// ── StorageResult ─────────────────────────────────────────────
class StorageResult<T> {
  final bool success;
  final T? data;
  final String? errorMessage;
  final StorageDomain domain;

  const StorageResult._({
    required this.success,
    this.data,
    this.errorMessage,
    required this.domain,
  });

  factory StorageResult.ok(T data, StorageDomain domain) =>
      StorageResult._(success: true, data: data, domain: domain);

  factory StorageResult.empty(StorageDomain domain) =>
      StorageResult._(success: true, domain: domain);

  factory StorageResult.failure(String message, StorageDomain domain) =>
      StorageResult._(success: false, errorMessage: message, domain: domain);
}

// ── Abstract backend ─────────────────────────────────────────
// Allows swapping to SharedPreferences, SQLite, Hive, etc.
// without changing StorageEngine logic.
abstract class StorageBackend {
  Future<void> write(String key, Map<String, dynamic> value);
  Future<Map<String, dynamic>?> read(String key);
  Future<void> delete(String key);
  Future<bool> exists(String key);
  Future<List<String>> keysWithPrefix(String prefix);
  Future<void> clear();
}

// ── In-memory backend (default / testing) ────────────────────
class InMemoryStorageBackend implements StorageBackend {
  final Map<String, Map<String, dynamic>> _store = {};

  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    _store[key] = Map<String, dynamic>.from(value);
  }

  @override
  Future<Map<String, dynamic>?> read(String key) async {
    final v = _store[key];
    return v != null ? Map<String, dynamic>.from(v) : null;
  }

  @override
  Future<void> delete(String key) async => _store.remove(key);

  @override
  Future<bool> exists(String key) async => _store.containsKey(key);

  @override
  Future<List<String>> keysWithPrefix(String prefix) async =>
      _store.keys.where((k) => k.startsWith(prefix)).toList();

  @override
  Future<void> clear() async => _store.clear();
}

// ── Key namespacing helpers ───────────────────────────────────
// Each domain gets its own prefix — domain failure isolation.
class _Keys {
  static const int _currentSchemaVersion = 1;
  static const String _appVersion = '1.0.0';

  // Domain prefixes
  static const String _design = 'domain.design.';
  static const String _autosave = 'domain.autosave.';
  static const String _recovery = 'domain.recovery.';
  static const String _settings = 'domain.settings.';
  static const String _history = 'domain.history.';
  static const String _cache = 'domain.cache.';

  static String design(String id) => '$_design$id';
  static String autosave(String id) => '$_autosave$id';
  static String recovery(String id) => '$_recovery$id';
  static String settings(String key) => '$_settings$key';
  static String history(String snapshotId) => '$_history$snapshotId';
  static String cache(String key) => '$_cache$key';

  static String prefixFor(StorageDomain domain) {
    switch (domain) {
      case StorageDomain.design:
        return _design;
      case StorageDomain.autosave:
        return _autosave;
      case StorageDomain.recovery:
        return _recovery;
      case StorageDomain.settings:
        return _settings;
      case StorageDomain.historySnapshot:
        return _history;
      case StorageDomain.cache:
        return _cache;
    }
  }

  static int get schemaVersion => _currentSchemaVersion;
  static String get appVersion => _appVersion;
}

// ── Validation pipeline ───────────────────────────────────────
class _ValidationResult {
  final bool valid;
  final String? reason;
  const _ValidationResult.ok() : valid = true, reason = null;
  const _ValidationResult.fail(this.reason) : valid = false;
}

// ── StorageEngine ─────────────────────────────────────────────
class StorageEngine {
  final StorageBackend _backend;

  StorageEngine({StorageBackend? backend})
      : _backend = backend ?? InMemoryStorageBackend();

  // ── Internal helpers ────────────────────────────────────────

  StorageRecord _buildRecord({
    required String recordId,
    required StorageRecordType recordType,
    required Map<String, dynamic> payload,
    DateTime? existingCreatedAt,
  }) {
    final now = DateTime.now().toUtc();
    return StorageRecord(
      recordId: recordId,
      recordType: recordType,
      schemaVersion: _Keys.schemaVersion,
      createdAt: existingCreatedAt ?? now,
      updatedAt: now,
      sourceVersion: _Keys.appVersion,
      futureMigrationFlag: false,
      payload: payload,
    );
  }

  _ValidationResult _validateIdentifier(String id, String context) {
    if (id.trim().isEmpty) {
      return _ValidationResult.fail('$context must not be empty.');
    }
    if (id.contains(RegExp(r'[\/\\<>:"|?*]'))) {
      return _ValidationResult.fail(
          '$context contains illegal characters: "$id".');
    }
    return const _ValidationResult.ok();
  }

  _ValidationResult _validatePayload(Map<String, dynamic>? payload, String context) {
    if (payload == null) {
      return _ValidationResult.fail('$context payload must not be null.');
    }
    return const _ValidationResult.ok();
  }

  _ValidationResult _validateRecord(StorageRecord record) {
    if (record.recordId.trim().isEmpty) {
      return _ValidationResult.fail('StorageRecord.recordId is empty.');
    }
    if (record.schemaVersion < 1) {
      return _ValidationResult.fail(
          'StorageRecord.schemaVersion is invalid: ${record.schemaVersion}.');
    }
    return const _ValidationResult.ok();
  }

  Future<StorageRecord?> _readRecord(String key) async {
    try {
      final raw = await _backend.read(key);
      if (raw == null) return null;
      return StorageRecord.fromMap(raw);
    } catch (_) {
      return null;
    }
  }

  Future<bool> _writeRecord(String key, StorageRecord record) async {
    final v = _validateRecord(record);
    if (!v.valid) return false;
    try {
      await _backend.write(key, record.toMap());
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── DESIGN DOMAIN ───────────────────────────────────────────

  /// Persist a design payload. Failure does not affect other domains.
  Future<StorageResult<void>> saveDesign(
      String designId, Map<String, dynamic> designPayload) async {
    final idCheck = _validateIdentifier(designId, 'designId');
    if (!idCheck.valid) {
      return StorageResult.failure(idCheck.reason!, StorageDomain.design);
    }
    final payloadCheck = _validatePayload(designPayload, 'design');
    if (!payloadCheck.valid) {
      return StorageResult.failure(payloadCheck.reason!, StorageDomain.design);
    }

    try {
      // Preserve original createdAt if record already exists.
      final existing = await _readRecord(_Keys.design(designId));
      final record = _buildRecord(
        recordId: designId,
        recordType: StorageRecordType.design,
        payload: designPayload,
        existingCreatedAt: existing?.createdAt,
      );
      final written = await _writeRecord(_Keys.design(designId), record);
      if (!written) {
        return StorageResult.failure(
            'Failed to write design "$designId".', StorageDomain.design);
      }
      return StorageResult.empty(StorageDomain.design);
    } catch (e) {
      return StorageResult.failure(
          'Unexpected error saving design "$designId": $e',
          StorageDomain.design);
    }
  }

  Future<StorageResult<StorageRecord>> loadDesign(String designId) async {
    final idCheck = _validateIdentifier(designId, 'designId');
    if (!idCheck.valid) {
      return StorageResult.failure(idCheck.reason!, StorageDomain.design);
    }
    try {
      final record = await _readRecord(_Keys.design(designId));
      if (record == null) {
        return StorageResult.failure(
            'Design "$designId" not found.', StorageDomain.design);
      }
      return StorageResult.ok(record, StorageDomain.design);
    } catch (e) {
      return StorageResult.failure(
          'Unexpected error loading design "$designId": $e',
          StorageDomain.design);
    }
  }

  Future<StorageResult<void>> deleteDesign(String designId) async {
    final idCheck = _validateIdentifier(designId, 'designId');
    if (!idCheck.valid) {
      return StorageResult.failure(idCheck.reason!, StorageDomain.design);
    }
    try {
      await _backend.delete(_Keys.design(designId));
      return StorageResult.empty(StorageDomain.design);
    } catch (e) {
      return StorageResult.failure(
          'Unexpected error deleting design "$designId": $e',
          StorageDomain.design);
    }
  }

  Future<bool> designExists(String designId) async {
    final idCheck = _validateIdentifier(designId, 'designId');
    if (!idCheck.valid) return false;
    try {
      return await _backend.exists(_Keys.design(designId));
    } catch (_) {
      return false;
    }
  }

  Future<List<String>> getStoredDesignIds() async {
    try {
      final keys =
          await _backend.keysWithPrefix(_Keys.prefixFor(StorageDomain.design));
      return keys
          .map((k) => k.replaceFirst(_Keys.prefixFor(StorageDomain.design), ''))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── AUTOSAVE DOMAIN ─────────────────────────────────────────

  Future<StorageResult<void>> saveAutosave(
      String designId, Map<String, dynamic> autosavePayload) async {
    final idCheck = _validateIdentifier(designId, 'designId (autosave)');
    if (!idCheck.valid) {
      return StorageResult.failure(idCheck.reason!, StorageDomain.autosave);
    }
    final payloadCheck = _validatePayload(autosavePayload, 'autosave');
    if (!payloadCheck.valid) {
      return StorageResult.failure(
          payloadCheck.reason!, StorageDomain.autosave);
    }
    try {
      final existing = await _readRecord(_Keys.autosave(designId));
      final record = _buildRecord(
        recordId: designId,
        recordType: StorageRecordType.autosave,
        payload: autosavePayload,
        existingCreatedAt: existing?.createdAt,
      );
      final written = await _writeRecord(_Keys.autosave(designId), record);
      if (!written) {
        return StorageResult.failure(
            'Failed to write autosave for "$designId".',
            StorageDomain.autosave);
      }
      return StorageResult.empty(StorageDomain.autosave);
    } catch (e) {
      return StorageResult.failure(
          'Unexpected error saving autosave "$designId": $e',
          StorageDomain.autosave);
    }
  }

  Future<StorageResult<StorageRecord>> loadAutosave(String designId) async {
    final idCheck = _validateIdentifier(designId, 'designId (autosave)');
    if (!idCheck.valid) {
      return StorageResult.failure(idCheck.reason!, StorageDomain.autosave);
    }
    try {
      final record = await _readRecord(_Keys.autosave(designId));
      if (record == null) {
        return StorageResult.failure(
            'No autosave found for "$designId".', StorageDomain.autosave);
      }
      return StorageResult.ok(record, StorageDomain.autosave);
    } catch (e) {
      return StorageResult.failure(
          'Unexpected error loading autosave "$designId": $e',
          StorageDomain.autosave);
    }
  }

  Future<StorageResult<void>> clearAutosave(String designId) async {
    final idCheck = _validateIdentifier(designId, 'designId (autosave)');
    if (!idCheck.valid) {
      return StorageResult.failure(idCheck.reason!, StorageDomain.autosave);
    }
    try {
      await _backend.delete(_Keys.autosave(designId));
      return StorageResult.empty(StorageDomain.autosave);
    } catch (e) {
      return StorageResult.failure(
          'Unexpected error clearing autosave "$designId": $e',
          StorageDomain.autosave);
    }
  }

  Future<bool> hasAutosaveState(String designId) async {
    final idCheck = _validateIdentifier(designId, 'designId (autosave)');
    if (!idCheck.valid) return false;
    try {
      return await _backend.exists(_Keys.autosave(designId));
    } catch (_) {
      return false;
    }
  }

  // ── RECOVERY DOMAIN ─────────────────────────────────────────

  Future<StorageResult<void>> saveRecoveryState(
      String sessionId, Map<String, dynamic> recoveryPayload) async {
    final idCheck = _validateIdentifier(sessionId, 'sessionId (recovery)');
    if (!idCheck.valid) {
      return StorageResult.failure(idCheck.reason!, StorageDomain.recovery);
    }
    final payloadCheck = _validatePayload(recoveryPayload, 'recovery');
    if (!payloadCheck.valid) {
      return StorageResult.failure(
          payloadCheck.reason!, StorageDomain.recovery);
    }
    try {
      final existing = await _readRecord(_Keys.recovery(sessionId));
      final record = _buildRecord(
        recordId: sessionId,
        recordType: StorageRecordType.recovery,
        payload: recoveryPayload,
        existingCreatedAt: existing?.createdAt,
      );
      final written = await _writeRecord(_Keys.recovery(sessionId), record);
      if (!written) {
        return StorageResult.failure(
            'Failed to write recovery state for session "$sessionId".',
            StorageDomain.recovery);
      }
      return StorageResult.empty(StorageDomain.recovery);
    } catch (e) {
      return StorageResult.failure(
          'Unexpected error saving recovery state "$sessionId": $e',
          StorageDomain.recovery);
    }
  }

  Future<StorageResult<StorageRecord>> loadRecoveryState(
      String sessionId) async {
    final idCheck = _validateIdentifier(sessionId, 'sessionId (recovery)');
    if (!idCheck.valid) {
      return StorageResult.failure(idCheck.reason!, StorageDomain.recovery);
    }
    try {
      final record = await _readRecord(_Keys.recovery(sessionId));
      if (record == null) {
        return StorageResult.failure(
            'No recovery state found for session "$sessionId".',
            StorageDomain.recovery);
      }
      return StorageResult.ok(record, StorageDomain.recovery);
    } catch (e) {
      return StorageResult.failure(
          'Unexpected error loading recovery state "$sessionId": $e',
          StorageDomain.recovery);
    }
  }

  Future<StorageResult<void>> clearRecoveryState(String sessionId) async {
    final idCheck = _validateIdentifier(sessionId, 'sessionId (recovery)');
    if (!idCheck.valid) {
      return StorageResult.failure(idCheck.reason!, StorageDomain.recovery);
    }
    try {
      await _backend.delete(_Keys.recovery(sessionId));
      return StorageResult.empty(StorageDomain.recovery);
    } catch (e) {
      return StorageResult.failure(
          'Unexpected error clearing recovery state "$sessionId": $e',
          StorageDomain.recovery);
    }
  }

  Future<bool> hasRecoveryState(String sessionId) async {
    final idCheck = _validateIdentifier(sessionId, 'sessionId (recovery)');
    if (!idCheck.valid) return false;
    try {
      return await _backend.exists(_Keys.recovery(sessionId));
    } catch (_) {
      return false;
    }
  }

  // ── SETTINGS DOMAIN ─────────────────────────────────────────

  Future<StorageResult<void>> saveSettings(
      String settingsKey, Map<String, dynamic> settingsPayload) async {
    final idCheck = _validateIdentifier(settingsKey, 'settingsKey');
    if (!idCheck.valid) {
      return StorageResult.failure(idCheck.reason!, StorageDomain.settings);
    }
    final payloadCheck = _validatePayload(settingsPayload, 'settings');
    if (!payloadCheck.valid) {
      return StorageResult.failure(
          payloadCheck.reason!, StorageDomain.settings);
    }
    try {
      final existing = await _readRecord(_Keys.settings(settingsKey));
      final record = _buildRecord(
        recordId: settingsKey,
        recordType: StorageRecordType.settings,
        payload: settingsPayload,
        existingCreatedAt: existing?.createdAt,
      );
      final written = await _writeRecord(_Keys.settings(settingsKey), record);
      if (!written) {
        return StorageResult.failure(
            'Failed to write settings for key "$settingsKey".',
            StorageDomain.settings);
      }
      return StorageResult.empty(StorageDomain.settings);
    } catch (e) {
      return StorageResult.failure(
          'Unexpected error saving settings "$settingsKey": $e',
          StorageDomain.settings);
    }
  }

  Future<StorageResult<StorageRecord>> loadSettings(
      String settingsKey) async {
    final idCheck = _validateIdentifier(settingsKey, 'settingsKey');
    if (!idCheck.valid) {
      return StorageResult.failure(idCheck.reason!, StorageDomain.settings);
    }
    try {
      final record = await _readRecord(_Keys.settings(settingsKey));
      if (record == null) {
        return StorageResult.failure(
            'No settings found for key "$settingsKey".',
            StorageDomain.settings);
      }
      return StorageResult.ok(record, StorageDomain.settings);
    } catch (e) {
      return StorageResult.failure(
          'Unexpected error loading settings "$settingsKey": $e',
          StorageDomain.settings);
    }
  }

  // ── HISTORY SNAPSHOT DOMAIN ──────────────────────────────────

  Future<StorageResult<void>> saveHistorySnapshot(
      String snapshotId, Map<String, dynamic> historyPayload) async {
    final idCheck = _validateIdentifier(snapshotId, 'snapshotId');
    if (!idCheck.valid) {
      return StorageResult.failure(
          idCheck.reason!, StorageDomain.historySnapshot);
    }
    final payloadCheck = _validatePayload(historyPayload, 'historySnapshot');
    if (!payloadCheck.valid) {
      return StorageResult.failure(
          payloadCheck.reason!, StorageDomain.historySnapshot);
    }
    try {
      final existing = await _readRecord(_Keys.history(snapshotId));
      final record = _buildRecord(
        recordId: snapshotId,
        recordType: StorageRecordType.historySnapshot,
        payload: historyPayload,
        existingCreatedAt: existing?.createdAt,
      );
      final written = await _writeRecord(_Keys.history(snapshotId), record);
      if (!written) {
        return StorageResult.failure(
            'Failed to write history snapshot "$snapshotId".',
            StorageDomain.historySnapshot);
      }
      return StorageResult.empty(StorageDomain.historySnapshot);
    } catch (e) {
      return StorageResult.failure(
          'Unexpected error saving history snapshot "$snapshotId": $e',
          StorageDomain.historySnapshot);
    }
  }

  Future<StorageResult<StorageRecord>> loadHistorySnapshot(
      String snapshotId) async {
    final idCheck = _validateIdentifier(snapshotId, 'snapshotId');
    if (!idCheck.valid) {
      return StorageResult.failure(
          idCheck.reason!, StorageDomain.historySnapshot);
    }
    try {
      final record = await _readRecord(_Keys.history(snapshotId));
      if (record == null) {
        return StorageResult.failure(
            'No history snapshot found for "$snapshotId".',
            StorageDomain.historySnapshot);
      }
      return StorageResult.ok(record, StorageDomain.historySnapshot);
    } catch (e) {
      return StorageResult.failure(
          'Unexpected error loading history snapshot "$snapshotId": $e',
          StorageDomain.historySnapshot);
    }
  }

  // ── STATS & MAINTENANCE ──────────────────────────────────────

  Future<StorageStats> getStorageStats() async {
    int _countPrefix(List<String> keys, String prefix) =>
        keys.where((k) => k.startsWith(prefix)).length;

    try {
      // Gather all keys across all domains in parallel.
      final results = await Future.wait([
        _backend.keysWithPrefix(
            _Keys.prefixFor(StorageDomain.design)),
        _backend.keysWithPrefix(
            _Keys.prefixFor(StorageDomain.autosave)),
        _backend.keysWithPrefix(
            _Keys.prefixFor(StorageDomain.recovery)),
        _backend.keysWithPrefix(
            _Keys.prefixFor(StorageDomain.settings)),
        _backend.keysWithPrefix(
            _Keys.prefixFor(StorageDomain.historySnapshot)),
        _backend.keysWithPrefix(
            _Keys.prefixFor(StorageDomain.cache)),
      ]);

      return StorageStats(
        designCount: results[0].length,
        autosaveCount: results[1].length,
        recoveryCount: results[2].length,
        settingsCount: results[3].length,
        historySnapshotCount: results[4].length,
        cacheCount: results[5].length,
        reportedAt: DateTime.now().toUtc(),
      );
    } catch (_) {
      return StorageStats(
        designCount: 0,
        autosaveCount: 0,
        recoveryCount: 0,
        settingsCount: 0,
        historySnapshotCount: 0,
        cacheCount: 0,
        reportedAt: DateTime.now().toUtc(),
      );
    }
  }

  /// Clears ALL storage across ALL domains.
  /// Use with caution — this is irreversible.
  Future<StorageResult<void>> clearStorage() async {
    try {
      await _backend.clear();
      return StorageResult.empty(StorageDomain.design);
    } catch (e) {
      return StorageResult.failure(
          'Unexpected error during clearStorage: $e', StorageDomain.design);
    }
  }
}
