// ==================================================
// Z-CANVAS — PHASE-13 ACTION BINDING & EXECUTION SYSTEM
// controllers/execution_bridge.dart
//
// PRIMARY ROLE: FINAL EXECUTION GATE (SAFETY LAYER)
//
// OWNS:
//   ✔ Validate the interpreted command (structure + safety + permissions)
//   ✔ Approve or reject with a recorded reason
//   ✔ Advance lifecycle: INTERPRETED → VALIDATED → APPROVED → DISPATCHED
//   ✔ Build a typed EditorControllerPayload
//   ✔ Hand off cleanly to EditorControllerInterface (the ONLY executor)
//   ✔ Maintain an immutable dispatch record per command
//
// DOES NOT OWN:
//   ❌ Direct engine access  ❌ Canvas / layer / storage manipulation
//   ❌ UI logic              ❌ Business logic decisions
//   ❌ Execution of any kind past the EditorController boundary
// ==================================================

import 'dart:async';
import 'dart:collection';
import 'action_router.dart';
import 'command_mapper.dart';
import 'intention_interpreter.dart';

// ==================================================
// EDITOR CONTROLLER PAYLOAD
// The typed, immutable handoff object forwarded to EditorController.
// Contains every field EditorController needs to execute the action —
// nothing more, nothing less. No engine references embedded.
// ==================================================

class EditorControllerPayload {
  const EditorControllerPayload({
    required this.commandId,
    required this.resolvedActionType,
    required this.params,
    required this.enrichment,
    required this.source,
    required this.confidence,
    required this.lifecycle,
  });

  /// Unique command identifier from ActionRouter (unchanged through pipeline).
  final String commandId;

  /// Action type after full semantic resolution.
  final ActionType resolvedActionType;

  /// Typed, validated parameters from CommandMapper.
  final CommandParams params;

  /// Semantic hints from IntentionInterpreter (may inform EditorController
  /// defaults but are never authoritative over typed params).
  final SemanticEnrichment enrichment;

  /// Origin channel of the original raw intent.
  final ActionSource source;

  /// Interpreter confidence score — EditorController may use this to
  /// decide whether to request user confirmation for low-confidence actions.
  final double confidence;

  /// Full lifecycle timing record.
  final CommandLifecycle lifecycle;

  @override
  String toString() =>
      'EditorControllerPayload(id: $commandId, '
      'action: $resolvedActionType, confidence: ${confidence.toStringAsFixed(2)})';
}

// ==================================================
// COMMAND LIFECYCLE
// Immutable timing record for every stage that a command passed through.
// Enables performance tracing and audit without coupling stages together.
// ==================================================

class CommandLifecycle {
  const CommandLifecycle({
    required this.receivedAt,
    required this.routedAt,
    required this.mappedAt,
    required this.interpretedAt,
    required this.validatedAt,
    required this.approvedAt,
    required this.dispatchedAt,
  });

  final DateTime receivedAt;    // ActionRouter
  final DateTime routedAt;      // ActionRouter → CommandMapper
  final DateTime mappedAt;      // CommandMapper → IntentionInterpreter
  final DateTime interpretedAt; // IntentionInterpreter → ExecutionBridge
  final DateTime validatedAt;   // ExecutionBridge validation pass
  final DateTime approvedAt;    // ExecutionBridge approval
  final DateTime dispatchedAt;  // Handed to EditorController

  /// Total wall-clock time from receipt to dispatch.
  Duration get totalDuration => dispatchedAt.difference(receivedAt);

  @override
  String toString() =>
      'CommandLifecycle(totalMs: ${totalDuration.inMilliseconds})';
}

// ==================================================
// DISPATCH RECORD
// Immutable audit entry written for every command the bridge processes,
// whether approved or rejected. Surfaced via [ExecutionBridge.dispatchLog].
// ==================================================

class DispatchRecord {
  const DispatchRecord({
    required this.commandId,
    required this.outcome,
    required this.resolvedActionType,
    required this.source,
    required this.confidence,
    required this.timestamp,
    this.rejectionReason,
    this.lifecycle,
  });

