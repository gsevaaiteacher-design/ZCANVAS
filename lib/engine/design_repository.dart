// ignore_for_file: avoid_catches_without_on_clauses

// ============================================================
// DesignRepository — Phase-3 Domain/Storage Translation Authority
// ============================================================
// OWNS: validation, normalization, domain↔storage mapping,
//       version migration, schema upgrades, legacy support.
// MUST NOT: do file IO, SQLite, SharedPreferences, network,
//           export, UI, rendering, canvas, layer/history
//           modification.
// DEPENDS ON: DesignModel, LayerModel, StorageEngine.
// ============================================================

import '../../models/design_model.dart';
import '../../models/layer_model.dart';
import '../engines/storage_engine.dart';

// ── Current domain schema version ────────────────────────────
// Bump this whenever the DesignModel or LayerModel serialization
// format changes. Migrations live exclusively in this file.
const int _kCurrentDesignSchemaVersion = 1;

// ── Repository result ─────────────────────────────────────────
class RepositoryResult<T> {
  final bool success;
  final T? data;
  final String? errorMessage;
  final List<String> warnings;

  const RepositoryResult._({
    required this.success,
    this.data,
    this.errorMessage,
    this.warnings = const [],
  });

  factory RepositoryResult.ok(T data, {List<String> warnings = const []}) =>
      RepositoryResult._(success: true, data: data, warnings: warnings);

  factory RepositoryResult.empty({List<String> warnings = const []}) =>
      RepositoryResult._(success: true, warnings: warnings);

  factory RepositoryResult.failure(String message,
          {List<String> warnings = const []}) =>
      RepositoryResult._(
          success: false, errorMessage: message, warnings: warnings);
}

// ── Validation result ─────────────────────────────────────────
class ValidationResult {
  final bool valid;
  final List<String> errors;
  final List<String> warnings;

  const ValidationResult.ok({this.warnings = const []})
      : valid = true,
        errors = const [];

  const ValidationResult.fail(this.errors, {this.warnings = const []})
      : valid = false;
}

// ── Integrity report ──────────────────────────────────────────
class RepositoryIntegrityReport {
  final bool passed;
  final List<String> issues;
  final List<String> warnings;
  final DateTime checkedAt;

  const RepositoryIntegrityReport({
    required this.passed,
    required this.issues,
    required this.warnings,
    required this.checkedAt,
  });
}

// ── DesignRepository ──────────────────────────────────────────
class DesignRepository {
  final StorageEngine _storage;

  DesignRepository({required StorageEngine storage}) : _storage = storage;

  // ────────────────────────────────────────────────────────────
  // VALIDATION
  // ────────────────────────────────────────────────────────────

  ValidationResult validateDesign(DesignModel design) {
    final errors = <String>[];
    final warnings = <String>[];

    if (design.id.trim().isEmpty) {
      errors.add('DesignModel.id must not be empty.');
    }
    if (design.title.trim().isEmpty) {
      warnings.add('DesignModel.title is empty; a default will be applied.');
    }
    if (design.canvasWidth <= 0) {
      errors.add(
          'DesignModel.canvasWidth must be > 0 (got ${design.canvasWidth}).');
    }
    if (design.canvasHeight <= 0) {
      errors.add(
          'DesignModel.canvasHeight must be > 0 (got ${design.canvasHeight}).');
    }
    if (design.version < 1) {
      errors.add(
          'DesignModel.version must be >= 1 (got ${design.version}).');
    }

    for (final layer in design.layers) {
      final layerResult = _validateLayer(layer);
      errors.addAll(layerResult.errors.map((e) => '[Layer ${layer.id}] $e'));
      warnings
          .addAll(layerResult.warnings.map((w) => '[Layer ${layer.id}] $w'));
    }

    if (errors.isEmpty) {
      return ValidationResult.ok(warnings: warnings);
    }
    return ValidationResult.fail(errors, warnings: warnings);
  }

