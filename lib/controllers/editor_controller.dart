import '../models/layer_model.dart';
import '../models/design_model.dart';
import '../engines/layer_engine.dart';
import '../engines/history_engine.dart';
import '../engines/render_engine.dart';

enum EditorTool {
  select,
  pan,
  text,
  image,
  icon,
  shape,
  sticker,
  frame,
}

enum EditorState {
  idle,
  editing,
  rendering,
  recovering,
  restoring,
}

class EditorEvent {
  final String eventId;
  final DateTime timestamp;
  final String eventType;
  final String? affectedLayerId;
  final String editorSessionId;

  const EditorEvent({
    required this.eventId,
    required this.timestamp,
    required this.eventType,
    this.affectedLayerId,
    required this.editorSessionId,
  });
}

class EditorController {
  final LayerEngine _layerEngine;
  final HistoryEngine _historyEngine;
  final RenderEngine _renderEngine;

  DesignModel? _currentDesign;
  LayerModel? _selectedLayer;
  final String _sessionId;
  EditorState _editorState;
  EditorTool _currentTool;
  bool _isDirty;
  bool _isRecovering;

  final List<EditorEvent> _eventLog = [];
  final List<void Function(EditorEvent)> _eventListeners = [];

  EditorController({
    required LayerEngine layerEngine,
    required HistoryEngine historyEngine,
    required RenderEngine renderEngine,
    required String sessionId,
  })  : _layerEngine = layerEngine,
        _historyEngine = historyEngine,
        _renderEngine = renderEngine,
        _sessionId = sessionId,
        _editorState = EditorState.idle,
        _currentTool = EditorTool.select,
        _isDirty = false,
        _isRecovering = false;

  DesignModel? get currentDesign => _currentDesign;
  LayerModel? get selectedLayer => _selectedLayer;
  String get sessionId => _sessionId;
  EditorState get editorState => _editorState;
  EditorTool get currentTool => _currentTool;
  bool get isDirty => _isDirty;
  bool get isRecovering => _isRecovering;

  void addEventListener(void Function(EditorEvent) listener) {
    _eventListeners.add(listener);
  }

  void removeEventListener(void Function(EditorEvent) listener) {
    _eventListeners.remove(listener);
  }

  void _emit(EditorEvent event) {
    _eventLog.add(event);
    for (final listener in List.of(_eventListeners)) {
      listener(event);
    }
  }

  EditorEvent _buildEvent(String eventType, {String? affectedLayerId}) {
    return EditorEvent(
      eventId: '${_sessionId}_${DateTime.now().microsecondsSinceEpoch}',
      timestamp: DateTime.now(),
      eventType: eventType,
      affectedLayerId: affectedLayerId,
      editorSessionId: _sessionId,
    );
  }

  void setCurrentDesign(DesignModel design) {
    _currentDesign = design;
    _emit(_buildEvent('editorStateChanged'));
  }

  void setCurrentTool(EditorTool tool) {
    _currentTool = tool;
    _emit(_buildEvent('editorStateChanged'));
  }

  void _setState(EditorState state) {
    _editorState = state;
    _emit(_buildEvent('editorStateChanged'));
  }

  void addLayer(LayerModel layer) {
    final before = _layerEngine.captureState();
    _layerEngine.addLayer(layer);
    final after = _layerEngine.captureState();
    _historyEngine.pushEntry(
      operationType: HistoryOperationType.addLayer,
      beforeState: before,
      afterState: after,
      affectedLayerId: layer.id,
      editorSessionId: _sessionId,
    );
    markDirty();
    requestRender();
    _emit(_buildEvent('layerAdded', affectedLayerId: layer.id));
  }

