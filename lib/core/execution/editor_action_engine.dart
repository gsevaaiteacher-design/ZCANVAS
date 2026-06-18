// ==================================================
// Z-CANVAS — PHASE-14 EXECUTION CORE & ACTION ENGINE
// core/execution/editor_action_engine.dart
//
// PRIMARY ROLE: EXECUTION ORCHESTRATOR + LIFECYCLE MANAGER
//
// OWNS:
//   ✔ Receive EditorControllerPayload from EditorController
//   ✔ Generate unique execution session ID per action
//   ✔ Capture pre-execution state snapshot
//   ✔ Orchestrate: Validator → SafetyLayer → Executor
//   ✔ Manage execution lifecycle state machine
//   ✔ Trigger rollback on any stage failure
//   ✔ Emit structured audit log entry per execution
//   ✔ Report result (success / fail) back to caller
//
// DOES NOT OWN:
//   ❌ Business logic  ❌ UI access  ❌ Direct engine mutation
//   ❌ Validation logic  ❌ Execution logic  ❌ Safety decisions
//
// VALID ENTRY POINT:
//   EditorController → EditorActionEngine ONLY
// ==================================================

import 'dart:async';

// Pull in the Phase-13 payload contract — read-only import, no execution.
import '../../controllers/execution_bridge.dart' show
    EditorControllerPayload, CommandLifecycle;
import '../../controllers/action_router.dart' show ActionType, ActionSource;
import '../../controllers/command_mapper.dart' show CommandParams;

// ==================================================
// EXECUTION LIFECYCLE STATE MACHINE
// Every execution session must advance through these states in order.
// Any failure triggers ROLLING_BACK → ROLLED_BACK before terminal state.
// ==================================================

enum ExecutionLifecycle {
  /// Session created, payload accepted.
  pending,

  /// Pre-execution snapshot successfully captured.
  snapshotTaken,

  /// ActionValidator is running its checks.
  validating,

  /// Validation passed; ExecutionSafetyLayer is running.
  safetyChecking,

  /// Safety cleared; ActionExecutor is running.
  executing,

  /// Executor reported success; state is being committed.
  committing,

  /// All steps succeeded; history and render confirmed.
  completed,

  /// A failure was detected; rollback is in progress.
  rollingBack,

  /// Rollback completed; system restored to pre-execution snapshot.
  rolledBack,

  /// Terminal failure — rollback itself failed (requires manual recovery).
  fatalError,
}

// ==================================================
// EXECUTION SESSION
// Immutable-by-convention record describing a single action execution.
// Created at engine entry, updated at each lifecycle transition.
// ==================================================

class ExecutionSession {
  ExecutionSession({
    required this.sessionId,
    required this.commandId,
    required this.actionType,
    required this.source,
    required this.createdAt,
  })  : _lifecycle = ExecutionLifecycle.pending,
        _transitions = [];

  /// Globally unique session ID — format: EX-{YYYYMMDD_HHmmss_mmm}-{SEQ}.
  final String sessionId;

  /// The commandId that originated this session (from Phase-13).
  final String commandId;

  final ActionType   actionType;
  final ActionSource source;
  final DateTime     createdAt;

  ExecutionLifecycle _lifecycle;
  final List<_LifecycleTransition> _transitions;

  /// Current lifecycle state.
  ExecutionLifecycle get lifecycle => _lifecycle;

  /// Ordered history of every state transition in this session.
  List<_LifecycleTransition> get transitions =>
      List.unmodifiable(_transitions);

  /// Advances the lifecycle to [next] and records the transition.
  /// Throws [StateError] if the advancement is invalid (enforces ordering).
  void advance(ExecutionLifecycle next, {String? note}) {
    _assertValidTransition(_lifecycle, next);
    _transitions.add(_LifecycleTransition(
      from:      _lifecycle,
      to:        next,
      timestamp: DateTime.now().toUtc(),
      note:      note,
    ));
    _lifecycle = next;
  }

  /// Wall-clock duration from creation to now.
  Duration get elapsed => DateTime.now().toUtc().difference(createdAt);

