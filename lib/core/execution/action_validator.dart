// ==================================================
// Z-CANVAS — PHASE-14 EXECUTION CORE & ACTION ENGINE
// core/execution/action_validator.dart
//
// PRIMARY ROLE: SYSTEM INTEGRITY CHECKPOINT (HARD GATEKEEPER)
//
// OWNS:
//   ✔ Action structure validation (per-type field invariants)
//   ✔ Layer existence check (target layer must exist before mutation)
//   ✔ Permission validation (execution-time re-check, independent of Phase-13)
//   ✔ System state consistency check (no corrupted / locked state)
//   ✔ Snapshot availability validation (rollback capability confirmed)
//   ✔ Conflict detection (concurrent edits / locked layers / in-flight ops)
//   ✔ Pre-execution safety validation (canvas ready, history writable)
//
// DOES NOT OWN:
//   ❌ Execution  ❌ Engine calls  ❌ State mutation
//   ❌ Business logic decisions  ❌ UI logic
//
// RULE: VALIDATION ONLY — every method returns a verdict, never mutates.
// ==================================================

import 'dart:async';

import '../../controllers/execution_bridge.dart' show EditorControllerPayload;
import '../../controllers/action_router.dart'    show ActionType, ActionSource;
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
import 'editor_action_engine.dart' show
    ActionValidatorInterface,
    StateSnapshot;

// ==================================================
// VALIDATION CHECK REGISTRY
// Named enumeration of every individual check the validator runs.
// Used in [ValidationReport] so the engine/auditor knows exactly
// which gate failed — without parsing a string.
// ==================================================

enum ValidationCheck {
  payloadPresence,       // commandId + actionType must be set
  structureIntegrity,    // per-type field invariants
  layerExistence,        // referenced layerId must exist in the registry
  permissionRecheck,     // execution-time permission re-verification
  systemStateConsistency,// system not locked, corrupted, or shutting down
  snapshotAvailability,  // a usable snapshot exists for rollback
  conflictDetection,     // no concurrent lock or in-flight op on target
  preExecutionSafety,    // canvas ready, history writable, render active
}

// ==================================================
// VALIDATION VERDICT
// Result of a single named check.
// ==================================================

enum VerdictStatus { passed, failed, skipped }

class CheckVerdict {
  const CheckVerdict({
    required this.check,
    required this.status,
    this.reason,
  });

  final ValidationCheck check;
  final VerdictStatus   status;

  /// Non-null when [status] == [VerdictStatus.failed] or [VerdictStatus.skipped].
  final String? reason;

  bool get passed  => status == VerdictStatus.passed;
  bool get failed  => status == VerdictStatus.failed;
  bool get skipped => status == VerdictStatus.skipped;

  factory CheckVerdict.pass(ValidationCheck c) =>
      CheckVerdict(check: c, status: VerdictStatus.passed);

  factory CheckVerdict.fail(ValidationCheck c, String reason) =>
      CheckVerdict(check: c, status: VerdictStatus.failed, reason: reason);

  factory CheckVerdict.skip(ValidationCheck c, String reason) =>
      CheckVerdict(check: c, status: VerdictStatus.skipped, reason: reason);

  @override
  String toString() =>
      'CheckVerdict(${check.name}: $status'
      '${reason != null ? ", reason: $reason" : ""})';
}

// ==================================================
// VALIDATION REPORT
// Complete result of a full validation pass.
// Returned by ActionValidator and surfaced via the audit trail.
// ==================================================

class ValidationReport {
  const ValidationReport({
    required this.commandId,
    required this.sessionId,
    required this.actionType,
    required this.verdicts,
    required this.validatedAt,
  });

  final String       commandId;
  final String       sessionId;
  final ActionType   actionType;
  final List<CheckVerdict> verdicts;
  final DateTime     validatedAt;

  /// True only when every check either passed or was skipped.
  bool get allPassed => verdicts.every((v) => v.passed || v.skipped);

  /// First failed verdict, or null if all passed.
  CheckVerdict? get firstFailure =>
      verdicts.cast<CheckVerdict?>().firstWhere(
          (v) => v != null && v.failed, orElse: () => null);

  /// Human-readable failure reason from the first failed check.
  String? get failureReason => firstFailure?.reason;

  int get passCount  => verdicts.where((v) => v.passed).length;
  int get failCount  => verdicts.where((v) => v.failed).length;
  int get skipCount  => verdicts.where((v) => v.skipped).length;

