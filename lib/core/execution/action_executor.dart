// ==================================================
// Z-CANVAS — PHASE-14 EXECUTION CORE & ACTION ENGINE
// core/execution/action_executor.dart
//
// PRIMARY ROLE: ATOMIC ACTION EXECUTION ENGINE
//
// OWNS:
//   ✔ Execute approved actions via injected engine adapters
//   ✔ Transaction-based micro-step execution with per-step confirmation
//   ✔ Add / Delete / Move / Resize layer execution
//   ✔ Style update execution
//   ✔ Undo / Redo trigger execution
//   ✔ Template apply execution
//   ✔ Export trigger execution (safe wrapper)
//   ✔ AI command dispatch execution
//   ✔ Render update trigger after every mutating action
//   ✔ Rollback trigger hook — signals orchestrator on any step failure
//   ✔ Execution status report per session
//
// DOES NOT OWN:
//   ❌ Decision making  ❌ Validation logic  ❌ UI logic  ❌ AI logic
//   ❌ Direct canvas access  ❌ Direct storage access  ❌ Safety checks
//
// RULE: EXECUTION ONLY — every engine call goes through an injected adapter.
// ==================================================

import 'dart:async';

import '../../controllers/execution_bridge.dart' show EditorControllerPayload;
import '../../controllers/action_router.dart'    show ActionType;
import '../../controllers/command_mapper.dart'   show
    CommandParams,
    AddLayerParams,
    DeleteLayerParams,
    MoveLayerParams,
    ResizeLayerParams,
    StyleUpdateParams,
    AiCommandParams,
    ExportRequestParams,
    UndoParams,
    RedoParams,
    TemplateRequestParams,
    PluginCommandParams,
    UnknownParams;
import 'editor_action_engine.dart' show ActionExecutorInterface;

// ==================================================
// TRANSACTION CONTEXT
// Carries session-level metadata through every micro-step.
// Passed to each adapter call so adapters can correlate their own logs.
// ==================================================

class TransactionContext {
  TransactionContext({
    required this.sessionId,
    required this.commandId,
    required this.actionType,
    required this.startedAt,
  });

  final String     sessionId;
  final String     commandId;
  final ActionType actionType;
  final DateTime   startedAt;

  final List<_StepRecord> _steps = [];

  /// Ordered list of micro-step results for this transaction.
  List<_StepRecord> get steps => List.unmodifiable(_steps);

  /// Records a completed micro-step (success or failure).
  void recordStep(ExecutorStep step, {required bool succeeded, String? detail}) {
    _steps.add(_StepRecord(
      step:      step,
      succeeded: succeeded,
      detail:    detail,
      recordedAt: DateTime.now().toUtc(),
    ));
  }

  /// True if every recorded step so far succeeded.
  bool get allStepsPassed => _steps.every((s) => s.succeeded);

  /// First failed step, or null.
  _StepRecord? get firstFailure =>
      _steps.cast<_StepRecord?>().firstWhere(
          (s) => s != null && !s.succeeded, orElse: () => null);

  Duration get elapsed => DateTime.now().toUtc().difference(startedAt);

  @override
  String toString() =>
      'TransactionContext(session: $sessionId, action: $actionType, '
      'steps: ${_steps.length}, elapsed: ${elapsed.inMilliseconds}ms)';
}

class _StepRecord {
  const _StepRecord({
    required this.step,
    required this.succeeded,
    required this.recordedAt,
    this.detail,
  });
  final ExecutorStep step;
  final bool         succeeded;
  final DateTime     recordedAt;
  final String?      detail;
}

// ==================================================
// EXECUTOR STEP REGISTRY
// Named micro-steps within every execution transaction.
// The order in which they appear reflects the execution order.
// ==================================================

enum ExecutorStep {
  // Layer-mutation steps
  applyLayerOperation,  // write to LayerEngine adapter
  writeHistoryEntry,    // record change to HistoryEngine adapter
  persistToStorage,     // optional durable write (some actions skip this)
  triggerRender,        // notify RenderEngine adapter to redraw