  final String       commandId;
  final DispatchOutcome outcome;
  final ActionType   resolvedActionType;
  final ActionSource source;
  final double       confidence;
  final DateTime     timestamp;
  final String?      rejectionReason;
  final CommandLifecycle? lifecycle;

  bool get wasDispatched => outcome == DispatchOutcome.dispatched;

  @override
  String toString() =>
      'DispatchRecord(id: $commandId, outcome: $outcome, '
      'action: $resolvedActionType)';
}

enum DispatchOutcome { dispatched, rejected, dropped }

// ==================================================
// VALIDATION RESULT
// Internal outcome of the bridge's validation pass.
// ==================================================

sealed class _ValidationResult {}

final class _ValidationPassed extends _ValidationResult {
  const _ValidationPassed();
}

final class _ValidationFailed extends _ValidationResult {
  const _ValidationFailed(this.reason);
  final String reason;
}

// ==================================================
// PERMISSION REGISTRY
// Declares which action types require an explicit permission token.
// The bridge checks whether the current session has that permission before
// approving. This is structural gate-keeping only — no business logic.
// ==================================================

enum BridgePermission {
  canAddLayer,
  canDeleteLayer,
  canMoveLayer,
  canResizeLayer,
  canStyleUpdate,
  canTriggerAi,
  canExport,
  canUndo,
  canRedo,
  canApplyTemplate,
  canRunPlugin,
}

const Map<ActionType, BridgePermission> _kPermissionMap = {
  ActionType.addLayer:       BridgePermission.canAddLayer,
  ActionType.deleteLayer:    BridgePermission.canDeleteLayer,
  ActionType.moveLayer:      BridgePermission.canMoveLayer,
  ActionType.resizeLayer:    BridgePermission.canResizeLayer,
  ActionType.styleUpdate:    BridgePermission.canStyleUpdate,
  ActionType.aiCommand:      BridgePermission.canTriggerAi,
  ActionType.exportRequest:  BridgePermission.canExport,
  ActionType.undo:           BridgePermission.canUndo,
  ActionType.redo:           BridgePermission.canRedo,
  ActionType.templateRequest: BridgePermission.canApplyTemplate,
  ActionType.unknown:        BridgePermission.canRunPlugin,
};

// ==================================================
// RATE LIMIT POLICY
// Maximum commands accepted per source per sliding window.
// Prevents runaway automation / AI loops from flooding EditorController.
// ==================================================

class _RateLimitPolicy {
  const _RateLimitPolicy({required this.maxPerWindow, required this.window});
  final int      maxPerWindow;
  final Duration window;
}

const Map<ActionSource, _RateLimitPolicy> _kRateLimits = {
  ActionSource.ui:       _RateLimitPolicy(maxPerWindow: 30,  window: Duration(seconds: 1)),
  ActionSource.voice:    _RateLimitPolicy(maxPerWindow: 5,   window: Duration(seconds: 1)),
  ActionSource.ai:       _RateLimitPolicy(maxPerWindow: 10,  window: Duration(seconds: 1)),
  ActionSource.gesture:  _RateLimitPolicy(maxPerWindow: 20,  window: Duration(seconds: 1)),
  ActionSource.plugin:   _RateLimitPolicy(maxPerWindow: 15,  window: Duration(seconds: 1)),
  ActionSource.internal: _RateLimitPolicy(maxPerWindow: 50,  window: Duration(seconds: 1)),
};

// ==================================================
// EDITOR CONTROLLER INTERFACE
// The ONLY boundary between Phase-13 and execution.
// Concrete implementation lives outside Phase-13.
// EditorController is the sole executor of all canvas / engine actions.
// ==================================================

abstract interface class EditorControllerInterface {
  /// Receives a fully-validated, approved [EditorControllerPayload] and
  /// executes the described action through the appropriate engine pipeline.
  ///
  /// This is the single point where Phase-13 ends and execution begins.
  /// The bridge calls this once per approved command — no retries, no fallback.
  Future<void> execute(EditorControllerPayload payload);
}

// ==================================================
// EXECUTION BRIDGE
// Implements ExecutionBridgeInterface (declared in intention_interpreter.dart).
// Owns the full INTERPRETED → VALIDATED → APPROVED → DISPATCHED transition.
// ==================================================

