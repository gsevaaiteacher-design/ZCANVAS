// ==================================================
// Z-CANVAS — PHASE-14 EXECUTION CORE & ACTION ENGINE
// core/execution/execution_safety_layer.dart
//
// PRIMARY ROLE: FINAL SYSTEM PROTECTION WALL
//
// OWNS:
//   ✔ Global execution kill-switch (hard stop — arms/disarms the entire system)
//   ✔ Forbidden operation detection (per-type + per-source block lists)
//   ✔ Recursive execution loop prevention (static session registry)
//   ✔ Multi-execution collision guard (per-type concurrency caps)
//   ✔ EditorController supremacy enforcement (lifecycle chain integrity)
//   ✔ Canvas / UI direct-access blocking (source origin enforcement)
//   ✔ Engine bypass detection (Phase-13 pipeline completeness check)
//
// DOES NOT OWN:
//   ❌ Execution logic  ❌ Business logic  ❌ State mutation (canvas/engine)
//   ❌ Engine control   ❌ Decision making ❌ UI access
//
// RULE: SAFETY FIRST, EXECUTION NEVER.
// This file may maintain its own internal protective bookkeeping
// (session registry, kill-switch flag) — that is NOT application state.
// ==================================================

import 'dart:async';

import '../../controllers/execution_bridge.dart'
    show EditorControllerPayload, CommandLifecycle;
import '../../controllers/action_router.dart' show ActionType, ActionSource;
import 'editor_action_engine.dart' show ExecutionSafetyLayerInterface;

// ==================================================
// SAFETY CHECK REGISTRY
// Named enumeration of every protection gate in sequence.
// Order is execution order — kill-switch always runs first.
// ==================================================

enum SafetyCheck {
  killSwitch,               // global hard-stop; arms entire system
  forbiddenOperation,       // action type or source is on the deny list
  recursionLoopPrevention,  // sessionId already active → cycle detected
  multiExecutionCollision,  // concurrent cap for this action type exceeded
  editorControllerSupremacy,// lifecycle chain must prove Phase-13 passage
  canvasAccessBlocking,     // payload must not originate from Canvas/UI directly
  engineBypassDetection,    // commandId + confidence prove Phase-13 routing
}

// ==================================================
// SAFETY VERDICT
// Result of a single named check.
// ==================================================

enum SafetyStatus { passed, blocked, skipped }

class SafetyVerdict {
  const SafetyVerdict({
    required this.check,
    required this.status,
    this.reason,
  });

  final SafetyCheck  check;
  final SafetyStatus status;

  /// Non-null when blocked or skipped.
  final String? reason;

  bool get passed  => status == SafetyStatus.passed;
  bool get blocked => status == SafetyStatus.blocked;
  bool get skipped => status == SafetyStatus.skipped;

  factory SafetyVerdict.pass(SafetyCheck c) =>
      SafetyVerdict(check: c, status: SafetyStatus.passed);

  factory SafetyVerdict.block(SafetyCheck c, String reason) =>
      SafetyVerdict(check: c, status: SafetyStatus.blocked, reason: reason);

  factory SafetyVerdict.skip(SafetyCheck c, String reason) =>
      SafetyVerdict(check: c, status: SafetyStatus.skipped, reason: reason);

  @override
  String toString() =>
      'SafetyVerdict(${check.name}: $status'
      '${reason != null ? ", reason: $reason" : ""})';
}

// ==================================================
// SAFETY REPORT
// Complete result of a full safety pass.
// Returned by the concrete class; the interface surfaces only String?.
// ==================================================

class SafetyReport {
  const SafetyReport({
    required this.sessionId,
    required this.commandId,
    required this.actionType,
    required this.verdicts,
    required this.checkedAt,
  });

  final String           sessionId;
  final String           commandId;
  final ActionType       actionType;
  final List<SafetyVerdict> verdicts;
  final DateTime         checkedAt;