  // Undo / Redo steps
  applyUndoRedo,        // call HistoryEngine undo/redo
  renderAfterUndoRedo,

  // Export steps
  prepareExport,        // lock canvas for export
  runExport,            // ExportEngine writes artefact
  releaseExportLock,    // unlock canvas

  // Template steps
  applyTemplate,        // TemplateEngine applies layout
  writeTemplateHistory,
  renderAfterTemplate,

  // AI steps
  dispatchAiCommand,    // forward to AiEngineAdapter (fire-and-confirm)

  // Plugin steps
  dispatchPluginCommand,
}

// ==================================================
// EXECUTION STATUS REPORT
// Emitted by the executor at the end of every transaction attempt.
// The orchestrator uses this to decide commit vs rollback.
// ==================================================

class ExecutorReport {
  const ExecutorReport({
    required this.sessionId,
    required this.commandId,
    required this.actionType,
    required this.succeeded,
    required this.steps,
    required this.completedAt,
    this.failedStep,
    this.failureDetail,
  });

  final String           sessionId;
  final String           commandId;
  final ActionType       actionType;
  final bool             succeeded;
  final List<_StepRecord> steps;
  final DateTime         completedAt;
  final ExecutorStep?    failedStep;
  final String?          failureDetail;

  int get stepCount         => steps.length;
  int get succeededStepCount => steps.where((s) => s.succeeded).length;

  @override
  String toString() =>
      'ExecutorReport(session: $sessionId, action: $actionType, '
      'succeeded: $succeeded, steps: $stepCount)';
}

// ==================================================
// ENGINE ADAPTER INTERFACES
// Executor calls only these — never raw engine singletons or statics.
// Concrete implementations live outside Phase-14 and are injected.
// ==================================================

// — Layer Engine Adapter —
abstract interface class LayerEngineAdapterInterface {
  /// Inserts a new layer of [layerType] with optional [extra] properties.
  /// Returns the new layer's ID on success, or throws on failure.
  Future<String> addLayer(
      String layerType, Map<String, dynamic> extra, String sessionId);

  /// Removes the layer identified by [layerId].
  Future<void> deleteLayer(String layerId, String sessionId);

  /// Translates [layerId] by [dx] / [dy] units.
  Future<void> moveLayer(
      String layerId, double dx, double dy, String sessionId);

  /// Resizes [layerId] to [width] × [height].
  Future<void> resizeLayer(
      String layerId, double width, double height, String sessionId);

  /// Applies [styleProps] to [layerId].
  Future<void> updateStyle(
      String layerId, Map<String, dynamic> styleProps, String sessionId);
}

// — History Engine Adapter —
abstract interface class HistoryEngineAdapterInterface {
  /// Records a forward action entry in the history stack.
  Future<void> push(String actionDescription, String sessionId);

  /// Applies [steps] undo operations. Returns the number actually applied.
  Future<int> undo(int steps, String sessionId);

  /// Applies [steps] redo operations. Returns the number actually applied.
  Future<int> redo(int steps, String sessionId);
}

// — Storage Engine Adapter —
// Safe wrapper only — executor never calls storage directly.
abstract interface class StorageEngineAdapterInterface {
  /// Persists the current canvas state.
  /// Called after successful layer mutations; skipped for transient ops.
  Future<void> persist(String sessionId);

  /// Marks the current state as dirty (deferred persist).
  Future<void> markDirty(String sessionId);
}

// — Render Engine Adapter —
abstract interface class RenderEngineAdapterInterface {
  /// Signals the render pipeline to redraw the canvas.
  /// Returns when the render frame has been scheduled (not necessarily drawn).
  Future<void> requestRedraw(String sessionId);

  /// Returns true when the last requested redraw has been confirmed.
  Future<bool> confirmRedraw(String sessionId);
}