  void deleteLayer(String layerId) {
    final before = _layerEngine.captureState();
    _layerEngine.deleteLayer(layerId);
    final after = _layerEngine.captureState();
    if (_selectedLayer?.id == layerId) {
      _selectedLayer = null;
      _emit(_buildEvent('selectionCleared'));
    }
    _historyEngine.pushEntry(
      operationType: HistoryOperationType.deleteLayer,
      beforeState: before,
      afterState: after,
      affectedLayerId: layerId,
      editorSessionId: _sessionId,
    );
    markDirty();
    requestRender();
    _emit(_buildEvent('layerDeleted', affectedLayerId: layerId));
  }

  void updateLayer(LayerModel updated) {
    final before = _layerEngine.captureState();
    _layerEngine.updateLayer(updated);
    final after = _layerEngine.captureState();
    _historyEngine.pushEntry(
      operationType: HistoryOperationType.updateLayer,
      beforeState: before,
      afterState: after,
      affectedLayerId: updated.id,
      editorSessionId: _sessionId,
    );
    markDirty();
    requestRender();
    _emit(_buildEvent('layerUpdated', affectedLayerId: updated.id));
  }

  void moveLayer(String layerId, double dx, double dy) {
    final before = _layerEngine.captureState();
    _layerEngine.moveLayer(layerId, dx, dy);
    final after = _layerEngine.captureState();
    _historyEngine.pushEntry(
      operationType: HistoryOperationType.moveLayer,
      beforeState: before,
      afterState: after,
      affectedLayerId: layerId,
      editorSessionId: _sessionId,
    );
    markDirty();
    requestRender();
    _emit(_buildEvent('layerMoved', affectedLayerId: layerId));
  }

  void resizeLayer(String layerId, double width, double height) {
    final before = _layerEngine.captureState();
    _layerEngine.resizeLayer(layerId, width, height);
    final after = _layerEngine.captureState();
    _historyEngine.pushEntry(
      operationType: HistoryOperationType.resizeLayer,
      beforeState: before,
      afterState: after,
      affectedLayerId: layerId,
      editorSessionId: _sessionId,
    );
    markDirty();
    requestRender();
    _emit(_buildEvent('layerResized', affectedLayerId: layerId));
  }

  void rotateLayer(String layerId, double angleDegrees) {
    final before = _layerEngine.captureState();
    _layerEngine.rotateLayer(layerId, angleDegrees);
    final after = _layerEngine.captureState();
    _historyEngine.pushEntry(
      operationType: HistoryOperationType.rotateLayer,
      beforeState: before,
      afterState: after,
      affectedLayerId: layerId,
      editorSessionId: _sessionId,
    );
    markDirty();
    requestRender();
    _emit(_buildEvent('layerRotated', affectedLayerId: layerId));
  }

  void duplicateLayer(String layerId) {
    final before = _layerEngine.captureState();
    final newLayer = _layerEngine.duplicateLayer(layerId);
    final after = _layerEngine.captureState();
    _historyEngine.pushEntry(
      operationType: HistoryOperationType.duplicateLayer,
      beforeState: before,
      afterState: after,
      affectedLayerId: newLayer.id,
      editorSessionId: _sessionId,
    );
    markDirty();
    requestRender();
    _emit(_buildEvent('layerAdded', affectedLayerId: newLayer.id));
  }

  void showLayer(String layerId) {
    final before = _layerEngine.captureState();
    _layerEngine.showLayer(layerId);
    final after = _layerEngine.captureState();
    _historyEngine.pushEntry(
      operationType: HistoryOperationType.showLayer,
      beforeState: before,
      afterState: after,
      affectedLayerId: layerId,
      editorSessionId: _sessionId,
    );
    markDirty();
    requestRender();
    _emit(_buildEvent('layerUpdated', affectedLayerId: layerId));
  }

  void hideLayer(String layerId) {
    final before = _layerEngine.captureState();
    _layerEngine.hideLayer(layerId);
    final after = _layerEngine.captureState();
    _historyEngine.pushEntry(
      operationType: HistoryOperationType.hideLayer,
      beforeState: before,
      afterState: after,
      affectedLayerId: layerId,
      editorSessionId: _sessionId,
    );
    markDirty();
    requestRender();
    _emit(_buildEvent('layerUpdated', affectedLayerId: layerId));
  }

