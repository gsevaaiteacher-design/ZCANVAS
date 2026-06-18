// engines/runtime_manager_engine.dart
//
// PHASE-9 — RuntimeManagerEngine
//
// ===========================================================================
// OWNERSHIP CONTRACT
// ===========================================================================
//
// WHAT THIS FILE CAN DO:
//   • Observe application lifecycle transitions (foreground, background, etc.)
//   • Track session start and end events
//   • Capture runtime activity state (read-only observation)
//   • Record memory pressure signals
//   • Record performance signals (frame timing, jank, latency)
//   • Build RuntimeSnapshot — a point-in-time read-only view of runtime state
//   • Generate runtime reports for advisory consumption
//   • Support future voice, robot, and AI session monitoring
//
// WHAT THIS FILE CANNOT DO:
//   ❌ Execute any action
//   ❌ Mutate application state
//   ❌ Modify or access LayerEngine
//   ❌ Modify or access HistoryEngine
//   ❌ Modify or access StorageEngine
//   ❌ Modify or access RenderEngine
//   ❌ Modify or access ExportEngine
//   ❌ Modify or access Canvas
//   ❌ Make AI, workflow, plugin, or automation decisions
//   ❌ Control any other engine
//   ❌ Block execution of any other engine
//
// WHAT THIS FILE CAN COMMUNICATE WITH:
//   ✔ EditorController (advisory / reporting only)
//   ✔ PHASE-9 peer engines (read-only data sharing; no commanding)
//
// WHAT THIS FILE CANNOT COMMUNICATE WITH:
//   ❌ LayerEngine
//   ❌ HistoryEngine
//   ❌ StorageEngine
//   ❌ RenderEngine
//   ❌ ExportEngine
//   ❌ Canvas
//
// AUTHORITY: RUNTIME OBSERVATION AUTHORITY ONLY.
//   This engine OBSERVES. It does not control.
//   EditorController remains the only execution authority.
//
// FAILURE ISOLATION:
//   If this engine fails, the editor MUST continue working uninterrupted.
//   The core system MUST NEVER depend on this engine.
// ===========================================================================

import 'dart:collection';

// ---------------------------------------------------------------------------
// SECTION 1 — ENUMERATIONS
// ---------------------------------------------------------------------------

/// Lifecycle states the application can occupy.
enum LifecycleState {
  /// Application has been initialized but not yet started.
  initializing,

  /// Application is in the foreground and actively rendering.
  foreground,

  /// Application has been moved to the background.
  background,

  /// Application is paused (e.g. system interrupt, incoming call).
  paused,

  /// Application is resuming from a paused or background state.
  resuming,

  /// Application is in the process of terminating.
  terminating,

  /// Lifecycle state is unknown or has not been set.
  unknown,
}

/// Session states for a tracked runtime session.
enum SessionState {
  /// No session is active.
  idle,

  /// A session is being initialized.
  starting,

  /// A session is active and running.
  active,

  /// A session is being cleanly ended.
  ending,

  /// A session was terminated unexpectedly.
  terminated,
}

/// Memory pressure levels reported by the device or runtime.
enum MemoryPressureLevel {
  /// No memory pressure detected.
  none,

  /// Low memory pressure — monitor but no action required.
  low,

  /// Moderate memory pressure — advisory warnings may be emitted.
  moderate,

  /// High memory pressure — strong advisory to reduce allocations.
  high,

  /// Critical memory pressure — system may terminate the process.
  critical,
}

/// Categories of runtime events observed by this engine.
enum RuntimeEventType {
  /// Application moved to foreground.
  appForegrounded,

  /// Application moved to background.
  appBackgrounded,

  /// Application paused.
  appPaused,

  /// Application resumed.
  appResumed,

  /// Application termination detected.
  appTerminating,

  /// A new session was started.
  sessionStarted,

  /// An existing session ended cleanly.
  sessionEnded,

  /// A session ended unexpectedly.
  sessionTerminated,