// — Export Engine Adapter —
abstract interface class ExportEngineAdapterInterface {
  /// Locks the canvas for export. Returns a lock token.
  Future<String> acquireLock(String sessionId);

  /// Runs the export for [format] at optional [quality].
  /// Returns the output file path or URL on success.
  Future<String> runExport(
      String format, double? quality, String lockToken, String sessionId);

  /// Releases the export lock identified by [lockToken].
  Future<void> releaseLock(String lockToken, String sessionId);
}

// — Template Engine Adapter —
abstract interface class TemplateEngineAdapterInterface {
  /// Applies [templateId] to the current canvas.
  Future<void> apply(
      String templateId, Map<String, dynamic> extra, String sessionId);
}

// — AI Engine Adapter —
abstract interface class AiEngineAdapterInterface {
  /// Forwards the [prompt] to the AI pipeline and waits for confirmation
  /// that the command was accepted (not necessarily completed).
  Future<void> dispatch(
      String prompt, Map<String, dynamic> context, String sessionId);
}

// — Plugin Engine Adapter —
abstract interface class PluginEngineAdapterInterface {
  /// Dispatches a plugin command to the plugin runtime.
  Future<void> dispatch(
      String pluginId, String commandKey,
      Map<String, dynamic> params, String sessionId);
}

// ==================================================
// ACTION EXECUTOR
// Implements ActionExecutorInterface (declared in editor_action_engine.dart).
// All engine access flows through injected adapter interfaces.
// ==================================================

class ActionExecutor implements ActionExecutorInterface {
  ActionExecutor({
    required LayerEngineAdapterInterface    layerEngine,
    required HistoryEngineAdapterInterface  historyEngine,
    required StorageEngineAdapterInterface  storageEngine,
    required RenderEngineAdapterInterface   renderEngine,
    required ExportEngineAdapterInterface   exportEngine,
    required TemplateEngineAdapterInterface templateEngine,
    required AiEngineAdapterInterface       aiEngine,
    required PluginEngineAdapterInterface   pluginEngine,
    ExecutorConfig config = const ExecutorConfig(),
  })  : _layer    = layerEngine,
        _history  = historyEngine,
        _storage  = storageEngine,
        _render   = renderEngine,
        _export   = exportEngine,
        _template = templateEngine,
        _ai       = aiEngine,
        _plugin   = pluginEngine,
        _config   = config;

  final LayerEngineAdapterInterface    _layer;
  final HistoryEngineAdapterInterface  _history;
  final StorageEngineAdapterInterface  _storage;
  final RenderEngineAdapterInterface   _render;
  final ExportEngineAdapterInterface   _export;
  final TemplateEngineAdapterInterface _template;
  final AiEngineAdapterInterface       _ai;
  final PluginEngineAdapterInterface   _plugin;
  final ExecutorConfig                 _config;

  // Per-instance report log (capped by config).
  final List<ExecutorReport> _reports = [];

  // --------------------------------------------------
  // PUBLIC API  (ActionExecutorInterface)
  // --------------------------------------------------

  @override
  Future<String?> execute(
      EditorControllerPayload payload, String sessionId) async {
    final ctx = TransactionContext(
      sessionId:  sessionId,
      commandId:  payload.commandId,
      actionType: payload.resolvedActionType,
      startedAt:  DateTime.now().toUtc(),
    );

    _log('[${ctx.sessionId}] Executor started | action=${ctx.actionType}');

    final error = await _dispatch(payload, ctx);

    final report = _buildReport(ctx, error);
    _appendReport(report);

    if (error != null) {
      _log('[${ctx.sessionId}] Executor FAILED at '
          '${report.failedStep?.name ?? "unknown"}: $error');
    } else {
      _log('[${ctx.sessionId}] Executor SUCCEEDED | '
          'steps=${report.stepCount} elapsed=${ctx.elapsed.inMilliseconds}ms');
    }

    return error;
  }

