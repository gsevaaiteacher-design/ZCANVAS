// ==================================================
// Z-CANVAS — PHASE-13 ACTION BINDING & EXECUTION SYSTEM
// controllers/action_router.dart
//
// PRIMARY ROLE: ENTRY GATE CONTROLLER
//
// OWNS:
//   ✔ Receive raw UI / Voice / AI intent
//   ✔ Generate unique commandId per action
//   ✔ Start command lifecycle (RECEIVED → ROUTED)
//   ✔ Forward structured intent to CommandMapper
//
// DOES NOT OWN:
//   ❌ Interpretation  ❌ Execution  ❌ Engine access
//   ❌ Canvas access   ❌ Storage    ❌ Layer logic
// ==================================================

import 'dart:async';

// --------------------------------------------------
// COMMAND LIFECYCLE STATE MACHINE
// Every command must advance through these states in order.
// Any failure drops the command — no fallback, no skip.
// --------------------------------------------------

enum CommandState {
  received,
  routed,
  mapped,
  interpreted,
  validated,
  approved,
  dispatched,
  executed,
  completed,
  failed,
}

// --------------------------------------------------
// ACTION SOURCE
// Identifies the origin channel of a raw intent signal.
// --------------------------------------------------

enum ActionSource {
  ui,       // Phase-12 UI component tap/interaction
  voice,    // Voice input pipeline
  ai,       // AI copilot / automation chain
  gesture,  // Gesture recogniser
  plugin,   // Plugin marketplace command
  internal, // System-level automation (e.g. undo/redo triggers)
}

// --------------------------------------------------
// ACTION TYPE
// Exhaustive set of supported action categories.
// The router does not interpret meaning — it tags the raw type only.
// --------------------------------------------------

enum ActionType {
  addLayer,
  deleteLayer,
  moveLayer,
  resizeLayer,
  styleUpdate,
  aiCommand,
  exportRequest,
  undo,
  redo,
  templateRequest,
  unknown, // Safety fallback — command_mapper will drop or escalate
}

// --------------------------------------------------
// RAW INTENT
// The unstructured signal that arrives at the router from any source.
// Shape is kept deliberately loose here; command_mapper normalises it.
// --------------------------------------------------

class RawIntent {
  const RawIntent({
    required this.source,
    required this.actionType,
    this.payload = const <String, dynamic>{},
    this.rawText,
  });

  /// Origin channel.
  final ActionSource source;

  /// Coarse action category — may be [ActionType.unknown] for voice/AI input.
  final ActionType actionType;

  /// Arbitrary key/value bag forwarded verbatim to the mapper.
  /// Must contain NO engine references and NO executable callbacks.
  final Map<String, dynamic> payload;

  /// Optional raw text string for voice / AI input passthrough.
  final String? rawText;

  @override
  String toString() =>
      'RawIntent(source: $source, actionType: $actionType, '
      'rawText: $rawText, payloadKeys: ${payload.keys.toList()})';
}

// --------------------------------------------------
// ROUTED COMMAND
// The enriched object produced by the router and forwarded downstream.
// Carries everything command_mapper needs; contains no execution logic.
// --------------------------------------------------

class RoutedCommand {
  const RoutedCommand({
    required this.commandId,
    required this.intent,
    required this.state,
    required this.routedAt,
  });

  /// Globally unique identifier for this command's lifecycle.
  final String commandId;

  /// The original raw intent, preserved unmodified.
  final RawIntent intent;

  /// Current lifecycle state — always [CommandState.routed] when leaving router.
  final CommandState state;

  /// Wall-clock timestamp of when the router accepted the command.
  final DateTime routedAt;

  /// Returns a copy advanced to the next lifecycle state.
  RoutedCommand copyWith({CommandState? state}) => RoutedCommand(
        commandId: commandId,
        intent:    intent,
        state:     state ?? this.state,
        routedAt:  routedAt,
      );

  @override
  String toString() =>
      'RoutedCommand(id: $commandId, state: $state, '
      'source: ${intent.source}, type: ${intent.actionType})';
}

// --------------------------------------------------
// COMMAND MAPPER INTERFACE
// The router depends only on this abstract boundary.
// Concrete implementation lives in command_mapper.dart (FILE-2).
// --------------------------------------------------

abstract interface class CommandMapperInterface {
  /// Receives a [RoutedCommand] in state [CommandState.routed] and advances
  /// it through the MAPPED stage and beyond.
  Future<void> receive(RoutedCommand command);
}

// --------------------------------------------------
// ROUTING RESULT
// Returned to the caller of [ActionRouter.dispatch] so the UI layer
// can observe whether routing succeeded — without knowing what happens next.
// --------------------------------------------------

class RoutingResult {
  const RoutingResult._({
    required this.commandId,
    required this.accepted,
    this.rejectionReason,
  });

  factory RoutingResult.accepted(String commandId) =>
      RoutingResult._(commandId: commandId, accepted: true);

  factory RoutingResult.rejected(String commandId, String reason) =>
      RoutingResult._(
          commandId: commandId, accepted: false, rejectionReason: reason);