  /// Memory pressure signal received.
  memoryPressureChanged,

  /// A performance signal was recorded (frame time, jank, latency).
  performanceSignalRecorded,

  /// A general runtime activity was observed.
  activityObserved,

  /// A runtime warning was generated.
  warningGenerated,
}

/// Severity levels for runtime warnings.
enum WarningSeverity { info, low, medium, high, critical }

// ---------------------------------------------------------------------------
// SECTION 2 — INPUT CONTRACT
// ---------------------------------------------------------------------------

/// The sole input type accepted by RuntimeManagerEngine.
///
/// Represents a single observable runtime event.
final class RuntimeEvent {
  const RuntimeEvent({
    required this.eventId,
    required this.eventType,
    required this.timestamp,
    this.runtimeContext = const {},
  });

  /// Unique identifier for this event. Must not be empty.
  final String eventId;

  /// The category of runtime event being reported.
  final RuntimeEventType eventType;

  /// UTC timestamp at which the event occurred.
  final DateTime timestamp;

  /// Arbitrary key-value context payload attached to this event.
  /// Engine stores as-is — no interpretation is performed.
  final Map<String, Object?> runtimeContext;

  @override
  String toString() =>
      'RuntimeEvent(id: $eventId, type: $eventType, at: $timestamp)';
}

// ---------------------------------------------------------------------------
// SECTION 3 — SUPPORTING DATA MODELS
// ---------------------------------------------------------------------------

/// A single observed runtime activity descriptor.
final class RuntimeActivity {
  const RuntimeActivity({
    required this.activityId,
    required this.description,
    required this.observedAt,
    this.metadata = const {},
  });

  final String activityId;
  final String description;
  final DateTime observedAt;
  final Map<String, Object?> metadata;

  @override
  String toString() =>
      'RuntimeActivity(id: $activityId, desc: $description, at: $observedAt)';
}

/// A set of performance signals captured at a point in time.
final class PerformanceSignals {
  const PerformanceSignals({
    this.averageFrameTimeMs,
    this.jankCount = 0,
    this.droppedFrameCount = 0,
    this.averageCommandLatencyMs,
    this.peakMemoryMb,
    this.cpuLoadPercent,
    this.capturedAt,
    this.additionalSignals = const {},
  });

  /// Average frame render time in milliseconds, if measured.
  final double? averageFrameTimeMs;

  /// Number of jank events (frames exceeding 16 ms target) observed.
  final int jankCount;

  /// Number of frames dropped during the observation window.
  final int droppedFrameCount;

  /// Average command processing latency in milliseconds, if measured.
  final double? averageCommandLatencyMs;

  /// Peak memory usage in megabytes, if measured.
  final double? peakMemoryMb;

  /// CPU load as a percentage 0–100, if available.
  final double? cpuLoadPercent;

  /// UTC timestamp when these signals were captured.
  final DateTime? capturedAt;

  /// Additional engine-agnostic signals for future expansion.
  final Map<String, Object?> additionalSignals;

  /// Returns true if any signal indicates potential performance degradation.
  bool get hasPerformanceConcern =>
      jankCount > 0 ||
      droppedFrameCount > 0 ||
      (averageFrameTimeMs != null && averageFrameTimeMs! > 16.0) ||
      (cpuLoadPercent != null && cpuLoadPercent! > 80.0);

  @override
  String toString() =>
      'PerformanceSignals(frameMs: $averageFrameTimeMs, jank: $jankCount, '
      'droppedFrames: $droppedFrameCount, cpuLoad: $cpuLoadPercent%)';
}

/// A runtime warning generated by the observation engine.
final class RuntimeWarning {
  const RuntimeWarning({
    required this.warningId,
    required this.message,
    required this.severity,
    required this.generatedAt,
    this.relatedEventId,
    this.context = const {},
  });

  final String warningId;
  final String message;
  final WarningSeverity severity;
  final DateTime generatedAt;

