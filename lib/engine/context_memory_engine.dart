// engines/context_memory_engine.dart
//
// PHASE-8 — ContextMemoryEngine
//
// PRIMARY ROLE: Temporary Session Context Management
//
// AUTHORITY: TEMPORARY CONTEXT AUTHORITY ONLY.
//   — This engine does NOT execute.
//   — This engine does NOT modify core state.
//   — This engine does NOT bypass EditorController.
//   — This engine is NOT storage, history, database, or persistence.
//
// COMMUNICATION:
//   MAY communicate with: EditorController, CommandGatewayEngine
//   MAY NEVER communicate with: LayerEngine, HistoryEngine, StorageEngine,
//     RenderEngine, ExportEngine, Canvas
//
// FAILURE ISOLATION:
//   If this engine fails, the system MUST continue with empty context.
//   No failure here may stop the editor.

import 'dart:collection';

// ---------------------------------------------------------------------------
// ENUMERATIONS
// ---------------------------------------------------------------------------

enum InteractionEventType {
  selectionChanged,
  toolChanged,
  actionPerformed,
  conversationTurn,
  workflowStepChanged,
  focusChanged,
  sessionStarted,
  sessionEnded,
}

enum RiskLevel { none, low, medium, high }

// ---------------------------------------------------------------------------
// INPUT CONTRACT
// ---------------------------------------------------------------------------

/// The sole input type accepted by ContextMemoryEngine.
/// Carries all context update signals for a session.
final class ContextRequest {
  const ContextRequest({
    required this.sessionId,
    this.interactionEvent,
    this.selectionState,
    this.workflowState,
  });

  /// Identifies the active session. Must not be empty.
  final String sessionId;

  /// Optional interaction event that triggered this update.
  final InteractionEvent? interactionEvent;

  /// Optional snapshot of the current selection state.
  final SelectionState? selectionState;

  /// Optional snapshot of the current workflow state.
  final WorkflowState? workflowState;

  @override
  String toString() =>
      'ContextRequest(sessionId: $sessionId, event: ${interactionEvent?.type})';
}

// ---------------------------------------------------------------------------
// SUPPORTING INPUT MODELS
// ---------------------------------------------------------------------------

final class InteractionEvent {
  const InteractionEvent({
    required this.type,
    required this.timestamp,
    this.payload = const {},
  });

  final InteractionEventType type;
  final DateTime timestamp;

  /// Arbitrary key-value payload — caller-defined, engine stores as-is.
  final Map<String, Object?> payload;
}

final class SelectionState {
  const SelectionState({
    this.selectedIds = const [],
    this.activeTool,
    this.focusedRegion,
  });

  /// IDs of currently selected objects on the canvas.
  final List<String> selectedIds;

  /// The tool currently active in the editor (e.g. "pen", "select", "text").
  final String? activeTool;

  /// Optional descriptor of the focused canvas region.
  final String? focusedRegion;
}

final class WorkflowState {
  const WorkflowState({
    this.workflowId,
    this.currentStep,
    this.stepCount = 0,
    this.metadata = const {},
  });

  /// Identifier of the active multi-step workflow, if any.
  final String? workflowId;

  /// Zero-based index of the current workflow step.
  final int? currentStep;

  /// Total number of steps in this workflow.
  final int stepCount;

  /// Caller-defined metadata for the workflow.
  final Map<String, Object?> metadata;
}

// ---------------------------------------------------------------------------
// OUTPUT CONTRACT
// ---------------------------------------------------------------------------

/// The sole output type produced by ContextMemoryEngine.
/// Represents a point-in-time snapshot of temporary session context.
///
/// This snapshot is NON-EXECUTABLE. It is informational only.
/// No engine other than EditorController or CommandGatewayEngine
/// may use a ContextSnapshot to trigger execution.
final class ContextSnapshot {
  const ContextSnapshot({
    required this.sessionId,
    required this.capturedAt,
    this.activeSelection = const [],
    this.activeTool,
    this.recentActions = const [],
    this.workflowState,
    this.conversationContext = const ConversationContext(),
    this.focusedRegion,
    this.isEmpty = false,
  });

  /// Creates an empty snapshot used when the engine has no context
  /// for a session, or when the engine itself has failed.
  factory ContextSnapshot.empty({required String sessionId}) {
    return ContextSnapshot(
      sessionId: sessionId,
      capturedAt: DateTime.now(),
      isEmpty: true,
    );
  }

  final String sessionId;

  /// UTC timestamp at which this snapshot was built.
  final DateTime capturedAt;

  /// IDs of objects currently selected in the editor.
  final List<String> activeSelection;