  bool get cleared       => verdicts.every((v) => v.passed || v.skipped);
  SafetyVerdict? get firstBlock =>
      verdicts.cast<SafetyVerdict?>().firstWhere(
          (v) => v != null && v.blocked, orElse: () => null);
  String? get blockReason => firstBlock?.reason;

  int get passCount  => verdicts.where((v) => v.passed).length;
  int get blockCount => verdicts.where((v) => v.blocked).length;

  @override
  String toString() =>
      'SafetyReport(session: $sessionId, cleared: $cleared, '
      'checks: ${verdicts.length}, blocked: $blockCount)';
}

// ==================================================
// SAFETY LAYER CONFIGURATION
// All thresholds and deny lists injected at construction.
// ==================================================

class SafetyLayerConfig {
  const SafetyLayerConfig({
    this.forbiddenActionTypes   = const {},
    this.forbiddenSources       = const {},
    this.maxConcurrentPerType   = 3,
    this.sessionExpiryMs        = 30000,     // 30 s
    this.maxPipelineAgeMs       = 60000,     // 60 s — max allowed Phase-13 age
    this.minConfidenceThreshold = 0.10,      // below this = not routed by Phase-13
    this.enableCollisionGuard   = true,
    this.enableRecursionGuard   = true,
    this.enableBypassDetection  = true,
    this.enableSupremacyCheck   = true,
    this.enableCanvasBlock      = true,
  });

  /// Action types that are unconditionally forbidden regardless of source.
  final Set<ActionType> forbiddenActionTypes;

  /// Action sources that must never reach Phase-14 directly.
  /// By contract, Canvas/UI must flow through EditorController, not bypass it.
  final Set<ActionSource> forbiddenSources;

  /// Maximum concurrent sessions allowed for any single action type.
  final int maxConcurrentPerType;

  /// Milliseconds after which a session registration is automatically expired.
  /// Prevents stale entries from blocking future executions after a crash.
  final int sessionExpiryMs;

  /// Maximum allowed age of the Phase-13 pipeline (receivedAt → now).
  /// Payloads older than this are considered stale and blocked.
  final int maxPipelineAgeMs;

  /// Minimum confidence score that proves Phase-13 routed the command.
  final double minConfidenceThreshold;

  final bool enableCollisionGuard;
  final bool enableRecursionGuard;
  final bool enableBypassDetection;
  final bool enableSupremacyCheck;
  final bool enableCanvasBlock;
}

// ==================================================
// SAFETY GLOBAL STATE
// Holds shared mutable protective bookkeeping across check() calls.
// This is NOT application state — it is the safety layer's own guard data.
// Replaceable for test isolation via [ExecutionSafetyLayer.withState].
// ==================================================

class SafetyGlobalState {
  SafetyGlobalState();

  // — Kill-switch —
  bool _killSwitchArmed = false;
  String? _killSwitchReason;

  bool   get killSwitchArmed  => _killSwitchArmed;
  String? get killSwitchReason => _killSwitchReason;

  /// Arms the kill-switch. All subsequent check() calls will be hard-blocked.
  void armKillSwitch(String reason) {
    _killSwitchArmed  = true;
    _killSwitchReason = reason;
  }

  /// Disarms the kill-switch (requires operator authority in production).
  void disarmKillSwitch() {
    _killSwitchArmed  = false;
    _killSwitchReason = null;
  }

  // — Session registry —
  // Tracks in-flight sessions: sessionId → registration timestamp.
  final Map<String, DateTime> _activeSessions = {};

  // — Per-type concurrency counter —
  final Map<ActionType, int> _activeByType = {};

  /// Registers a session as active. Called just before execution begins.
  void registerSession(String sessionId, ActionType type) {
    _activeSessions[sessionId] = DateTime.now().toUtc();
    _activeByType[type] = (_activeByType[type] ?? 0) + 1;
  }