  /// ID of the RuntimeEvent that triggered this warning, if applicable.
  final String? relatedEventId;

  /// Additional context for this warning.
  final Map<String, Object?> context;

  @override
  String toString() =>
      'RuntimeWarning(id: $warningId, severity: $severity, msg: $message)';
}

// ---------------------------------------------------------------------------
// SECTION 4 — OUTPUT CONTRACT
// ---------------------------------------------------------------------------

/// Point-in-time read-only snapshot of the application's runtime state.
///
/// This snapshot is NON-EXECUTABLE and ADVISORY ONLY.
/// No engine may use a RuntimeSnapshot to trigger or approve execution.
final class RuntimeSnapshot {
  const RuntimeSnapshot({
    required this.snapshotId,
    required this.capturedAt,
    required this.sessionState,
    required this.lifecycleState,
    this.activeRuntimeActivities = const [],
    this.memoryPressureLevel = MemoryPressureLevel.none,
    this.runtimeWarnings = const [],
    this.performanceSignals,
    this.activeSessionId,
    this.isEmpty = false,
  });

  /// Creates an empty snapshot used when the engine has no state to report,
  /// or when any internal error occurs.
  factory RuntimeSnapshot.empty() {
    return RuntimeSnapshot(
      snapshotId: 'empty',
      capturedAt: DateTime.now(),
      sessionState: SessionState.idle,
      lifecycleState: LifecycleState.unknown,
      isEmpty: true,
    );
  }

  /// Unique identifier for this snapshot.
  final String snapshotId;

  /// UTC timestamp when this snapshot was captured.
  final DateTime capturedAt;

  /// Current session state at snapshot time.
  final SessionState sessionState;

  /// Current lifecycle state at snapshot time.
  final LifecycleState lifecycleState;

  /// Ordered list of recently observed runtime activities.
  final List<RuntimeActivity> activeRuntimeActivities;

  /// Most recently observed memory pressure level.
  final MemoryPressureLevel memoryPressureLevel;

  /// Active warnings at snapshot time (unresolved).
  final List<RuntimeWarning> runtimeWarnings;

  /// Latest performance signals, if captured.
  final PerformanceSignals? performanceSignals;

  /// The ID of the currently active session, if any.
  final String? activeSessionId;

  /// True when the snapshot carries no meaningful runtime data.
  final bool isEmpty;

  /// Convenience: true if any high-or-above warnings exist.
  bool get hasHighSeverityWarnings => runtimeWarnings.any(
        (w) =>
            w.severity == WarningSeverity.high ||
            w.severity == WarningSeverity.critical,
      );

  @override
  String toString() =>
      'RuntimeSnapshot(id: $snapshotId, lifecycle: $lifecycleState, '
      'session: $sessionState, pressure: $memoryPressureLevel, '
      'warnings: ${runtimeWarnings.length}, empty: $isEmpty)';
}

/// A structured runtime report suitable for advisory consumption by
/// EditorController or PHASE-9 peer engines.
///
/// This report is ADVISORY ONLY. It does not authorize execution.
final class RuntimeReport {
  const RuntimeReport({
    required this.reportId,
    required this.generatedAt,
    required this.snapshot,
    this.eventsSinceLastReport = const [],
    this.summary = '',
    this.recommendations = const [],
    this.isHealthy = true,
  });

  /// Unique identifier for this report.
  final String reportId;

  /// UTC timestamp when this report was generated.
  final DateTime generatedAt;

  /// The snapshot that forms the basis of this report.
  final RuntimeSnapshot snapshot;

  /// Events observed since the previous report was generated.
  final List<RuntimeEvent> eventsSinceLastReport;

  /// Human-readable summary of the current runtime state.
  final String summary;

  /// Advisory recommendations for EditorController (informational).
  /// These are suggestions — EditorController decides whether to act.
  final List<String> recommendations;

  /// True when no high-severity warnings or performance concerns exist.
  final bool isHealthy;