  /// Name/type of the currently active editor tool.
  final String? activeTool;

  /// Ordered list of recent action descriptors (most recent last).
  /// Capped by the engine's [ContextMemoryEngine.maxRecentActions] setting.
  final List<String> recentActions;

  /// Current workflow state, or null if no workflow is active.
  final WorkflowState? workflowState;

  /// Accumulated conversation context for multi-turn interactions.
  final ConversationContext conversationContext;

  /// Optional focused region descriptor.
  final String? focusedRegion;

  /// True when the snapshot contains no meaningful context data.
  /// Callers must handle empty snapshots gracefully.
  final bool isEmpty;

  @override
  String toString() =>
      'ContextSnapshot(session: $sessionId, selectedIds: ${activeSelection.length}, '
      'tool: $activeTool, recentActions: ${recentActions.length}, '
      'empty: $isEmpty, capturedAt: $capturedAt)';
}

// ---------------------------------------------------------------------------
// SUPPORTING OUTPUT MODELS
// ---------------------------------------------------------------------------

final class ConversationContext {
  const ConversationContext({
    this.turns = const [],
    this.lastIntent,
    this.pendingClarification,
  });

  /// Ordered conversation turns (oldest first).
  final List<ConversationTurn> turns;

  /// The most recently resolved intent string, if any.
  final String? lastIntent;

  /// Clarification prompt awaiting user response, if any.
  final String? pendingClarification;

  bool get hasPendingClarification => pendingClarification != null;
  bool get hasHistory => turns.isNotEmpty;

  ConversationContext copyWith({
    List<ConversationTurn>? turns,
    String? lastIntent,
    String? pendingClarification,
    bool clearClarification = false,
  }) {
    return ConversationContext(
      turns: turns ?? this.turns,
      lastIntent: lastIntent ?? this.lastIntent,
      pendingClarification:
          clearClarification ? null : (pendingClarification ?? this.pendingClarification),
    );
  }
}

final class ConversationTurn {
  const ConversationTurn({
    required this.role,
    required this.content,
    required this.timestamp,
    this.resolvedIntent,
  });

  /// 'user' | 'assistant' | 'system'
  final String role;
  final String content;
  final DateTime timestamp;

  /// Intent resolved from this turn, if applicable.
  final String? resolvedIntent;
}

// ---------------------------------------------------------------------------
// INTERNAL SESSION STATE (package-private)
// ---------------------------------------------------------------------------

/// Mutable internal state for a single session.
/// Not exposed outside this file.
final class _SessionContext {
  _SessionContext({required this.sessionId, required this.createdAt});

  final String sessionId;
  final DateTime createdAt;

  SelectionState _selection = const SelectionState();
  WorkflowState? _workflowState;
  ConversationContext _conversationContext = const ConversationContext();
  final Queue<String> _recentActions = Queue();
  DateTime _lastUpdated = DateTime.now();
  bool _isActive = true;

  SelectionState get selection => _selection;
  WorkflowState? get workflowState => _workflowState;
  ConversationContext get conversationContext => _conversationContext;
  List<String> get recentActions => List.unmodifiable(_recentActions.toList());
  DateTime get lastUpdated => _lastUpdated;
  bool get isActive => _isActive;

  void updateSelection(SelectionState state) {
    _selection = state;
    _lastUpdated = DateTime.now();
  }

  void updateWorkflow(WorkflowState state) {
    _workflowState = state;
    _lastUpdated = DateTime.now();
  }

  void recordAction(String descriptor, int maxActions) {
    _recentActions.addLast(descriptor);
    while (_recentActions.length > maxActions) {
      _recentActions.removeFirst();
    }
    _lastUpdated = DateTime.now();
  }

  void appendConversationTurn(ConversationTurn turn) {
    _conversationContext = _conversationContext.copyWith(
      turns: [..._conversationContext.turns, turn],
    );
    _lastUpdated = DateTime.now();
  }

  void resolveIntent(String intent) {
    _conversationContext = _conversationContext.copyWith(lastIntent: intent);
    _lastUpdated = DateTime.now();
  }

  void setPendingClarification(String prompt) {
    _conversationContext = _conversationContext.copyWith(pendingClarification: prompt);
    _lastUpdated = DateTime.now();
  }

  void clearPendingClarification() {
    _conversationContext =
        _conversationContext.copyWith(clearClarification: true);
    _lastUpdated = DateTime.now();
  }

  void deactivate() {
    _isActive = false;
  }
}

// ---------------------------------------------------------------------------
// CONTEXT MEMORY ENGINE
// ---------------------------------------------------------------------------