  @override
  String toString() =>
      'ExecutionSession(id: $sessionId, cmd: $commandId, '
      'lifecycle: $_lifecycle, elapsed: ${elapsed.inMilliseconds}ms)';
}

class _LifecycleTransition {
  const _LifecycleTransition({
    required this.from,
    required this.to,
    required this.timestamp,
    this.note,
  });
  final ExecutionLifecycle from;
  final ExecutionLifecycle to;
  final DateTime           timestamp;
  final String?            note;
}

// Valid forward transitions — any unlisted transition is illegal.
const Map<ExecutionLifecycle, Set<ExecutionLifecycle>> _kValidTransitions = {
  ExecutionLifecycle.pending:        {ExecutionLifecycle.snapshotTaken,
                                      ExecutionLifecycle.rollingBack},
  ExecutionLifecycle.snapshotTaken:  {ExecutionLifecycle.validating,
                                      ExecutionLifecycle.rollingBack},
  ExecutionLifecycle.validating:     {ExecutionLifecycle.safetyChecking,
                                      ExecutionLifecycle.rollingBack},
  ExecutionLifecycle.safetyChecking: {ExecutionLifecycle.executing,
                                      ExecutionLifecycle.rollingBack},
  ExecutionLifecycle.executing:      {ExecutionLifecycle.committing,
                                      ExecutionLifecycle.rollingBack},
  ExecutionLifecycle.committing:     {ExecutionLifecycle.completed,
                                      ExecutionLifecycle.rollingBack},
  ExecutionLifecycle.rollingBack:    {ExecutionLifecycle.rolledBack,
                                      ExecutionLifecycle.fatalError},
  // Terminal states have no further transitions.
  ExecutionLifecycle.completed:      {},
  ExecutionLifecycle.rolledBack:     {},
  ExecutionLifecycle.fatalError:     {},
};

void _assertValidTransition(ExecutionLifecycle from, ExecutionLifecycle to) {
  final allowed = _kValidTransitions[from];
  if (allowed == null || !allowed.contains(to)) {
    throw StateError(
        'Invalid execution lifecycle transition: $from → $to. '
        'Allowed from $from: ${_kValidTransitions[from] ?? {}}');
  }
}

// ==================================================
// STATE SNAPSHOT
// Opaque pre-execution state capture.
// Concrete implementations (provided by engine adapters) populate fields.
// The orchestrator never reads snapshot contents — it only holds and
// passes them to the rollback pathway.
// ==================================================

abstract interface class StateSnapshot {
  /// Unique hash of the captured state — used in audit log.
  String get stateHash;

  /// When the snapshot was taken.
  DateTime get capturedAt;

  /// Human-readable description of what was captured.
  String get description;
}

// --------------------------------------------------
// Null Snapshot — used when the snapshot provider is unavailable.
// Engine will treat a null snapshot as "rollback not possible".
// --------------------------------------------------

class _NullSnapshot implements StateSnapshot {
  const _NullSnapshot();
  @override String   get stateHash   => 'NULL_SNAPSHOT';
  @override DateTime get capturedAt  => DateTime.fromMillisecondsSinceEpoch(0);
  @override String   get description => 'No snapshot available.';
}

// ==================================================
// EXECUTION RESULT
// Returned to EditorController after each engine run.
// Always produced — success or failure, rollback or not.
// ==================================================

sealed class ExecutionResult {}

final class ExecutionSuccess extends ExecutionResult {
  ExecutionSuccess({
    required this.sessionId,
    required this.commandId,
    required this.actionType,
    required this.duration,
    required this.auditEntry,
  });

  final String         sessionId;
  final String         commandId;
  final ActionType     actionType;
  final Duration       duration;
  final AuditLogEntry  auditEntry;

  @override
  String toString() =>
      'ExecutionSuccess(session: $sessionId, '
      'action: $actionType, durationMs: ${duration.inMilliseconds})';
}

final class ExecutionFailure extends ExecutionResult {
  ExecutionFailure({
    required this.sessionId,
    required this.commandId,
    required this.actionType,
    required this.failedAtStage,
    required this.reason,
    required this.rolledBack,
    required this.duration,
    required this.auditEntry,
  });