  @override
  String toString() =>
      'RuntimeReport(id: $reportId, healthy: $isHealthy, '
      'recommendations: ${recommendations.length}, at: $generatedAt)';
}

// ---------------------------------------------------------------------------
// SECTION 5 — INTERNAL STATE (private)
// ---------------------------------------------------------------------------

/// Mutable internal state managed by RuntimeManagerEngine.
/// Not exposed outside this file.
final class _RuntimeState {
  _RuntimeState();

  LifecycleState lifecycleState = LifecycleState.unknown;
  SessionState sessionState = SessionState.idle;
  MemoryPressureLevel memoryPressureLevel = MemoryPressureLevel.none;
  String? activeSessionId;
  DateTime? sessionStartedAt;

  PerformanceSignals? latestPerformanceSignals;

  final Queue<RuntimeActivity> _recentActivities = Queue();
  final List<RuntimeWarning> _activeWarnings = [];
  final List<RuntimeEvent> _pendingEvents = [];

  List<RuntimeActivity> get recentActivities =>
      List.unmodifiable(_recentActivities.toList());

  List<RuntimeWarning> get activeWarnings =>
      List.unmodifiable(_activeWarnings);

  List<RuntimeEvent> drainPendingEvents() {
    final events = List<RuntimeEvent>.from(_pendingEvents);
    _pendingEvents.clear();
    return events;
  }

  void recordActivity(RuntimeActivity activity, int maxActivities) {
    _recentActivities.addLast(activity);
    while (_recentActivities.length > maxActivities) {
      _recentActivities.removeFirst();
    }
  }

  void addWarning(RuntimeWarning warning) {
    _activeWarnings.add(warning);
  }

  void clearResolvedWarnings() {
    _activeWarnings.removeWhere(
      (w) =>
          w.severity == WarningSeverity.info ||
          w.severity == WarningSeverity.low,
    );
  }

  void recordEvent(RuntimeEvent event) {
    _pendingEvents.add(event);
  }
}

// ---------------------------------------------------------------------------
// SECTION 6 — RUNTIME MANAGER ENGINE
// ---------------------------------------------------------------------------

/// RuntimeManagerEngine — PHASE-9 Observation Engine
///
/// APPLICATION RUNTIME OBSERVATION AUTHORITY.
///
/// This engine KNOWS what the application is doing.
/// It NEVER CONTROLS what the application does.
///
/// LAWS:
///   1. READ ONLY — this engine never mutates application state.
///   2. NO EXECUTION — this engine never triggers or approves actions.
///   3. NO CONTROL — this engine never commands other engines.
///   4. FAILURE SAFE — every method is non-throwing; errors yield
///      empty/safe defaults so the editor continues uninterrupted.
///   5. EditorController remains the only execution authority.
final class RuntimeManagerEngine {
  /// [maxRecentActivities] — maximum runtime activity records retained
  ///   in memory at any time. Oldest entries are evicted automatically.
  ///
  /// [maxWarnings] — maximum advisory warnings retained at any time.
  ///   Oldest low-severity warnings are evicted first.
  RuntimeManagerEngine({
    int maxRecentActivities = 100,
    int maxWarnings = 50,
    String engineId = 'runtime_manager_engine',
  })  : _maxRecentActivities = maxRecentActivities,
        _maxWarnings = maxWarnings,
        _engineId = engineId;

  final int _maxRecentActivities;
  final int _maxWarnings;
  final String _engineId;

  final _RuntimeState _state = _RuntimeState();

  int _snapshotCounter = 0;
  int _reportCounter = 0;
  DateTime? _lastReportGeneratedAt;

  // -------------------------------------------------------------------------
  // SECTION 6A — MANDATORY FUNCTIONS (as required by PHASE-9 Constitution)
  // -------------------------------------------------------------------------

