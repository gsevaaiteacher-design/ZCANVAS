// ignore_for_file: avoid_catches_without_on_clauses

import 'dart:math';

// ── Source types ───────────────────────────────────────────────
enum CommandSourceType {
  text,
  voice,
  gesture,
  robotAssistant,
  aiAssistant,
  automation,
  plugin,
  workflow,
  multimodal,
  unknown,
}

// ── Intent types ───────────────────────────────────────────────
enum CommandIntentType {
  addLayer,
  deleteLayer,
  selectLayer,
  moveLayer,
  resizeLayer,
  rotateLayer,
  duplicateLayer,
  showLayer,
  hideLayer,
  lockLayer,
  unlockLayer,
  changeColor,
  changeFont,
  changeOpacity,
  applyTemplate,
  undoAction,
  redoAction,
  saveDesign,
  exportDesign,
  openSettings,
  openLayerPanel,
  clearSelection,
  batchEdit,
  reorderLayers,
  runWorkflow,
  triggerPlugin,
  requestAnalysis,
  requestSuggestion,
  unknown,
}

// ── Command target scope ───────────────────────────────────────
enum CommandTarget {
  selectedLayer,
  specificLayer,
  allLayers,
  visibleLayers,
  lockedLayers,
  design,
  canvas,
  system,
  none,
}

// ── Validation status ─────────────────────────────────────────
enum CommandValidationStatus { valid, invalid, requiresEnrichment }

// ── Gateway processing status ─────────────────────────────────
enum GatewayStatus { accepted, rejected, pendingEnrichment }

// ── Context snapshot supplied by ContextMemoryEngine ─────────
// This is a read-only snapshot — CommandGatewayEngine never writes
// to ContextMemoryEngine directly within this file's scope.
class GatewayContextSnapshot {
  final String? activeDesignId;
  final String? selectedLayerId;
  final String? activeTool;
  final List<String> recentActionTypes;
  final Map<String, dynamic> workflowState;
  final Map<String, dynamic> conversationContext;
  final int layerCount;
  final bool hasUnsavedChanges;

  const GatewayContextSnapshot({
    this.activeDesignId,
    this.selectedLayerId,
    this.activeTool,
    this.recentActionTypes = const [],
    this.workflowState = const {},
    this.conversationContext = const {},
    required this.layerCount,
    required this.hasUnsavedChanges,
  });

  static const GatewayContextSnapshot empty = GatewayContextSnapshot(
    layerCount: 0,
    hasUnsavedChanges: false,
  );
}

// ── CommandRequest — input contract ───────────────────────────
class CommandRequest {
  final String requestId;
  final CommandSourceType sourceType;
  final String rawInput;
  final GatewayContextSnapshot contextSnapshot;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  const CommandRequest({
    required this.requestId,
    required this.sourceType,
    required this.rawInput,
    required this.contextSnapshot,
    required this.timestamp,
    this.metadata = const {},
  });
}

// ── UnifiedEditorCommand — output contract ────────────────────
class UnifiedEditorCommand {
  final String commandId;
  final CommandIntentType intent;
  final CommandTarget target;
  final Map<String, dynamic> parameters;
  final double confidence;
  final CommandSourceType sourceType;
  final Map<String, dynamic> metadata;

  // CONTRACT LAW: A UnifiedEditorCommand is NEVER self-executable.
  // It is a structured data packet waiting for EditorController approval.
  final bool isExecutable;

  // Structural validation stamp — set by validateStructure().
  final CommandValidationStatus validationStatus;
  final List<String> validationWarnings;

  const UnifiedEditorCommand._({
    required this.commandId,
    required this.intent,
    required this.target,
    required this.parameters,
    required this.confidence,
    required this.sourceType,
    required this.metadata,
    required this.validationStatus,
    required this.validationWarnings,
  })  : isExecutable = false;