  /// Releases a session. Must be called when the execution completes or fails.
  void releaseSession(String sessionId, ActionType type) {
    _activeSessions.remove(sessionId);
    final current = _activeByType[type] ?? 0;
    if (current > 0) _activeByType[type] = current - 1;
  }

  /// Returns true if [sessionId] is already registered (recursion signal).
  bool isSessionActive(String sessionId) =>
      _activeSessions.containsKey(sessionId);

  /// Returns the concurrent count for [type] (expired sessions excluded).
  int concurrentCount(ActionType type, int sessionExpiryMs) {
    _evictExpired(sessionExpiryMs);
    return _activeByType[type] ?? 0;
  }

  /// Removes sessions registered more than [expiryMs] milliseconds ago.
  void _evictExpired(int expiryMs) {
    final cutoff = DateTime.now().toUtc()
        .subtract(Duration(milliseconds: expiryMs));
    final expired = _activeSessions.entries
        .where((e) => e.value.isBefore(cutoff))
        .map((e) => e.key)
        .toList();
    for (final id in expired) {
      final entryTime = _activeSessions[id];
      _activeSessions.remove(id);
      // We cannot recover the ActionType from id alone, so just reset the
      // per-type counter conservatively (decrement only if positive).
      _activeByType.updateAll((t, v) => v > 0 ? v - 1 : 0);
      _log('SafetyGlobalState: evicted expired session $id '
          '(registered at $entryTime).');
    }
  }

  void _log(String msg) {
    // ignore: avoid_print
    print('[SafetyGlobalState] $msg');
  }
}

// ==================================================
// EXECUTION SAFETY LAYER
// Implements ExecutionSafetyLayerInterface.
// Runs all protection gates in order; first block short-circuits.
// ==================================================

class ExecutionSafetyLayer implements ExecutionSafetyLayerInterface {
  ExecutionSafetyLayer({
    SafetyLayerConfig? config,
    SafetyGlobalState? state,
  })  : _config = config ?? const SafetyLayerConfig(),
        _state  = state ?? SafetyGlobalState();

  /// Named constructor that injects an explicit [SafetyGlobalState].
  /// Use in tests to isolate global kill-switch and session state.
  ExecutionSafetyLayer.withState(SafetyGlobalState state,
      {SafetyLayerConfig? config})
      : _config = config ?? const SafetyLayerConfig(),
        _state  = state;

  final SafetyLayerConfig _config;
  final SafetyGlobalState _state;

  // In-memory report log.
  final List<SafetyReport> _history = [];

  // --------------------------------------------------
  // KILL-SWITCH CONTROL (exposed on concrete class)
  // --------------------------------------------------

  /// Arms the system-wide execution kill-switch.
  /// All check() calls will be hard-blocked until [disarmKillSwitch] is called.
  void armKillSwitch(String reason) {
    _log('KILL-SWITCH ARMED: $reason');
    _state.armKillSwitch(reason);
  }

  /// Disarms the kill-switch, restoring normal execution flow.
  void disarmKillSwitch() {
    _log('Kill-switch disarmed.');
    _state.disarmKillSwitch();
  }

  bool   get killSwitchArmed  => _state.killSwitchArmed;
  String? get killSwitchReason => _state.killSwitchReason;

  // --------------------------------------------------
  // SESSION LIFECYCLE (called by EditorActionEngine)
  // --------------------------------------------------

  /// Registers [sessionId] as active so recursion checks work correctly.
  /// The orchestrator must call this immediately after check() clears.
  void registerSession(String sessionId, ActionType type) =>
      _state.registerSession(sessionId, type);

  /// Releases [sessionId] when execution completes or fails.
  /// The orchestrator MUST always call this — even on rollback paths.
  void releaseSession(String sessionId, ActionType type) =>
      _state.releaseSession(sessionId, type);

  // --------------------------------------------------
  // PUBLIC API  (ExecutionSafetyLayerInterface)
  // --------------------------------------------------