  /// Marks the start of a new monitored session.
  ///
  /// Records the session transition and updates internal session state.
  /// Emits a [SessionState.starting] → [SessionState.active] transition.
  ///
  /// If a session is already active, this call is a no-op (idempotent).
  /// Never throws — errors are silently absorbed.
  void startSession(String sessionId) {
    try {
      if (sessionId.isEmpty) return;
      if (_state.sessionState == SessionState.active) return;

      _state.sessionState = SessionState.starting;
      _state.activeSessionId = sessionId;
      _state.sessionStartedAt = DateTime.now();

      _state.recordActivity(
        RuntimeActivity(
          activityId: _activityId('session_start'),
          description: 'Session started: $sessionId',
          observedAt: DateTime.now(),
        ),
        _maxRecentActivities,
      );

      _state.sessionState = SessionState.active;
    } catch (_) {
      // Failure isolation: silently absorb all errors.
    }
  }

  /// Marks the end of the currently active session.
  ///
  /// Transitions session state to [SessionState.ending] → [SessionState.idle].
  /// Retains all observations made during the session in the activity log
  /// until capacity is exceeded.
  ///
  /// Never throws — errors are silently absorbed.
  void endSession({bool unexpected = false}) {
    try {
      if (_state.sessionState == SessionState.idle) return;

      final finalState =
          unexpected ? SessionState.terminated : SessionState.ending;
      _state.sessionState = finalState;

      final sessionId = _state.activeSessionId ?? 'unknown';
      _state.recordActivity(
        RuntimeActivity(
          activityId: _activityId('session_end'),
          description: unexpected
              ? 'Session terminated unexpectedly: $sessionId'
              : 'Session ended cleanly: $sessionId',
          observedAt: DateTime.now(),
          metadata: {'unexpected': unexpected},
        ),
        _maxRecentActivities,
      );

      _state.activeSessionId = null;
      _state.sessionStartedAt = null;
      _state.sessionState = SessionState.idle;
    } catch (_) {}
  }

  /// Observes and records a lifecycle state transition.
  ///
  /// Accepts a [RuntimeEvent] whose [RuntimeEventType] maps to a lifecycle
  /// transition. Non-lifecycle events are accepted but trigger only activity
  /// recording, not a lifecycle state change.
  ///
  /// Never throws — errors are silently absorbed.
  void trackLifecycle(RuntimeEvent event) {
    try {
      _state.recordEvent(event);

      final nextLifecycle = _lifecycleFromEvent(event.eventType);
      if (nextLifecycle != null) {
        _state.lifecycleState = nextLifecycle;
      }

      _state.recordActivity(
        RuntimeActivity(
          activityId: _activityId('lifecycle'),
          description: 'Lifecycle event: ${event.eventType.name}',
          observedAt: event.timestamp,
          metadata: {
            'eventId': event.eventId,
            'newLifecycleState': nextLifecycle?.name ?? 'unchanged',
            ...event.runtimeContext,
          },
        ),
        _maxRecentActivities,
      );

      _maybeGenerateLifecycleWarning(event);
    } catch (_) {}
  }

  /// Captures the current observable runtime state from an event.
  ///
  /// Handles memory pressure updates, session transitions, and general
  /// activity observations. All state is recorded; nothing is executed.
  ///
  /// Never throws — errors are silently absorbed.
  void captureRuntimeState(RuntimeEvent event) {
    try {
      _state.recordEvent(event);

      switch (event.eventType) {
        case RuntimeEventType.memoryPressureChanged:
          _applyMemoryPressure(event);
        case RuntimeEventType.sessionStarted:
          final sessionId =
              event.runtimeContext['sessionId'] as String? ?? event.eventId;
          startSession(sessionId);
        case RuntimeEventType.sessionEnded:
          endSession(unexpected: false);
        case RuntimeEventType.sessionTerminated:
          endSession(unexpected: true);
        case RuntimeEventType.activityObserved:
          final desc =
              event.runtimeContext['description'] as String? ?? event.eventType.name;
          _state.recordActivity(
            RuntimeActivity(
              activityId: _activityId('activity'),
              description: desc,
              observedAt: event.timestamp,
              metadata: event.runtimeContext,
            ),
            _maxRecentActivities,
          );
        default:
          trackLifecycle(event);
      }
    } catch (_) {}
  }