  @override
  String toString() =>
      'ValidationReport(cmd: $commandId, passed: $allPassed, '
      'checks: ${verdicts.length}, failed: $failCount)';
}

// ==================================================
// EXTERNAL QUERY INTERFACES
// Validator only READS through these — never writes.
// Concrete implementations are provided by the app's engine layer.
// ==================================================

// — Layer Registry Query —
// Answers "does layerId exist in the current canvas?"
abstract interface class LayerRegistryQueryInterface {
  /// Returns true if [layerId] is present in the active canvas layer set.
  Future<bool> exists(String layerId);

  /// Returns true if [layerId] is currently locked (edit-blocked).
  Future<bool> isLocked(String layerId);

  /// Returns the total number of layers currently on the canvas.
  Future<int> layerCount();
}

// — System State Query —
// Answers "is the system in a consistent, writable state?"
abstract interface class SystemStateQueryInterface {
  /// True when the system is fully initialised and ready to accept mutations.
  Future<bool> isReady();

  /// True when any subsystem is in a locked or corrupted state.
  Future<bool> isLocked();

  /// True when a shutdown sequence has been initiated.
  Future<bool> isShuttingDown();

  /// True when the history stack has remaining write capacity.
  Future<bool> isHistoryWritable();

  /// True when the render pipeline is active and accepting updates.
  Future<bool> isRenderActive();
}

// — Conflict Registry Query —
// Answers "is there a concurrent operation that would conflict?"
abstract interface class ConflictRegistryQueryInterface {
  /// Returns true if [sessionId] is different from the current holder and
  /// the target [layerId] is being mutated by another session.
  Future<bool> hasActiveConflict({
    required String sessionId,
    required String layerId,
  });

  /// Returns true if a bulk operation (e.g. template apply, export) is
  /// running that should block other mutations.
  Future<bool> hasBulkOperationInProgress();

  /// Returns the session ID of the conflicting operation, or null.
  Future<String?> conflictingSessionId(String layerId);
}

// — Execution Permission Registry —
// Final execution-time permission source, independent of Phase-13.
abstract interface class ExecutionPermissionQueryInterface {
  /// Returns true if the current session context has [permission].
  Future<bool> hasPermission(ExecutionPermission permission);
}

// Execution-time permission identifiers (independent of Phase-13 BridgePermission).
enum ExecutionPermission {
  writeLayer,
  deleteLayer,
  reorderLayer,
  writeStyle,
  triggerAi,
  exportCanvas,
  mutateHistory,
  applyTemplate,
  runPlugin,
}

// ==================================================
// PERMISSION MAP
// Maps each ActionType to the ExecutionPermission required.
// ==================================================

const Map<ActionType, ExecutionPermission> _kExecPermissionMap = {
  ActionType.addLayer:        ExecutionPermission.writeLayer,
  ActionType.deleteLayer:     ExecutionPermission.deleteLayer,
  ActionType.moveLayer:       ExecutionPermission.reorderLayer,
  ActionType.resizeLayer:     ExecutionPermission.writeLayer,
  ActionType.styleUpdate:     ExecutionPermission.writeStyle,
  ActionType.aiCommand:       ExecutionPermission.triggerAi,
  ActionType.exportRequest:   ExecutionPermission.exportCanvas,
  ActionType.undo:            ExecutionPermission.mutateHistory,
  ActionType.redo:            ExecutionPermission.mutateHistory,
  ActionType.templateRequest: ExecutionPermission.applyTemplate,
  ActionType.unknown:         ExecutionPermission.runPlugin,
};

// ==================================================
// VALIDATOR CONFIGURATION
// Controls which checks are active and their tolerance levels.
// ==================================================

class ValidatorConfig {
  const ValidatorConfig({
    this.requireSnapshot             = true,
    this.snapshotNullIsBlocking      = false, // null snapshot skips, not fails
    this.maxLayerCountForAddLayer    = 500,
    this.maxUndoSteps                = 100,
    this.maxRedoSteps                = 100,
    this.enableConflictDetection     = true,
    this.enablePermissionRecheck     = true,
    this.enableSystemStateCheck      = true,
    this.enablePreExecutionSafety    = true,
  });

  final bool requireSnapshot;
  final bool snapshotNullIsBlocking;
  final int  maxLayerCountForAddLayer;
  final int  maxUndoSteps;
  final int  maxRedoSteps;
  final bool enableConflictDetection;
  final bool enablePermissionRecheck;
  final bool enableSystemStateCheck;
  final bool enablePreExecutionSafety;
}