class ExecutionBridge implements ExecutionBridgeInterface {
  ExecutionBridge({
    required EditorControllerInterface  editorController,
    required Set<BridgePermission>       grantedPermissions,
    double   minimumConfidenceOverride  = ZConfidence.minimum,
  })  : _controller            = editorController,
        _grantedPermissions    = Set.unmodifiable(grantedPermissions),
        _minimumConfidence     = minimumConfidenceOverride;

  final EditorControllerInterface _controller;
  final Set<BridgePermission>      _grantedPermissions;
  final double                     _minimumConfidence;

  // Ordered audit log of every command processed by this bridge.
  final List<DispatchRecord> _dispatchLog = [];

  // Deduplication: commandIds seen in this session.
  final Set<String> _seenCommandIds = HashSet();

  // Rate-limit sliding window: source → list of timestamps in the window.
  final Map<ActionSource, List<DateTime>> _rateCounts = {};

  // --------------------------------------------------
  // PUBLIC API  (ExecutionBridgeInterface)
  // --------------------------------------------------

  @override
  Future<void> receive(InterpretedCommand command) async {
    _log('[${command.metadata.commandId}] Bridge received | '
        'state=${command.state} '
        'action=${command.intent.resolvedActionType} '
        'band=${command.intent.band}');

    // — GUARD: must arrive as INTERPRETED —
    if (command.state != CommandState.interpreted) {
      _reject(command, DispatchOutcome.dropped,
          'Expected state INTERPRETED, got ${command.state}.');
      return;
    }

    // — LIFECYCLE: VALIDATED —
    final validatedAt   = DateTime.now().toUtc();
    final validation    = _validate(command);

    switch (validation) {
      case _ValidationFailed(:final reason):
        _log('[${command.metadata.commandId}] REJECTED at validation — $reason');
        _reject(command, DispatchOutcome.rejected, reason,
            validatedAt: validatedAt);
        return;
      case _ValidationPassed():
        _log('[${command.metadata.commandId}] State → VALIDATED');
    }

    // — LIFECYCLE: APPROVED —
    final approvedAt = DateTime.now().toUtc();
    _log('[${command.metadata.commandId}] State → APPROVED');

    // — BUILD PAYLOAD —
    final lifecycle = _buildLifecycle(
      command:     command,
      validatedAt: validatedAt,
      approvedAt:  approvedAt,
      dispatchedAt: DateTime.now().toUtc(),
    );

    final payload = EditorControllerPayload(
      commandId:           command.metadata.commandId,
      resolvedActionType:  command.intent.resolvedActionType,
      params:              command.params,
      enrichment:          command.intent.enrichment,
      source:              command.metadata.source,
      confidence:          command.intent.confidence,
      lifecycle:           lifecycle,
    );

    // — LIFECYCLE: DISPATCHED —
    _log('[${command.metadata.commandId}] State → DISPATCHED → EditorController');

    _recordDispatch(DispatchRecord(
      commandId:          command.metadata.commandId,
      outcome:            DispatchOutcome.dispatched,
      resolvedActionType: command.intent.resolvedActionType,
      source:             command.metadata.source,
      confidence:         command.intent.confidence,
      timestamp:          lifecycle.dispatchedAt,
      lifecycle:          lifecycle,
    ));

    // — HAND OFF TO EDITORCONTROLLER — bridge responsibility ends here —
    try {
      await _controller.execute(payload);
    } catch (e, stack) {
      // EditorController threw — log but do NOT retry or fallback.
      // Phase-13 never re-executes a command.
      _log('[${command.metadata.commandId}] WARNING — EditorController '
          'threw (isolated): $e\n$stack');
    }
  }

  /// Read-only ordered audit log of every command that reached the bridge.
  List<DispatchRecord> get dispatchLog => List.unmodifiable(_dispatchLog);

  /// Clears session state (dedup set, rate counters, dispatch log).
  void resetSession() {
    _seenCommandIds.clear();
    _rateCounts.clear();
    _dispatchLog.clear();
    _log('Session reset.');
  }

  // --------------------------------------------------
  // VALIDATION PIPELINE
  // All checks must pass. First failure drops the command.
  // --------------------------------------------------