  /// Captures and records a set of performance signals.
  ///
  /// Replaces the most recently stored [PerformanceSignals] with those
  /// extracted from the provided event. Emits a warning if signals
  /// indicate performance degradation.
  ///
  /// Never throws — errors are silently absorbed.
  void capturePerformanceSignals(RuntimeEvent event) {
    try {
      if (event.eventType != RuntimeEventType.performanceSignalRecorded) return;

      final ctx = event.runtimeContext;
      final signals = PerformanceSignals(
        averageFrameTimeMs: _toDouble(ctx['averageFrameTimeMs']),
        jankCount: _toInt(ctx['jankCount']) ?? 0,
        droppedFrameCount: _toInt(ctx['droppedFrameCount']) ?? 0,
        averageCommandLatencyMs: _toDouble(ctx['averageCommandLatencyMs']),
        peakMemoryMb: _toDouble(ctx['peakMemoryMb']),
        cpuLoadPercent: _toDouble(ctx['cpuLoadPercent']),
        capturedAt: event.timestamp,
        additionalSignals: Map<String, Object?>.from(ctx)
          ..removeWhere((k, _) => _knownSignalKeys.contains(k)),
      );

      _state.latestPerformanceSignals = signals;
      _state.recordEvent(event);

      if (signals.hasPerformanceConcern) {
        _addWarning(RuntimeWarning(
          warningId: _warningId('perf'),
          message: 'Performance concern detected: jank=${signals.jankCount}, '
              'droppedFrames=${signals.droppedFrameCount}, '
              'frameMs=${signals.averageFrameTimeMs?.toStringAsFixed(1)}',
          severity: signals.jankCount > 10 || signals.droppedFrameCount > 10
              ? WarningSeverity.high
              : WarningSeverity.medium,
          generatedAt: event.timestamp,
          relatedEventId: event.eventId,
          context: ctx,
        ));
      }
    } catch (_) {}
  }

  /// Builds and returns a [RuntimeSnapshot] representing the current
  /// observable state of the application runtime.
  ///
  /// Returns [RuntimeSnapshot.empty] if any internal error occurs.
  /// The returned value is always non-null and safe to consume.
  RuntimeSnapshot buildSnapshot() {
    try {
      _snapshotCounter++;
      return RuntimeSnapshot(
        snapshotId: '${_engineId}_snapshot_$_snapshotCounter',
        capturedAt: DateTime.now(),
        sessionState: _state.sessionState,
        lifecycleState: _state.lifecycleState,
        activeRuntimeActivities: _state.recentActivities,
        memoryPressureLevel: _state.memoryPressureLevel,
        runtimeWarnings: _state.activeWarnings,
        performanceSignals: _state.latestPerformanceSignals,
        activeSessionId: _state.activeSessionId,
        isEmpty: false,
      );
    } catch (_) {
      return RuntimeSnapshot.empty();
    }
  }

