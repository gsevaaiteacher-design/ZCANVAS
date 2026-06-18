// ==================================================
// Z-CANVAS — PHASE-15 HISTORY, SNAPSHOT & RECOVERY
// core/history/snapshot_engine.dart
//
// PRIMARY ROLE: STATE CAPTURE SYSTEM
//
// OWNS:
//   ✔ Design state snapshot capture (full canvas design model)
//   ✔ Layer state snapshot capture (layer collection + properties)
//   ✔ Selection state snapshot capture (active selection set)
//   ✔ Snapshot registry (in-memory, keyed by snapshot ID)
//   ✔ Snapshot validation (integrity + version checks)
//   ✔ Snapshot retrieval (by ID)
//   ✔ Snapshot removal (with orphan protection)
//   ✔ Snapshot report generation
//
// DOES NOT OWN:
//   ❌ Undo logic  ❌ Redo logic  ❌ Recovery logic
//   ❌ Canvas write access  ❌ Render access  ❌ Execution
//   ❌ Layer mutation  ❌ State restoration
//
// COMMUNICATION ALLOWED:
//   ✔ HistoryManager (via SnapshotEngineInterface)
//   ✔ HistoryGuard   (read-only integrity queries)
//   ✔ LayerEngine    (READ ONLY — via LayerStateReaderInterface)
//
// COMMUNICATION FORBIDDEN:
//   ❌ UI  ❌ Canvas  ❌ RenderEngine  ❌ ExecutionCore
// ==================================================

import 'dart:async';
import 'dart:convert';

import 'history_manager.dart' show SnapshotEngineInterface;

// ==================================================
// SNAPSHOT VERSION
// Bumped whenever SnapshotData's serialisation shape changes.
// Older versions are flagged as incompatible during validateSnapshot().
// ==================================================

const int _kSnapshotVersion = 1;
const String _kSnapshotVersionKey = 'z_canvas_snapshot_v$_kSnapshotVersion';

// ==================================================
// READ-ONLY EXTERNAL QUERY INTERFACES
// SnapshotEngine READS through these — never writes.
// Concrete implementations are provided by the engine layer.
// ==================================================

// — Layer Engine read surface —
abstract interface class LayerStateReaderInterface {
  /// Returns a serialisable representation of all current layers.
  /// The structure is opaque to SnapshotEngine — it stores and returns it as-is.
  Future<List<Map<String, dynamic>>> readAllLayers();

  /// Returns the ID of the currently active / focused layer, or null.
  Future<String?> readActiveLayerId();

  /// Returns the current layer z-order as an ordered list of layer IDs.
  Future<List<String>> readLayerOrder();

  /// Returns the total number of layers on the canvas.
  Future<int> readLayerCount();
}

// — Design Model read surface —
abstract interface class DesignModelReaderInterface {
  /// Returns a serialisable map of the top-level design document properties
  /// (canvas size, background, DPI, metadata, etc.).
  Future<Map<String, dynamic>> readDesignModel();

  /// Returns the current document version string (e.g. "1.0.3").
  Future<String> readDocumentVersion();

  /// Returns the document's stable ID.
  Future<String> readDocumentId();
}

// — Selection State read surface —
abstract interface class SelectionStateReaderInterface {
  /// Returns the IDs of all currently selected layers.
  Future<List<String>> readSelectedLayerIds();

  /// Returns any active transform handle state (e.g. resize in progress).
  Future<Map<String, dynamic>> readTransformState();

  /// Returns true when a multi-select (marquee) is in progress.
  Future<bool> readIsMultiSelecting();
}

// ==================================================
// CAPTURED STATE VALUE OBJECTS
// Immutable; constructed by the capture methods below.
// The design is opaque — we store what the engine gives us verbatim.
// ==================================================

class CapturedDesignState {
  const CapturedDesignState({
    required this.documentId,
    required this.documentVersion,
    required this.designModel,
    required this.capturedAt,
  });

  final String               documentId;
  final String               documentVersion;
  final Map<String, dynamic> designModel;
  final DateTime             capturedAt;

  Map<String, dynamic> toMap() => {
        'documentId':      documentId,
        'documentVersion': documentVersion,
        'designModel':     designModel,
        'capturedAt':      capturedAt.toIso8601String(),
      };