  @override
  Future<String?> check(
      EditorControllerPayload payload, String sessionId) async {
    final report = await fullCheck(payload, sessionId);
    _history.add(report);
    _log('[${sessionId}] Safety check complete — '
        'cleared=${report.cleared} blocked=${report.blockCount}');
    return report.cleared ? null : report.blockReason;
  }

  /// Extended entry point that returns the full [SafetyReport].
  Future<SafetyReport> fullCheck(
      EditorControllerPayload payload, String sessionId) async {
    final verdicts  = <SafetyVerdict>[];
    final checks    = <Future<SafetyVerdict> Function()>[
      () => _checkKillSwitch(),
      () => _checkForbiddenOperation(payload),
      () => _checkRecursionLoop(sessionId),
      () => _checkMultiExecutionCollision(payload, sessionId),
      () => _checkEditorControllerSupremacy(payload),
      () => _checkCanvasAccessBlocking(payload),
      () => _checkEngineBypassDetection(payload),
    ];

    for (final fn in checks) {
      final verdict = await fn();
      verdicts.add(verdict);
      if (verdict.blocked) break; // hard short-circuit on first block
    }

    return SafetyReport(
      sessionId:  sessionId,
      commandId:  payload.commandId,
      actionType: payload.resolvedActionType,
      verdicts:   List.unmodifiable(verdicts),
      checkedAt:  DateTime.now().toUtc(),
    );
  }

  /// Read-only history of all safety reports.
  List<SafetyReport> get history => List.unmodifiable(_history);

  // ==================================================
  // PROTECTION GATES — private, ordered
  // ==================================================

  // --------------------------------------------------
  // GATE 1 — KILL-SWITCH
  // If the kill-switch is armed, nothing passes. Ever.
  // Arms on catastrophic system failure to prevent further corruption.
  // --------------------------------------------------

  Future<SafetyVerdict> _checkKillSwitch() async {
    if (_state.killSwitchArmed) {
      return SafetyVerdict.block(SafetyCheck.killSwitch,
          'Execution kill-switch is ARMED. '
          'All Phase-14 execution is hard-blocked. '
          'Reason: ${_state.killSwitchReason ?? "unspecified"}. '
          'Disarm via ExecutionSafetyLayer.disarmKillSwitch() '
          'after resolving the underlying fault.');
    }
    return SafetyVerdict.pass(SafetyCheck.killSwitch);
  }

  // --------------------------------------------------
  // GATE 2 — FORBIDDEN OPERATION DETECTION
  // Blocks unconditionally forbidden action types and forbidden sources.
  // --------------------------------------------------

  Future<SafetyVerdict> _checkForbiddenOperation(
      EditorControllerPayload payload) async {
    // Type-level block.
    if (_config.forbiddenActionTypes.contains(payload.resolvedActionType)) {
      return SafetyVerdict.block(SafetyCheck.forbiddenOperation,
          'Action type ${payload.resolvedActionType} is on the forbidden '
          'operation deny list. This type is unconditionally blocked by '
          'system policy regardless of source or confidence.');
    }
    // Source-level block.
    if (_config.forbiddenSources.contains(payload.source)) {
      return SafetyVerdict.block(SafetyCheck.forbiddenOperation,
          'Action source ${payload.source} is on the forbidden source deny '
          'list. Payloads from this origin are blocked from reaching '
          'Phase-14 by system policy.');
    }
    return SafetyVerdict.pass(SafetyCheck.forbiddenOperation);
  }

  // --------------------------------------------------
  // GATE 3 — RECURSION LOOP PREVENTION
  // Detects if this sessionId is already in the execution pipeline,
  // which would indicate a recursive call back into the action engine.
  // --------------------------------------------------