  factory UnifiedEditorCommand.create({
    required String commandId,
    required CommandIntentType intent,
    required CommandTarget target,
    required Map<String, dynamic> parameters,
    required double confidence,
    required CommandSourceType sourceType,
    required Map<String, dynamic> metadata,
    CommandValidationStatus validationStatus =
        CommandValidationStatus.valid,
    List<String> validationWarnings = const [],
  }) =>
      UnifiedEditorCommand._(
        commandId: commandId,
        intent: intent,
        target: target,
        parameters: Map.unmodifiable(parameters),
        confidence: confidence.clamp(0.0, 100.0),
        sourceType: sourceType,
        metadata: Map.unmodifiable(metadata),
        validationStatus: validationStatus,
        validationWarnings: List.unmodifiable(validationWarnings),
      );

  Map<String, dynamic> toMap() => {
        'commandId': commandId,
        'intent': intent.name,
        'target': target.name,
        'parameters': parameters,
        'confidence': confidence,
        'sourceType': sourceType.name,
        'metadata': metadata,
        'isExecutable': isExecutable,
        'validationStatus': validationStatus.name,
        'validationWarnings': validationWarnings,
      };
}

// ── Gateway result ─────────────────────────────────────────────
class GatewayResult {
  final GatewayStatus status;
  final UnifiedEditorCommand? command;
  final List<String> errors;
  final List<String> warnings;
  final String requestId;
  final DateTime processedAt;

  const GatewayResult._({
    required this.status,
    required this.requestId,
    required this.processedAt,
    this.command,
    this.errors = const [],
    this.warnings = const [],
  });

  factory GatewayResult.accepted(
          String requestId, UnifiedEditorCommand command,
          {List<String> warnings = const []}) =>
      GatewayResult._(
        status: GatewayStatus.accepted,
        requestId: requestId,
        processedAt: DateTime.now().toUtc(),
        command: command,
        warnings: warnings,
      );

  factory GatewayResult.rejected(
          String requestId, List<String> errors,
          {List<String> warnings = const []}) =>
      GatewayResult._(
        status: GatewayStatus.rejected,
        requestId: requestId,
        processedAt: DateTime.now().toUtc(),
        errors: errors,
        warnings: warnings,
      );

  factory GatewayResult.pendingEnrichment(
          String requestId, UnifiedEditorCommand command,
          {List<String> warnings = const []}) =>
      GatewayResult._(
        status: GatewayStatus.pendingEnrichment,
        requestId: requestId,
        processedAt: DateTime.now().toUtc(),
        command: command,
        warnings: warnings,
      );

  bool get isAccepted => status == GatewayStatus.accepted;
  bool get isRejected => status == GatewayStatus.rejected;

  Map<String, dynamic> toMap() => {
        'status': status.name,
        'requestId': requestId,
        'processedAt': processedAt.toIso8601String(),
        'command': command?.toMap(),
        'errors': errors,
        'warnings': warnings,
      };
}

// ── Structure validation result ───────────────────────────────
class StructureValidationResult {
  final CommandValidationStatus status;
  final List<String> errors;
  final List<String> warnings;

  const StructureValidationResult.valid({this.warnings = const []})
      : status = CommandValidationStatus.valid,
        errors = const [];

  const StructureValidationResult.invalid(this.errors,
      {this.warnings = const []})
      : status = CommandValidationStatus.invalid;

  const StructureValidationResult.requiresEnrichment(this.warnings)
      : status = CommandValidationStatus.requiresEnrichment,
        errors = const [];

  bool get isValid => status == CommandValidationStatus.valid;
}

// ── Routing envelope ───────────────────────────────────────────
// CommandGatewayEngine produces this when handing off to EditorController.
// It is a data packet only — it contains no callable references.
class ApprovalRoutingEnvelope {
  final String envelopeId;
  final String commandId;
  final String requestId;
  final UnifiedEditorCommand command;
  final CommandSourceType sourceType;
  final double confidence;
  final DateTime routedAt;

  // GATEWAY LAW: The gateway NEVER approves or rejects.
  // It hands this envelope to EditorController, which holds final authority.
  final bool awaitingEditorControllerDecision;

  const ApprovalRoutingEnvelope._({
    required this.envelopeId,
    required this.commandId,
    required this.requestId,
    required this.command,
    required this.sourceType,
    required this.confidence,
    required this.routedAt,
  }) : awaitingEditorControllerDecision = true;