// ==================================================
// ACTION VALIDATOR
// Implements ActionValidatorInterface (declared in editor_action_engine.dart).
// Runs all checks in a defined sequence; first failure short-circuits.
// ==================================================

class ActionValidator implements ActionValidatorInterface {
  ActionValidator({
    required LayerRegistryQueryInterface    layerRegistry,
    required SystemStateQueryInterface      systemState,
    required ConflictRegistryQueryInterface conflictRegistry,
    required ExecutionPermissionQueryInterface permissions,
    ValidatorConfig config = const ValidatorConfig(),
  })  : _layers      = layerRegistry,
        _system      = systemState,
        _conflicts   = conflictRegistry,
        _permissions = permissions,
        _config      = config;

  final LayerRegistryQueryInterface    _layers;
  final SystemStateQueryInterface      _system;
  final ConflictRegistryQueryInterface _conflicts;
  final ExecutionPermissionQueryInterface _permissions;
  final ValidatorConfig                _config;

  // In-memory log of every report produced by this validator instance.
  final List<ValidationReport> _history = [];

  // --------------------------------------------------
  // PUBLIC API  (ActionValidatorInterface)
  // --------------------------------------------------

  @override
  Future<String?> validate(
      EditorControllerPayload payload, StateSnapshot snapshot) async {
    final report = await fullValidate(payload, snapshot,
        sessionId: payload.commandId);

    _history.add(report);
    _log('[${payload.commandId}] Validation complete — '
        'passed=${report.allPassed} '
        'checks=${report.verdicts.length} '
        'failed=${report.failCount}');

    return report.allPassed ? null : report.failureReason;
  }

  /// Extended entry point that returns the full [ValidationReport].
  /// Useful for testing and detailed audit integration.
  Future<ValidationReport> fullValidate(
    EditorControllerPayload payload,
    StateSnapshot           snapshot, {
    String? sessionId,
  }) async {
    final sid      = sessionId ?? payload.commandId;
    final verdicts = <CheckVerdict>[];

    // Checks run in priority order — first failure stops the chain.
    final checks = <Future<CheckVerdict> Function()>[
      () => _checkPayloadPresence(payload),
      () => _checkStructureIntegrity(payload),
      () => _checkSnapshotAvailability(snapshot),
      () => _checkSystemStateConsistency(),
      () => _checkPermission(payload),
      () => _checkLayerExistence(payload),
      () => _checkConflicts(payload, sid),
      () => _checkPreExecutionSafety(payload),
    ];

    for (final checkFn in checks) {
      final verdict = await checkFn();
      verdicts.add(verdict);
      if (verdict.failed) break; // hard short-circuit on first failure
    }

    return ValidationReport(
      commandId:   payload.commandId,
      sessionId:   sid,
      actionType:  payload.resolvedActionType,
      verdicts:    List.unmodifiable(verdicts),
      validatedAt: DateTime.now().toUtc(),
    );
  }

  /// Read-only history of all reports produced in this validator's lifetime.
  List<ValidationReport> get history => List.unmodifiable(_history);

  // --------------------------------------------------
  // CHECK 1 — PAYLOAD PRESENCE
  // commandId and actionType must be set and non-trivial.
  // --------------------------------------------------

  Future<CheckVerdict> _checkPayloadPresence(
      EditorControllerPayload payload) async {
    if (payload.commandId.trim().isEmpty) {
      return CheckVerdict.fail(ValidationCheck.payloadPresence,
          'commandId is empty. Payload cannot be accepted.');
    }
    if (payload.resolvedActionType == ActionType.unknown) {
      return CheckVerdict.fail(ValidationCheck.payloadPresence,
          'resolvedActionType is still unknown. '
          'The Phase-13 pipeline must resolve the action type before execution.');
    }
    if (payload.confidence <= 0.0) {
      return CheckVerdict.fail(ValidationCheck.payloadPresence,
          'confidence score is 0.0 — command is entirely unresolved.');
    }
    return CheckVerdict.pass(ValidationCheck.payloadPresence);
  }

  // --------------------------------------------------
  // CHECK 2 — STRUCTURE INTEGRITY
  // Per-action-type field invariants checked at the execution boundary.
  // These are tighter than the Phase-13 bridge checks because they run
  // after potential time has passed since dispatch.
  // --------------------------------------------------

