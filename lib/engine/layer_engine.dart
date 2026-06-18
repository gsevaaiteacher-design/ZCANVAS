import 'dart:async';
import 'dart:math';

import '../models/layer_model.dart';

// ============================================================
// LayerEventType
// ============================================================

enum LayerEventType {
  layerAdded,
  layerDeleted,
  layerUpdated,
  layerMoved,
  layerResized,
  layerRotated,
  layerLocked,
  layerUnlocked,
  layerShown,
  layerHidden,
  layerDuplicated,
  layerSelected,
  layerOrderChanged,
}

// ============================================================
// LayerChangeEvent
// ============================================================

class LayerChangeEvent {
  final String eventId;
  final DateTime timestamp;
  final LayerEventType operationType;
  final String layerId;

  const LayerChangeEvent({
    required this.eventId,
    required this.timestamp,
    required this.operationType,
    required this.layerId,
  });

  @override
  String toString() {
    return 'LayerChangeEvent('
        'eventId: $eventId, '
        'timestamp: $timestamp, '
        'operationType: ${operationType.name}, '
        'layerId: $layerId'
        ')';
  }
}

// ============================================================
// LayerSnapshot
// ============================================================

class LayerSnapshot {
  final String snapshotId;
  final DateTime timestamp;
  final List<LayerModel> layers;
  final Set<String> selectedIds;

  LayerSnapshot({
    required this.snapshotId,
    required this.timestamp,
    required List<LayerModel> layers,
    required Set<String> selectedIds,
  })  : layers = List.unmodifiable(List<LayerModel>.from(layers)),
        selectedIds = Set.unmodifiable(Set<String>.from(selectedIds));
}

// ============================================================
// LayerEngine
// ============================================================

class LayerEngine {
  List<LayerModel> _layers;
  Set<String> _selectedIds;
  bool _inTransaction;
  LayerSnapshot? _transactionSnapshot;

  final StreamController<LayerChangeEvent> _eventController;

  static final Random _random = Random.secure();

  LayerEngine({List<LayerModel>? initialLayers})
      : _layers = List<LayerModel>.from(initialLayers ?? const []),
        _selectedIds = {},
        _inTransaction = false,
        _transactionSnapshot = null,
        _eventController =
            StreamController<LayerChangeEvent>.broadcast();

  // ---- Public read-only views ----

  List<LayerModel> get layers => List.unmodifiable(_layers);
  Set<String> get selectedIds => Set.unmodifiable(_selectedIds);
  bool get inTransaction => _inTransaction;

  /// Subscribe to listen for every mutation event.
  /// External history and autosave systems must use this stream.
  Stream<LayerChangeEvent> get events => _eventController.stream;

  // ============================================================
  // Mandatory Operations
  // ============================================================

  void addLayer(LayerModel layer) {
    _requireNonEmptyId(layer.id);
    _requireNoDuplicateId(layer.id);
    _layers = [..._layers, layer];
    _emit(LayerEventType.layerAdded, layer.id);
  }

  void deleteLayer(String id) {
    _requireNonEmptyId(id);
    _requireExists(id);
    _layers = _layers.where((l) => l.id != id).toList();
    _selectedIds = Set<String>.from(_selectedIds)..remove(id);
    _emit(LayerEventType.layerDeleted, id);
  }

  void updateLayer(LayerModel updated) {
    _requireNonEmptyId(updated.id);
    _requireExists(updated.id);
    _layers = _layers
        .map((l) => l.id == updated.id ? updated : l)
        .toList();
    _emit(LayerEventType.layerUpdated, updated.id);
  }

  void moveLayer(String id, {required double x, required double y}) {
    _requireNonEmptyId(id);
    _requireExists(id);
    _layers = _layers.map((l) {
      if (l.id != id) return l;
      return l.copyWith(x: x, y: y, updatedAt: DateTime.now());
    }).toList();
    _emit(LayerEventType.layerMoved, id);
  }

  void resizeLayer(
    String id, {
    required double width,
    required double height,
  }) {
    _requireNonEmptyId(id);
    _requireExists(id);
    if (width < 0) {
      throw ArgumentError('width must be >= 0. Got: $width');
    }
    if (height < 0) {
      throw ArgumentError('height must be >= 0. Got: $height');
    }
    _layers = _layers.map((l) {
      if (l.id != id) return l;
      return l.copyWith(
        width: width,
        height: height,
        updatedAt: DateTime.now(),
      );
    }).toList();
    _emit(LayerEventType.layerResized, id);
  }

  void rotateLayer(String id, {required double rotation}) {
    _requireNonEmptyId(id);
    _requireExists(id);
    if (rotation < 0 || rotation > 360) {
      throw ArgumentError(
          'rotation must be in range 0–360. Got: $rotation');
    }
    _layers = _layers.map((l) {
      if (l.id != id) return l;
      return l.copyWith(rotation: rotation, updatedAt: DateTime.now());
    }).toList();
    _emit(LayerEventType.layerRotated, id);
  }

