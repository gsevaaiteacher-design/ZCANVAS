// ==================================================
// Z-CANVAS — PHASE-13 ACTION BINDING & EXECUTION SYSTEM
// controllers/command_mapper.dart
//
// PRIMARY ROLE: STRUCTURE NORMALIZER
//
// OWNS:
//   ✔ Convert raw RoutedCommand → typed MappedCommand
//   ✔ Normalize action parameters into typed, schema-validated objects
//   ✔ Attach full metadata (timestamp, source, commandId, mapper version)
//   ✔ Validate command structure before forwarding
//   ✔ Advance lifecycle: ROUTED → MAPPED
//   ✔ Forward MappedCommand to IntentionInterpreterInterface
//
// DOES NOT OWN:
//   ❌ Intent interpretation / meaning extraction
//   ❌ Execution  ❌ Business logic decisions
//   ❌ Engine access  ❌ Canvas / layer / storage access
// ==================================================

import 'dart:async';
import 'action_router.dart';

// ==================================================
// COMMAND METADATA
// Stable provenance record attached to every MappedCommand.
// Immutable after construction — never modified downstream.
// ==================================================

class CommandMetadata {
  const CommandMetadata({
    required this.commandId,
    required this.source,
    required this.actionType,
    required this.routedAt,
    required this.mappedAt,
    this.rawText,
    this.mapperVersion = _kMapperVersion,
  });

  /// Unique ID assigned by ActionRouter.
  final String commandId;

  /// Origin channel (ui / voice / ai / gesture / plugin / internal).
  final ActionSource source;

  /// Coarse action type carried from the raw intent.
  final ActionType actionType;

  /// UTC timestamp from the router stage.
  final DateTime routedAt;

  /// UTC timestamp of this mapping pass.
  final DateTime mappedAt;

  /// Optional raw text (voice / AI prompts) passed through unchanged.
  final String? rawText;

  /// Version token for forward-compatibility auditing.
  final String mapperVersion;

  static const String _kMapperVersion = 'cmd-mapper-v1';

  @override
  String toString() =>
      'CommandMetadata(id: $commandId, source: $source, '
      'type: $actionType, mapper: $mapperVersion)';
}

// ==================================================
// TYPED COMMAND PARAMETERS
// One sealed variant per ActionType.
// Mapper extracts and validates fields from the raw payload map;
// downstream layers receive strongly-typed values — never raw maps.
// ==================================================

sealed class CommandParams {
  const CommandParams();
}

// — Add Layer —
final class AddLayerParams extends CommandParams {
  const AddLayerParams({required this.layerType, this.extra = const {}});
  final String               layerType;
  final Map<String, dynamic> extra;
}

// — Delete Layer —
final class DeleteLayerParams extends CommandParams {
  const DeleteLayerParams({required this.layerId});
  final String layerId;
}

// — Move Layer —
final class MoveLayerParams extends CommandParams {
  const MoveLayerParams({
    required this.layerId,
    required this.dx,
    required this.dy,
  });
  final String layerId;
  final double dx;
  final double dy;
}

// — Resize Layer —
final class ResizeLayerParams extends CommandParams {
  const ResizeLayerParams({
    required this.layerId,
    required this.width,
    required this.height,
  });
  final String layerId;
  final double width;
  final double height;
}

// — Style Update —
final class StyleUpdateParams extends CommandParams {
  const StyleUpdateParams({
    required this.layerId,
    required this.styleProps,
  });
  final String               layerId;
  final Map<String, dynamic> styleProps;
}

// — AI Command —
// actionType.unknown from voice/AI sources also maps here after resolution.
final class AiCommandParams extends CommandParams {
  const AiCommandParams({required this.prompt, this.context = const {}});
  final String               prompt;
  final Map<String, dynamic> context;
}

// — Export Request —
final class ExportRequestParams extends CommandParams {
  const ExportRequestParams({
    required this.format,
    this.quality,
    this.extra = const {},
  });
  final String               format;   // 'png' | 'pdf' | 'svg' | 'jpg' …
  final double?              quality;  // 0.0 – 1.0, nullable = use default
  final Map<String, dynamic> extra;
}

// — Undo —
final class UndoParams extends CommandParams {
  const UndoParams({this.steps = 1});
  final int steps;
}

// — Redo —
final class RedoParams extends CommandParams {
  const RedoParams({this.steps = 1});
  final int steps;
}

// — Template Request —
final class TemplateRequestParams extends CommandParams {
  const TemplateRequestParams({required this.templateId, this.extra = const {}});
  final String               templateId;
  final Map<String, dynamic> extra;
}