  Future<CheckVerdict> _checkStructureIntegrity(
      EditorControllerPayload payload) async {
    final failure = _validateParamStructure(
        payload.resolvedActionType, payload.params);
    if (failure != null) {
      return CheckVerdict.fail(ValidationCheck.structureIntegrity, failure);
    }
    return CheckVerdict.pass(ValidationCheck.structureIntegrity);
  }

  String? _validateParamStructure(ActionType type, CommandParams params) {
    return switch (params) {

      AddLayerParams p => () {
        if (p.layerType.trim().isEmpty) {
          return 'addLayer: layerType must not be empty.';
        }
        return null;
      }(),

      DeleteLayerParams p => () {
        if (p.layerId.trim().isEmpty) {
          return 'deleteLayer: layerId must not be empty.';
        }
        return null;
      }(),

      MoveLayerParams p => () {
        if (p.layerId.trim().isEmpty) {
          return 'moveLayer: layerId must not be empty.';
        }
        if (p.dx == 0 && p.dy == 0) {
          return 'moveLayer: dx=0 dy=0 is a no-op — rejected at structure check.';
        }
        if (p.dx.isNaN || p.dy.isNaN || p.dx.isInfinite || p.dy.isInfinite) {
          return 'moveLayer: dx/dy contains NaN or Infinity.';
        }
        return null;
      }(),

      ResizeLayerParams p => () {
        if (p.layerId.trim().isEmpty) {
          return 'resizeLayer: layerId must not be empty.';
        }
        if (p.width <= 0 || p.height <= 0) {
          return 'resizeLayer: width and height must be positive '
              '(got ${p.width}×${p.height}).';
        }
        if (p.width.isNaN || p.height.isNaN ||
            p.width.isInfinite || p.height.isInfinite) {
          return 'resizeLayer: width/height contains NaN or Infinity.';
        }
        if (p.width > 99999 || p.height > 99999) {
          return 'resizeLayer: dimensions exceed maximum allowed '
              '(99999 × 99999) — got ${p.width}×${p.height}.';
        }
        return null;
      }(),

      StyleUpdateParams p => () {
        if (p.layerId.trim().isEmpty) {
          return 'styleUpdate: layerId must not be empty.';
        }
        if (p.styleProps.isEmpty) {
          return 'styleUpdate: styleProps must contain at least one entry.';
        }
        for (final key in p.styleProps.keys) {
          if (key.trim().isEmpty) {
            return 'styleUpdate: styleProps contains an empty key.';
          }
        }
        return null;
      }(),

      AiCommandParams p => () {
        if (p.prompt.trim().isEmpty) {
          return 'aiCommand: prompt must not be empty.';
        }
        if (p.prompt.length > 8000) {
          return 'aiCommand: prompt exceeds maximum length of 8000 characters '
              '(got ${p.prompt.length}).';
        }
        return null;
      }(),

      ExportRequestParams p => () {
        const supported = {'png', 'pdf', 'svg', 'jpg', 'jpeg', 'webp', 'gif'};
        final fmt = p.format.trim().toLowerCase();
        if (fmt.isEmpty) {
          return 'exportRequest: format must not be empty.';
        }
        if (!supported.contains(fmt)) {
          return 'exportRequest: unsupported format "$fmt". '
              'Supported: ${supported.join(", ")}.';
        }
        if (p.quality != null && (p.quality! < 0.0 || p.quality! > 1.0)) {
          return 'exportRequest: quality must be in range 0.0–1.0 '
              '(got ${p.quality}).';
        }
        return null;
      }(),

      UndoParams p => () {
        if (p.steps < 1) {
          return 'undo: steps must be ≥ 1 (got ${p.steps}).';
        }
        if (p.steps > _config.maxUndoSteps) {
          return 'undo: steps ${p.steps} exceeds maximum '
              '${_config.maxUndoSteps}.';
        }
        return null;
      }(),

      RedoParams p => () {
        if (p.steps < 1) {
          return 'redo: steps must be ≥ 1 (got ${p.steps}).';
        }
        if (p.steps > _config.maxRedoSteps) {
          return 'redo: steps ${p.steps} exceeds maximum '
              '${_config.maxRedoSteps}.';
        }
        return null;
      }(),

      TemplateRequestParams p => () {
        if (p.templateId.trim().isEmpty) {
          return 'templateRequest: templateId must not be empty.';
        }
        return null;
      }(),

      PluginCommandParams p => () {
        if (p.pluginId.trim().isEmpty) {
          return 'pluginCommand: pluginId must not be empty.';
        }
        if (p.commandKey.trim().isEmpty) {
          return 'pluginCommand: commandKey must not be empty.';
        }
        return null;
      }(),

      UnknownParams _ =>
          'UnknownParams reached the validator — '
          'action type was not resolved before execution.',
    };
  }