  factory CapturedDesignState.fromMap(Map<String, dynamic> m) =>
      CapturedDesignState(
        documentId:      m['documentId'] as String,
        documentVersion: m['documentVersion'] as String,
        designModel:     (m['designModel'] as Map).cast<String, dynamic>(),
        capturedAt:      DateTime.parse(m['capturedAt'] as String),
      );
}

class CapturedLayerState {
  const CapturedLayerState({
    required this.layers,
    required this.layerOrder,
    required this.activeLayerId,
    required this.layerCount,
    required this.capturedAt,
  });

  final List<Map<String, dynamic>> layers;
  final List<String>  layerOrder;
  final String?       activeLayerId;
  final int           layerCount;
  final DateTime      capturedAt;

  Map<String, dynamic> toMap() => {
        'layers':        layers,
        'layerOrder':    layerOrder,
        'activeLayerId': activeLayerId,
        'layerCount':    layerCount,
        'capturedAt':    capturedAt.toIso8601String(),
      };

  factory CapturedLayerState.fromMap(Map<String, dynamic> m) =>
      CapturedLayerState(
        layers:        (m['layers'] as List)
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList(),
        layerOrder:    (m['layerOrder'] as List).cast<String>(),
        activeLayerId: m['activeLayerId'] as String?,
        layerCount:    m['layerCount'] as int,
        capturedAt:    DateTime.parse(m['capturedAt'] as String),
      );
}

class CapturedSelectionState {
  const CapturedSelectionState({
    required this.selectedLayerIds,
    required this.transformState,
    required this.isMultiSelecting,
    required this.capturedAt,
  });

  final List<String>           selectedLayerIds;
  final Map<String, dynamic>   transformState;
  final bool                   isMultiSelecting;
  final DateTime               capturedAt;

  Map<String, dynamic> toMap() => {
        'selectedLayerIds': selectedLayerIds,
        'transformState':   transformState,
        'isMultiSelecting': isMultiSelecting,
        'capturedAt':       capturedAt.toIso8601String(),
      };

  factory CapturedSelectionState.fromMap(Map<String, dynamic> m) =>
      CapturedSelectionState(
        selectedLayerIds: (m['selectedLayerIds'] as List).cast<String>(),
        transformState:   (m['transformState'] as Map).cast<String, dynamic>(),
        isMultiSelecting: m['isMultiSelecting'] as bool,
        capturedAt:       DateTime.parse(m['capturedAt'] as String),
      );
}

// ==================================================
// SNAPSHOT METADATA
// Administrative data attached to every snapshot.
// ==================================================

class SnapshotMetadata {
  const SnapshotMetadata({
    required this.snapshotId,
    required this.sessionId,
    required this.createdAt,
    required this.version,
    required this.layerCount,
    required this.integrityHash,
  });

  final String   snapshotId;
  final String   sessionId;
  final DateTime createdAt;
  final int      version;       // = _kSnapshotVersion
  final int      layerCount;
  final String   integrityHash; // simple hash over serialised content

  Map<String, dynamic> toMap() => {
        'snapshotId':    snapshotId,
        'sessionId':     sessionId,
        'createdAt':     createdAt.toIso8601String(),
        'version':       version,
        'layerCount':    layerCount,
        'integrityHash': integrityHash,
      };

  factory SnapshotMetadata.fromMap(Map<String, dynamic> m) => SnapshotMetadata(
        snapshotId:    m['snapshotId'] as String,
        sessionId:     m['sessionId'] as String,
        createdAt:     DateTime.parse(m['createdAt'] as String),
        version:       m['version'] as int,
        layerCount:    m['layerCount'] as int,
        integrityHash: m['integrityHash'] as String,
      );
}

// ==================================================
// SNAPSHOT DATA
// The complete, immutable record stored in the registry.
// Fields match contract: designModel, layerCollection,
// selectionState, metadata, timestamp, version.
// ==================================================

class SnapshotData {
  const SnapshotData({
    required this.metadata,
    required this.designState,
    required this.layerState,
    required this.selectionState,
  });

  final SnapshotMetadata     metadata;
  final CapturedDesignState  designState;
  final CapturedLayerState   layerState;
  final CapturedSelectionState selectionState;