  Map<String, dynamic> toMap() => {
        'envelopeId': envelopeId,
        'commandId': commandId,
        'requestId': requestId,
        'command': command.toMap(),
        'sourceType': sourceType.name,
        'confidence': confidence,
        'routedAt': routedAt.toIso8601String(),
        'awaitingEditorControllerDecision': awaitingEditorControllerDecision,
      };
}

// ── Normalised input carrier ───────────────────────────────────
class _NormalisedInput {
  final String text;
  final CommandSourceType resolvedSource;
  final Map<String, dynamic> extractedParams;

  const _NormalisedInput({
    required this.text,
    required this.resolvedSource,
    required this.extractedParams,
  });
}

// ── Intent extraction result ───────────────────────────────────
class _IntentResult {
  final CommandIntentType intent;
  final CommandTarget target;
  final double confidence;
  final Map<String, dynamic> params;

  const _IntentResult({
    required this.intent,
    required this.target,
    required this.confidence,
    required this.params,
  });
}

// ── ID generator ──────────────────────────────────────────────
class _CGIdGen {
  static final Random _rng = Random.secure();

  static String next(String prefix) {
    final bytes = List<int>.generate(8, (_) => _rng.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '$prefix-$hex-${DateTime.now().microsecondsSinceEpoch}';
  }
}

// ── Keyword → intent map (no engine references) ───────────────
const Map<String, CommandIntentType> _kIntentKeywords = {
  'add layer':       CommandIntentType.addLayer,
  'new layer':       CommandIntentType.addLayer,
  'create layer':    CommandIntentType.addLayer,
  'delete layer':    CommandIntentType.deleteLayer,
  'remove layer':    CommandIntentType.deleteLayer,
  'select':          CommandIntentType.selectLayer,
  'move':            CommandIntentType.moveLayer,
  'drag':            CommandIntentType.moveLayer,
  'resize':          CommandIntentType.resizeLayer,
  'scale':           CommandIntentType.resizeLayer,
  'rotate':          CommandIntentType.rotateLayer,
  'turn':            CommandIntentType.rotateLayer,
  'duplicate':       CommandIntentType.duplicateLayer,
  'copy':            CommandIntentType.duplicateLayer,
  'show layer':      CommandIntentType.showLayer,
  'unhide':          CommandIntentType.showLayer,
  'hide layer':      CommandIntentType.hideLayer,
  'hide':            CommandIntentType.hideLayer,
  'lock layer':      CommandIntentType.lockLayer,
  'lock':            CommandIntentType.lockLayer,
  'unlock layer':    CommandIntentType.unlockLayer,
  'unlock':          CommandIntentType.unlockLayer,
  'change color':    CommandIntentType.changeColor,
  'change colour':   CommandIntentType.changeColor,
  'color':           CommandIntentType.changeColor,
  'colour':          CommandIntentType.changeColor,
  'change font':     CommandIntentType.changeFont,
  'font':            CommandIntentType.changeFont,
  'opacity':         CommandIntentType.changeOpacity,
  'transparency':    CommandIntentType.changeOpacity,
  'apply template':  CommandIntentType.applyTemplate,
  'template':        CommandIntentType.applyTemplate,
  'undo':            CommandIntentType.undoAction,
  'go back':         CommandIntentType.undoAction,
  'redo':            CommandIntentType.redoAction,
  'save':            CommandIntentType.saveDesign,
  'export':          CommandIntentType.exportDesign,
  'settings':        CommandIntentType.openSettings,
  'layers panel':    CommandIntentType.openLayerPanel,
  'layer panel':     CommandIntentType.openLayerPanel,
  'deselect':        CommandIntentType.clearSelection,
  'clear selection': CommandIntentType.clearSelection,
  'batch':           CommandIntentType.batchEdit,
  'reorder':         CommandIntentType.reorderLayers,
  'workflow':        CommandIntentType.runWorkflow,
  'run workflow':    CommandIntentType.runWorkflow,
  'plugin':          CommandIntentType.triggerPlugin,
  'run plugin':      CommandIntentType.triggerPlugin,
  'analyse':         CommandIntentType.requestAnalysis,
  'analyze':         CommandIntentType.requestAnalysis,
  'insight':         CommandIntentType.requestAnalysis,
  'suggest':         CommandIntentType.requestSuggestion,
  'suggestion':      CommandIntentType.requestSuggestion,
};

// ── Gesture pattern → intent map ──────────────────────────────
const Map<String, CommandIntentType> _kGestureIntents = {
  'swipe_up':           CommandIntentType.addLayer,
  'swipe_down':         CommandIntentType.deleteLayer,
  'swipe_left':         CommandIntentType.undoAction,
  'swipe_right':        CommandIntentType.redoAction,
  'pinch_in':           CommandIntentType.resizeLayer,
  'pinch_out':          CommandIntentType.resizeLayer,
  'two_finger_tap':     CommandIntentType.selectLayer,
  'long_press':         CommandIntentType.openLayerPanel,
  'rotate_gesture':     CommandIntentType.rotateLayer,
  'double_tap':         CommandIntentType.duplicateLayer,
  'three_finger_swipe': CommandIntentType.batchEdit,
  'tap':                CommandIntentType.selectLayer,
};

// ── Target resolution map ─────────────────────────────────────
const Map<CommandIntentType, CommandTarget> _kIntentTargets = {
  CommandIntentType.addLayer:        CommandTarget.design,
  CommandIntentType.deleteLayer:     CommandTarget.selectedLayer,
  CommandIntentType.selectLayer:     CommandTarget.specificLayer,
  CommandIntentType.moveLayer:       CommandTarget.selectedLayer,
  CommandIntentType.resizeLayer:     CommandTarget.selectedLayer,
  CommandIntentType.rotateLayer:     CommandTarget.selectedLayer,
  CommandIntentType.duplicateLayer:  CommandTarget.selectedLayer,
  CommandIntentType.showLayer:       CommandTarget.selectedLayer,
  CommandIntentType.hideLayer:       CommandTarget.selectedLayer,
  CommandIntentType.lockLayer:       CommandTarget.selectedLayer,
  CommandIntentType.unlockLayer:     CommandTarget.selectedLayer,
  CommandIntentType.changeColor:     CommandTarget.selectedLayer,
  CommandIntentType.changeFont:      CommandTarget.selectedLayer,
  CommandIntentType.changeOpacity:   CommandTarget.selectedLayer,
  CommandIntentType.applyTemplate:   CommandTarget.design,
  CommandIntentType.undoAction:      CommandTarget.system,
  CommandIntentType.redoAction:      CommandTarget.system,
  CommandIntentType.saveDesign:      CommandTarget.design,
  CommandIntentType.exportDesign:    CommandTarget.design,
  CommandIntentType.openSettings:    CommandTarget.system,
  CommandIntentType.openLayerPanel:  CommandTarget.system,
  CommandIntentType.clearSelection:  CommandTarget.system,
  CommandIntentType.batchEdit:       CommandTarget.allLayers,
  CommandIntentType.reorderLayers:   CommandTarget.allLayers,
  CommandIntentType.runWorkflow:     CommandTarget.system,
  CommandIntentType.triggerPlugin:   CommandTarget.system,
  CommandIntentType.requestAnalysis: CommandTarget.design,
  CommandIntentType.requestSuggestion: CommandTarget.design,
  CommandIntentType.unknown:         CommandTarget.none,
};

// ── Forbidden metadata keys ────────────────────────────────────
const _kForbiddenKeys = {
  'layerengine', 'historyengine', 'renderengine',
  'storageengine', 'exportengine', 'canvas',
  'buildcontext', 'widget', 'aiengine',
};

// ══════════════════════════════════════════════════════════════
// CommandGatewayEngine
// ══════════════════════════════════════════════════════════════
class CommandGatewayEngine {
  // History of processed command IDs for the session (no persistence).
  final List<String> _sessionCommandLog = [];