  final String  commandId;
  final bool    accepted;
  final String? rejectionReason;

  @override
  String toString() => accepted
      ? 'RoutingResult.accepted($commandId)'
      : 'RoutingResult.rejected($commandId, "$rejectionReason")';
}

// --------------------------------------------------
// VIOLATION LOG ENTRY
// Written whenever a caller attempts to mis-use the router.
// --------------------------------------------------

class _ViolationEntry {
  const _ViolationEntry({
    required this.commandId,
    required this.reason,
    required this.timestamp,
  });
  final String   commandId;
  final String   reason;
  final DateTime timestamp;
}

// --------------------------------------------------
// ACTION ROUTER
// The single public entry point for the entire Phase-13 pipeline.
//
// Responsibilities (router layer only):
//   1. Accept a RawIntent from any source (UI, Voice, AI, Gesture, Plugin).
//   2. Generate a UUID-style commandId.
//   3. Stamp lifecycle state as RECEIVED, then advance to ROUTED.
//   4. Validate the intent minimally (source + type must be set).
//   5. Forward the RoutedCommand to the injected CommandMapperInterface.
//   6. Return a RoutingResult to the caller — nothing more.
//
// The router NEVER calls engines, NEVER touches canvas/layers/history/storage,
// and NEVER executes actions. Violations are logged and the command is dropped.
// --------------------------------------------------

class ActionRouter {
  ActionRouter({required CommandMapperInterface mapper}) : _mapper = mapper;

  final CommandMapperInterface _mapper;

  // Internal violation audit log (in-memory; surface via [violations] getter).
  final List<_ViolationEntry> _violations = [];

  // Counter for ID uniqueness within a session (supplemented by timestamp).
  int _sequence = 0;

  // --------------------------------------------------
  // PUBLIC API
  // --------------------------------------------------

  /// Dispatches a [RawIntent] into the command pipeline.
  ///
  /// Returns a [RoutingResult] synchronously-ish (awaited internally) so the
  /// UI can log or display feedback without blocking the render thread.
  ///
  /// The router neither awaits downstream processing nor cares about its
  /// outcome — it is fire-and-observe at this boundary.
  Future<RoutingResult> dispatch(RawIntent intent) async {
    final commandId = _generateCommandId(intent.source);

    // — LIFECYCLE: RECEIVED —
    _log('[$commandId] State → RECEIVED | source=${intent.source} '
        'type=${intent.actionType}');

    // Guard: reject structurally invalid intents before they enter the pipeline.
    final guardResult = _guardIntent(commandId, intent);
    if (guardResult != null) {
      _recordViolation(commandId, guardResult);
      _log('[$commandId] DROPPED — $guardResult');
      return RoutingResult.rejected(commandId, guardResult);
    }

    // — LIFECYCLE: ROUTED —
    final command = RoutedCommand(
      commandId: commandId,
      intent:    intent,
      state:     CommandState.routed,
      routedAt:  DateTime.now().toUtc(),
    );

    _log('[$commandId] State → ROUTED | forwarding to CommandMapper');

    // Forward to mapper — router's responsibility ends here.
    // Any error from the mapper is isolated; the router reports success
    // for its own stage and lets the downstream lifecycle handle failures.
    try {
      await _mapper.receive(command);
    } catch (e, stack) {
      // Mapper threw unexpectedly — log the violation, do not rethrow.
      // Router still reports ROUTED because its own stage completed cleanly.
      _recordViolation(commandId,
          'CommandMapper threw unexpectedly: $e\n$stack');
      _log('[$commandId] WARNING — mapper error isolated: $e');
    }

    return RoutingResult.accepted(commandId);
  }

  /// Read-only access to the violation audit log.
  List<_ViolationEntry> get violations => List.unmodifiable(_violations);

  /// Clears the in-memory violation log (e.g. on session reset).
  void clearViolations() => _violations.clear();

  // --------------------------------------------------
  // PRIVATE HELPERS
  // --------------------------------------------------

  /// Produces a collision-resistant, traceable command ID.
  /// Format: ZC-{SOURCE_PREFIX}-{YYYYMMDD_HHmmss_mmm}-{SEQ}
  String _generateCommandId(ActionSource source) {
    final prefix = _sourcePrefix(source);
    final now    = DateTime.now().toUtc();
    final stamp  = '${now.year.toString().padLeft(4, '0')}'
                   '${now.month.toString().padLeft(2, '0')}'
                   '${now.day.toString().padLeft(2, '0')}_'
                   '${now.hour.toString().padLeft(2, '0')}'
                   '${now.minute.toString().padLeft(2, '0')}'
                   '${now.second.toString().padLeft(2, '0')}_'
                   '${now.millisecond.toString().padLeft(3, '0')}';
    final seq    = (_sequence++).toString().padLeft(6, '0');
    return 'ZC-$prefix-$stamp-$seq';
  }