  void lockLayer(String layerId) {
    final before = _layerEngine.captureState();
    _layerEngine.lockLayer(layerId);
    final after = _layerEngine.captureState();
    _historyEngine.pushEntry(
      operationType: HistoryOperationType.lockLayer,
      beforeState: before,
      afterState: after,
      affectedLayerId: layerId,
      editorSessionId: _sessionId,
    );
    markDirty();
    _emit(_buildEvent('layerUpdated', affectedLayerId: layerId));
  }

  void unlockLayer(String layerId) {
    final before = _layerEngine.captureState();
    _layerEngine.unlockLayer(layerId);
    final after = _layerEngine.captureState();
    _historyEngine.pushEntry(
      operationType: HistoryOperationType.unlockLayer,
      beforeState: before,
      afterState: after,
      affectedLayerId: layerId,
      editorSessionId: _sessionId,
    );
    markDirty();
    _emit(_buildEvent('layerUpdated', affectedLayerId: layerId));
  }

  void selectLayer(String layerId) {
    final layer = _layerEngine.getLayerById(layerId);
    _selectedLayer = layer;
    _historyEngine.pushEntry(
      operationType: HistoryOperationType.selectLayer,
      beforeState: _selectedLayer != null ? {'selectedLayerId': _selectedLayer!.id} : {},
      afterState: {'selectedLayerId': layerId},
      affectedLayerId: layerId,
      editorSessionId: _sessionId,
    );
    _emit(_buildEvent('layerSelected', affectedLayerId: layerId));
  }

  void clearSelection() {
    _selectedLayer = null;
    _emit(_buildEvent('selectionCleared'));
  }

  void replaceSelection(String layerId) {
    clearSelection();
    selectLayer(layerId);
  }

  void undo() {
    if (!_historyEngine.canUndo) return;
    final restoredState = _historyEngine.undo();
    if (restoredState != null) {
      _layerEngine.restoreState(restoredState);
      requestRender();
      markDirty();
      _emit(_buildEvent('historyChanged'));
    }
  }

  void redo() {
    if (!_historyEngine.canRedo) return;
    final restoredState = _historyEngine.redo();
    if (restoredState != null) {
      _layerEngine.restoreState(restoredState);
      requestRender();
      markDirty();
      _emit(_buildEvent('historyChanged'));
    }
  }

  void requestRender() {
    _setState(EditorState.rendering);
    _renderEngine.buildRenderTree(_layerEngine.layers, _currentDesign);
    _setState(EditorState.idle);
    _emit(_buildEvent('renderRequested'));
  }

  void markDirty() {
    _isDirty = true;
    _emit(_buildEvent('editorStateChanged'));
  }

  void markClean() {
    _isDirty = false;
    _emit(_buildEvent('editorStateChanged'));
  }

  void recoverDesign(DesignModel design) {
    _isRecovering = true;
    _setState(EditorState.recovering);
    _currentDesign = design;
    _layerEngine.restoreState(design.layerState);
    _historyEngine.clearHistory();
    _isRecovering = false;
    markClean();
    requestRender();
    _setState(EditorState.idle);
    _emit(_buildEvent('editorStateChanged'));
  }

  void restoreSession(Map<String, dynamic> sessionSnapshot) {
    _setState(EditorState.restoring);
    if (sessionSnapshot.containsKey('layerState')) {
      _layerEngine.restoreState(sessionSnapshot['layerState'] as Map<String, dynamic>);
    }
    if (sessionSnapshot.containsKey('historyState')) {
      _historyEngine.restoreFromSnapshot(sessionSnapshot['historyState'] as Map<String, dynamic>);
    }
    markDirty();
    requestRender();
    _setState(EditorState.idle);
    _emit(_buildEvent('editorStateChanged'));
  }

  List<EditorEvent> get eventLog => List.unmodifiable(_eventLog);
}