  // ── receiveInput ───────────────────────────────────────────────

  GatewayResult receiveInput(CommandRequest request) {
    try {
      // 1. Basic request guard.
      final requestErrors = _guardRequest(request);
      if (requestErrors.isNotEmpty) {
        return GatewayResult.rejected(request.requestId, requestErrors);
      }

      // 2. Detect authoritative source.
      final source = detectSource(request);

      // 3. Normalise raw input.
      final normalised = normalizeInput(request, source);

      // 4. Extract intent and build parameter set.
      final intentResult = _extractIntent(normalised, request.contextSnapshot);

      // 5. Attach context enrichment.
      final enrichedParams = attachContext(
          intentResult.params, request.contextSnapshot, source);

      // 6. Assemble metadata.
      final commandMeta = _buildMetadata(request, source, intentResult);

      // 7. Build the unified command.
      final commandId = _CGIdGen.next('cmd');
      final draft = UnifiedEditorCommand.create(
        commandId: commandId,
        intent: intentResult.intent,
        target: intentResult.target,
        parameters: enrichedParams,
        confidence: intentResult.confidence,
        sourceType: source,
        metadata: commandMeta,
      );

      // 8. Validate structure.
      final validation = validateStructure(draft);
      if (validation.status == CommandValidationStatus.invalid) {
        return GatewayResult.rejected(
            request.requestId, validation.errors,
            warnings: validation.warnings);
      }

      // 9. Stamp validation result onto final command.
      final command = UnifiedEditorCommand.create(
        commandId: draft.commandId,
        intent: draft.intent,
        target: draft.target,
        parameters: draft.parameters,
        confidence: draft.confidence,
        sourceType: draft.sourceType,
        metadata: draft.metadata,
        validationStatus: validation.status,
        validationWarnings: validation.warnings,
      );

      // 10. Log to session (no persistence).
      _sessionCommandLog.add(commandId);

      // 11. Route for approval.
      routeForApproval(command, request.requestId);

      // 12. Return result — note: no approval decision is made here.
      if (validation.status == CommandValidationStatus.requiresEnrichment) {
        return GatewayResult.pendingEnrichment(
            request.requestId, command,
            warnings: validation.warnings);
      }

      final resultWarnings = <String>[];
      if (intentResult.confidence < 50.0) {
        resultWarnings.add(
            'Low confidence (${intentResult.confidence.toStringAsFixed(1)}) — '
            'EditorController should request user confirmation.');
      }

      return GatewayResult.accepted(request.requestId, command,
          warnings: resultWarnings);
    } catch (e) {
      return GatewayResult.rejected(
          request.requestId, ['receiveInput threw: $e']);
    }
  }