  /// Read-only list of all execution reports produced in this instance's lifetime.
  List<ExecutorReport> get reports => List.unmodifiable(_reports);

  // --------------------------------------------------
  // DISPATCH ROUTER
  // Routes to the correct atomic handler per action type.
  // Returns null on success, failure reason on error.
  // --------------------------------------------------

  Future<String?> _dispatch(
      EditorControllerPayload payload, TransactionContext ctx) async {
    return switch (payload.resolvedActionType) {
      ActionType.addLayer       => _executeAddLayer(payload, ctx),
      ActionType.deleteLayer    => _executeDeleteLayer(payload, ctx),
      ActionType.moveLayer      => _executeMoveLayer(payload, ctx),
      ActionType.resizeLayer    => _executeResizeLayer(payload, ctx),
      ActionType.styleUpdate    => _executeStyleUpdate(payload, ctx),
      ActionType.undo           => _executeUndo(payload, ctx),
      ActionType.redo           => _executeRedo(payload, ctx),
      ActionType.exportRequest  => _executeExport(payload, ctx),
      ActionType.templateRequest => _executeTemplate(payload, ctx),
      ActionType.aiCommand      => _executeAiCommand(payload, ctx),
      ActionType.unknown        => _executePlugin(payload, ctx),
    };
  }

  // ==================================================
  // ATOMIC HANDLERS — one per action type
  // Each follows: engine step → history step → [storage] → render step
  // Any step failure returns a reason string immediately.
  // ==================================================

  // --------------------------------------------------
  // ADD LAYER
  // Steps: applyLayerOperation → writeHistoryEntry → markDirty → triggerRender
  // --------------------------------------------------

  Future<String?> _executeAddLayer(
      EditorControllerPayload payload, TransactionContext ctx) async {
    final p = payload.params as AddLayerParams;

    // Step 1 — layer engine write.
    final layerError = await _step(ctx, ExecutorStep.applyLayerOperation,
        () => _layer.addLayer(p.layerType, p.extra, ctx.sessionId));
    if (layerError != null) return layerError;

    // Step 2 — history entry.
    final histError = await _step(ctx, ExecutorStep.writeHistoryEntry,
        () => _history.push(
            'addLayer type=${p.layerType}', ctx.sessionId));
    if (histError != null) return histError;

    // Step 3 — mark dirty (deferred persist; full persist on explicit save).
    if (_config.persistAfterMutation) {
      await _stepOptional(ctx, ExecutorStep.persistToStorage,
          () => _storage.markDirty(ctx.sessionId));
    }

    // Step 4 — render.
    return _executeRenderStep(ctx);
  }

  // --------------------------------------------------
  // DELETE LAYER
  // --------------------------------------------------

  Future<String?> _executeDeleteLayer(
      EditorControllerPayload payload, TransactionContext ctx) async {
    final p = payload.params as DeleteLayerParams;

    final layerError = await _step(ctx, ExecutorStep.applyLayerOperation,
        () => _layer.deleteLayer(p.layerId, ctx.sessionId));
    if (layerError != null) return layerError;

    final histError = await _step(ctx, ExecutorStep.writeHistoryEntry,
        () => _history.push(
            'deleteLayer id=${p.layerId}', ctx.sessionId));
    if (histError != null) return histError;

    if (_config.persistAfterMutation) {
      await _stepOptional(ctx, ExecutorStep.persistToStorage,
          () => _storage.markDirty(ctx.sessionId));
    }

    return _executeRenderStep(ctx);
  }

  // --------------------------------------------------
  // MOVE LAYER
  // --------------------------------------------------