// — Plugin Command —
final class PluginCommandParams extends CommandParams {
  const PluginCommandParams({
    required this.pluginId,
    required this.commandKey,
    this.params = const {},
  });
  final String               pluginId;
  final String               commandKey;
  final Map<String, dynamic> params;
}

// — Unknown / Unresolved —
// Passed through with raw text so the interpreter can attempt meaning extraction.
final class UnknownParams extends CommandParams {
  const UnknownParams({this.rawText, this.payload = const {}});
  final String?              rawText;
  final Map<String, dynamic> payload;
}

// ==================================================
// MAPPED COMMAND
// The fully normalised, typed command object.
// Lifecycle state is always [CommandState.mapped] when it leaves this file.
// ==================================================

class MappedCommand {
  const MappedCommand({
    required this.metadata,
    required this.params,
    required this.state,
    required this.normalizedActionType,
  });

  /// Immutable provenance record.
  final CommandMetadata metadata;

  /// Typed, schema-validated parameters for this action.
  final CommandParams params;

  /// Always [CommandState.mapped] at this stage.
  final CommandState state;

  /// Resolved action type after mapper normalisation.
  /// May differ from [metadata.actionType] if the mapper resolved
  /// [ActionType.unknown] from plugin payload keys.
  final ActionType normalizedActionType;

  /// Returns a copy with a new lifecycle state (for downstream advancement).
  MappedCommand copyWith({CommandState? state}) => MappedCommand(
        metadata:             metadata,
        params:               params,
        state:                state ?? this.state,
        normalizedActionType: normalizedActionType,
      );

  @override
  String toString() =>
      'MappedCommand(id: ${metadata.commandId}, '
      'action: $normalizedActionType, state: $state)';
}

// ==================================================
// MAPPING RESULT
// Internal value returned by each normalisation pass.
// Either a clean MappedCommand or a structured failure.
// ==================================================

sealed class _MappingResult {}

final class _MappingSuccess extends _MappingResult {
  _MappingSuccess(this.command);
  final MappedCommand command;
}

final class _MappingFailure extends _MappingResult {
  _MappingFailure(this.reason);
  final String reason;
}

// ==================================================
// INTENTION INTERPRETER INTERFACE
// Forward boundary contract — concrete implementation in FILE-3.
// The mapper depends only on this interface, never the concrete class.
// ==================================================

abstract interface class IntentionInterpreterInterface {
  /// Receives a [MappedCommand] in state [CommandState.mapped] and advances
  /// it through the INTERPRETED stage.
  Future<void> receive(MappedCommand command);
}

// ==================================================
// PAYLOAD SCHEMA DEFINITIONS
// Declarative required-key registry per action type.
// Mapper validates the raw payload against these rules before extraction.
// ==================================================

class _FieldRule {
  const _FieldRule(this.key, this.type, {this.required = true});
  final String key;
  final Type   type;
  final bool   required;
}

const Map<ActionType, List<_FieldRule>> _kPayloadSchema = {
  ActionType.addLayer: [
    _FieldRule('layerType', String),
  ],
  ActionType.deleteLayer: [
    _FieldRule('layerId', String),
  ],
  ActionType.moveLayer: [
    _FieldRule('layerId', String),
    _FieldRule('dx', double),
    _FieldRule('dy', double),
  ],
  ActionType.resizeLayer: [
    _FieldRule('layerId', String),
    _FieldRule('width', double),
    _FieldRule('height', double),
  ],
  ActionType.styleUpdate: [
    _FieldRule('layerId', String),
    _FieldRule('styleProps', Map),
  ],
  ActionType.aiCommand: [], // rawText is the payload — validated separately
  ActionType.exportRequest: [
    _FieldRule('format', String),
    _FieldRule('quality', double, required: false),
  ],
  ActionType.undo:            [], // no payload required
  ActionType.redo:            [], // no payload required
  ActionType.templateRequest: [
    _FieldRule('templateId', String),
  ],
  ActionType.unknown: [], // interpreter resolves — no schema enforced here
};

// ==================================================
// COMMAND MAPPER
// Implements CommandMapperInterface (declared in action_router.dart).
// Owns the full ROUTED → MAPPED transition.
// ==================================================

class CommandMapper implements CommandMapperInterface {
  CommandMapper({required IntentionInterpreterInterface interpreter})
      : _interpreter = interpreter;

  final IntentionInterpreterInterface _interpreter;

  // Violation audit log (in-memory).
  final List<_MapperViolationEntry> _violations = [];

  // --------------------------------------------------
  // PUBLIC API  (CommandMapperInterface implementation)
  // --------------------------------------------------