  _ValidationResult _validate(InterpretedCommand command) {
    // 1. Duplicate command guard.
    final dedupResult = _checkDedup(command.metadata.commandId);
    if (dedupResult != null) return _ValidationFailed(dedupResult);

    // 2. Confidence threshold.
    final confResult = _checkConfidence(command);
    if (confResult != null) return _ValidationFailed(confResult);

    // 3. Action type must be fully resolved.
    final typeResult = _checkResolvedType(command);
    if (typeResult != null) return _ValidationFailed(typeResult);

    // 4. Permission check.
    final permResult = _checkPermission(command);
    if (permResult != null) return _ValidationFailed(permResult);

    // 5. Payload integrity (no callable references).
    final integrityResult = _checkPayloadIntegrity(command.params);
    if (integrityResult != null) return _ValidationFailed(integrityResult);

    // 6. Rate limit.
    final rateResult = _checkRateLimit(command.metadata.source);
    if (rateResult != null) return _ValidationFailed(rateResult);

    // 7. Action-specific structural check.
    final structResult = _checkActionStructure(command);
    if (structResult != null) return _ValidationFailed(structResult);

    return const _ValidationPassed();
  }

  // --------------------------------------------------
  // CHECK: DEDUPLICATION
  // --------------------------------------------------

  String? _checkDedup(String commandId) {
    if (_seenCommandIds.contains(commandId)) {
      return 'Duplicate commandId "$commandId" — command already processed '
          'in this session.';
    }
    _seenCommandIds.add(commandId);
    return null;
  }

  // --------------------------------------------------
  // CHECK: CONFIDENCE THRESHOLD
  // --------------------------------------------------

  String? _checkConfidence(InterpretedCommand command) {
    final score = command.intent.confidence;
    if (score < _minimumConfidence) {
      return 'Confidence ${score.toStringAsFixed(2)} is below minimum '
          '${_minimumConfidence.toStringAsFixed(2)} for action '
          '${command.intent.resolvedActionType}.';
    }
    if (command.intent.band == ConfidenceBand.unresolvable) {
      return 'Command is unresolvable (band=unresolvable). Cannot approve.';
    }
    return null;
  }

  // --------------------------------------------------
  // CHECK: RESOLVED TYPE
  // unknown must have been resolved before reaching the bridge.
  // --------------------------------------------------

  String? _checkResolvedType(InterpretedCommand command) {
    if (command.intent.resolvedActionType == ActionType.unknown) {
      return 'ActionType is still unknown after interpretation. '
          'The bridge cannot dispatch an unresolved command.';
    }
    return null;
  }

  // --------------------------------------------------
  // CHECK: PERMISSION
  // --------------------------------------------------

  String? _checkPermission(InterpretedCommand command) {
    final required = _kPermissionMap[command.intent.resolvedActionType];
    if (required == null) return null; // no permission gating for this type
    if (!_grantedPermissions.contains(required)) {
      return 'Permission $required is required for '
          '${command.intent.resolvedActionType} but is not granted.';
    }
    return null;
  }

  // --------------------------------------------------
  // CHECK: PAYLOAD INTEGRITY
  // No Function or closure references anywhere in typed params.
  // --------------------------------------------------

  String? _checkPayloadIntegrity(CommandParams params) {
    switch (params) {
      case AddLayerParams p:
        return _scanMap(p.extra, 'AddLayerParams.extra');
      case StyleUpdateParams p:
        return _scanMap(p.styleProps, 'StyleUpdateParams.styleProps');
      case ExportRequestParams p:
        return _scanMap(p.extra, 'ExportRequestParams.extra');
      case TemplateRequestParams p:
        return _scanMap(p.extra, 'TemplateRequestParams.extra');
      case PluginCommandParams p:
        return _scanMap(p.params, 'PluginCommandParams.params');
      case AiCommandParams p:
        return _scanMap(p.context, 'AiCommandParams.context');
      default:
        return null;
    }
  }