  Future<String?> _executeMoveLayer(
      EditorControllerPayload payload, TransactionContext ctx) async {
    final p = payload.params as MoveLayerParams;

    final layerError = await _step(ctx, ExecutorStep.applyLayerOperation,
        () => _layer.moveLayer(p.layerId, p.dx, p.dy, ctx.sessionId));
    if (layerError != null) return layerError;

    final histError = await _step(ctx, ExecutorStep.writeHistoryEntry,
        () => _history.push(
            'moveLayer id=${p.layerId} dx=${p.dx} dy=${p.dy}',
            ctx.sessionId));
    if (histError != null) return histError;

    if (_config.persistAfterMutation) {
      await _stepOptional(ctx, ExecutorStep.persistToStorage,
          () => _storage.markDirty(ctx.sessionId));
    }

    return _executeRenderStep(ctx);
  }

  // --------------------------------------------------
  // RESIZE LAYER
  // --------------------------------------------------

  Future<String?> _executeResizeLayer(
      EditorControllerPayload payload, TransactionContext ctx) async {
    final p = payload.params as ResizeLayerParams;

    final layerError = await _step(ctx, ExecutorStep.applyLayerOperation,
        () => _layer.resizeLayer(
            p.layerId, p.width, p.height, ctx.sessionId));
    if (layerError != null) return layerError;

    final histError = await _step(ctx, ExecutorStep.writeHistoryEntry,
        () => _history.push(
            'resizeLayer id=${p.layerId} ${p.width}x${p.height}',
            ctx.sessionId));
    if (histError != null) return histError;

    if (_config.persistAfterMutation) {
      await _stepOptional(ctx, ExecutorStep.persistToStorage,
          () => _storage.markDirty(ctx.sessionId));
    }

    return _executeRenderStep(ctx);
  }

  // --------------------------------------------------
  // STYLE UPDATE
  // --------------------------------------------------

  Future<String?> _executeStyleUpdate(
      EditorControllerPayload payload, TransactionContext ctx) async {
    final p = payload.params as StyleUpdateParams;

    final layerError = await _step(ctx, ExecutorStep.applyLayerOperation,
        () => _layer.updateStyle(p.layerId, p.styleProps, ctx.sessionId));
    if (layerError != null) return layerError;

    final histError = await _step(ctx, ExecutorStep.writeHistoryEntry,
        () => _history.push(
            'styleUpdate id=${p.layerId} props=${p.styleProps.keys.join(",")}',
            ctx.sessionId));
    if (histError != null) return histError;

    if (_config.persistAfterMutation) {
      await _stepOptional(ctx, ExecutorStep.persistToStorage,
          () => _storage.markDirty(ctx.sessionId));
    }

    return _executeRenderStep(ctx);
  }

  // --------------------------------------------------
  // UNDO
  // Steps: applyUndoRedo → renderAfterUndoRedo
  // History engine owns the state restoration; executor only triggers it.
  // --------------------------------------------------

  Future<String?> _executeUndo(
      EditorControllerPayload payload, TransactionContext ctx) async {
    final p = payload.params as UndoParams;

    final undoError = await _step(ctx, ExecutorStep.applyUndoRedo,
        () => _history.undo(p.steps, ctx.sessionId));
    if (undoError != null) return undoError;

    return await _step(ctx, ExecutorStep.renderAfterUndoRedo,
        () => _render.requestRedraw(ctx.sessionId));
  }

  // --------------------------------------------------
  // REDO
  // --------------------------------------------------

  Future<String?> _executeRedo(
      EditorControllerPayload payload, TransactionContext ctx) async {
    final p = payload.params as RedoParams;

    final redoError = await _step(ctx, ExecutorStep.applyUndoRedo,
        () => _history.redo(p.steps, ctx.sessionId));
    if (redoError != null) return redoError;

    return await _step(ctx, ExecutorStep.renderAfterUndoRedo,
        () => _render.requestRedraw(ctx.sessionId));
  }

  // --------------------------------------------------
  // EXPORT
  // Steps: acquireLock → runExport → releaseLock
  // Canvas is locked for the duration to prevent mutation mid-render.
  // Render trigger is NOT called — exporting reads the current frame.
  // --------------------------------------------------