  String _sourcePrefix(ActionSource source) => switch (source) {
        ActionSource.ui       => 'UI',
        ActionSource.voice    => 'VC',
        ActionSource.ai       => 'AI',
        ActionSource.gesture  => 'GS',
        ActionSource.plugin   => 'PL',
        ActionSource.internal => 'IN',
      };

  /// Validates the raw intent for structural correctness.
  /// Returns a violation reason string, or null if the intent is clean.
  String? _guardIntent(String commandId, RawIntent intent) {
    // ActionType.unknown is allowed to pass through — the mapper will handle it.
    // Reject only structurally broken intents that would corrupt the pipeline.

    // Payload must not contain callable references (Dart closures / functions).
    // We can only check at the key level for common misuse patterns here.
    for (final key in intent.payload.keys) {
      if (intent.payload[key] is Function) {
        return 'Payload contains a Function reference at key "$key". '
            'Phase-13 does not accept executable payloads.';
      }
    }

    return null; // Intent passes guard.
  }

  void _recordViolation(String commandId, String reason) {
    _violations.add(_ViolationEntry(
      commandId: commandId,
      reason:    reason,
      timestamp: DateTime.now().toUtc(),
    ));
  }

  /// Structured log — replace with a proper logger in production
  /// (e.g. `package:logging` or Zynquar's internal logger).
  void _log(String message) {
    // ignore: avoid_print
    print('[ActionRouter] $message');
  }
}

// ==================================================
// CONVENIENCE FACTORY HELPERS
// Thin wrappers so Phase-11 screens can build intents without
// constructing the full map manually every time.
// ==================================================

extension RawIntentFactory on RawIntent {
  /// Creates a UI-sourced add-layer intent.
  static RawIntent addLayer({
    required String  layerType,
    Map<String, dynamic> params = const {},
  }) =>
      RawIntent(
        source:     ActionSource.ui,
        actionType: ActionType.addLayer,
        payload:    {'layerType': layerType, ...params},
      );

  /// Creates a UI-sourced delete-layer intent.
  static RawIntent deleteLayer({required String layerId}) =>
      RawIntent(
        source:     ActionSource.ui,
        actionType: ActionType.deleteLayer,
        payload:    {'layerId': layerId},
      );

  /// Creates a UI-sourced move-layer intent.
  static RawIntent moveLayer({
    required String layerId,
    required double dx,
    required double dy,
  }) =>
      RawIntent(
        source:     ActionSource.ui,
        actionType: ActionType.moveLayer,
        payload:    {'layerId': layerId, 'dx': dx, 'dy': dy},
      );

  /// Creates a UI-sourced resize-layer intent.
  static RawIntent resizeLayer({
    required String layerId,
    required double width,
    required double height,
  }) =>
      RawIntent(
        source:     ActionSource.ui,
        actionType: ActionType.resizeLayer,
        payload:    {'layerId': layerId, 'width': width, 'height': height},
      );

  /// Creates a UI-sourced style-update intent.
  static RawIntent styleUpdate({
    required String              layerId,
    required Map<String, dynamic> styleProps,
  }) =>
      RawIntent(
        source:     ActionSource.ui,
        actionType: ActionType.styleUpdate,
        payload:    {'layerId': layerId, 'styleProps': styleProps},
      );

  /// Creates an AI-sourced command intent with raw natural language text.
  static RawIntent aiCommand({required String prompt}) =>
      RawIntent(
        source:     ActionSource.ai,
        actionType: ActionType.aiCommand,
        rawText:    prompt,
      );

  /// Creates a UI-sourced export request.
  static RawIntent exportRequest({required String format}) =>
      RawIntent(
        source:     ActionSource.ui,
        actionType: ActionType.exportRequest,
        payload:    {'format': format},
      );

  /// Creates a UI-sourced undo intent.
  static RawIntent undo() =>
      const RawIntent(source: ActionSource.ui, actionType: ActionType.undo);

  /// Creates a UI-sourced redo intent.
  static RawIntent redo() =>
      const RawIntent(source: ActionSource.ui, actionType: ActionType.redo);

  /// Creates a UI-sourced template request.
  static RawIntent templateRequest({required String templateId}) =>
      RawIntent(
        source:     ActionSource.ui,
        actionType: ActionType.templateRequest,
        payload:    {'templateId': templateId},
      );

  /// Creates a voice-sourced intent with raw spoken text.
  static RawIntent voice({required String spokenText}) =>
      RawIntent(
        source:     ActionSource.voice,
        actionType: ActionType.unknown, // Interpreter resolves from rawText.
        rawText:    spokenText,
      );

  /// Creates a plugin-sourced command intent.
  static RawIntent plugin({
    required String              pluginId,
    required String              commandKey,
    Map<String, dynamic>         params = const {},
  }) =>
      RawIntent(
        source:     ActionSource.plugin,
        actionType: ActionType.unknown, // Mapper resolves plugin commands.
        payload:    {'pluginId': pluginId, 'commandKey': commandKey, ...params},
      );
}

// ==================================================
// END OF controllers/action_router.dart
// Z-CANVAS — PHASE-13 — ENTRY GATE CONTROLLER
// Powered by Zynquar
// ==================================================