  String? _scanMap(Map<String, dynamic> map, String location) {
    for (final entry in map.entries) {
      if (entry.value is Function) {
        return 'Payload integrity violation: Function reference found at '
            '$location["${entry.key}"].';
      }
      if (entry.value is Map<String, dynamic>) {
        final nested = _scanMap(
            entry.value as Map<String, dynamic>, '$location["${entry.key}"]');
        if (nested != null) return nested;
      }
    }
    return null;
  }

  // --------------------------------------------------
  // CHECK: RATE LIMIT
  // Sliding-window counter per ActionSource.
  // --------------------------------------------------

  String? _checkRateLimit(ActionSource source) {
    final policy = _kRateLimits[source];
    if (policy == null) return null;

    final now      = DateTime.now().toUtc();
    final cutoff   = now.subtract(policy.window);
    final window   = _rateCounts.putIfAbsent(source, () => []);

    // Evict timestamps outside the current window.
    window.removeWhere((t) => t.isBefore(cutoff));

    if (window.length >= policy.maxPerWindow) {
      return 'Rate limit exceeded for source $source: '
          '${window.length} commands in the last '
          '${policy.window.inMilliseconds}ms '
          '(max ${policy.maxPerWindow}).';
    }

    window.add(now);
    return null;
  }

  // --------------------------------------------------
  // CHECK: ACTION-SPECIFIC STRUCTURAL INVARIANTS
  // Last line of defence — catches edge cases the mapper/interpreter missed.
  // --------------------------------------------------

  String? _checkActionStructure(InterpretedCommand command) {
    return switch (command.params) {
      AddLayerParams p     => p.layerType.isEmpty
          ? 'addLayer: layerType must not be empty.'
          : null,

      DeleteLayerParams p  => p.layerId.isEmpty
          ? 'deleteLayer: layerId must not be empty.'
          : null,

      MoveLayerParams p    => p.layerId.isEmpty
          ? 'moveLayer: layerId must not be empty.'
          : (p.dx == 0 && p.dy == 0)
              ? 'moveLayer: dx=0 dy=0 is a no-op — rejected.'
              : null,

      ResizeLayerParams p  => p.layerId.isEmpty
          ? 'resizeLayer: layerId must not be empty.'
          : (p.width <= 0 || p.height <= 0)
              ? 'resizeLayer: width and height must be positive '
                '(got ${p.width}×${p.height}).'
              : null,

      StyleUpdateParams p  => p.layerId.isEmpty
          ? 'styleUpdate: layerId must not be empty.'
          : p.styleProps.isEmpty
              ? 'styleUpdate: styleProps must contain at least one entry.'
              : null,

      AiCommandParams p    => p.prompt.trim().isEmpty
          ? 'aiCommand: prompt must not be empty.'
          : null,

      ExportRequestParams p => p.format.trim().isEmpty
          ? 'exportRequest: format must not be empty.'
          : null,

      UndoParams p         => p.steps < 1
          ? 'undo: steps must be ≥ 1 (got ${p.steps}).'
          : null,

      RedoParams p         => p.steps < 1
          ? 'redo: steps must be ≥ 1 (got ${p.steps}).'
          : null,

      TemplateRequestParams p => p.templateId.isEmpty
          ? 'templateRequest: templateId must not be empty.'
          : null,

      PluginCommandParams p => (p.pluginId.isEmpty || p.commandKey.isEmpty)
          ? 'pluginCommand: pluginId and commandKey must not be empty.'
          : null,

      UnknownParams _ => 'UnknownParams reached the bridge unresolved. '
          'Interpreter must resolve ActionType before dispatch.',
    };
  }

  // --------------------------------------------------
  // LIFECYCLE BUILDER
  // Reconstructs the full timing chain from the upstream pipeline objects.
  // --------------------------------------------------

  CommandLifecycle _buildLifecycle({
    required InterpretedCommand command,
    required DateTime           validatedAt,
    required DateTime           approvedAt,
    required DateTime           dispatchedAt,
  }) {
    final meta   = command.metadata;
    final routed = meta.routedAt;
    final mapped = meta.mappedAt;

    // receivedAt is not directly stored after the router stage;
    // we approximate it as ≤ routedAt (sub-millisecond difference).
    final receivedAt = routed.subtract(const Duration(milliseconds: 1));

    return CommandLifecycle(
      receivedAt:    receivedAt,
      routedAt:      routed,
      mappedAt:      mapped,
      interpretedAt: command.interpretedAt,
      validatedAt:   validatedAt,
      approvedAt:    approvedAt,
      dispatchedAt:  dispatchedAt,
    );
  }