  Future<String?> _executeExport(
      EditorControllerPayload payload, TransactionContext ctx) async {
    final p = payload.params as ExportRequestParams;

    String? lockToken;

    // Step 1 — acquire export lock.
    String? lockError;
    try {
      lockToken = await _export.acquireLock(ctx.sessionId);
      ctx.recordStep(ExecutorStep.prepareExport,
          succeeded: true, detail: 'lock=$lockToken');
    } catch (e) {
      lockError = 'Export lock acquisition failed: $e';
      ctx.recordStep(ExecutorStep.prepareExport,
          succeeded: false, detail: lockError);
    }
    if (lockError != null) return lockError;

    // Step 2 — run export.
    String? exportError;
    try {
      final output = await _export.runExport(
          p.format, p.quality, lockToken!, ctx.sessionId);
      ctx.recordStep(ExecutorStep.runExport,
          succeeded: true, detail: 'output=$output');
    } catch (e) {
      exportError = 'Export execution failed: $e';
      ctx.recordStep(ExecutorStep.runExport,
          succeeded: false, detail: exportError);
    }

    // Step 3 — always release lock, even if export failed.
    try {
      await _export.releaseLock(lockToken!, ctx.sessionId);
      ctx.recordStep(ExecutorStep.releaseExportLock, succeeded: true);
    } catch (e) {
      // Lock release failure is logged but does not override a prior error.
      ctx.recordStep(ExecutorStep.releaseExportLock,
          succeeded: false, detail: 'Lock release failed: $e');
      _log('[${ctx.sessionId}] WARNING — export lock release failed: $e');
    }

    return exportError;
  }

  // --------------------------------------------------
  // TEMPLATE APPLY
  // Steps: applyTemplate → writeTemplateHistory → markDirty → renderAfterTemplate
  // --------------------------------------------------

  Future<String?> _executeTemplate(
      EditorControllerPayload payload, TransactionContext ctx) async {
    final p = payload.params as TemplateRequestParams;

    final tplError = await _step(ctx, ExecutorStep.applyTemplate,
        () => _template.apply(p.templateId, p.extra, ctx.sessionId));
    if (tplError != null) return tplError;

    final histError = await _step(ctx, ExecutorStep.writeTemplateHistory,
        () => _history.push(
            'templateApply id=${p.templateId}', ctx.sessionId));
    if (histError != null) return histError;

    if (_config.persistAfterMutation) {
      await _stepOptional(ctx, ExecutorStep.persistToStorage,
          () => _storage.persist(ctx.sessionId));
    }

    return await _step(ctx, ExecutorStep.renderAfterTemplate,
        () => _render.requestRedraw(ctx.sessionId));
  }

  // --------------------------------------------------
  // AI COMMAND
  // Single step: dispatch prompt to AI engine adapter.
  // The AI engine handles its own render pipeline — executor does not trigger.
  // --------------------------------------------------

  Future<String?> _executeAiCommand(
      EditorControllerPayload payload, TransactionContext ctx) async {
    final p = payload.params as AiCommandParams;

    return await _step(ctx, ExecutorStep.dispatchAiCommand,
        () => _ai.dispatch(p.prompt, p.context, ctx.sessionId));
  }

  // --------------------------------------------------
  // PLUGIN COMMAND
  // Single step: dispatch to plugin runtime adapter.
  // Render is the plugin's responsibility.
  // --------------------------------------------------

  Future<String?> _executePlugin(
      EditorControllerPayload payload, TransactionContext ctx) async {
    CommandParams params = payload.params;

    // PluginCommandParams arrive tagged as ActionType.unknown.
    if (params is! PluginCommandParams) {
      return 'executePlugin: expected PluginCommandParams but got '
          '${params.runtimeType}. '
          'UnknownParams without pluginId cannot be executed.';
    }

    return await _step(ctx, ExecutorStep.dispatchPluginCommand,
        () => _plugin.dispatch(
            params.pluginId, params.commandKey,
            params.params, ctx.sessionId));
  }