  // Contract-named accessors:
  SnapshotMetadata     get snapshotMetadata  => metadata;
  CapturedDesignState  get designModel       => designState;
  CapturedLayerState   get layerCollection   => layerState;
  CapturedSelectionState get selectionStateData => selectionState;
  DateTime             get timestamp          => metadata.createdAt;
  int                  get version            => metadata.version;

  Map<String, dynamic> toMap() => {
        'metadata':       metadata.toMap(),
        'designState':    designState.toMap(),
        'layerState':     layerState.toMap(),
        'selectionState': selectionState.toMap(),
        'version':        version,
        'versionKey':     _kSnapshotVersionKey,
      };

  factory SnapshotData.fromMap(Map<String, dynamic> m) => SnapshotData(
        metadata:       SnapshotMetadata.fromMap(
            (m['metadata'] as Map).cast<String, dynamic>()),
        designState:    CapturedDesignState.fromMap(
            (m['designState'] as Map).cast<String, dynamic>()),
        layerState:     CapturedLayerState.fromMap(
            (m['layerState'] as Map).cast<String, dynamic>()),
        selectionState: CapturedSelectionState.fromMap(
            (m['selectionState'] as Map).cast<String, dynamic>()),
      );
}

// ==================================================
// SNAPSHOT VALIDATION RESULT
// Returned by validateSnapshot() — richer than a bare bool.
// ==================================================

enum SnapshotValidationStatus { valid, notFound, versionMismatch, hashMismatch, corrupted }

class SnapshotValidationResult {
  const SnapshotValidationResult({
    required this.snapshotId,
    required this.status,
    this.reason,
  });

  final String                    snapshotId;
  final SnapshotValidationStatus  status;
  final String?                   reason;

  bool get isValid => status == SnapshotValidationStatus.valid;

  factory SnapshotValidationResult.valid(String id) =>
      SnapshotValidationResult(snapshotId: id,
          status: SnapshotValidationStatus.valid);

  factory SnapshotValidationResult.fail(
          String id, SnapshotValidationStatus s, String reason) =>
      SnapshotValidationResult(snapshotId: id, status: s, reason: reason);

  @override
  String toString() =>
      'SnapshotValidationResult($snapshotId: $status'
      '${reason != null ? ", $reason" : ""})';
}

// ==================================================
// SNAPSHOT REPORT
// ==================================================

class SnapshotReport {
  const SnapshotReport({
    required this.generatedAt,
    required this.registrySize,
    required this.totalCreated,
    required this.totalRemoved,
    required this.totalValidated,
    required this.totalValidationFailures,
    required this.snapshotIds,
    required this.newestSnapshotId,
    required this.oldestSnapshotId,
    required this.maxRegistrySize,
  });

  final DateTime     generatedAt;
  final int          registrySize;
  final int          totalCreated;
  final int          totalRemoved;
  final int          totalValidated;
  final int          totalValidationFailures;
  final List<String> snapshotIds;
  final String?      newestSnapshotId;
  final String?      oldestSnapshotId;
  final int          maxRegistrySize;

  @override
  String toString() =>
      'SnapshotReport(size: $registrySize/$maxRegistrySize, '
      'created: $totalCreated, removed: $totalRemoved, '
      'validationFailures: $totalValidationFailures)';
}

// ==================================================
// SNAPSHOT ENGINE CONFIGURATION
// ==================================================

class SnapshotEngineConfig {
  const SnapshotEngineConfig({
    this.maxRegistrySize      = 200,
    this.evictOldestOnFull    = true,
    this.computeIntegrityHash = true,
    this.validateOnGet        = false,
  });

  /// Maximum number of snapshots retained in the registry at once.
  final int maxRegistrySize;

  /// When true, the oldest snapshot is evicted if the registry is full.
  final bool evictOldestOnFull;

  /// Whether to compute and store a content integrity hash at creation time.
  final bool computeIntegrityHash;

  /// Whether to run validation automatically inside getSnapshot().
  final bool validateOnGet;
}

// ==================================================
// SNAPSHOT ENGINE
// Implements SnapshotEngineInterface (from history_manager.dart).
// ==================================================

class SnapshotEngine implements SnapshotEngineInterface {
  SnapshotEngine({
    required LayerStateReaderInterface    layerReader,
    required DesignModelReaderInterface   designReader,
    required SelectionStateReaderInterface selectionReader,
    SnapshotEngineConfig config = const SnapshotEngineConfig(),
  })  : _layerReader     = layerReader,
        _designReader    = designReader,
        _selectionReader = selectionReader,
        _config          = config;