  // --------------------------------------------------
  // HELPERS
  // --------------------------------------------------

  void _reject(
    InterpretedCommand command,
    DispatchOutcome    outcome,
    String             reason, {
    DateTime?          validatedAt,
  }) {
    _log('[${command.metadata.commandId}] $outcome — $reason');
    _recordDispatch(DispatchRecord(
      commandId:          command.metadata.commandId,
      outcome:            outcome,
      resolvedActionType: command.intent.resolvedActionType,
      source:             command.metadata.source,
      confidence:         command.intent.confidence,
      timestamp:          DateTime.now().toUtc(),
      rejectionReason:    reason,
    ));
  }

  void _recordDispatch(DispatchRecord record) => _dispatchLog.add(record);

  void _log(String message) {
    // ignore: avoid_print
    print('[ExecutionBridge] $message');
  }
}

// ==================================================
// CONVENIENCE: FULL PERMISSION SET
// Pass to ExecutionBridge during development / testing when all actions
// should be permitted. In production, supply a scoped set per user role.
// ==================================================

const Set<BridgePermission> kAllPermissions = {
  BridgePermission.canAddLayer,
  BridgePermission.canDeleteLayer,
  BridgePermission.canMoveLayer,
  BridgePermission.canResizeLayer,
  BridgePermission.canStyleUpdate,
  BridgePermission.canTriggerAi,
  BridgePermission.canExport,
  BridgePermission.canUndo,
  BridgePermission.canRedo,
  BridgePermission.canApplyTemplate,
  BridgePermission.canRunPlugin,
};

// ==================================================
// CONVENIENCE: READ-ONLY PERMISSION SET
// Viewer / preview sessions — may observe but not mutate.
// ==================================================

const Set<BridgePermission> kReadOnlyPermissions = {
  BridgePermission.canExport,
};

// ==================================================
// CONVENIENCE: STANDARD EDITOR PERMISSION SET
// Typical logged-in editor user with AI and plugin access.
// ==================================================

const Set<BridgePermission> kEditorPermissions = {
  BridgePermission.canAddLayer,
  BridgePermission.canDeleteLayer,
  BridgePermission.canMoveLayer,
  BridgePermission.canResizeLayer,
  BridgePermission.canStyleUpdate,
  BridgePermission.canTriggerAi,
  BridgePermission.canExport,
  BridgePermission.canUndo,
  BridgePermission.canRedo,
  BridgePermission.canApplyTemplate,
};

// ==================================================
// PIPELINE FACTORY
// Wires all four Phase-13 stages together in the correct order.
// Returns the ActionRouter entry point — the only object callers need.
// EditorController is injected from outside Phase-13.
// ==================================================

class Phase13Pipeline {
  Phase13Pipeline._();

  /// Assembles the full Phase-13 command pipeline.
  ///
  /// ```dart
  /// final router = Phase13Pipeline.assemble(
  ///   editorController: myEditorController,
  ///   permissions:      kEditorPermissions,
  /// );
  ///
  /// // From a Phase-11 screen:
  /// await router.dispatch(RawIntentFactory.addLayer(layerType: 'text'));
  /// ```
  static ActionRouter assemble({
    required EditorControllerInterface editorController,
    required Set<BridgePermission>      permissions,
    double minimumConfidence = ZConfidence.minimum,
  }) {
    final bridge = ExecutionBridge(
      editorController:          editorController,
      grantedPermissions:        permissions,
      minimumConfidenceOverride: minimumConfidence,
    );

    final interpreter = IntentionInterpreter(bridge: bridge);
    final mapper      = CommandMapper(interpreter: interpreter);

    return ActionRouter(mapper: mapper);
  }
}

// ==================================================
// END OF controllers/execution_bridge.dart
// Z-CANVAS — PHASE-13 — FINAL EXECUTION GATE
// Powered by Zynquar
// ==================================================