  void lockLayer(String id) {
    _requireNonEmptyId(id);
    _requireExists(id);
    _layers = _layers.map((l) {
      if (l.id != id) return l;
      return l.copyWith(locked: true, updatedAt: DateTime.now());
    }).toList();
    _emit(LayerEventType.layerLocked, id);
  }

  void unlockLayer(String id) {
    _requireNonEmptyId(id);
    _requireExists(id);
    _layers = _layers.map((l) {
      if (l.id != id) return l;
      return l.copyWith(locked: false, updatedAt: DateTime.now());
    }).toList();
    _emit(LayerEventType.layerUnlocked, id);
  }

  void showLayer(String id) {
    _requireNonEmptyId(id);
    _requireExists(id);
    _layers = _layers.map((l) {
      if (l.id != id) return l;
      return l.copyWith(visible: true, updatedAt: DateTime.now());
    }).toList();
    _emit(LayerEventType.layerShown, id);
  }

  void hideLayer(String id) {
    _requireNonEmptyId(id);
    _requireExists(id);
    _layers = _layers.map((l) {
      if (l.id != id) return l;
      return l.copyWith(visible: false, updatedAt: DateTime.now());
    }).toList();
    _emit(LayerEventType.layerHidden, id);
  }

  void duplicateLayer(String id) {
    _requireNonEmptyId(id);
    _requireExists(id);
    final source = _layers.firstWhere((l) => l.id == id);
    final now = DateTime.now();
    final duplicate = source.copyWith(
      id: _generateId(),
      zIndex: _maxZIndex() + 1,
      createdAt: now,
      updatedAt: now,
    );
    _layers = [..._layers, duplicate];
    _emit(LayerEventType.layerDuplicated, duplicate.id);
  }

  // ============================================================
  // Ordering Operations (zIndex-based)
  // ============================================================

  void bringToFront(String id) {
    _requireNonEmptyId(id);
    _requireExists(id);
    final newZIndex = _maxZIndex() + 1;
    _layers = _layers.map((l) {
      if (l.id != id) return l;
      return l.copyWith(zIndex: newZIndex, updatedAt: DateTime.now());
    }).toList();
    _emit(LayerEventType.layerOrderChanged, id);
  }

  void sendToBack(String id) {
    _requireNonEmptyId(id);
    _requireExists(id);
    final newZIndex = _minZIndex() - 1;
    _layers = _layers.map((l) {
      if (l.id != id) return l;
      return l.copyWith(zIndex: newZIndex, updatedAt: DateTime.now());
    }).toList();
    _emit(LayerEventType.layerOrderChanged, id);
  }

  void moveUp(String id) {
    _requireNonEmptyId(id);
    _requireExists(id);
    final layer = _layers.firstWhere((l) => l.id == id);
    _layers = _layers.map((l) {
      if (l.id != id) return l;
      return l.copyWith(
        zIndex: layer.zIndex + 1,
        updatedAt: DateTime.now(),
      );
    }).toList();
    _emit(LayerEventType.layerOrderChanged, id);
  }

  void moveDown(String id) {
    _requireNonEmptyId(id);
    _requireExists(id);
    final layer = _layers.firstWhere((l) => l.id == id);
    _layers = _layers.map((l) {
      if (l.id != id) return l;
      return l.copyWith(
        zIndex: layer.zIndex - 1,
        updatedAt: DateTime.now(),
      );
    }).toList();
    _emit(LayerEventType.layerOrderChanged, id);
  }

  // ============================================================
  // Selection Operations
  // ============================================================

  void selectLayer(String id) {
    _requireNonEmptyId(id);
    _requireExists(id);
    _selectedIds = {id};
    _emit(LayerEventType.layerSelected, id);
  }

  void selectLayers(List<String> ids) {
    for (final id in ids) {
      _requireNonEmptyId(id);
      _requireExists(id);
    }
    _selectedIds = Set<String>.from(ids);
    if (ids.isNotEmpty) {
      _emit(LayerEventType.layerSelected, ids.first);
    }
  }

  void addSelection(String id) {
    _requireNonEmptyId(id);
    _requireExists(id);
    _selectedIds = {..._selectedIds, id};
    _emit(LayerEventType.layerSelected, id);
  }

  void removeSelection(String id) {
    _requireNonEmptyId(id);
    _selectedIds = Set<String>.from(_selectedIds)..remove(id);
    _emit(LayerEventType.layerSelected, id);
  }

  void replaceSelection(List<String> ids) {
    for (final id in ids) {
      _requireNonEmptyId(id);
      _requireExists(id);
    }
    _selectedIds = Set<String>.from(ids);
    if (ids.isNotEmpty) {
      _emit(LayerEventType.layerSelected, ids.first);
    }
  }

  void clearSelection() {
    _selectedIds = {};
  }