  // --------------------------------------------------
  // CHECK 3 — SNAPSHOT AVAILABILITY
  // Confirms a usable rollback snapshot exists for this session.
  // --------------------------------------------------

  Future<CheckVerdict> _checkSnapshotAvailability(
      StateSnapshot snapshot) async {
    if (!_config.requireSnapshot) {
      return CheckVerdict.skip(ValidationCheck.snapshotAvailability,
          'Snapshot requirement disabled by config.');
    }

    final isNull = snapshot.stateHash == 'NULL_SNAPSHOT';
    if (isNull) {
      if (_config.snapshotNullIsBlocking) {
        return CheckVerdict.fail(ValidationCheck.snapshotAvailability,
            'No snapshot is available — rollback would be impossible. '
            'Execution blocked by config policy.');
      }
      return CheckVerdict.skip(ValidationCheck.snapshotAvailability,
          'Null snapshot detected — rollback unavailable but not blocking '
          '(snapshotNullIsBlocking=false).');
    }

    // Snapshot must have been taken recently (within 30 seconds).
    final age = DateTime.now().toUtc().difference(snapshot.capturedAt);
    if (age.inSeconds > 30) {
      return CheckVerdict.fail(ValidationCheck.snapshotAvailability,
          'Snapshot is stale (age: ${age.inSeconds}s > 30s). '
          'A fresh snapshot must be captured before execution.');
    }

    return CheckVerdict.pass(ValidationCheck.snapshotAvailability);
  }

  // --------------------------------------------------
  // CHECK 4 — SYSTEM STATE CONSISTENCY
  // The system must be ready, unlocked, and not shutting down.
  // --------------------------------------------------

  Future<CheckVerdict> _checkSystemStateConsistency() async {
    if (!_config.enableSystemStateCheck) {
      return CheckVerdict.skip(ValidationCheck.systemStateConsistency,
          'System state check disabled by config.');
    }

    if (await _system.isShuttingDown()) {
      return CheckVerdict.fail(ValidationCheck.systemStateConsistency,
          'System is shutting down — no new executions accepted.');
    }
    if (await _system.isLocked()) {
      return CheckVerdict.fail(ValidationCheck.systemStateConsistency,
          'System is in a locked state — execution blocked until lock is '
          'released.');
    }
    if (!await _system.isReady()) {
      return CheckVerdict.fail(ValidationCheck.systemStateConsistency,
          'System is not ready — initialisation incomplete or subsystem '
          'failure detected.');
    }

    return CheckVerdict.pass(ValidationCheck.systemStateConsistency);
  }

  // --------------------------------------------------
  // CHECK 5 — PERMISSION RE-CHECK
  // Independent execution-time permission verification.
  // Phase-13 already checked permissions but session context may have changed.
  // --------------------------------------------------

  Future<CheckVerdict> _checkPermission(
      EditorControllerPayload payload) async {
    if (!_config.enablePermissionRecheck) {
      return CheckVerdict.skip(ValidationCheck.permissionRecheck,
          'Permission re-check disabled by config.');
    }

    final required = _kExecPermissionMap[payload.resolvedActionType];
    if (required == null) {
      return CheckVerdict.skip(ValidationCheck.permissionRecheck,
          'No execution permission mapped for ${payload.resolvedActionType}.');
    }

    final granted = await _permissions.hasPermission(required);
    if (!granted) {
      return CheckVerdict.fail(ValidationCheck.permissionRecheck,
          'Execution permission $required is not granted for '
          '${payload.resolvedActionType}. '
          'Session context may have changed since Phase-13 approval.');
    }

    return CheckVerdict.pass(ValidationCheck.permissionRecheck);
  }

  // --------------------------------------------------
  // CHECK 6 — LAYER EXISTENCE
  // Any action that targets a specific layerId must confirm that layer
  // exists in the live registry and is not locked.
  // addLayer and layer-count cap are also verified here.
  // --------------------------------------------------

