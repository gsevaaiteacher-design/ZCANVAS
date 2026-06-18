enum HistoryOperationType {
  addLayer,
  deleteLayer,
  updateLayer,
  moveLayer,
  resizeLayer,
  rotateLayer,
  lockLayer,
  unlockLayer,
  showLayer,
  hideLayer,
  duplicateLayer,
  selectLayer,
}

class HistoryEntry {
  final String operationId;
  final HistoryOperationType operationType;
  final DateTime timestamp;
  final Map<String, dynamic> beforeState;
  final Map<String, dynamic> afterState;
  final String? affectedLayerId;
  final String editorSessionId;

  const HistoryEntry({
    required this.operationId,
    required this.operationType,
    required this.timestamp,
    required this.beforeState,
    required this.afterState,
    this.affectedLayerId,
    required this.editorSessionId,
  });
}

class HistoryEngine {
  final List<HistoryEntry> _undoStack = [];
  final List<HistoryEntry> _redoStack = [];

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;
  int get historyCount => _undoStack.length;

  void pushEntry({
    required HistoryOperationType operationType,
    required Map<String, dynamic> beforeState,
    required Map<String, dynamic> afterState,
    String? affectedLayerId,
    required String editorSessionId,
  }) {
    _validateState(beforeState);
    _validateState(afterState);

    final operationId = '${editorSessionId}_${operationType.name}_${DateTime.now().microsecondsSinceEpoch}';

    if (operationId.isEmpty) {
      throw ArgumentError('Operation ID must not be empty.');
    }

    final entry = HistoryEntry(
      operationId: operationId,
      operationType: operationType,
      timestamp: DateTime.now(),
      beforeState: Map.unmodifiable(beforeState),
      afterState: Map.unmodifiable(afterState),
      affectedLayerId: affectedLayerId,
      editorSessionId: editorSessionId,
    );

    _undoStack.add(entry);
    _redoStack.clear();
  }

  Map<String, dynamic>? undo() {
    if (!canUndo) return null;
    final entry = _undoStack.removeLast();
    _redoStack.add(entry);
    return Map.of(entry.beforeState);
  }

  Map<String, dynamic>? redo() {
    if (!canRedo) return null;
    final entry = _redoStack.removeLast();
    _undoStack.add(entry);
    return Map.of(entry.afterState);
  }

  void clearHistory() {
    _undoStack.clear();
    _redoStack.clear();
  }

  void clearUndoStack() {
    _undoStack.clear();
  }

  void clearRedoStack() {
    _redoStack.clear();
  }

  List<HistoryEntry> get undoStack => List.unmodifiable(_undoStack);
  List<HistoryEntry> get redoStack => List.unmodifiable(_redoStack);

  void restoreFromSnapshot(Map<String, dynamic> snapshot) {
    clearHistory();

    final rawUndo = snapshot['undoStack'];
    final rawRedo = snapshot['redoStack'];

    if (rawUndo is List) {
      for (final raw in rawUndo) {
        final entry = _deserializeEntry(raw as Map<String, dynamic>);
        if (entry != null) _undoStack.add(entry);
      }
    }

    if (rawRedo is List) {
      for (final raw in rawRedo) {
        final entry = _deserializeEntry(raw as Map<String, dynamic>);
        if (entry != null) _redoStack.add(entry);
      }
    }
  }

  Map<String, dynamic> captureSnapshot() {
    return {
      'undoStack': _undoStack.map(_serializeEntry).toList(),
      'redoStack': _redoStack.map(_serializeEntry).toList(),
    };
  }

  void _validateState(Map<String, dynamic>? state) {
    if (state == null) {
      throw ArgumentError('History state must not be null.');
    }
  }

  Map<String, dynamic> _serializeEntry(HistoryEntry entry) {
    return {
      'operationId': entry.operationId,
      'operationType': entry.operationType.name,
      'timestamp': entry.timestamp.toIso8601String(),
      'beforeState': entry.beforeState,
      'afterState': entry.afterState,
      'affectedLayerId': entry.affectedLayerId,
      'editorSessionId': entry.editorSessionId,
    };
  }

  HistoryEntry? _deserializeEntry(Map<String, dynamic> raw) {
    final operationId = raw['operationId'];
    final operationTypeName = raw['operationType'];
    final editorSessionId = raw['editorSessionId'];

    if (operationId == null || (operationId as String).isEmpty) return null;
    if (operationTypeName == null) return null;
    if (editorSessionId == null) return null;

    HistoryOperationType? operationType;
    for (final value in HistoryOperationType.values) {
      if (value.name == operationTypeName) {
        operationType = value;
        break;
      }
    }
    if (operationType == null) return null;

    final beforeState = raw['beforeState'];
    final afterState = raw['afterState'];
    if (beforeState == null || afterState == null) return null;

    return HistoryEntry(
      operationId: operationId,
      operationType: operationType,
      timestamp: DateTime.tryParse(raw['timestamp'] as String? ?? '') ?? DateTime.now(),
      beforeState: Map<String, dynamic>.from(beforeState as Map),
      afterState: Map<String, dynamic>.from(afterState as Map),
      affectedLayerId: raw['affectedLayerId'] as String?,
      editorSessionId: editorSessionId as String,
    );
  }
}