  // ── detectSource ───────────────────────────────────────────────

  CommandSourceType detectSource(CommandRequest request) {
    // Explicit declaration wins.
    if (request.sourceType != CommandSourceType.unknown) {
      return request.sourceType;
    }

    final raw = request.rawInput.trim().toLowerCase();
    final meta = request.metadata;

    // Metadata hint.
    final metaSource = meta['sourceType']?.toString().toLowerCase();
    if (metaSource != null) {
      for (final v in CommandSourceType.values) {
        if (v.name.toLowerCase() == metaSource) return v;
      }
    }

    // Prefix heuristics.
    if (raw.startsWith('robot:') || raw.startsWith('bot:')) {
      return CommandSourceType.robotAssistant;
    }
    if (raw.startsWith('auto:') || raw.startsWith('workflow:')) {
      return CommandSourceType.automation;
    }
    if (raw.startsWith('plugin:')) return CommandSourceType.plugin;
    if (raw.startsWith('ai:')) return CommandSourceType.aiAssistant;

    // Gesture pattern.
    if (_kGestureIntents.keys.any((k) => raw.contains(k))) {
      return CommandSourceType.gesture;
    }

    // Voice starters.
    const voiceStarters = [
      'hey ', 'please ', 'can you ', 'could you ', 'i want ', 'i need ',
    ];
    if (voiceStarters.any((s) => raw.startsWith(s))) {
      return CommandSourceType.voice;
    }

    // Multimodal: both gesture and text signals present.
    final hasGesture = meta.containsKey('gesturePayload');
    final hasText = meta.containsKey('textPayload');
    if (hasGesture && hasText) return CommandSourceType.multimodal;

    return CommandSourceType.text;
  }