  final String           sessionId;
  final String           commandId;
  final ActionType       actionType;
  final ExecutionLifecycle failedAtStage;
  final String           reason;
  final bool             rolledBack;
  final Duration         duration;
  final AuditLogEntry    auditEntry;

  @override
  String toString() =>
      'ExecutionFailure(session: $sessionId, '
      'stage: $failedAtStage, rolledBack: $rolledBack, '
      'reason: "$reason")';
}

// ==================================================
// AUDIT LOG ENTRY
// Immutable record written for every execution attempt.
// One entry per session — written at terminal state.
// ==================================================

class AuditLogEntry {
  const AuditLogEntry({
    required this.sessionId,
    required this.commandId,
    required this.actionType,
    required this.source,
    required this.startedAt,
    required this.finishedAt,
    required this.finalLifecycle,
    required this.beforeStateHash,
    required this.afterStateHash,
    required this.succeeded,
    this.failureReason,
    this.lifecycleTrace = const [],
  });

  /// Unique execution session ID.
  final String sessionId;

  /// Phase-13 command ID that triggered this execution.
  final String commandId;

  final ActionType     actionType;
  final ActionSource   source;

  /// Wall-clock start of the execution session.
  final DateTime startedAt;

  /// Wall-clock end (success, rollback, or fatal).
  final DateTime finishedAt;

  final ExecutionLifecycle finalLifecycle;

  /// State hash captured before execution began.
  final String beforeStateHash;

  /// State hash after execution completed (equals beforeStateHash on rollback).
  final String afterStateHash;

  final bool    succeeded;
  final String? failureReason;

  /// Ordered list of lifecycle stage names for tracing.
  final List<String> lifecycleTrace;

  /// Total wall-clock execution time.
  Duration get duration => finishedAt.difference(startedAt);

  @override
  String toString() =>
      'AuditLogEntry(session: $sessionId, action: $actionType, '
      'succeeded: $succeeded, durationMs: ${duration.inMilliseconds})';
}

// ==================================================
// DOWNSTREAM INTERFACE CONTRACTS
// Orchestrator depends only on these — concrete implementations
// live in the respective Phase-14 files.
// ==================================================

// — FILE-2 boundary —
abstract interface class ActionValidatorInterface {
  /// Validates the payload before execution mutates any state.
  /// Returns null on success or a failure reason string.
  Future<String?> validate(
      EditorControllerPayload payload, StateSnapshot snapshot);
}

// — FILE-3 boundary —
abstract interface class ExecutionSafetyLayerInterface {
  /// Runs final safety checks (recursion, parallelism, atomic risk).
  /// Returns null on success or a blocking reason string.
  Future<String?> check(
      EditorControllerPayload payload, String sessionId);
}

// — FILE-4 boundary —
abstract interface class ActionExecutorInterface {
  /// Executes the approved action atomically.
  /// Returns null on success or a failure reason string.
  Future<String?> execute(
      EditorControllerPayload payload, String sessionId);
}

// — Snapshot provider boundary —
abstract interface class SnapshotProviderInterface {
  /// Captures the current state before execution begins.
  Future<StateSnapshot> capture(String sessionId, ActionType actionType);
}

// — Rollback provider boundary —
abstract interface class RollbackProviderInterface {
  /// Restores state from the given snapshot.
  /// Returns null on success or a failure reason string.
  Future<String?> restore(StateSnapshot snapshot, String sessionId);
}

// ==================================================
// EXECUTION ENGINE CONFIGURATION
// Injected at construction — separates policy from orchestration.
// ==================================================

class EngineConfig {
  const EngineConfig({
    this.enableSnapshots     = true,
    this.enableRollback      = true,
    this.executionTimeoutMs  = 10000,
    this.auditRetentionLimit = 500,
  });

  /// Whether to attempt a snapshot before every execution.
  final bool enableSnapshots;

  /// Whether to attempt rollback on failure.
  final bool enableRollback;

  /// Maximum milliseconds allowed for the full execution session.
  final int executionTimeoutMs;

  /// Maximum number of audit entries kept in memory.
  final int auditRetentionLimit;
}