  // ============================================================
  // Group Operations
  // ============================================================

  void groupLayers(List<String> ids, {required String groupId}) {
    if (groupId.isEmpty) {
      throw ArgumentError('groupId must not be empty.');
    }
    for (final id in ids) {
      _requireNonEmptyId(id);
      _requireExists(id);
    }
    final idSet = ids.toSet();
    final now = DateTime.now();
    _layers = _layers.map((l) {
      if (!idSet.contains(l.id)) return l;
      return l.copyWith(groupId: groupId, updatedAt: now);
    }).toList();
    for (final id in ids) {
      _emit(LayerEventType.layerUpdated, id);
    }
  }

  void ungroupLayers(String groupId) {
    if (groupId.isEmpty) {
      throw ArgumentError('groupId must not be empty.');
    }
    final affectedIds = _layers
        .where((l) => l.groupId == groupId)
        .map((l) => l.id)
        .toList();
    final now = DateTime.now();
    _layers = _layers.map((l) {
      if (l.groupId != groupId) return l;
      return l.copyWith(groupId: null, updatedAt: now);
    }).toList();
    for (final id in affectedIds) {
      _emit(LayerEventType.layerUpdated, id);
    }
  }

  // ============================================================
  // Query Operations — read-only, must never mutate state
  // ============================================================

  LayerModel? getLayerById(String id) {
    for (final layer in _layers) {
      if (layer.id == id) return layer;
    }
    return null;
  }

  List<LayerModel> getLayersByType(LayerType type) {
    return _layers.where((l) => l.type == type).toList();
  }

  List<LayerModel> getVisibleLayers() {
    return _layers.where((l) => l.visible).toList();
  }

  List<LayerModel> getLockedLayers() {
    return _layers.where((l) => l.locked).toList();
  }

  LayerModel? getSelectedLayer() {
    if (_selectedIds.isEmpty) return null;
    return getLayerById(_selectedIds.first);
  }

  List<LayerModel> getSelectedLayers() {
    return _layers.where((l) => _selectedIds.contains(l.id)).toList();
  }

  // ============================================================
  // Transaction Contract
  // ============================================================

  void beginTransaction() {
    if (_inTransaction) {
      throw StateError(
          'Cannot begin transaction: a transaction is already in progress.');
    }
    _transactionSnapshot = _captureSnapshot();
    _inTransaction = true;
  }

  void commitTransaction() {
    if (!_inTransaction) {
      throw StateError(
          'Cannot commit: no transaction is in progress.');
    }
    _transactionSnapshot = null;
    _inTransaction = false;
  }

  void rollbackTransaction() {
    if (!_inTransaction) {
      throw StateError(
          'Cannot rollback: no transaction is in progress.');
    }
    final snapshot = _transactionSnapshot;
    if (snapshot != null) {
      _layers = List<LayerModel>.from(snapshot.layers);
      _selectedIds = Set<String>.from(snapshot.selectedIds);
    }
    _transactionSnapshot = null;
    _inTransaction = false;
  }

  // ============================================================
  // Snapshot Contract
  // ============================================================

  LayerSnapshot createSnapshot() {
    return _captureSnapshot();
  }

  void restoreSnapshot(LayerSnapshot snapshot) {
    _layers = List<LayerModel>.from(snapshot.layers);
    _selectedIds = Set<String>.from(snapshot.selectedIds);
  }

  // ============================================================
  // Lifecycle
  // ============================================================

  void dispose() {
    _eventController.close();
  }

  // ============================================================
  // Private Helpers
  // ============================================================

  void _requireNonEmptyId(String id) {
    if (id.isEmpty) {
      throw ArgumentError('Layer id must not be empty.');
    }
  }

  void _requireNoDuplicateId(String id) {
    if (_layers.any((l) => l.id == id)) {
      throw ArgumentError('Duplicate layer id: "$id".');
    }
  }

  void _requireExists(String id) {
    if (!_layers.any((l) => l.id == id)) {
      throw ArgumentError('Layer with id "$id" does not exist.');
    }
  }

  void _emit(LayerEventType type, String layerId) {
    if (!_eventController.isClosed) {
      _eventController.add(LayerChangeEvent(
        eventId: _generateId(),
        timestamp: DateTime.now(),
        operationType: type,
        layerId: layerId,
      ));
    }
  }

  LayerSnapshot _captureSnapshot() {
    return LayerSnapshot(
      snapshotId: _generateId(),
      timestamp: DateTime.now(),
      layers: _layers,
      selectedIds: _selectedIds,
    );
  }

  int _maxZIndex() {
    if (_layers.isEmpty) return 0;
    return _layers.map((l) => l.zIndex).reduce(max);
  }

  int _minZIndex() {
    if (_layers.isEmpty) return 0;
    return _layers.map((l) => l.zIndex).reduce(min);
  }

  static String _generateId() {
    final ts = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final rnd = _random.nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
    return '$ts-$rnd';
  }
}