  /// Generates an advisory [RuntimeReport] for consumption by
  /// EditorController or PHASE-9 peer engines.
  ///
  /// The report is ADVISORY ONLY. It does not authorize any execution.
  /// EditorController decides whether to act on recommendations.
  ///
  /// Returns a minimal safe report if any internal error occurs.
  RuntimeReport generateRuntimeReport() {
    try {
      _reportCounter++;
      final snapshot = buildSnapshot();
      final pendingEvents = _state.drainPendingEvents();
      final recommendations = _buildRecommendations(snapshot);
      final isHealthy = !snapshot.hasHighSeverityWarnings &&
          snapshot.memoryPressureLevel != MemoryPressureLevel.critical &&
          (snapshot.performanceSignals?.hasPerformanceConcern != true);

      final summary = _buildSummary(snapshot, isHealthy);

      _lastReportGeneratedAt = DateTime.now();

      // Evict low-severity resolved warnings to bound memory.
      _state.clearResolvedWarnings();

      return RuntimeReport(
        reportId: '${_engineId}_report_$_reportCounter',
        generatedAt: _lastReportGeneratedAt!,
        snapshot: snapshot,
        eventsSinceLastReport: pendingEvents,
        summary: summary,
        recommendations: recommendations,
        isHealthy: isHealthy,
      );
    } catch (_) {
      return RuntimeReport(
        reportId: '${_engineId}_report_error',
        generatedAt: DateTime.now(),
        snapshot: RuntimeSnapshot.empty(),
        summary: 'Runtime report unavailable due to internal error.',
        isHealthy: true,
      );
    }
  }

  // -------------------------------------------------------------------------
  // SECTION 6B — ADDITIONAL OBSERVATION OPERATIONS
  // -------------------------------------------------------------------------

  /// Updates the observed memory pressure level directly.
  ///
  /// Use when the caller has a resolved [MemoryPressureLevel] value
  /// and does not need to wrap it in a [RuntimeEvent].
  void updateMemoryPressure(MemoryPressureLevel level) {
    try {
      _state.memoryPressureLevel = level;
      if (level == MemoryPressureLevel.high ||
          level == MemoryPressureLevel.critical) {
        _addWarning(RuntimeWarning(
          warningId: _warningId('mem'),
          message:
              'Memory pressure elevated to ${level.name}. Advisory: reduce allocations.',
          severity: level == MemoryPressureLevel.critical
              ? WarningSeverity.critical
              : WarningSeverity.high,
          generatedAt: DateTime.now(),
          context: {'pressureLevel': level.name},
        ));
      }
    } catch (_) {}
  }

  // -------------------------------------------------------------------------
  // SECTION 6C — READ-ONLY INTROSPECTION
  // -------------------------------------------------------------------------

  /// Current lifecycle state (read-only observation).
  LifecycleState get currentLifecycleState {
    try {
      return _state.lifecycleState;
    } catch (_) {
      return LifecycleState.unknown;
    }
  }

  /// Current session state (read-only observation).
  SessionState get currentSessionState {
    try {
      return _state.sessionState;
    } catch (_) {
      return SessionState.idle;
    }
  }

  /// Current memory pressure level (read-only observation).
  MemoryPressureLevel get currentMemoryPressure {
    try {
      return _state.memoryPressureLevel;
    } catch (_) {
      return MemoryPressureLevel.none;
    }
  }

  /// True if a session is currently active.
  bool get hasActiveSession {
    try {
      return _state.sessionState == SessionState.active &&
          _state.activeSessionId != null;
    } catch (_) {
      return false;
    }
  }

  /// The ID of the currently active session, or null.
  String? get activeSessionId {
    try {
      return _state.activeSessionId;
    } catch (_) {
      return null;
    }
  }

  /// Returns the UTC timestamp of the last generated report, or null.
  DateTime? get lastReportGeneratedAt => _lastReportGeneratedAt;

  /// Count of active (unresolved high-severity) warnings.
  int get activeWarningCount {
    try {
      return _state.activeWarnings.length;
    } catch (_) {
      return 0;
    }
  }

  // -------------------------------------------------------------------------
  // SECTION 7 — PRIVATE HELPERS
  // -------------------------------------------------------------------------

  /// Maps [RuntimeEventType] to a [LifecycleState] transition, or null
  /// if the event does not represent a lifecycle transition.
  LifecycleState? _lifecycleFromEvent(RuntimeEventType type) {
    switch (type) {
      case RuntimeEventType.appForegrounded:
        return LifecycleState.foreground;
      case RuntimeEventType.appBackgrounded:
        return LifecycleState.background;
      case RuntimeEventType.appPaused:
        return LifecycleState.paused;
      case RuntimeEventType.appResumed:
        return LifecycleState.resuming;
      case RuntimeEventType.appTerminating:
        return LifecycleState.terminating;
      default:
        return null;
    }
  }