  // ── normalizeInput ─────────────────────────────────────────────

  _NormalisedInput normalizeInput(
      CommandRequest request, CommandSourceType source) {
    var raw = request.rawInput.trim();
    final params = <String, dynamic>{};

    switch (source) {
      case CommandSourceType.voice:
        raw = _normaliseVoice(raw);
        params['inputMode'] = 'voice';
        break;

      case CommandSourceType.gesture:
        raw = _normaliseGesture(raw);
        params['inputMode'] = 'gesture';
        break;

      case CommandSourceType.robotAssistant:
        raw = raw.replaceFirst(RegExp(r'^(robot:|bot:)\s*',
            caseSensitive: false), '').trim().toLowerCase();
        params['inputMode'] = 'robot';
        params['robotSource'] = true;
        break;

      case CommandSourceType.automation:
        raw = raw.replaceFirst(
            RegExp(r'^(auto:|workflow:)\s*', caseSensitive: false),
            '').trim().toLowerCase();
        params['inputMode'] = 'automation';
        break;

      case CommandSourceType.plugin:
        raw = raw.replaceFirst(
            RegExp(r'^plugin:\s*', caseSensitive: false),
            '').trim().toLowerCase();
        params['inputMode'] = 'plugin';
        break;

      case CommandSourceType.aiAssistant:
        raw = raw.replaceFirst(
            RegExp(r'^ai:\s*', caseSensitive: false),
            '').trim().toLowerCase();
        params['inputMode'] = 'ai';
        break;

      case CommandSourceType.multimodal:
        final textPart = (request.metadata['textPayload'] as String?) ?? raw;
        final gesturePart =
            (request.metadata['gesturePayload'] as String?) ?? '';
        raw = '${_normaliseText(textPart)} ${_normaliseGesture(gesturePart)}'
            .trim();
        params['inputMode'] = 'multimodal';
        break;

      case CommandSourceType.text:
      case CommandSourceType.unknown:
        raw = _normaliseText(raw);
        params['inputMode'] = 'text';
        break;
    }

    // Extract numeric values.
    final num = RegExp(r'\b(\d+(?:\.\d+)?)\b').firstMatch(raw);
    if (num != null) {
      params['numericValue'] = double.tryParse(num.group(1)!);
    }

    // Extract colour hints.
    const colours = [
      'red', 'blue', 'green', 'yellow', 'black', 'white',
      'orange', 'purple', 'pink', 'grey', 'gray', 'brown', 'cyan',
    ];
    for (final c in colours) {
      if (raw.contains(c)) {
        params['colorHint'] = c;
        break;
      }
    }

    return _NormalisedInput(
      text: raw,
      resolvedSource: source,
      extractedParams: params,
    );
  }

  // ── attachContext ──────────────────────────────────────────────

  Map<String, dynamic> attachContext(
      Map<String, dynamic> params,
      GatewayContextSnapshot context,
      CommandSourceType source) {
    final enriched = Map<String, dynamic>.from(params);

    if (context.activeDesignId != null) {
      enriched['contextDesignId'] = context.activeDesignId;
    }
    if (context.selectedLayerId != null) {
      enriched['contextSelectedLayerId'] = context.selectedLayerId;
    }
    if (context.activeTool != null) {
      enriched['contextActiveTool'] = context.activeTool;
    }
    enriched['contextLayerCount'] = context.layerCount;
    enriched['contextHasUnsavedChanges'] = context.hasUnsavedChanges;
    enriched['commandSource'] = source.name;

    if (context.workflowState.isNotEmpty &&
        source == CommandSourceType.automation) {
      enriched['workflowContext'] = Map<String, dynamic>.unmodifiable(
          context.workflowState);
    }
    if (context.conversationContext.isNotEmpty &&
        (source == CommandSourceType.voice ||
            source == CommandSourceType.robotAssistant ||
            source == CommandSourceType.aiAssistant)) {
      enriched['conversationContext'] = Map<String, dynamic>.unmodifiable(
          context.conversationContext);
    }

    return _sanitiseParams(enriched);
  }

  // ── validateStructure ─────────────────────────────────────────