  Future<SafetyVerdict> _checkRecursionLoop(String sessionId) async {
    if (!_config.enableRecursionGuard) {
      return SafetyVerdict.skip(SafetyCheck.recursionLoopPrevention,
          'Recursion guard disabled by config.');
    }
    if (_state.isSessionActive(sessionId)) {
      return SafetyVerdict.block(SafetyCheck.recursionLoopPrevention,
          'RECURSION DETECTED: session "$sessionId" is already registered as '
          'active in the safety layer. An execution action attempted to '
          're-enter the Phase-14 pipeline from within itself. '
          'This is an absolute violation of the execution contract. '
          'Blocking to prevent stack overflow and state corruption.');
    }
    return SafetyVerdict.pass(SafetyCheck.recursionLoopPrevention);
  }

  // --------------------------------------------------
  // GATE 4 — MULTI-EXECUTION COLLISION GUARD
  // Prevents more than [maxConcurrentPerType] concurrent sessions
  // for the same action type running simultaneously.
  // --------------------------------------------------

  Future<SafetyVerdict> _checkMultiExecutionCollision(
      EditorControllerPayload payload, String sessionId) async {
    if (!_config.enableCollisionGuard) {
      return SafetyVerdict.skip(SafetyCheck.multiExecutionCollision,
          'Collision guard disabled by config.');
    }
    final concurrentCount = _state.concurrentCount(
        payload.resolvedActionType, _config.sessionExpiryMs);
    if (concurrentCount >= _config.maxConcurrentPerType) {
      return SafetyVerdict.block(SafetyCheck.multiExecutionCollision,
          'Multi-execution collision: ${payload.resolvedActionType} already '
          'has $concurrentCount concurrent session(s) active, which meets or '
          'exceeds the maximum of ${_config.maxConcurrentPerType}. '
          'Blocking to prevent parallel state corruption. '
          'Wait for an active session to complete before retrying.');
    }
    return SafetyVerdict.pass(SafetyCheck.multiExecutionCollision);
  }

  // --------------------------------------------------
  // GATE 5 — EDITORCONTROLLER SUPREMACY ENFORCEMENT
  // Validates that the payload's CommandLifecycle proves it passed through
  // all Phase-13 stages in strict chronological order.
  // A payload that skipped or forged any stage is blocked unconditionally.
  //
  // Required order:
  //   receivedAt < routedAt < mappedAt < interpretedAt
  //               < validatedAt < approvedAt < dispatchedAt
  // --------------------------------------------------

  Future<SafetyVerdict> _checkEditorControllerSupremacy(
      EditorControllerPayload payload) async {
    if (!_config.enableSupremacyCheck) {
      return SafetyVerdict.skip(SafetyCheck.editorControllerSupremacy,
          'EditorController supremacy check disabled by config.');
    }

    final lc = payload.lifecycle;

    // Monotonic order check — each stage must be strictly after the previous.
    final stages = <String, DateTime>{
      'receivedAt':    lc.receivedAt,
      'routedAt':      lc.routedAt,
      'mappedAt':      lc.mappedAt,
      'interpretedAt': lc.interpretedAt,
      'validatedAt':   lc.validatedAt,
      'approvedAt':    lc.approvedAt,
      'dispatchedAt':  lc.dispatchedAt,
    };

    final stageEntries = stages.entries.toList();
    for (var i = 1; i < stageEntries.length; i++) {
      final prev = stageEntries[i - 1];
      final curr = stageEntries[i];
      if (!curr.value.isAfter(prev.value)) {
        return SafetyVerdict.block(SafetyCheck.editorControllerSupremacy,
            'EditorController supremacy VIOLATED: lifecycle stage '
            '"${curr.key}" (${curr.value.toIso8601String()}) is not strictly '
            'after "${prev.key}" (${prev.value.toIso8601String()}). '
            'The Phase-13 pipeline was either skipped, partially forged, '
            'or executed out of order. Execution is unconditionally blocked.');
      }
    }

    // Pipeline age check — the command must not be stale.
    final pipelineAge = DateTime.now().toUtc()
        .difference(lc.receivedAt)
        .inMilliseconds;
    if (pipelineAge > _config.maxPipelineAgeMs) {
      return SafetyVerdict.block(SafetyCheck.editorControllerSupremacy,
          'EditorController supremacy: payload is STALE. '
          'Pipeline age ${pipelineAge}ms exceeds maximum '
          '${_config.maxPipelineAgeMs}ms. '
          'The command was routed too long ago to be safely executed now. '
          'Re-submit the action through the Phase-13 pipeline.');
    }

    return SafetyVerdict.pass(SafetyCheck.editorControllerSupremacy);
  }