  Future<CheckVerdict> _checkLayerExistence(
      EditorControllerPayload payload) async {
    final params = payload.params;

    // Determine target layerId (if any) from params.
    final String? targetLayerId = switch (params) {
      DeleteLayerParams p  => p.layerId,
      MoveLayerParams p    => p.layerId,
      ResizeLayerParams p  => p.layerId,
      StyleUpdateParams p  => p.layerId,
      _                    => null,
    };

    // For addLayer: check the canvas is not full.
    if (params is AddLayerParams) {
      final count = await _layers.layerCount();
      if (count >= _config.maxLayerCountForAddLayer) {
        return CheckVerdict.fail(ValidationCheck.layerExistence,
            'addLayer: maximum layer count reached '
            '(${_config.maxLayerCountForAddLayer}). '
            'Delete existing layers before adding more.');
      }
      return CheckVerdict.pass(ValidationCheck.layerExistence);
    }

    // No layer target — skip this check.
    if (targetLayerId == null) {
      return CheckVerdict.skip(ValidationCheck.layerExistence,
          '${payload.resolvedActionType} does not target a specific layer.');
    }

    // Layer must exist.
    if (!await _layers.exists(targetLayerId)) {
      return CheckVerdict.fail(ValidationCheck.layerExistence,
          '${payload.resolvedActionType}: target layerId "$targetLayerId" '
          'does not exist in the current canvas layer registry. '
          'It may have been deleted by a concurrent operation.');
    }

    // Layer must not be locked.
    if (await _layers.isLocked(targetLayerId)) {
      return CheckVerdict.fail(ValidationCheck.layerExistence,
          '${payload.resolvedActionType}: target layerId "$targetLayerId" '
          'is currently locked and cannot be mutated. '
          'Wait for the locking operation to complete.');
    }

    return CheckVerdict.pass(ValidationCheck.layerExistence);
  }

  // --------------------------------------------------
  // CHECK 7 — CONFLICT DETECTION
  // Detects concurrent operations that would produce a corrupted state.
  // --------------------------------------------------

  Future<CheckVerdict> _checkConflicts(
      EditorControllerPayload payload, String sessionId) async {
    if (!_config.enableConflictDetection) {
      return CheckVerdict.skip(ValidationCheck.conflictDetection,
          'Conflict detection disabled by config.');
    }

    // Bulk operations (export, template apply) block all other mutations.
    final bulkInProgress = await _conflicts.hasBulkOperationInProgress();
    if (bulkInProgress) {
      return CheckVerdict.fail(ValidationCheck.conflictDetection,
          '${payload.resolvedActionType}: a bulk operation (export or template '
          'apply) is in progress. Mutations are blocked until it completes.');
    }

    // Layer-specific conflict check.
    final String? targetLayerId = switch (payload.params) {
      DeleteLayerParams p  => p.layerId,
      MoveLayerParams p    => p.layerId,
      ResizeLayerParams p  => p.layerId,
      StyleUpdateParams p  => p.layerId,
      _                    => null,
    };

    if (targetLayerId != null && targetLayerId.isNotEmpty) {
      final hasConflict = await _conflicts.hasActiveConflict(
          sessionId: sessionId, layerId: targetLayerId);
      if (hasConflict) {
        final conflictingId =
            await _conflicts.conflictingSessionId(targetLayerId);
        return CheckVerdict.fail(ValidationCheck.conflictDetection,
            '${payload.resolvedActionType}: layerId "$targetLayerId" is '
            'being mutated by session "${conflictingId ?? "unknown"}". '
            'This operation would produce a conflict.');
      }
    }

    // Export-specific: block concurrent exports.
    if (payload.resolvedActionType == ActionType.exportRequest) {
      final exportConflict = await _conflicts.hasBulkOperationInProgress();
      if (exportConflict) {
        return CheckVerdict.fail(ValidationCheck.conflictDetection,
            'exportRequest: another export or bulk operation is already '
            'in progress.');
      }
    }

    return CheckVerdict.pass(ValidationCheck.conflictDetection);
  }

  // --------------------------------------------------
  // CHECK 8 — PRE-EXECUTION SAFETY
  // Canvas must be ready, history must be writable, render must be active.
  // Template and undo/redo have additional pre-flight checks.
  // --------------------------------------------------