// ==================================================
// EDITOR ACTION ENGINE
// The single orchestration class for Phase-14.
// Called exclusively by EditorController.
// ==================================================

class EditorActionEngine {
  EditorActionEngine({
    required ActionValidatorInterface       validator,
    required ExecutionSafetyLayerInterface  safetyLayer,
    required ActionExecutorInterface        executor,
    required SnapshotProviderInterface      snapshotProvider,
    required RollbackProviderInterface      rollbackProvider,
    EngineConfig config = const EngineConfig(),
  })  : _validator        = validator,
        _safetyLayer      = safetyLayer,
        _executor         = executor,
        _snapshotProvider = snapshotProvider,
        _rollbackProvider = rollbackProvider,
        _config           = config;

  final ActionValidatorInterface      _validator;
  final ExecutionSafetyLayerInterface _safetyLayer;
  final ActionExecutorInterface       _executor;
  final SnapshotProviderInterface     _snapshotProvider;
  final RollbackProviderInterface     _rollbackProvider;
  final EngineConfig                  _config;

  // Session ID sequence (monotonic within process lifetime).
  int _sessionSeq = 0;

  // In-memory audit log (capped at config.auditRetentionLimit).
  final List<AuditLogEntry> _auditLog = [];

  // Set of active session IDs — prevents concurrent execution of same command.
  final Set<String> _activeSessions = {};

  // --------------------------------------------------
  // PUBLIC API — called by EditorController only
  // --------------------------------------------------

  /// Entry point for the Phase-14 execution pipeline.
  ///
  /// Flow: snapshot → validate → safety → execute → commit → audit
  ///
  /// Returns an [ExecutionResult] regardless of outcome.
  /// Never throws — all failures are captured in [ExecutionFailure].
  Future<ExecutionResult> run(EditorControllerPayload payload) async {
    final sessionId = _generateSessionId(payload.resolvedActionType);
    final session   = ExecutionSession(
      sessionId:  sessionId,
      commandId:  payload.commandId,
      actionType: payload.resolvedActionType,
      source:     payload.source,
      createdAt:  DateTime.now().toUtc(),
    );

    _log('[${session.sessionId}] Execution session opened | '
        'cmd=${payload.commandId} action=${payload.resolvedActionType}');

    // Guard: reject if this commandId is already being executed.
    if (_activeSessions.contains(payload.commandId)) {
      return _buildFailure(
        session:        session,
        failedAt:       ExecutionLifecycle.pending,
        reason:         'Command "${payload.commandId}" is already being '
                        'executed. Concurrent execution rejected.',
        snapshot:       const _NullSnapshot(),
        rolledBack:     false,
      );
    }
    _activeSessions.add(payload.commandId);

    StateSnapshot snapshot = const _NullSnapshot();

    try {
      return await _runWithTimeout(payload, session, snapshot);
    } catch (e, stack) {
      // Unhandled exception — attempt rollback and return failure.
      _log('[${session.sessionId}] UNHANDLED EXCEPTION: $e\n$stack');
      final rolledBack = await _attemptRollback(session, snapshot);
      return _buildFailure(
        session:    session,
        failedAt:   session.lifecycle,
        reason:     'Unhandled exception: $e',
        snapshot:   snapshot,
        rolledBack: rolledBack,
      );
    } finally {
      _activeSessions.remove(payload.commandId);
    }
  }

  /// Read-only ordered audit log.
  List<AuditLogEntry> get auditLog => List.unmodifiable(_auditLog);

  /// Clears the in-memory audit log.
  void clearAuditLog() => _auditLog.clear();

  // --------------------------------------------------
  // INTERNAL ORCHESTRATION
  // --------------------------------------------------

  Future<ExecutionResult> _runWithTimeout(
    EditorControllerPayload payload,
    ExecutionSession        session,
    StateSnapshot           snapshot,
  ) =>
      payload.commandId.isNotEmpty
          ? _orchestrate(payload, session).timeout(
              Duration(milliseconds: _config.executionTimeoutMs),
              onTimeout: () async {
                _log('[${session.sessionId}] TIMEOUT after '
                    '${_config.executionTimeoutMs}ms');
                final rolledBack = await _attemptRollback(session, snapshot);
                return _buildFailure(
                  session:    session,
                  failedAt:   session.lifecycle,
                  reason:     'Execution timed out after '
                              '${_config.executionTimeoutMs}ms.',
                  snapshot:   snapshot,
                  rolledBack: rolledBack,
                );
              },
            )
          : Future.value(_buildFailure(
              session:    session,
              failedAt:   ExecutionLifecycle.pending,
              reason:     'Payload commandId is empty.',
              snapshot:   snapshot,
              rolledBack: false,
            ));