/// ContextMemoryEngine — PHASE-8 Support Engine
///
/// Manages temporary runtime context and session snapshots.
///
/// LAWS:
///   1. This engine is NOT storage, history, or a database.
///   2. All data lives in-memory and is discarded on session clear.
///   3. This engine MUST NEVER block or throw to its callers.
///   4. This engine MUST NEVER communicate with LayerEngine,
///      HistoryEngine, StorageEngine, RenderEngine, ExportEngine,
///      or Canvas.
///   5. EditorController remains the only execution authority.
///   6. If this engine fails, callers receive an empty ContextSnapshot
///      and the editor continues uninterrupted.
final class ContextMemoryEngine {
  /// [maxRecentActions] — maximum number of recent action descriptors
  ///   retained per session. Older entries are evicted automatically.
  ///
  /// [sessionTtl] — maximum idle duration before a session is considered
  ///   stale. Stale sessions are not auto-evicted but are flagged via
  ///   [isSessionStale]. Callers (EditorController, CommandGatewayEngine)
  ///   must call [clearContext] to release them.
  ContextMemoryEngine({
    int maxRecentActions = 50,
    Duration sessionTtl = const Duration(hours: 2),
  })  : _maxRecentActions = maxRecentActions,
        _sessionTtl = sessionTtl;

  final int _maxRecentActions;
  final Duration _sessionTtl;

  /// Active sessions, keyed by sessionId.
  final Map<String, _SessionContext> _sessions = {};

  // -------------------------------------------------------------------------
  // MANDATORY FUNCTIONS (as required by PHASE-8 Constitution)
  // -------------------------------------------------------------------------