  @override
  Future<void> receive(RoutedCommand command) async {
    _log('[${command.commandId}] Mapper received | state=${command.state}');

    // Guard: only accept commands in ROUTED state.
    if (command.state != CommandState.routed) {
      _recordViolation(
        command.commandId,
        'Expected state ROUTED, got ${command.state}. Command dropped.',
      );
      return;
    }

    final result = _normalise(command);

    switch (result) {
      case _MappingSuccess(:final command):
        _log('[${command.metadata.commandId}] State → MAPPED | '
            'action=${command.normalizedActionType}');
        // Forward to interpreter — mapper's responsibility ends here.
        try {
          await _interpreter.receive(command);
        } catch (e, stack) {
          _recordViolation(
            command.metadata.commandId,
            'IntentionInterpreter threw unexpectedly: $e\n$stack',
          );
          _log('[${command.metadata.commandId}] WARNING — interpreter '
              'error isolated: $e');
        }

      case _MappingFailure(:final reason):
        _recordViolation(command.commandId, 'Mapping failed: $reason');
        _log('[${command.commandId}] DROPPED — $reason');
    }
  }

  /// Read-only access to the violation audit log.
  List<_MapperViolationEntry> get violations => List.unmodifiable(_violations);

  /// Clears in-memory violation log (e.g. on session reset).
  void clearViolations() => _violations.clear();

  // --------------------------------------------------
  // NORMALISATION ENGINE
  // --------------------------------------------------

  _MappingResult _normalise(RoutedCommand routed) {
    final intent   = routed.intent;
    final payload  = intent.payload;
    var   type     = intent.actionType;

    // — Attempt plugin command resolution for ActionType.unknown —
    if (type == ActionType.unknown &&
        intent.source == ActionSource.plugin &&
        payload.containsKey('pluginId')) {
      // Plugin commands stay as unknown type with plugin params extracted.
      return _buildPluginCommand(routed);
    }

    // — Voice / AI unknown: pass through with rawText for interpreter —
    if (type == ActionType.unknown) {
      return _buildUnknownCommand(routed);
    }

    // — Schema validation —
    final schema = _kPayloadSchema[type];
    if (schema == null) {
      return _MappingFailure('No schema registered for ActionType.$type');
    }

    // Special case: aiCommand uses rawText, not payload keys.
    if (type == ActionType.aiCommand) {
      if (intent.rawText == null || intent.rawText!.trim().isEmpty) {
        return _MappingFailure(
            'aiCommand requires non-empty rawText; payload: $payload');
      }
    } else {
      final validationError = _validatePayload(type, payload, schema);
      if (validationError != null) return _MappingFailure(validationError);
    }

    // — Parameter extraction —
    final CommandParams params;
    try {
      params = _extractParams(type, intent);
    } catch (e) {
      return _MappingFailure('Parameter extraction failed for $type: $e');
    }

    final mapped = MappedCommand(
      metadata: _buildMetadata(routed),
      params:   params,
      state:    CommandState.mapped,
      normalizedActionType: type,
    );

    return _MappingSuccess(mapped);
  }

  // --------------------------------------------------
  // PAYLOAD VALIDATION
  // --------------------------------------------------

  String? _validatePayload(
    ActionType          type,
    Map<String, dynamic> payload,
    List<_FieldRule>    schema,
  ) {
    for (final rule in schema) {
      if (!rule.required) continue;

      if (!payload.containsKey(rule.key)) {
        return 'Missing required field "${rule.key}" for ActionType.$type';
      }

      final value = payload[rule.key];
      if (value == null) {
        return 'Field "${rule.key}" is null for ActionType.$type';
      }

      // Numeric coercion: int is acceptable for a double field.
      if (rule.type == double && value is int) continue;

      if (!_isAssignable(value, rule.type)) {
        return 'Field "${rule.key}" expected ${rule.type} '
            'but got ${value.runtimeType} for ActionType.$type';
      }
    }
    return null;
  }

  bool _isAssignable(dynamic value, Type expected) {
    if (expected == String)  return value is String;
    if (expected == double)  return value is double || value is int;
    if (expected == int)     return value is int;
    if (expected == bool)    return value is bool;
    if (expected == Map)     return value is Map;
    if (expected == List)    return value is List;
    return true; // permissive fallback for unregistered types
  }

  // --------------------------------------------------
  // TYPED PARAMETER EXTRACTION
  // --------------------------------------------------