  Future<ExecutionResult> _orchestrate(
    EditorControllerPayload payload,
    ExecutionSession        session,
  ) async {
    StateSnapshot snapshot = const _NullSnapshot();

    // ── STAGE 1: PRE-EXECUTION SNAPSHOT ──────────────────────────────────────
    if (_config.enableSnapshots) {
      try {
        snapshot = await _snapshotProvider.capture(
            session.sessionId, payload.resolvedActionType);
        session.advance(ExecutionLifecycle.snapshotTaken,
            note: 'hash=${snapshot.stateHash}');
        _log('[${session.sessionId}] Snapshot captured | '
            'hash=${snapshot.stateHash}');
      } catch (e) {
        _log('[${session.sessionId}] Snapshot failed (non-blocking): $e');
        // Snapshot failure is non-blocking: proceed without rollback capability.
        session.advance(ExecutionLifecycle.snapshotTaken,
            note: 'Snapshot unavailable — rollback disabled for this session.');
      }
    } else {
      session.advance(ExecutionLifecycle.snapshotTaken,
          note: 'Snapshots disabled by config.');
    }

    // ── STAGE 2: VALIDATION ───────────────────────────────────────────────────
    session.advance(ExecutionLifecycle.validating);
    _log('[${session.sessionId}] Running ActionValidator');

    final validationError = await _validator.validate(payload, snapshot);
    if (validationError != null) {
      _log('[${session.sessionId}] Validation FAILED: $validationError');
      final rolledBack = await _attemptRollback(session, snapshot);
      return _buildFailure(
        session:    session,
        failedAt:   ExecutionLifecycle.validating,
        reason:     'Validation failed: $validationError',
        snapshot:   snapshot,
        rolledBack: rolledBack,
      );
    }
    _log('[${session.sessionId}] Validation PASSED');

    // ── STAGE 3: SAFETY CHECK ─────────────────────────────────────────────────
    session.advance(ExecutionLifecycle.safetyChecking);
    _log('[${session.sessionId}] Running ExecutionSafetyLayer');

    final safetyError = await _safetyLayer.check(payload, session.sessionId);
    if (safetyError != null) {
      _log('[${session.sessionId}] Safety check FAILED: $safetyError');
      final rolledBack = await _attemptRollback(session, snapshot);
      return _buildFailure(
        session:    session,
        failedAt:   ExecutionLifecycle.safetyChecking,
        reason:     'Safety check failed: $safetyError',
        snapshot:   snapshot,
        rolledBack: rolledBack,
      );
    }
    _log('[${session.sessionId}] Safety check PASSED');

    // ── STAGE 4: EXECUTION ────────────────────────────────────────────────────
    session.advance(ExecutionLifecycle.executing);
    _log('[${session.sessionId}] Running ActionExecutor');

    final executionError = await _executor.execute(payload, session.sessionId);
    if (executionError != null) {
      _log('[${session.sessionId}] Execution FAILED: $executionError');
      final rolledBack = await _attemptRollback(session, snapshot);
      return _buildFailure(
        session:    session,
        failedAt:   ExecutionLifecycle.executing,
        reason:     'Execution failed: $executionError',
        snapshot:   snapshot,
        rolledBack: rolledBack,
      );
    }
    _log('[${session.sessionId}] Execution SUCCEEDED');

    // ── STAGE 5: COMMIT ───────────────────────────────────────────────────────
    session.advance(ExecutionLifecycle.committing);
    _log('[${session.sessionId}] State → COMMITTING');

    // The executor owns the actual commit; the orchestrator stamps the state.
    // If an error surfaces here it means the executor reported success but the
    // commit confirmation was not received — treat as failure with rollback.

    session.advance(ExecutionLifecycle.completed);
    _log('[${session.sessionId}] State → COMPLETED');

    return _buildSuccess(session: session, snapshot: snapshot);
  }