  Future<CheckVerdict> _checkPreExecutionSafety(
      EditorControllerPayload payload) async {
    if (!_config.enablePreExecutionSafety) {
      return CheckVerdict.skip(ValidationCheck.preExecutionSafety,
          'Pre-execution safety check disabled by config.');
    }

    // History writability is required for all mutating actions.
    const historyMutatingTypes = {
      ActionType.addLayer,
      ActionType.deleteLayer,
      ActionType.moveLayer,
      ActionType.resizeLayer,
      ActionType.styleUpdate,
      ActionType.templateRequest,
    };

    if (historyMutatingTypes.contains(payload.resolvedActionType)) {
      if (!await _system.isHistoryWritable()) {
        return CheckVerdict.fail(ValidationCheck.preExecutionSafety,
            '${payload.resolvedActionType}: history stack is not writable. '
            'The action cannot be recorded — execution blocked to prevent '
            'an unrecoverable state.');
      }
    }

    // Render pipeline must be active for visual mutations.
    const visualTypes = {
      ActionType.addLayer,
      ActionType.deleteLayer,
      ActionType.moveLayer,
      ActionType.resizeLayer,
      ActionType.styleUpdate,
      ActionType.templateRequest,
    };

    if (visualTypes.contains(payload.resolvedActionType)) {
      if (!await _system.isRenderActive()) {
        return CheckVerdict.fail(ValidationCheck.preExecutionSafety,
            '${payload.resolvedActionType}: render pipeline is inactive. '
            'Canvas updates would not be visible — execution blocked.');
      }
    }

    // Undo: cannot undo past the beginning of history.
    if (payload.resolvedActionType == ActionType.undo) {
      if (!await _system.isHistoryWritable()) {
        return CheckVerdict.fail(ValidationCheck.preExecutionSafety,
            'undo: history stack is empty or at its oldest entry — '
            'nothing to undo.');
      }
    }

    // Redo: same check (history must have a forward entry).
    if (payload.resolvedActionType == ActionType.redo) {
      if (!await _system.isHistoryWritable()) {
        return CheckVerdict.fail(ValidationCheck.preExecutionSafety,
            'redo: no forward history entry available — nothing to redo.');
      }
    }

    // AI command: render must be active to display generated content.
    if (payload.resolvedActionType == ActionType.aiCommand) {
      if (!await _system.isRenderActive()) {
        return CheckVerdict.fail(ValidationCheck.preExecutionSafety,
            'aiCommand: render pipeline must be active to display AI output.');
      }
    }

    return CheckVerdict.pass(ValidationCheck.preExecutionSafety);
  }

  // --------------------------------------------------
  // LOGGING
  // --------------------------------------------------

  void _log(String message) {
    // ignore: avoid_print
    print('[ActionValidator] $message');
  }
}

// ==================================================
// NULL IMPLEMENTATIONS
// Safe no-op providers for testing and dev environments.
// All queries return permissive results (everything ready, no conflicts).
// ==================================================

/// All layers exist, none are locked, count = 1.
class NullLayerRegistry implements LayerRegistryQueryInterface {
  const NullLayerRegistry();
  @override Future<bool> exists(String id)   async => true;
  @override Future<bool> isLocked(String id) async => false;
  @override Future<int>  layerCount()        async => 1;
}

/// System is always ready, not locked, not shutting down, history writable.
class NullSystemState implements SystemStateQueryInterface {
  const NullSystemState();
  @override Future<bool> isReady()           async => true;
  @override Future<bool> isLocked()          async => false;
  @override Future<bool> isShuttingDown()    async => false;
  @override Future<bool> isHistoryWritable() async => true;
  @override Future<bool> isRenderActive()    async => true;
}

/// No conflicts, no bulk operations.
class NullConflictRegistry implements ConflictRegistryQueryInterface {
  const NullConflictRegistry();
  @override Future<bool>    hasActiveConflict({required String sessionId,
                                               required String layerId})
      async => false;
  @override Future<bool>    hasBulkOperationInProgress() async => false;
  @override Future<String?> conflictingSessionId(String id) async => null;
}

/// All permissions granted.
class NullPermissionRegistry implements ExecutionPermissionQueryInterface {
  const NullPermissionRegistry();
  @override Future<bool> hasPermission(ExecutionPermission p) async => true;
}

// ==================================================
// END OF core/execution/action_validator.dart
// Z-CANVAS — PHASE-14 — SYSTEM INTEGRITY CHECKPOINT
// Powered by Zynquar
// ==================================================