  // ==================================================
  // MICRO-STEP HELPERS
  // ==================================================

  /// Runs [fn], records the step, returns null on success or a failure string.
  /// On exception the step is recorded as failed and the reason is returned.
  Future<String?> _step<T>(
    TransactionContext ctx,
    ExecutorStep       step,
    Future<T> Function() fn,
  ) async {
    try {
      await fn();
      ctx.recordStep(step, succeeded: true);
      return null;
    } catch (e, stack) {
      final reason = '${step.name} failed: $e';
      ctx.recordStep(step, succeeded: false, detail: '$reason\n$stack');
      return reason;
    }
  }

  /// Runs [fn] as a best-effort optional step.
  /// Failure is recorded but does NOT propagate — execution continues.
  Future<void> _stepOptional<T>(
    TransactionContext ctx,
    ExecutorStep       step,
    Future<T> Function() fn,
  ) async {
    try {
      await fn();
      ctx.recordStep(step, succeeded: true);
    } catch (e) {
      ctx.recordStep(step,
          succeeded: false, detail: 'Optional step failed (non-blocking): $e');
      _log('[${ctx.sessionId}] Optional step ${step.name} failed '
          '(non-blocking): $e');
    }
  }

  /// Common render step shared by all layer-mutation handlers.
  Future<String?> _executeRenderStep(TransactionContext ctx) async {
    final renderError = await _step(ctx, ExecutorStep.triggerRender,
        () => _render.requestRedraw(ctx.sessionId));
    if (renderError != null) return renderError;

    // Optionally confirm the redraw was scheduled.
    if (_config.confirmRedrawAfterExecution) {
      try {
        final confirmed = await _render
            .confirmRedraw(ctx.sessionId)
            .timeout(Duration(milliseconds: _config.redrawConfirmTimeoutMs));
        if (!confirmed) {
          _log('[${ctx.sessionId}] WARNING — render redraw not confirmed '
              'within ${_config.redrawConfirmTimeoutMs}ms. '
              'Execution is still marked successful.');
        }
      } on TimeoutException {
        _log('[${ctx.sessionId}] WARNING — confirmRedraw timed out '
            'after ${_config.redrawConfirmTimeoutMs}ms (non-blocking).');
      } catch (e) {
        _log('[${ctx.sessionId}] WARNING — confirmRedraw threw: $e '
            '(non-blocking).');
      }
    }

    return null; // render confirmation failure is non-blocking
  }

  // --------------------------------------------------
  // REPORT BUILDER
  // --------------------------------------------------

  ExecutorReport _buildReport(TransactionContext ctx, String? error) {
    final failure = ctx.firstFailure;
    return ExecutorReport(
      sessionId:     ctx.sessionId,
      commandId:     ctx.commandId,
      actionType:    ctx.actionType,
      succeeded:     error == null,
      steps:         ctx.steps,
      completedAt:   DateTime.now().toUtc(),
      failedStep:    failure?.step,
      failureDetail: failure?.detail ?? error,
    );
  }

  void _appendReport(ExecutorReport report) {
    _reports.add(report);
    while (_reports.length > _config.reportRetentionLimit) {
      _reports.removeAt(0);
    }
  }

  // --------------------------------------------------
  // LOGGING
  // --------------------------------------------------

  void _log(String message) {
    // ignore: avoid_print
    print('[ActionExecutor] $message');
  }
}

// ==================================================
// EXECUTOR CONFIGURATION
// Controls optional execution behaviour without changing the pipeline flow.
// ==================================================

class ExecutorConfig {
  const ExecutorConfig({
    this.persistAfterMutation       = true,
    this.confirmRedrawAfterExecution = false,
    this.redrawConfirmTimeoutMs     = 500,
    this.reportRetentionLimit       = 500,
  });