  CommandParams _extractParams(ActionType type, RawIntent intent) {
    final p = intent.payload;

    return switch (type) {
      ActionType.addLayer => AddLayerParams(
          layerType: p['layerType'] as String,
          extra: Map<String, dynamic>.from(
              p..remove('layerType')),
        ),

      ActionType.deleteLayer => DeleteLayerParams(
          layerId: p['layerId'] as String,
        ),

      ActionType.moveLayer => MoveLayerParams(
          layerId: p['layerId'] as String,
          dx:      _toDouble(p['dx']),
          dy:      _toDouble(p['dy']),
        ),

      ActionType.resizeLayer => ResizeLayerParams(
          layerId: p['layerId'] as String,
          width:   _toDouble(p['width']),
          height:  _toDouble(p['height']),
        ),

      ActionType.styleUpdate => StyleUpdateParams(
          layerId:    p['layerId'] as String,
          styleProps: Map<String, dynamic>.from(p['styleProps'] as Map),
        ),

      ActionType.aiCommand => AiCommandParams(
          prompt:  intent.rawText ?? (p['prompt'] as String? ?? ''),
          context: p.containsKey('context')
              ? Map<String, dynamic>.from(p['context'] as Map)
              : const {},
        ),

      ActionType.exportRequest => ExportRequestParams(
          format:  p['format'] as String,
          quality: p.containsKey('quality') ? _toDouble(p['quality']) : null,
          extra:   _stripKeys(p, ['format', 'quality']),
        ),

      ActionType.undo => UndoParams(
          steps: p.containsKey('steps') ? (p['steps'] as int? ?? 1) : 1,
        ),

      ActionType.redo => RedoParams(
          steps: p.containsKey('steps') ? (p['steps'] as int? ?? 1) : 1,
        ),

      ActionType.templateRequest => TemplateRequestParams(
          templateId: p['templateId'] as String,
          extra:      _stripKeys(p, ['templateId']),
        ),

      ActionType.unknown => UnknownParams(
          rawText: intent.rawText,
          payload: Map<String, dynamic>.from(p),
        ),
    };
  }

  // --------------------------------------------------
  // PLUGIN + UNKNOWN COMMAND BUILDERS
  // --------------------------------------------------

  _MappingResult _buildPluginCommand(RoutedCommand routed) {
    final p = routed.intent.payload;

    if (!p.containsKey('pluginId') || !p.containsKey('commandKey')) {
      return _MappingFailure(
          'Plugin command missing "pluginId" or "commandKey" in payload');
    }

    final params = PluginCommandParams(
      pluginId:   p['pluginId'] as String,
      commandKey: p['commandKey'] as String,
      params:     _stripKeys(p, ['pluginId', 'commandKey']),
    );

    return _MappingSuccess(MappedCommand(
      metadata:             _buildMetadata(routed),
      params:               params,
      state:                CommandState.mapped,
      normalizedActionType: ActionType.unknown, // interpreter classifies further
    ));
  }

  _MappingResult _buildUnknownCommand(RoutedCommand routed) {
    final params = UnknownParams(
      rawText: routed.intent.rawText,
      payload: Map<String, dynamic>.from(routed.intent.payload),
    );

    return _MappingSuccess(MappedCommand(
      metadata:             _buildMetadata(routed),
      params:               params,
      state:                CommandState.mapped,
      normalizedActionType: ActionType.unknown,
    ));
  }

  // --------------------------------------------------
  // METADATA BUILDER
  // --------------------------------------------------

  CommandMetadata _buildMetadata(RoutedCommand routed) => CommandMetadata(
        commandId:  routed.commandId,
        source:     routed.intent.source,
        actionType: routed.intent.actionType,
        routedAt:   routed.routedAt,
        mappedAt:   DateTime.now().toUtc(),
        rawText:    routed.intent.rawText,
      );

  // --------------------------------------------------
  // UTILITIES
  // --------------------------------------------------

  double _toDouble(dynamic v) {
    if (v is double) return v;
    if (v is int)    return v.toDouble();
    throw ArgumentError('Cannot coerce ${v.runtimeType} to double: $v');
  }

  /// Returns a copy of [map] with [keys] removed.
  Map<String, dynamic> _stripKeys(
      Map<String, dynamic> map, List<String> keys) {
    final copy = Map<String, dynamic>.from(map);
    for (final k in keys) copy.remove(k);
    return copy;
  }

  void _recordViolation(String commandId, String reason) {
    _violations.add(_MapperViolationEntry(
      commandId: commandId,
      reason:    reason,
      timestamp: DateTime.now().toUtc(),
    ));
  }

  void _log(String message) {
    // ignore: avoid_print
    print('[CommandMapper] $message');
  }
}

// ==================================================
// MAPPER VIOLATION LOG ENTRY
// ==================================================

class _MapperViolationEntry {
  const _MapperViolationEntry({
    required this.commandId,
    required this.reason,
    required this.timestamp,
  });
  final String   commandId;
  final String   reason;
  final DateTime timestamp;
}

// ==================================================
// END OF controllers/command_mapper.dart
// Z-CANVAS — PHASE-13 — STRUCTURE NORMALIZER
// Powered by Zynquar
// ==================================================