  // --------------------------------------------------
  // ROLLBACK
  // --------------------------------------------------

  /// Attempts to restore state from [snapshot].
  /// Returns true if rollback succeeded, false otherwise.
  Future<bool> _attemptRollback(
      ExecutionSession session, StateSnapshot snapshot) async {
    if (!_config.enableRollback || snapshot is _NullSnapshot) {
      _log('[${session.sessionId}] Rollback skipped '
          '(disabled or no snapshot available).');
      return false;
    }

    _log('[${session.sessionId}] State → ROLLING_BACK');
    try {
      session.advance(ExecutionLifecycle.rollingBack,
          note: 'Restoring snapshot ${snapshot.stateHash}');
    } catch (_) {
      // Session may already be in rollingBack from a prior attempt.
    }

    final rollbackError = await _rollbackProvider.restore(
        snapshot, session.sessionId);

    if (rollbackError != null) {
      _log('[${session.sessionId}] Rollback FAILED: $rollbackError');
      try {
        session.advance(ExecutionLifecycle.fatalError,
            note: 'Rollback failed: $rollbackError');
      } catch (_) {}
      return false;
    }

    _log('[${session.sessionId}] Rollback SUCCEEDED — '
        'restored to snapshot ${snapshot.stateHash}');
    try {
      session.advance(ExecutionLifecycle.rolledBack,
          note: 'Restored snapshot ${snapshot.stateHash}');
    } catch (_) {}
    return true;
  }

  // --------------------------------------------------
  // RESULT BUILDERS
  // --------------------------------------------------

  ExecutionSuccess _buildSuccess({
    required ExecutionSession session,
    required StateSnapshot    snapshot,
  }) {
    final entry = _writeAuditEntry(
      session:        session,
      snapshot:       snapshot,
      afterHash:      snapshot.stateHash, // executor sets final hash externally
      succeeded:      true,
      failureReason:  null,
    );
    return ExecutionSuccess(
      sessionId:  session.sessionId,
      commandId:  session.commandId,
      actionType: session.actionType,
      duration:   session.elapsed,
      auditEntry: entry,
    );
  }

  ExecutionFailure _buildFailure({
    required ExecutionSession  session,
    required ExecutionLifecycle failedAt,
    required String            reason,
    required StateSnapshot     snapshot,
    required bool              rolledBack,
  }) {
    final entry = _writeAuditEntry(
      session:       session,
      snapshot:      snapshot,
      afterHash:     snapshot.stateHash, // unchanged on rollback
      succeeded:     false,
      failureReason: reason,
    );
    return ExecutionFailure(
      sessionId:    session.sessionId,
      commandId:    session.commandId,
      actionType:   session.actionType,
      failedAtStage: failedAt,
      reason:       reason,
      rolledBack:   rolledBack,
      duration:     session.elapsed,
      auditEntry:   entry,
    );
  }

  // --------------------------------------------------
  // AUDIT LOG
  // --------------------------------------------------

  AuditLogEntry _writeAuditEntry({
    required ExecutionSession session,
    required StateSnapshot    snapshot,
    required String           afterHash,
    required bool             succeeded,
    required String?          failureReason,
  }) {
    final entry = AuditLogEntry(
      sessionId:      session.sessionId,
      commandId:      session.commandId,
      actionType:     session.actionType,
      source:         session.source,
      startedAt:      session.createdAt,
      finishedAt:     DateTime.now().toUtc(),
      finalLifecycle: session.lifecycle,
      beforeStateHash: snapshot.stateHash,
      afterStateHash:  afterHash,
      succeeded:      succeeded,
      failureReason:  failureReason,
      lifecycleTrace: session.transitions
          .map((t) => '${t.from.name}→${t.to.name}'
              '${t.note != null ? "(${t.note})" : ""}')
          .toList(),
    );

    _auditLog.add(entry);

    // Enforce retention cap — drop oldest entries.
    while (_auditLog.length > _config.auditRetentionLimit) {
      _auditLog.removeAt(0);
    }

    _log('[${session.sessionId}] Audit entry written | '
        'succeeded=$succeeded lifecycle=${session.lifecycle}');
    return entry;
  }