  StructureValidationResult validateStructure(UnifiedEditorCommand command) {
    final errors = <String>[];
    final warnings = <String>[];

    if (command.commandId.trim().isEmpty) {
      errors.add('UnifiedEditorCommand.commandId must not be empty.');
    }

    if (command.isExecutable) {
      errors.add(
          'UnifiedEditorCommand.isExecutable is true — Phase-8 contract '
          'violation. Commands must never be self-executable.');
    }

    if (command.confidence < 0.0 || command.confidence > 100.0) {
      errors.add(
          'UnifiedEditorCommand.confidence ${command.confidence} '
          'is outside [0, 100].');
    }

    // Forbidden parameter keys.
    for (final key in command.parameters.keys) {
      if (_kForbiddenKeys.contains(key.toLowerCase())) {
        errors.add(
            'Parameter key "$key" references a forbidden engine or '
            'context object — Phase-8 forbidden connection violation.');
      }
    }
    for (final key in command.metadata.keys) {
      if (_kForbiddenKeys.contains(key.toLowerCase())) {
        errors.add(
            'Metadata key "$key" references a forbidden engine or '
            'context object.');
      }
    }

    if (errors.isNotEmpty) {
      return StructureValidationResult.invalid(errors, warnings: warnings);
    }

    // Enrichment flags — intent unknown or very low confidence.
    if (command.intent == CommandIntentType.unknown) {
      warnings.add(
          'Intent is unknown — EditorController should prompt user '
          'for clarification before proceeding.');
      return StructureValidationResult.requiresEnrichment(warnings);
    }
    if (command.confidence < 30.0) {
      warnings.add(
          'Confidence ${command.confidence.toStringAsFixed(1)} is '
          'very low — EditorController may require explicit confirmation.');
      return StructureValidationResult.requiresEnrichment(warnings);
    }

    return StructureValidationResult.valid(warnings: warnings);
  }

  // ── buildUnifiedCommand ────────────────────────────────────────

  UnifiedEditorCommand buildUnifiedCommand({
    required CommandIntentType intent,
    required CommandTarget target,
    required Map<String, dynamic> parameters,
    required double confidence,
    required CommandSourceType sourceType,
    required Map<String, dynamic> metadata,
    CommandValidationStatus validationStatus =
        CommandValidationStatus.valid,
    List<String> validationWarnings = const [],
  }) {
    return UnifiedEditorCommand.create(
      commandId: _CGIdGen.next('cmd'),
      intent: intent,
      target: target,
      parameters: _sanitiseParams(parameters),
      confidence: confidence,
      sourceType: sourceType,
      metadata: _sanitiseMeta(metadata),
      validationStatus: validationStatus,
      validationWarnings: validationWarnings,
    );
  }

  // ── routeForApproval ──────────────────────────────────────────

  ApprovalRoutingEnvelope routeForApproval(
      UnifiedEditorCommand command, String requestId) {
    // The gateway packages the command into an envelope and hands it off.
    // It does NOT approve, does NOT reject, does NOT execute.
    // All authority belongs to EditorController.
    return ApprovalRoutingEnvelope._(
      envelopeId: _CGIdGen.next('env'),
      commandId: command.commandId,
      requestId: requestId,
      command: command,
      sourceType: command.sourceType,
      confidence: command.confidence,
      routedAt: DateTime.now().toUtc(),
    );
  }

  // ── Session log query (read-only) ──────────────────────────────

  List<String> get sessionCommandLog =>
      List.unmodifiable(_sessionCommandLog);

  int get sessionCommandCount => _sessionCommandLog.length;

  // ── Private helpers ───────────────────────────────────────────