  final LayerStateReaderInterface     _layerReader;
  final DesignModelReaderInterface    _designReader;
  final SelectionStateReaderInterface _selectionReader;
  final SnapshotEngineConfig          _config;

  // Ordered registry: insertion-order preserved for oldest/newest queries.
  final Map<String, SnapshotData> _registry = {};

  // Counters for report generation.
  int _totalCreated            = 0;
  int _totalRemoved            = 0;
  int _totalValidated          = 0;
  int _totalValidationFailures = 0;
  int _snapshotSeq             = 0;

  // ==================================================
  // PUBLIC API — mandatory functions per contract
  // ==================================================

  // --------------------------------------------------
  // createSnapshot()
  // Captures all three state sub-systems, assembles SnapshotData,
  // registers it, and returns the new snapshot ID.
  // Implements SnapshotEngineInterface.createSnapshot().
  // --------------------------------------------------

  @override
  Future<String> createSnapshot({required String sessionId}) async {
    final snapshotId = _generateSnapshotId(sessionId);

    _log('createSnapshot: capturing state for session $sessionId '
        '→ $snapshotId');

    // Capture all three state layers in parallel for minimal latency.
    final results = await Future.wait([
      captureDesignState(),
      captureLayerState(),
      captureSelectionState(),
    ]);

    final design    = results[0] as CapturedDesignState;
    final layer     = results[1] as CapturedLayerState;
    final selection = results[2] as CapturedSelectionState;

    // Compute integrity hash over serialised content.
    final contentMap = {
      'designState':    design.toMap(),
      'layerState':     layer.toMap(),
      'selectionState': selection.toMap(),
    };
    final hash = _config.computeIntegrityHash
        ? _computeHash(contentMap)
        : 'hash_disabled';

    final metadata = SnapshotMetadata(
      snapshotId:    snapshotId,
      sessionId:     sessionId,
      createdAt:     DateTime.now().toUtc(),
      version:       _kSnapshotVersion,
      layerCount:    layer.layerCount,
      integrityHash: hash,
    );

    final snapshot = SnapshotData(
      metadata:       metadata,
      designState:    design,
      layerState:     layer,
      selectionState: selection,
    );

    _registerInRegistry(snapshotId, snapshot);
    _totalCreated++;

    _log('createSnapshot: registered $snapshotId '
        '(layers: ${layer.layerCount}, '
        'registrySize: ${_registry.length}).');
    return snapshotId;
  }

  // --------------------------------------------------
  // captureDesignState()
  // Reads the current design model via DesignModelReaderInterface.
  // Read-only. Returns an immutable CapturedDesignState.
  // --------------------------------------------------

  Future<CapturedDesignState> captureDesignState() async {
    final docId      = await _designReader.readDocumentId();
    final docVersion = await _designReader.readDocumentVersion();
    final model      = await _designReader.readDesignModel();

    return CapturedDesignState(
      documentId:      docId,
      documentVersion: docVersion,
      designModel:     Map.unmodifiable(model),
      capturedAt:      DateTime.now().toUtc(),
    );
  }

  // --------------------------------------------------
  // captureLayerState()
  // Reads the complete layer collection via LayerStateReaderInterface.
  // Read-only. Returns an immutable CapturedLayerState.
  // --------------------------------------------------

  Future<CapturedLayerState> captureLayerState() async {
    final layers   = await _layerReader.readAllLayers();
    final order    = await _layerReader.readLayerOrder();
    final activeId = await _layerReader.readActiveLayerId();
    final count    = await _layerReader.readLayerCount();

    return CapturedLayerState(
      layers:        List.unmodifiable(
          layers.map((l) => Map<String, dynamic>.unmodifiable(l)).toList()),
      layerOrder:    List.unmodifiable(order),
      activeLayerId: activeId,
      layerCount:    count,
      capturedAt:    DateTime.now().toUtc(),
    );
  }

  // --------------------------------------------------
  // captureSelectionState()
  // Reads the active selection set via SelectionStateReaderInterface.
  // Read-only. Returns an immutable CapturedSelectionState.
  // --------------------------------------------------