  ValidationResult _validateLayer(LayerModel layer) {
    final errors = <String>[];
    final warnings = <String>[];

    if (layer.id.trim().isEmpty) errors.add('LayerModel.id must not be empty.');
    if (layer.type.trim().isEmpty) {
      errors.add('LayerModel.type must not be empty.');
    }
    if (layer.zIndex < 0) {
      warnings.add('LayerModel.zIndex is negative (${layer.zIndex}).');
    }
    if (layer.opacity < 0.0 || layer.opacity > 1.0) {
      errors.add(
          'LayerModel.opacity must be in [0.0, 1.0] (got ${layer.opacity}).');
    }
    if (layer.width < 0) {
      warnings.add('LayerModel.width is negative (${layer.width}).');
    }
    if (layer.height < 0) {
      warnings.add('LayerModel.height is negative (${layer.height}).');
    }

    if (errors.isEmpty) return ValidationResult.ok(warnings: warnings);
    return ValidationResult.fail(errors, warnings: warnings);
  }

  // ────────────────────────────────────────────────────────────
  // NORMALIZATION
  // ────────────────────────────────────────────────────────────

  DesignModel normalizeDesign(DesignModel design) {
    final normalizedTitle =
        design.title.trim().isEmpty ? 'Untitled Design' : design.title.trim();

    final normalizedLayers = design.layers.map(_normalizeLayer).toList();

    // Deduplicate layer IDs — last occurrence wins (safe recovery).
    final seen = <String>{};
    final deduped = <LayerModel>[];
    for (final layer in normalizedLayers.reversed) {
      if (seen.add(layer.id)) deduped.insert(0, layer);
    }

    return design.copyWith(
      title: normalizedTitle,
      layers: deduped,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  LayerModel _normalizeLayer(LayerModel layer) {
    return layer.copyWith(
      opacity: layer.opacity.clamp(0.0, 1.0),
      rotation: layer.rotation % 360.0,
      zIndex: layer.zIndex < 0 ? 0 : layer.zIndex,
      width: layer.width < 0 ? 0 : layer.width,
      height: layer.height < 0 ? 0 : layer.height,
    );
  }

  // ────────────────────────────────────────────────────────────
  // DOMAIN → STORAGE MAPPING
  // ────────────────────────────────────────────────────────────

  Map<String, dynamic> _designToStorageMap(DesignModel design) {
    return {
      'schemaVersion': _kCurrentDesignSchemaVersion,
      'id': design.id,
      'title': design.title,
      'version': design.version,
      'createdAt': design.createdAt.toUtc().toIso8601String(),
      'updatedAt': design.updatedAt.toUtc().toIso8601String(),
      'canvasWidth': design.canvasWidth,
      'canvasHeight': design.canvasHeight,
      'canvasOriginX': design.canvasOriginX,
      'canvasOriginY': design.canvasOriginY,
      'layers': design.layers.map(_layerToStorageMap).toList(),
      'metadata': design.metadata,
    };
  }

  Map<String, dynamic> _layerToStorageMap(LayerModel layer) {
    return {
      'id': layer.id,
      'type': layer.type,
      'zIndex': layer.zIndex,
      'visible': layer.visible,
      'locked': layer.locked,
      'x': layer.x,
      'y': layer.y,
      'width': layer.width,
      'height': layer.height,
      'rotation': layer.rotation,
      'opacity': layer.opacity,
      'scaleX': layer.scaleX,
      'scaleY': layer.scaleY,
      'properties': layer.properties,
    };
  }

  // ────────────────────────────────────────────────────────────
  // STORAGE → DOMAIN MAPPING
  // ────────────────────────────────────────────────────────────

  DesignModel? _storageMapToDesign(Map<String, dynamic> raw) {
    try {
      final migrated = _migrateStorageMap(raw);

      final rawLayers = migrated['layers'];
      final layers = <LayerModel>[];
      if (rawLayers is List) {
        for (final rawLayer in rawLayers) {
          final layer =
              _storageMapToLayer(rawLayer as Map<String, dynamic>);
          if (layer != null) layers.add(layer);
        }
      }

      return DesignModel(
        id: migrated['id'] as String,
        title: migrated['title'] as String? ?? 'Untitled Design',
        version: (migrated['version'] as num?)?.toInt() ?? 1,
        createdAt: DateTime.tryParse(migrated['createdAt'] as String? ?? '') ??
            DateTime.now().toUtc(),
        updatedAt: DateTime.tryParse(migrated['updatedAt'] as String? ?? '') ??
            DateTime.now().toUtc(),
        canvasWidth: (migrated['canvasWidth'] as num?)?.toDouble() ?? 1920,
        canvasHeight: (migrated['canvasHeight'] as num?)?.toDouble() ?? 1080,
        canvasOriginX: (migrated['canvasOriginX'] as num?)?.toDouble() ?? 0,
        canvasOriginY: (migrated['canvasOriginY'] as num?)?.toDouble() ?? 0,
        layers: layers,
        metadata: Map<String, dynamic>.from(
            (migrated['metadata'] as Map?)?.cast<String, dynamic>() ?? {}),
      );
    } catch (_) {
      return null;
    }
  }

  LayerModel? _storageMapToLayer(Map<String, dynamic> raw) {
    try {
      return LayerModel(
        id: raw['id'] as String,
        type: raw['type'] as String,
        zIndex: (raw['zIndex'] as num?)?.toInt() ?? 0,
        visible: raw['visible'] as bool? ?? true,
        locked: raw['locked'] as bool? ?? false,
        x: (raw['x'] as num?)?.toDouble() ?? 0,
        y: (raw['y'] as num?)?.toDouble() ?? 0,
        width: (raw['width'] as num?)?.toDouble() ?? 0,
        height: (raw['height'] as num?)?.toDouble() ?? 0,
        rotation: (raw['rotation'] as num?)?.toDouble() ?? 0,
        opacity: (raw['opacity'] as num?)?.toDouble() ?? 1.0,
        scaleX: (raw['scaleX'] as num?)?.toDouble() ?? 1.0,
        scaleY: (raw['scaleY'] as num?)?.toDouble() ?? 1.0,
        properties: Map<String, dynamic>.from(
            (raw['properties'] as Map?)?.cast<String, dynamic>() ?? {}),
      );
    } catch (_) {
      return null;
    }
  }

  // ────────────────────────────────────────────────────────────
  // VERSION MIGRATION  ← sole authority for all schema upgrades
  // ────────────────────────────────────────────────────────────

  Map<String, dynamic> _migrateStorageMap(Map<String, dynamic> raw) {
    int version = (raw['schemaVersion'] as num?)?.toInt() ?? 0;

    // Chain of migrations — each step advances by exactly one version.
    while (version < _kCurrentDesignSchemaVersion) {
      switch (version) {
        case 0:
          raw = _migrateV0toV1(raw);
          version = 1;
          break;
        // Future migrations: add cases here, bump
        // _kCurrentDesignSchemaVersion, and implement _migrateVNtoVN+1.
        default:
          // Unknown version above current — nothing to migrate.
          version = _kCurrentDesignSchemaVersion;
          break;
      }
    }

    return raw;
  }

  /// v0 → v1: initial format; adds required fields with safe defaults.
  Map<String, dynamic> _migrateV0toV1(Map<String, dynamic> raw) {
    final migrated = Map<String, dynamic>.from(raw);
    migrated['schemaVersion'] = 1;
    migrated['canvasOriginX'] ??= 0.0;
    migrated['canvasOriginY'] ??= 0.0;
    migrated['metadata'] ??= <String, dynamic>{};
    migrated['version'] ??= 1;

    final rawLayers = migrated['layers'];
    if (rawLayers is List) {
      migrated['layers'] = rawLayers.map((l) {
        if (l is! Map) return l;
        final layer = Map<String, dynamic>.from(l as Map);
        layer['scaleX'] ??= 1.0;
        layer['scaleY'] ??= 1.0;
        layer['properties'] ??= <String, dynamic>{};
        return layer;
      }).toList();
    }

    return migrated;
  }

  /// Explicit public upgrade entrypoint. Called by EditorController
  /// before loading a stored design into the session.
  DesignModel upgradeDesignVersion(DesignModel design) {
    // Re-serialize through the migration pipeline to apply any pending
    // schema changes, then deserialize back into a domain object.
    final storageMap = _designToStorageMap(design);
    final migrated = _migrateStorageMap(storageMap);
    return _storageMapToDesign(migrated) ?? design;
  }

  // ────────────────────────────────────────────────────────────
  // DESIGN OPERATIONS
  // ────────────────────────────────────────────────────────────

  Future<RepositoryResult<void>> saveDesign(DesignModel design) async {
    final validation = validateDesign(design);
    if (!validation.valid) {
      return RepositoryResult.failure(
        'Design validation failed: ${validation.errors.join('; ')}',
        warnings: validation.warnings,
      );
    }

    final normalized = normalizeDesign(design);
    final storageMap = _designToStorageMap(normalized);

    final result = await _storage.saveDesign(design.id, storageMap);
    if (!result.success) {
      return RepositoryResult.failure(
        result.errorMessage ?? 'StorageEngine failed to save design.',
        warnings: validation.warnings,
      );
    }
    return RepositoryResult.empty(warnings: validation.warnings);
  }

  Future<RepositoryResult<DesignModel>> loadDesign(String designId) async {
    if (designId.trim().isEmpty) {
      return RepositoryResult.failure('designId must not be empty.');
    }

    final result = await _storage.loadDesign(designId);
    if (!result.success || result.data == null) {
      return RepositoryResult.failure(
          result.errorMessage ?? 'Design "$designId" not found.');
    }

    final rawPayload = result.data!.payload;
    final domain = _storageMapToDesign(rawPayload);
    if (domain == null) {
      return RepositoryResult.failure(
          'Failed to deserialize design "$designId" from storage.');
    }

    final validation = validateDesign(domain);
    if (!validation.valid) {
      return RepositoryResult.failure(
        'Loaded design failed domain validation: ${validation.errors.join('; ')}',
        warnings: validation.warnings,
      );
    }

    return RepositoryResult.ok(domain, warnings: validation.warnings);
  }

  Future<RepositoryResult<void>> deleteDesign(String designId) async {
    if (designId.trim().isEmpty) {
      return RepositoryResult.failure('designId must not be empty.');
    }
    final result = await _storage.deleteDesign(designId);
    if (!result.success) {
      return RepositoryResult.failure(
          result.errorMessage ?? 'StorageEngine failed to delete design.');
    }
    return RepositoryResult.empty();
  }

  Future<bool> designExists(String designId) async {
    if (designId.trim().isEmpty) return false;
    return _storage.designExists(designId);
  }

  // ────────────────────────────────────────────────────────────
  // AUTOSAVE OPERATIONS
  // ────────────────────────────────────────────────────────────

  Future<RepositoryResult<void>> saveAutosave(DesignModel design) async {
    final validation = validateDesign(design);
    // Autosave tolerates warnings; only hard errors block the write.
    if (!validation.valid) {
      return RepositoryResult.failure(
        'Autosave validation failed: ${validation.errors.join('; ')}',
        warnings: validation.warnings,
      );
    }

    final normalized = normalizeDesign(design);
    final storageMap = _designToStorageMap(normalized);
    final result = await _storage.saveAutosave(design.id, storageMap);
    if (!result.success) {
      return RepositoryResult.failure(
        result.errorMessage ?? 'StorageEngine failed to save autosave.',
        warnings: validation.warnings,
      );
    }
    return RepositoryResult.empty(warnings: validation.warnings);
  }

  Future<RepositoryResult<DesignModel>> loadAutosave(String designId) async {
    if (designId.trim().isEmpty) {
      return RepositoryResult.failure('designId must not be empty.');
    }

    final result = await _storage.loadAutosave(designId);
    if (!result.success || result.data == null) {
      return RepositoryResult.failure(
          result.errorMessage ?? 'No autosave found for "$designId".');
    }

    final domain = _storageMapToDesign(result.data!.payload);
    if (domain == null) {
      return RepositoryResult.failure(
          'Failed to deserialize autosave for "$designId".');
    }
    return RepositoryResult.ok(domain);
  }

  // ────────────────────────────────────────────────────────────
  // RECOVERY OPERATIONS
  // ────────────────────────────────────────────────────────────

  Future<RepositoryResult<void>> saveRecoveryState(
      String sessionId, DesignModel design) async {
    if (sessionId.trim().isEmpty) {
      return RepositoryResult.failure('sessionId must not be empty.');
    }
    final validation = validateDesign(design);
    if (!validation.valid) {
      return RepositoryResult.failure(
        'Recovery state validation failed: ${validation.errors.join('; ')}',
        warnings: validation.warnings,
      );
    }

    final normalized = normalizeDesign(design);
    final storageMap = _designToStorageMap(normalized);
    final result = await _storage.saveRecoveryState(sessionId, storageMap);
    if (!result.success) {
      return RepositoryResult.failure(
        result.errorMessage ?? 'StorageEngine failed to save recovery state.',
        warnings: validation.warnings,
      );
    }
    return RepositoryResult.empty(warnings: validation.warnings);
  }

  Future<RepositoryResult<DesignModel>> loadRecoveryState(
      String sessionId) async {
    if (sessionId.trim().isEmpty) {
      return RepositoryResult.failure('sessionId must not be empty.');
    }

    final result = await _storage.loadRecoveryState(sessionId);
    if (!result.success || result.data == null) {
      return RepositoryResult.failure(
          result.errorMessage ?? 'No recovery state for session "$sessionId".');
    }

    final domain = _storageMapToDesign(result.data!.payload);
    if (domain == null) {
      return RepositoryResult.failure(
          'Failed to deserialize recovery state for session "$sessionId".');
    }
    return RepositoryResult.ok(domain);
  }

  // ────────────────────────────────────────────────────────────
  // SETTINGS OPERATIONS
  // ────────────────────────────────────────────────────────────

  Future<RepositoryResult<void>> saveSettings(
      String settingsKey, Map<String, dynamic> settings) async {
    if (settingsKey.trim().isEmpty) {
      return RepositoryResult.failure('settingsKey must not be empty.');
    }
    if (settings.isEmpty) {
      return RepositoryResult.failure(
          'Settings payload must not be empty for key "$settingsKey".');
    }

    final result = await _storage.saveSettings(settingsKey, settings);
    if (!result.success) {
      return RepositoryResult.failure(
          result.errorMessage ?? 'StorageEngine failed to save settings.');
    }
    return RepositoryResult.empty();
  }

  Future<RepositoryResult<Map<String, dynamic>>> loadSettings(
      String settingsKey) async {
    if (settingsKey.trim().isEmpty) {
      return RepositoryResult.failure('settingsKey must not be empty.');
    }

    final result = await _storage.loadSettings(settingsKey);
    if (!result.success || result.data == null) {
      return RepositoryResult.failure(
          result.errorMessage ?? 'No settings found for key "$settingsKey".');
    }
    return RepositoryResult.ok(result.data!.payload);
  }

  // ────────────────────────────────────────────────────────────
  // INTEGRITY CHECK
  // ────────────────────────────────────────────────────────────

  Future<RepositoryIntegrityReport> verifyRepositoryIntegrity() async {
    final issues = <String>[];
    final warnings = <String>[];

    try {
      final designIds = await _storage.getStoredDesignIds();

      for (final id in designIds) {
        try {
          final loadResult = await loadDesign(id);
          if (!loadResult.success) {
            issues.add('Design "$id" failed to load: ${loadResult.errorMessage}');
          } else {
            warnings.addAll(loadResult.warnings.map((w) => '[Design $id] $w'));
          }
        } catch (e) {
          issues.add('Unexpected error verifying design "$id": $e');
        }
      }

      final stats = await _storage.getStorageStats();
      if (stats.totalRecords == 0) {
        warnings.add('Repository is empty — no records found.');
      }
    } catch (e) {
      issues.add('Integrity check encountered an unexpected error: $e');
    }

    return RepositoryIntegrityReport(
      passed: issues.isEmpty,
      issues: issues,
      warnings: warnings,
      checkedAt: DateTime.now().toUtc(),
    );
  }
}