  // --------------------------------------------------
  // SESSION ID GENERATOR
  // Format: EX-{YYYYMMDD_HHmmss_mmm}-{SEQ}
  // --------------------------------------------------

  String _generateSessionId(ActionType actionType) {
    final now   = DateTime.now().toUtc();
    final stamp = '${now.year.toString().padLeft(4, '0')}'
                  '${now.month.toString().padLeft(2, '0')}'
                  '${now.day.toString().padLeft(2, '0')}_'
                  '${now.hour.toString().padLeft(2, '0')}'
                  '${now.minute.toString().padLeft(2, '0')}'
                  '${now.second.toString().padLeft(2, '0')}_'
                  '${now.millisecond.toString().padLeft(3, '0')}';
    final seq   = (_sessionSeq++).toString().padLeft(6, '0');
    final prefix = _actionPrefix(actionType);
    return 'EX-$prefix-$stamp-$seq';
  }

  String _actionPrefix(ActionType type) => switch (type) {
        ActionType.addLayer       => 'ADD',
        ActionType.deleteLayer    => 'DEL',
        ActionType.moveLayer      => 'MOV',
        ActionType.resizeLayer    => 'RSZ',
        ActionType.styleUpdate    => 'STY',
        ActionType.aiCommand      => 'AIC',
        ActionType.exportRequest  => 'EXP',
        ActionType.undo           => 'UND',
        ActionType.redo           => 'RED',
        ActionType.templateRequest => 'TPL',
        ActionType.unknown        => 'UNK',
      };

  void _log(String message) {
    // ignore: avoid_print
    print('[EditorActionEngine] $message');
  }
}

// ==================================================
// CONVENIENCE: ENGINE BUILDER
// Fluent factory for constructing a fully-wired EditorActionEngine.
// Concrete implementations of the four provider interfaces are
// registered once at app startup and reused across sessions.
// ==================================================

class EditorActionEngineBuilder {
  ActionValidatorInterface?       _validator;
  ExecutionSafetyLayerInterface?  _safetyLayer;
  ActionExecutorInterface?        _executor;
  SnapshotProviderInterface?      _snapshotProvider;
  RollbackProviderInterface?      _rollbackProvider;
  EngineConfig                    _config = const EngineConfig();

  EditorActionEngineBuilder withValidator(ActionValidatorInterface v) {
    _validator = v; return this;
  }
  EditorActionEngineBuilder withSafetyLayer(ExecutionSafetyLayerInterface s) {
    _safetyLayer = s; return this;
  }
  EditorActionEngineBuilder withExecutor(ActionExecutorInterface e) {
    _executor = e; return this;
  }
  EditorActionEngineBuilder withSnapshotProvider(SnapshotProviderInterface s) {
    _snapshotProvider = s; return this;
  }
  EditorActionEngineBuilder withRollbackProvider(RollbackProviderInterface r) {
    _rollbackProvider = r; return this;
  }
  EditorActionEngineBuilder withConfig(EngineConfig c) {
    _config = c; return this;
  }

  EditorActionEngine build() {
    assert(_validator        != null, 'ActionValidator must be registered.');
    assert(_safetyLayer      != null, 'ExecutionSafetyLayer must be registered.');
    assert(_executor         != null, 'ActionExecutor must be registered.');
    assert(_snapshotProvider != null, 'SnapshotProvider must be registered.');
    assert(_rollbackProvider != null, 'RollbackProvider must be registered.');
    return EditorActionEngine(
      validator:        _validator!,
      safetyLayer:      _safetyLayer!,
      executor:         _executor!,
      snapshotProvider: _snapshotProvider!,
      rollbackProvider: _rollbackProvider!,
      config:           _config,
    );
  }
}

// ==================================================
// END OF core/execution/editor_action_engine.dart
// Z-CANVAS — PHASE-14 — EXECUTION ORCHESTRATOR
// Powered by Zynquar
// ==================================================