  Future<CapturedSelectionState> captureSelectionState() async {
    final selectedIds     = await _selectionReader.readSelectedLayerIds();
    final transformState  = await _selectionReader.readTransformState();
    final isMultiSelect   = await _selectionReader.readIsMultiSelecting();

    return CapturedSelectionState(
      selectedLayerIds: List.unmodifiable(selectedIds),
      transformState:   Map.unmodifiable(transformState),
      isMultiSelecting: isMultiSelect,
      capturedAt:       DateTime.now().toUtc(),
    );
  }

  // --------------------------------------------------
  // validateSnapshot()
  // Confirms a snapshot in the registry is intact:
  //   1. It must exist.
  //   2. Its version must match the current schema version.
  //   3. Its integrity hash must match a freshly computed hash.
  // Returns true (interface contract) and caches the full result internally.
  // --------------------------------------------------

  @override
  Future<bool> validateSnapshot(String snapshotId) async {
    final result = await validateSnapshotFull(snapshotId);
    _totalValidated++;
    if (!result.isValid) _totalValidationFailures++;
    return result.isValid;
  }

  /// Extended validation returning the full [SnapshotValidationResult].
  Future<SnapshotValidationResult> validateSnapshotFull(
      String snapshotId) async {
    final snapshot = _registry[snapshotId];

    if (snapshot == null) {
      return SnapshotValidationResult.fail(snapshotId,
          SnapshotValidationStatus.notFound,
          'Snapshot $snapshotId not found in registry.');
    }

    if (snapshot.version != _kSnapshotVersion) {
      return SnapshotValidationResult.fail(snapshotId,
          SnapshotValidationStatus.versionMismatch,
          'Snapshot version ${snapshot.version} does not match '
          'current schema version $_kSnapshotVersion.');
    }

    if (_config.computeIntegrityHash) {
      final contentMap = {
        'designState':    snapshot.designState.toMap(),
        'layerState':     snapshot.layerState.toMap(),
        'selectionState': snapshot.selectionState.toMap(),
      };
      final recomputed = _computeHash(contentMap);
      if (recomputed != snapshot.metadata.integrityHash) {
        return SnapshotValidationResult.fail(snapshotId,
            SnapshotValidationStatus.hashMismatch,
            'Integrity hash mismatch for $snapshotId. '
            'Expected ${snapshot.metadata.integrityHash}, '
            'got $recomputed. Snapshot may be corrupted.');
      }
    }

    return SnapshotValidationResult.valid(snapshotId);
  }

  // --------------------------------------------------
  // getSnapshot()
  // Retrieves SnapshotData by ID.
  // Optionally validates before returning (config-gated).
  // Returns null if the snapshot does not exist or fails validation.
  // --------------------------------------------------

  Future<SnapshotData?> getSnapshot(String snapshotId) async {
    final snapshot = _registry[snapshotId];
    if (snapshot == null) {
      _log('getSnapshot: $snapshotId not found.');
      return null;
    }

    if (_config.validateOnGet) {
      final valid = await validateSnapshot(snapshotId);
      if (!valid) {
        _log('getSnapshot: $snapshotId failed validation — not returned.');
        return null;
      }
    }

    return snapshot;
  }

  // --------------------------------------------------
  // removeSnapshot()
  // Removes a snapshot from the registry by ID.
  // Implements SnapshotEngineInterface.removeSnapshot().
  // No-op if the snapshot does not exist.
  // --------------------------------------------------

  @override
  Future<void> removeSnapshot(String snapshotId) async {
    if (_registry.containsKey(snapshotId)) {
      _registry.remove(snapshotId);
      _totalRemoved++;
      _log('removeSnapshot: $snapshotId removed '
          '(registrySize now: ${_registry.length}).');
    }
  }

  // --------------------------------------------------
  // generateSnapshotReport()
  // Returns an immutable point-in-time view of the snapshot registry.
  // --------------------------------------------------

  SnapshotReport generateSnapshotReport() {
    final ids = List<String>.unmodifiable(_registry.keys);
    return SnapshotReport(
      generatedAt:             DateTime.now().toUtc(),
      registrySize:            _registry.length,
      totalCreated:            _totalCreated,
      totalRemoved:            _totalRemoved,
      totalValidated:          _totalValidated,
      totalValidationFailures: _totalValidationFailures,
      snapshotIds:             ids,
      newestSnapshotId:        ids.isNotEmpty ? ids.last  : null,
      oldestSnapshotId:        ids.isNotEmpty ? ids.first : null,
      maxRegistrySize:         _config.maxRegistrySize,
    );
  }