  /// Creates a new context for the given session.
  ///
  /// If a context already exists for [sessionId], the existing context
  /// is retained and this call is a no-op (idempotent).
  ///
  /// Returns true if a new context was created; false if it already existed.
  bool createContext(String sessionId) {
    try {
      if (sessionId.isEmpty) return false;
      if (_sessions.containsKey(sessionId)) return false;

      _sessions[sessionId] = _SessionContext(
        sessionId: sessionId,
        createdAt: DateTime.now(),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Updates the context for the session identified in [request].
  ///
  /// If no context exists for the session, one is created automatically
  /// before applying the update (fail-open behaviour).
  ///
  /// This method NEVER throws. All errors are swallowed to satisfy the
  /// Failure Isolation Law.
  void updateContext(ContextRequest request) {
    try {
      if (request.sessionId.isEmpty) return;

      final session = _sessions.putIfAbsent(
        request.sessionId,
        () => _SessionContext(
          sessionId: request.sessionId,
          createdAt: DateTime.now(),
        ),
      );

      if (!session.isActive) return;

      final event = request.interactionEvent;
      if (request.selectionState != null) {
        session.updateSelection(request.selectionState!);
      }
      if (request.workflowState != null) {
        session.updateWorkflow(request.workflowState!);
      }
      if (event != null) {
        _applyInteractionEvent(session, event);
      }
    } catch (_) {
      // Failure isolation: silently absorb all errors.
    }
  }

  /// Captures and persists the current selection state for a session.
  ///
  /// Convenience method for callers that only need to record selection.
  void captureSelection(String sessionId, SelectionState selectionState) {
    try {
      if (sessionId.isEmpty) return;
      final session = _sessions[sessionId];
      if (session == null || !session.isActive) return;
      session.updateSelection(selectionState);
    } catch (_) {}
  }

  /// Captures and persists the current workflow state for a session.
  ///
  /// Convenience method for callers that only need to record workflow progress.
  void captureWorkflowState(String sessionId, WorkflowState workflowState) {
    try {
      if (sessionId.isEmpty) return;
      final session = _sessions[sessionId];
      if (session == null || !session.isActive) return;
      session.updateWorkflow(workflowState);
    } catch (_) {}
  }

  /// Builds and returns a [ContextSnapshot] for the given session.
  ///
  /// Returns [ContextSnapshot.empty] if:
  ///   — The session does not exist.
  ///   — The session has been cleared/deactivated.
  ///   — Any internal error occurs.
  ///
  /// The returned snapshot is always non-null and safe to consume.
  ContextSnapshot buildSnapshot(String sessionId) {
    try {
      if (sessionId.isEmpty) return ContextSnapshot.empty(sessionId: sessionId);

      final session = _sessions[sessionId];
      if (session == null || !session.isActive) {
        return ContextSnapshot.empty(sessionId: sessionId);
      }

      return ContextSnapshot(
        sessionId: sessionId,
        capturedAt: DateTime.now(),
        activeSelection: List.unmodifiable(session.selection.selectedIds),
        activeTool: session.selection.activeTool,
        recentActions: session.recentActions,
        workflowState: session.workflowState,
        conversationContext: session.conversationContext,
        focusedRegion: session.selection.focusedRegion,
        isEmpty: false,
      );
    } catch (_) {
      return ContextSnapshot.empty(sessionId: sessionId);
    }
  }

  /// Clears and destroys the context for the given session.
  ///
  /// After this call the session no longer exists in memory.
  /// Subsequent calls to [buildSnapshot] for this sessionId will return
  /// [ContextSnapshot.empty].
  ///
  /// This is the terminal step of the session lifecycle:
  ///   Session Start → Context Created → … → Session End → Context Cleared
  void clearContext(String sessionId) {
    try {
      final session = _sessions.remove(sessionId);
      session?.deactivate();
    } catch (_) {}
  }

  // -------------------------------------------------------------------------
  // ADDITIONAL CONTEXT OPERATIONS
  // -------------------------------------------------------------------------

  /// Appends a conversation turn to the session's conversation context.
  ///
  /// Intended for use by CommandGatewayEngine when processing natural-language
  /// or multi-turn voice/robot assistant commands.
  void appendConversationTurn(String sessionId, ConversationTurn turn) {
    try {
      final session = _sessions[sessionId];
      if (session == null || !session.isActive) return;
      session.appendConversationTurn(turn);
    } catch (_) {}
  }

  /// Records the resolved intent string for the session's conversation.
  void resolveConversationIntent(String sessionId, String intent) {
    try {
      final session = _sessions[sessionId];
      if (session == null || !session.isActive) return;
      session.resolveIntent(intent);
    } catch (_) {}
  }

  /// Sets a pending clarification prompt awaiting user response.
  void setPendingClarification(String sessionId, String clarificationPrompt) {
    try {
      final session = _sessions[sessionId];
      if (session == null || !session.isActive) return;
      session.setPendingClarification(clarificationPrompt);
    } catch (_) {}
  }

  /// Clears the pending clarification once it has been resolved.
  void clearPendingClarification(String sessionId) {
    try {
      final session = _sessions[sessionId];
      if (session == null || !session.isActive) return;
      session.clearPendingClarification();
    } catch (_) {}
  }

  // -------------------------------------------------------------------------
  // SESSION INTROSPECTION (read-only, non-mutating)
  // -------------------------------------------------------------------------

  /// Returns true if a live (active, non-stale) context exists for [sessionId].
  bool hasContext(String sessionId) {
    try {
      final session = _sessions[sessionId];
      return session != null && session.isActive;
    } catch (_) {
      return false;
    }
  }

  /// Returns true if the session exists but has been idle longer than [sessionTtl].
  ///
  /// Stale detection is advisory. The session is NOT automatically cleared.
  /// EditorController or CommandGatewayEngine must call [clearContext] to release it.
  bool isSessionStale(String sessionId) {
    try {
      final session = _sessions[sessionId];
      if (session == null || !session.isActive) return false;
      return DateTime.now().difference(session.lastUpdated) > _sessionTtl;
    } catch (_) {
      return false;
    }
  }

  /// Returns the number of currently active sessions held in memory.
  int get activeSessionCount {
    try {
      return _sessions.values.where((s) => s.isActive).length;
    } catch (_) {
      return 0;
    }
  }

  // -------------------------------------------------------------------------
  // PRIVATE HELPERS
  // -------------------------------------------------------------------------

  void _applyInteractionEvent(_SessionContext session, InteractionEvent event) {
    switch (event.type) {
      case InteractionEventType.actionPerformed:
        final descriptor = event.payload['descriptor'] as String?;
        if (descriptor != null && descriptor.isNotEmpty) {
          session.recordAction(descriptor, _maxRecentActions);
        }

      case InteractionEventType.conversationTurn:
        final role = event.payload['role'] as String?;
        final content = event.payload['content'] as String?;
        if (role != null && content != null) {
          session.appendConversationTurn(ConversationTurn(
            role: role,
            content: content,
            timestamp: event.timestamp,
            resolvedIntent: event.payload['resolvedIntent'] as String?,
          ));
        }

      case InteractionEventType.selectionChanged:
      case InteractionEventType.toolChanged:
      case InteractionEventType.workflowStepChanged:
      case InteractionEventType.focusChanged:
      case InteractionEventType.sessionStarted:
      case InteractionEventType.sessionEnded:
        break;
    }
  }
}