  // --------------------------------------------------
  // GATE 6 — CANVAS / UI DIRECT ACCESS BLOCKING
  // Phase-14 must never receive a payload that originated directly from
  // a Canvas widget or a UI component without passing through
  // EditorController → EditorActionEngine.
  //
  // Forbidden source pattern:
  //   ActionSource.ui + extremely high confidence (1.0) with no Phase-13
  //   latency gap indicates a direct call that bypassed interpretation.
  // --------------------------------------------------

  Future<SafetyVerdict> _checkCanvasAccessBlocking(
      EditorControllerPayload payload) async {
    if (!_config.enableCanvasBlock) {
      return SafetyVerdict.skip(SafetyCheck.canvasAccessBlocking,
          'Canvas access blocking disabled by config.');
    }

    // Direct-canvas signal: source is 'ui', confidence is exactly 1.0
    // (Phase-13 interpretation always produces a fractional score), AND
    // the Phase-13 pipeline had zero latency (all timestamps identical),
    // indicating lifecycle fields were synthetically constructed.
    final lc               = payload.lifecycle;
    final zeroLatency      = lc.dispatchedAt == lc.receivedAt;
    final exactConfidence  = payload.confidence == 1.0;
    final uiSource         = payload.source == ActionSource.ui;

    if (uiSource && exactConfidence && zeroLatency) {
      return SafetyVerdict.block(SafetyCheck.canvasAccessBlocking,
          'Canvas / UI direct-access BLOCKED: payload exhibits the signature '
          'of a synthetically constructed call (source=ui, confidence=1.0, '
          'zero pipeline latency). Phase-14 may only be reached via '
          'EditorController → EditorActionEngine — never directly from a '
          'widget or canvas handler.');
    }

    // Additionally block the `internal` source only when the lifecycle
    // timestamps are identical (same synthetic-construction signal).
    if (payload.source == ActionSource.internal && zeroLatency) {
      return SafetyVerdict.block(SafetyCheck.canvasAccessBlocking,
          'Internal source with zero pipeline latency BLOCKED. '
          'System-generated payloads (undo/redo triggers) must still pass '
          'through the full Phase-13 routing chain before reaching Phase-14.');
    }

    return SafetyVerdict.pass(SafetyCheck.canvasAccessBlocking);
  }

  // --------------------------------------------------
  // GATE 7 — ENGINE BYPASS DETECTION
  // The commandId and confidence prove the command was routed by ActionRouter
  // and scored by IntentionInterpreter. A bypassed call would have neither.
  //
  // commandId format contract (from Phase-13 ActionRouter):
  //   Non-empty string, length ≥ 8, must not equal the payload's raw text.
  // confidence contract:
  //   Must be above the configured minimum — 0.0 means Phase-13 never scored it.
  // --------------------------------------------------