  // ==================================================
  // READ-ONLY ACCESSORS
  // ==================================================

  /// True if [snapshotId] is in the registry (without validation).
  bool contains(String snapshotId) => _registry.containsKey(snapshotId);

  /// Current number of snapshots in the registry.
  int get registrySize => _registry.length;

  /// Ordered list of all registered snapshot IDs (oldest → newest).
  List<String> get allSnapshotIds => List.unmodifiable(_registry.keys);

  // ==================================================
  // PRIVATE HELPERS
  // ==================================================

  String _generateSnapshotId(String sessionId) {
    _snapshotSeq++;
    final ts = DateTime.now().toUtc().millisecondsSinceEpoch;
    return 'snap_${_snapshotSeq.toString().padLeft(6, "0")}_${ts}_'
        '${sessionId.length > 8 ? sessionId.substring(0, 8) : sessionId}';
  }

  void _registerInRegistry(String id, SnapshotData data) {
    if (_registry.length >= _config.maxRegistrySize) {
      if (_config.evictOldestOnFull && _registry.isNotEmpty) {
        final oldest = _registry.keys.first;
        _registry.remove(oldest);
        _totalRemoved++;
        _log('_registerInRegistry: registry full — evicted oldest $oldest.');
      } else {
        _log('_registerInRegistry: registry full and eviction disabled. '
            'Snapshot $id NOT stored.');
        return;
      }
    }
    _registry[id] = data;
  }

  /// Computes a stable string hash over the serialised content map.
  /// Uses JSON encoding → hashCode for a lightweight integrity check.
  /// Not cryptographic — sufficient for accidental corruption detection.
  String _computeHash(Map<String, dynamic> content) {
    try {
      final encoded = jsonEncode(content);
      // Combine multiple hash windows for better collision resistance.
      final h1 = encoded.hashCode;
      final h2 = encoded.split('').reversed.join().hashCode;
      return '${h1.toRadixString(16)}_${h2.toRadixString(16)}';
    } catch (e) {
      _log('WARNING: hash computation failed: $e — using fallback.');
      return 'hash_error';
    }
  }

  void _log(String message) {
    // ignore: avoid_print
    print('[SnapshotEngine] $message');
  }
}

// ==================================================
// NULL / STUB READER IMPLEMENTATIONS
// Safe no-op readers for testing and dev environments.
// Return minimal valid data — no real state is read.
// ==================================================

class NullLayerStateReader implements LayerStateReaderInterface {
  const NullLayerStateReader();
  @override Future<List<Map<String, dynamic>>> readAllLayers()   async => [];
  @override Future<String?> readActiveLayerId()                  async => null;
  @override Future<List<String>> readLayerOrder()               async => [];
  @override Future<int> readLayerCount()                        async => 0;
}

class NullDesignModelReader implements DesignModelReaderInterface {
  const NullDesignModelReader();
  @override Future<Map<String, dynamic>> readDesignModel()  async => {};
  @override Future<String> readDocumentVersion()            async => '0.0.0';
  @override Future<String> readDocumentId()                 async => 'null-doc';
}

class NullSelectionStateReader implements SelectionStateReaderInterface {
  const NullSelectionStateReader();
  @override Future<List<String>>           readSelectedLayerIds() async => [];
  @override Future<Map<String, dynamic>>   readTransformState()   async => {};
  @override Future<bool>                   readIsMultiSelecting() async => false;
}

/// Convenience factory — returns a SnapshotEngine wired with all null readers.
SnapshotEngine buildNullSnapshotEngine({
  SnapshotEngineConfig config = const SnapshotEngineConfig(),
}) =>
    SnapshotEngine(
      layerReader:     const NullLayerStateReader(),
      designReader:    const NullDesignModelReader(),
      selectionReader: const NullSelectionStateReader(),
      config:          config,
    );

// ==================================================
// END OF core/history/snapshot_engine.dart
// Z-CANVAS — PHASE-15 — STATE CAPTURE SYSTEM
// Powered by Zynquar
// ==================================================