  void _applyMemoryPressure(RuntimeEvent event) {
    final levelName =
        event.runtimeContext['pressureLevel'] as String? ?? 'none';
    final level = MemoryPressureLevel.values.firstWhere(
      (l) => l.name == levelName,
      orElse: () => MemoryPressureLevel.none,
    );
    updateMemoryPressure(level);
  }

  void _maybeGenerateLifecycleWarning(RuntimeEvent event) {
    if (event.eventType == RuntimeEventType.appTerminating) {
      _addWarning(RuntimeWarning(
        warningId: _warningId('lifecycle'),
        message: 'Application termination observed.',
        severity: WarningSeverity.high,
        generatedAt: event.timestamp,
        relatedEventId: event.eventId,
      ));
    }
  }

  void _addWarning(RuntimeWarning warning) {
    _state.addWarning(warning);
    // Evict oldest low-severity warnings when at capacity.
    while (_state.activeWarnings.length > _maxWarnings) {
      final warnings = List<RuntimeWarning>.from(_state.activeWarnings);
      final oldestLow = warnings.indexWhere(
        (w) =>
            w.severity == WarningSeverity.info ||
            w.severity == WarningSeverity.low,
      );
      if (oldestLow >= 0) {
        _state.activeWarnings.removeAt(oldestLow);
      } else {
        // No low-severity to evict — drop the oldest warning.
        _state.activeWarnings.removeAt(0);
      }
    }
  }

  List<String> _buildRecommendations(RuntimeSnapshot snapshot) {
    final recs = <String>[];

    if (snapshot.memoryPressureLevel == MemoryPressureLevel.high ||
        snapshot.memoryPressureLevel == MemoryPressureLevel.critical) {
      recs.add(
        'Advisory: Memory pressure is ${snapshot.memoryPressureLevel.name}. '
        'Consider deferring heavy operations.',
      );
    }

    if (snapshot.performanceSignals?.hasPerformanceConcern == true) {
      recs.add(
        'Advisory: Performance signals indicate degradation '
        '(jank: ${snapshot.performanceSignals!.jankCount}). '
        'Consider reducing render workload.',
      );
    }

    if (snapshot.lifecycleState == LifecycleState.background) {
      recs.add(
        'Advisory: Application is in background. '
        'Non-critical work may be safely deferred.',
      );
    }

    if (snapshot.runtimeWarnings.any(
      (w) => w.severity == WarningSeverity.critical,
    )) {
      recs.add(
        'Advisory: Critical warnings are active. '
        'Immediate review is recommended.',
      );
    }

    return List.unmodifiable(recs);
  }

  String _buildSummary(RuntimeSnapshot snapshot, bool isHealthy) {
    final sessionPart = snapshot.activeSessionId != null
        ? 'Session: ${snapshot.activeSessionId}'
        : 'No active session';
    final healthPart = isHealthy ? 'Healthy' : 'Degraded';
    return '[$healthPart] Lifecycle: ${snapshot.lifecycleState.name} | '
        '$sessionPart | '
        'Memory: ${snapshot.memoryPressureLevel.name} | '
        'Warnings: ${snapshot.runtimeWarnings.length}';
  }

  String _activityId(String tag) =>
      '${_engineId}_${tag}_${DateTime.now().microsecondsSinceEpoch}';

  String _warningId(String tag) =>
      '${_engineId}_warn_${tag}_${DateTime.now().microsecondsSinceEpoch}';

  static double? _toDouble(Object? value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int? _toInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static const Set<String> _knownSignalKeys = {
    'averageFrameTimeMs',
    'jankCount',
    'droppedFrameCount',
    'averageCommandLatencyMs',
    'peakMemoryMb',
    'cpuLoadPercent',
  };
}