  /// Whether to call [StorageEngineAdapterInterface.markDirty] after
  /// every layer mutation. Disable for high-frequency drag operations.
  final bool persistAfterMutation;

  /// Whether to await [RenderEngineAdapterInterface.confirmRedraw]
  /// after each render trigger. Enable for testability.
  final bool confirmRedrawAfterExecution;

  /// Timeout for awaiting redraw confirmation (milliseconds).
  final int redrawConfirmTimeoutMs;

  /// Maximum number of execution reports retained in memory.
  final int reportRetentionLimit;
}

// ==================================================
// NULL ADAPTER IMPLEMENTATIONS
// Safe no-op adapters for testing and dev injection.
// No real engine state is changed.
// ==================================================

class NullLayerEngineAdapter implements LayerEngineAdapterInterface {
  const NullLayerEngineAdapter();
  @override Future<String> addLayer(String t, Map e, String s) async =>
      'null-layer-id';
  @override Future<void> deleteLayer(String id, String s) async {}
  @override Future<void> moveLayer(String id, double dx, double dy, String s) async {}
  @override Future<void> resizeLayer(String id, double w, double h, String s) async {}
  @override Future<void> updateStyle(String id, Map p, String s) async {}
}

class NullHistoryEngineAdapter implements HistoryEngineAdapterInterface {
  const NullHistoryEngineAdapter();
  @override Future<void> push(String desc, String s) async {}
  @override Future<int>  undo(int steps, String s) async => steps;
  @override Future<int>  redo(int steps, String s) async => steps;
}

class NullStorageEngineAdapter implements StorageEngineAdapterInterface {
  const NullStorageEngineAdapter();
  @override Future<void> persist(String s) async {}
  @override Future<void> markDirty(String s) async {}
}

class NullRenderEngineAdapter implements RenderEngineAdapterInterface {
  const NullRenderEngineAdapter();
  @override Future<void> requestRedraw(String s) async {}
  @override Future<bool> confirmRedraw(String s) async => true;
}

class NullExportEngineAdapter implements ExportEngineAdapterInterface {
  const NullExportEngineAdapter();
  @override Future<String> acquireLock(String s) async => 'null-lock';
  @override Future<String> runExport(String f, double? q, String l, String s)
      async => '/dev/null/export.$f';
  @override Future<void> releaseLock(String l, String s) async {}
}

class NullTemplateEngineAdapter implements TemplateEngineAdapterInterface {
  const NullTemplateEngineAdapter();
  @override Future<void> apply(String id, Map e, String s) async {}
}

class NullAiEngineAdapter implements AiEngineAdapterInterface {
  const NullAiEngineAdapter();
  @override Future<void> dispatch(String p, Map c, String s) async {}
}

class NullPluginEngineAdapter implements PluginEngineAdapterInterface {
  const NullPluginEngineAdapter();
  @override Future<void> dispatch(String pi, String ck, Map p, String s) async {}
}

// ==================================================
// CONVENIENCE: FULLY-WIRED NULL EXECUTOR
// Returns an ActionExecutor wired with all null adapters.
// Useful for unit tests and development runs.
// ==================================================

ActionExecutor buildNullExecutor({ExecutorConfig config = const ExecutorConfig()}) =>
    ActionExecutor(
      layerEngine:    const NullLayerEngineAdapter(),
      historyEngine:  const NullHistoryEngineAdapter(),
      storageEngine:  const NullStorageEngineAdapter(),
      renderEngine:   const NullRenderEngineAdapter(),
      exportEngine:   const NullExportEngineAdapter(),
      templateEngine: const NullTemplateEngineAdapter(),
      aiEngine:       const NullAiEngineAdapter(),
      pluginEngine:   const NullPluginEngineAdapter(),
      config:         config,
    );

// ==================================================
// END OF core/execution/action_executor.dart
// Z-CANVAS — PHASE-14 — ATOMIC ACTION EXECUTION ENGINE
// Powered by Zynquar
// ==================================================