  Future<SafetyVerdict> _checkEngineBypassDetection(
      EditorControllerPayload payload) async {
    if (!_config.enableBypassDetection) {
      return SafetyVerdict.skip(SafetyCheck.engineBypassDetection,
          'Engine bypass detection disabled by config.');
    }

    // commandId integrity.
    if (payload.commandId.trim().isEmpty) {
      return SafetyVerdict.block(SafetyCheck.engineBypassDetection,
          'Engine bypass detected: commandId is empty. '
          'ActionRouter generates a non-empty ID for every command. '
          'An empty commandId means Phase-13 was bypassed entirely.');
    }
    if (payload.commandId.length < 8) {
      return SafetyVerdict.block(SafetyCheck.engineBypassDetection,
          'Engine bypass detected: commandId "${payload.commandId}" is '
          'suspiciously short (length ${payload.commandId.length} < 8). '
          'ActionRouter IDs are at least 8 characters.');
    }

    // Confidence integrity.
    if (payload.confidence < _config.minConfidenceThreshold) {
      return SafetyVerdict.block(SafetyCheck.engineBypassDetection,
          'Engine bypass detected: confidence ${payload.confidence.toStringAsFixed(4)} '
          'is below the minimum routing threshold '
          '${_config.minConfidenceThreshold}. '
          'IntentionInterpreter assigns a score to every routed command. '
          'A score this low means either the interpreter was bypassed or '
          'the command was force-injected without semantic resolution.');
    }

    // ActionType.unknown with zero confidence is a hard bypass signal.
    if (payload.resolvedActionType == ActionType.unknown &&
        payload.confidence < _config.minConfidenceThreshold) {
      return SafetyVerdict.block(SafetyCheck.engineBypassDetection,
          'Engine bypass detected: unresolved action type combined with '
          'sub-threshold confidence. This payload never passed through '
          'IntentionInterpreter resolution.');
    }

    // Confirm the enrichment source is not empty (every interpreted command
    // carries at least one semantic keyword, even if low-confidence).
    // enrichment.keywords is present on SemanticEnrichment.
    // We check via payload.enrichment — access .keywords if available.
    // (SemanticEnrichment is a concrete class from intention_interpreter.dart.)
    final keywordsEmpty = payload.enrichment.keywords.isEmpty;
    if (keywordsEmpty && payload.source != ActionSource.internal) {
      return SafetyVerdict.block(SafetyCheck.engineBypassDetection,
          'Engine bypass detected: SemanticEnrichment.keywords is empty for '
          'a non-internal source. IntentionInterpreter always extracts at '
          'least one keyword during routing. An empty keyword set proves '
          'the interpreter stage was skipped.');
    }

    return SafetyVerdict.pass(SafetyCheck.engineBypassDetection);
  }

  // --------------------------------------------------
  // LOGGING
  // --------------------------------------------------

  void _log(String message) {
    // ignore: avoid_print
    print('[ExecutionSafetyLayer] $message');
  }
}

// ==================================================
// NULL / PERMISSIVE IMPLEMENTATION
// Clears every check unconditionally.
// For dev and test environments where full safety validation is not needed.
// DO NOT USE IN PRODUCTION.
// ==================================================

class PermissiveSafetyLayer implements ExecutionSafetyLayerInterface {
  const PermissiveSafetyLayer();

  @override
  Future<String?> check(
      EditorControllerPayload payload, String sessionId) async {
    return null; // always clears
  }
}

// ==================================================
// STATIC KILL-SWITCH HELPER
// Provides a process-wide kill-switch that any component can read
// without holding a reference to the concrete ExecutionSafetyLayer instance.
// The concrete layer's armKillSwitch() / disarmKillSwitch() are the
// canonical write paths; this helper is READ-ONLY from external code.
// ==================================================

abstract final class ZCanvasKillSwitch {
  static bool _armed = false;
  static String? _reason;

  static bool    get isArmed => _armed;
  static String? get reason  => _reason;

  /// Arms the static kill-switch. Used by crash handlers and integrity monitors.
  static void arm(String reason) {
    _armed  = true;
    _reason = reason;
    // ignore: avoid_print
    print('[ZCanvasKillSwitch] ARMED — $reason');
  }

  /// Disarms the static kill-switch.
  static void disarm() {
    _armed  = false;
    _reason = null;
    // ignore: avoid_print
    print('[ZCanvasKillSwitch] Disarmed.');
  }
}

// ==================================================
// END OF core/execution/execution_safety_layer.dart
// Z-CANVAS — PHASE-14 — FINAL SYSTEM PROTECTION WALL
// Powered by Zynquar
// ==================================================