  _IntentResult _extractIntent(
      _NormalisedInput normalised,
      GatewayContextSnapshot context) {
    final text = normalised.text;
    final params = Map<String, dynamic>.from(normalised.extractedParams);
    final source = normalised.resolvedSource;

    CommandIntentType matched = CommandIntentType.unknown;
    double confidence = 25.0;
    int bestLen = 0;

    // Gesture source — check gesture map first.
    if (source == CommandSourceType.gesture) {
      for (final entry in _kGestureIntents.entries) {
        if (text.contains(entry.key) && entry.key.length > bestLen) {
          matched = entry.value;
          bestLen = entry.key.length;
          confidence = 78.0;
        }
      }
    }

    // Keyword scan across all sources.
    for (final entry in _kIntentKeywords.entries) {
      if (text.contains(entry.key) && entry.key.length > bestLen) {
        matched = entry.value;
        bestLen = entry.key.length;
        // Robot / AI / automation payloads are more explicit.
        confidence = switch (source) {
          CommandSourceType.robotAssistant  => 88.0,
          CommandSourceType.aiAssistant     => 86.0,
          CommandSourceType.automation      => 84.0,
          CommandSourceType.plugin          => 82.0,
          CommandSourceType.workflow => 82.0,
          _ => bestLen > 10 ? 80.0 : bestLen > 5 ? 68.0 : 55.0,
        };
      }
    }

    // Context boosts: if selectedLayer exists and intent targets a layer, bump.
    if (context.selectedLayerId != null &&
        matched != CommandIntentType.unknown) {
      final target = _kIntentTargets[matched];
      if (target == CommandTarget.selectedLayer) confidence += 6.0;
    }

    final finalTarget =
        _kIntentTargets[matched] ?? CommandTarget.none;

    return _IntentResult(
      intent: matched,
      target: finalTarget,
      confidence: confidence.clamp(0.0, 100.0),
      params: params,
    );
  }

  Map<String, dynamic> _buildMetadata(
      CommandRequest request,
      CommandSourceType source,
      _IntentResult intent) {
    final raw = <String, dynamic>{
      'requestId': request.requestId,
      'sourceType': source.name,
      'rawInputLength': request.rawInput.length,
      'timestamp': request.timestamp.toIso8601String(),
      'sessionCommandCount': _sessionCommandLog.length,
      'extractedIntent': intent.intent.name,
      'extractedTarget': intent.target.name,
      'confidence': intent.confidence,
    };

    // Merge caller-supplied metadata, excluding forbidden keys.
    for (final entry in request.metadata.entries) {
      if (!_kForbiddenKeys.contains(entry.key.toLowerCase())) {
        raw[entry.key] = entry.value;
      }
    }

    return raw;
  }

  List<String> _guardRequest(CommandRequest request) {
    final errors = <String>[];
    if (request.requestId.trim().isEmpty) {
      errors.add('CommandRequest.requestId must not be empty.');
    }
    if (request.rawInput.trim().isEmpty) {
      errors.add('CommandRequest.rawInput must not be empty.');
    }
    for (final key in request.metadata.keys) {
      if (_kForbiddenKeys.contains(key.toLowerCase())) {
        errors.add(
            'CommandRequest.metadata key "$key" references a forbidden '
            'engine or context object.');
      }
    }
    return errors;
  }

  // ── Text normalisers ───────────────────────────────────────────

  String _normaliseText(String raw) =>
      raw.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  String _normaliseVoice(String raw) {
    var text = raw.trim().toLowerCase();
    const fillers = [
      'um ', 'uh ', 'like ', 'you know ', 'basically ',
      'actually ', 'just ', 'please ', 'hey ', 'okay ', 'so ',
    ];
    for (final f in fillers) {
      text = text.replaceAll(f, ' ');
    }
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _normaliseGesture(String raw) =>
      raw.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');

  // ── Sanitisers ─────────────────────────────────────────────────

  Map<String, dynamic> _sanitiseParams(Map<String, dynamic> raw) {
    final result = <String, dynamic>{};
    for (final entry in raw.entries) {
      if (_kForbiddenKeys.contains(entry.key.toLowerCase())) continue;
      final v = entry.value;
      final safe = v == null ||
          v is num ||
          v is String ||
          v is bool ||
          (v is List && v.every((e) => e is num || e is String || e is bool)) ||
          v is Map<String, dynamic>;
      if (safe) result[entry.key] = v;
    }
    return result;
  }

  Map<String, dynamic> _sanitiseMeta(Map<String, dynamic> raw) =>
      _sanitiseParams(raw);
}
