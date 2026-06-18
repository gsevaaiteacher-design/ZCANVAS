// ==================================================
// Z-CANVAS — PHASE-13 ACTION BINDING & EXECUTION SYSTEM
// controllers/intention_interpreter.dart
//
// PRIMARY ROLE: SEMANTIC ENGINE (MEANING LAYER)
//
// OWNS:
//   ✔ Analyze user intent semantically
//   ✔ Detect / confirm action type (add/edit/delete/export/AI/…)
//   ✔ Extract semantic parameters (text, color, layerId, settings)
//   ✔ Resolve unknown intents from rawText (voice / AI input)
//   ✔ Assign per-intent confidence score (0.0 – 1.0)
//   ✔ Advance lifecycle: MAPPED → INTERPRETED
//   ✔ Forward InterpretedCommand to ExecutionBridgeInterface
//
// DOES NOT OWN:
//   ❌ Execution  ❌ Engine calls  ❌ State mutation
//   ❌ Canvas / layer / storage access  ❌ Business logic decisions
// ==================================================

import 'dart:async';
import 'action_router.dart';
import 'command_mapper.dart';

// ==================================================
// CONFIDENCE THRESHOLDS
// Scores below MINIMUM are dropped as unresolvable.
// Scores between MINIMUM and HIGH are forwarded with a LOW flag.
// ==================================================

class ZConfidence {
  ZConfidence._();

  /// Drop threshold — anything below this is too ambiguous to proceed.
  static const double minimum = 0.35;

  /// Threshold above which the bridge treats the command as high-confidence.
  static const double high = 0.80;

  /// Exact structural match — mapper already confirmed the type.
  static const double certain = 1.00;

  /// Well-matched voice/AI keyword hit.
  static const double strong = 0.90;

  /// Reasonable keyword match with minor ambiguity.
  static const double moderate = 0.70;

  /// Weak match — one or two keyword signals but uncertain.
  static const double weak = 0.45;

  /// Completely unresolvable from available signals.
  static const double unresolvable = 0.00;
}

// ==================================================
// INTENT CONFIDENCE BAND
// Categorical label derived from the numeric score.
// Used by ExecutionBridge for fast branching without re-computing thresholds.
// ==================================================

enum ConfidenceBand { certain, high, moderate, low, unresolvable }

ConfidenceBand _bandFor(double score) {
  if (score >= ZConfidence.certain) return ConfidenceBand.certain;
  if (score >= ZConfidence.high)    return ConfidenceBand.high;
  if (score >= ZConfidence.moderate) return ConfidenceBand.moderate;
  if (score >= ZConfidence.minimum) return ConfidenceBand.low;
  return ConfidenceBand.unresolvable;
}

// ==================================================
// SEMANTIC ENRICHMENT
// Additional meaning extracted on top of the typed CommandParams.
// Carries interpreter-derived fields the bridge or controller may use
// as hints — never as mandatory inputs.
// ==================================================

class SemanticEnrichment {
  const SemanticEnrichment({
    this.inferredLayerKind,
    this.inferredColor,
    this.inferredText,
    this.inferredFontSize,
    this.inferredExportFormat,
    this.mentionedLayerIds = const [],
    this.detectedLocale,
    this.rawTokens         = const [],
    this.notes             = const [],
  });

  /// e.g. 'text' | 'image' | 'shape' | 'group' — inferred from layerType string.
  final String? inferredLayerKind;

  /// Hex or CSS colour string parsed from rawText.
  final String? inferredColor;

  /// Verbatim text content to apply (e.g. from "add text hello world").
  final String? inferredText;

  /// Font size inferred from phrases like "size 24" or "big text".
  final double? inferredFontSize;

  /// Export format hint extracted from phrases like "save as PDF".
  final String? inferredExportFormat;

  /// Layer IDs explicitly mentioned in the raw text.
  final List<String> mentionedLayerIds;

  /// BCP 47 language tag detected in the raw text.
  final String? detectedLocale;

  /// Lowercased, punctuation-stripped tokens from rawText.
  final List<String> rawTokens;

  /// Human-readable notes from the interpreter (for debug / audit).
  final List<String> notes;

  SemanticEnrichment copyWith({
    String?       inferredLayerKind,
    String?       inferredColor,
    String?       inferredText,
    double?       inferredFontSize,
    String?       inferredExportFormat,
    List<String>? mentionedLayerIds,
    String?       detectedLocale,
    List<String>? rawTokens,
    List<String>? notes,
  }) =>
      SemanticEnrichment(
        inferredLayerKind:    inferredLayerKind    ?? this.inferredLayerKind,
        inferredColor:        inferredColor        ?? this.inferredColor,
        inferredText:         inferredText         ?? this.inferredText,
        inferredFontSize:     inferredFontSize     ?? this.inferredFontSize,
        inferredExportFormat: inferredExportFormat ?? this.inferredExportFormat,
        mentionedLayerIds:    mentionedLayerIds    ?? this.mentionedLayerIds,
        detectedLocale:       detectedLocale       ?? this.detectedLocale,
        rawTokens:            rawTokens            ?? this.rawTokens,
        notes:                notes                ?? this.notes,
      );
}

// ==================================================
// INTERPRETED INTENT
// The conclusion of the semantic analysis pass.
// ==================================================

class InterpretedIntent {
  const InterpretedIntent({
    required this.resolvedActionType,
    required this.confidence,
    required this.band,
    required this.enrichment,
    this.interpretationNotes = const [],
  });

  /// Action type after semantic analysis.
  /// For already-typed commands this echoes [MappedCommand.normalizedActionType].
  /// For unknown/voice commands this is the interpreter's best resolution.
  final ActionType resolvedActionType;

  /// Numeric confidence — 0.0 (none) to 1.0 (certain).
  final double confidence;

  /// Categorical band derived from [confidence].
  final ConfidenceBand band;

  /// Additional meaning extracted from the input.
  final SemanticEnrichment enrichment;

  /// Ordered audit trail of reasoning steps.
  final List<String> interpretationNotes;

  @override
  String toString() =>
      'InterpretedIntent(action: $resolvedActionType, '
      'confidence: ${confidence.toStringAsFixed(2)}, band: $band)';
}

// ==================================================
// INTERPRETED COMMAND
// Produced by IntentionInterpreter; lifecycle state = INTERPRETED.
// Carries the full upstream chain plus the semantic analysis result.
// ==================================================

class InterpretedCommand {
  const InterpretedCommand({
    required this.source,
    required this.intent,
    required this.state,
    required this.interpretedAt,
  });

  /// The MappedCommand from FILE-2 (provenance preserved).
  final MappedCommand source;

  /// Semantic analysis result.
  final InterpretedIntent intent;

  /// Always [CommandState.interpreted] when leaving this file.
  final CommandState state;

  /// UTC timestamp of the interpretation pass.
  final DateTime interpretedAt;

  /// Convenience pass-through to the stable metadata.
  CommandMetadata get metadata => source.metadata;

  /// Typed parameters from the mapper (unchanged).
  CommandParams get params => source.params;

  InterpretedCommand copyWith({CommandState? state}) => InterpretedCommand(
        source:         source,
        intent:         intent,
        state:          state ?? this.state,
        interpretedAt:  interpretedAt,
      );

  @override
  String toString() =>
      'InterpretedCommand(id: ${metadata.commandId}, '
      'action: ${intent.resolvedActionType}, '
      'confidence: ${intent.confidence.toStringAsFixed(2)}, '
      'state: $state)';
}

// ==================================================
// EXECUTION BRIDGE INTERFACE
// Forward boundary contract — concrete implementation in FILE-4.
// Interpreter depends only on this interface.
// ==================================================

abstract interface class ExecutionBridgeInterface {
  /// Receives an [InterpretedCommand] in state [CommandState.interpreted]
  /// and advances it through VALIDATED → APPROVED → DISPATCHED.
  Future<void> receive(InterpretedCommand command);
}

// ==================================================
// INTERPRETATION RESULT
// Internal value returned by each semantic analysis pass.
// ==================================================

sealed class _InterpretResult {}

final class _InterpretSuccess extends _InterpretResult {
  _InterpretSuccess(this.command);
  final InterpretedCommand command;
}

final class _InterpretFailure extends _InterpretResult {
  _InterpretFailure(this.reason);
  final String reason;
}

// ==================================================
// KEYWORD RESOLUTION TABLE
// Maps action types to ranked keyword groups.
// Higher-weight groups contribute more to the confidence score.
// Used exclusively for rawText resolution — no execution triggered.
// ==================================================

class _KeywordGroup {
  const _KeywordGroup(this.keywords, {required this.weight});
  final List<String> keywords;
  final double       weight; // 0.0 – 1.0
}

const Map<ActionType, List<_KeywordGroup>> _kKeywordTable = {
  ActionType.addLayer: [
    _KeywordGroup(['add', 'insert', 'create', 'new', 'place'],  weight: 0.50),
    _KeywordGroup(['layer', 'element', 'object', 'item'],        weight: 0.30),
    _KeywordGroup(['text', 'image', 'shape', 'box', 'circle',
                   'rect', 'rectangle', 'photo', 'sticker'],     weight: 0.20),
  ],
  ActionType.deleteLayer: [
    _KeywordGroup(['delete', 'remove', 'erase', 'clear', 'drop',
                   'trash', 'destroy'],                          weight: 0.70),
    _KeywordGroup(['layer', 'element', 'object', 'this', 'it'],  weight: 0.30),
  ],
  ActionType.moveLayer: [
    _KeywordGroup(['move', 'drag', 'shift', 'reposition',
                   'translate', 'relocate'],                     weight: 0.60),
    _KeywordGroup(['left', 'right', 'up', 'down', 'to', 'by'],  weight: 0.40),
  ],
  ActionType.resizeLayer: [
    _KeywordGroup(['resize', 'scale', 'bigger', 'smaller',
                   'larger', 'shrink', 'grow', 'size'],          weight: 0.60),
    _KeywordGroup(['width', 'height', 'dimension', 'px', 'pixels',
                   'percent', '%'],                              weight: 0.40),
  ],
  ActionType.styleUpdate: [
    _KeywordGroup(['style', 'color', 'colour', 'font', 'opacity',
                   'bold', 'italic', 'underline', 'fill',
                   'border', 'shadow', 'gradient'],              weight: 0.55),
    _KeywordGroup(['change', 'update', 'set', 'make', 'apply'],  weight: 0.30),
    _KeywordGroup(['red', 'blue', 'green', 'black', 'white',
                   'yellow', 'purple', '#'],                     weight: 0.15),
  ],
  ActionType.aiCommand: [
    _KeywordGroup(['generate', 'suggest', 'ai', 'copilot',
                   'automate', 'design', 'help me', 'create for me',
                   'write', 'compose', 'imagine'],               weight: 0.70),
    _KeywordGroup(['layout', 'poster', 'banner', 'template',
                   'theme', 'idea'],                             weight: 0.30),
  ],
  ActionType.exportRequest: [
    _KeywordGroup(['export', 'save', 'download', 'share',
                   'publish', 'render'],                         weight: 0.60),
    _KeywordGroup(['png', 'pdf', 'svg', 'jpg', 'jpeg',
                   'file', 'image', 'document'],                 weight: 0.40),
  ],
  ActionType.undo: [
    _KeywordGroup(['undo', 'revert', 'go back', 'undo last',
                   'ctrl z', 'take back'],                       weight: 1.00),
  ],
  ActionType.redo: [
    _KeywordGroup(['redo', 'reapply', 'redo last', 'ctrl y',
                   'ctrl shift z', 'repeat'],                    weight: 1.00),
  ],
  ActionType.templateRequest: [
    _KeywordGroup(['template', 'preset', 'layout', 'theme',
                   'starting point', 'use template'],            weight: 0.70),
    _KeywordGroup(['apply', 'load', 'open', 'choose', 'pick'],   weight: 0.30),
  ],
};

// ==================================================
// COLOUR PATTERN REGISTRY
// Minimal hex / named-colour extraction from raw text.
// ==================================================

final _hexColorRegex       = RegExp(r'#([0-9a-fA-F]{6}|[0-9a-fA-F]{3})');
final _namedColorRegex     = RegExp(
    r'\b(red|blue|green|black|white|yellow|purple|orange|pink|grey|gray|'
    r'cyan|magenta|brown|gold|silver|transparent)\b',
    caseSensitive: false);

// ==================================================
// NUMBER PATTERN REGISTRY
// ==================================================

final _numberRegex         = RegExp(r'\b(\d+(?:\.\d+)?)\b');
final _fontSizeRegex       = RegExp(r'\b(?:size|font size|pt|px)\s*(\d+(?:\.\d+)?)',
    caseSensitive: false);

// ==================================================
// EXPORT FORMAT PATTERN
// ==================================================

final _exportFormatRegex   = RegExp(
    r'\b(png|pdf|svg|jpg|jpeg|webp|gif)\b',
    caseSensitive: false);

// ==================================================
// LAYER ID PATTERN
// Matches router-generated IDs of the form ZC-??-…
// ==================================================

final _layerIdRegex        = RegExp(r'\bZC-[A-Z]{2}-\d{8}_\d{6}_\d{3}-\d{6}\b');

// ==================================================
// INTENTION INTERPRETER
// Implements IntentionInterpreterInterface (declared in command_mapper.dart).
// Owns the full MAPPED → INTERPRETED transition.
// ==================================================

class IntentionInterpreter implements IntentionInterpreterInterface {
  IntentionInterpreter({required ExecutionBridgeInterface bridge})
      : _bridge = bridge;

  final ExecutionBridgeInterface _bridge;

  final List<_InterpreterViolationEntry> _violations = [];

  // --------------------------------------------------
  // PUBLIC API  (IntentionInterpreterInterface)
  // --------------------------------------------------

  @override
  Future<void> receive(MappedCommand command) async {
    _log('[${command.metadata.commandId}] Interpreter received | '
        'state=${command.state} action=${command.normalizedActionType}');

    // Guard: only accept commands in MAPPED state.
    if (command.state != CommandState.mapped) {
      _recordViolation(
        command.metadata.commandId,
        'Expected state MAPPED, got ${command.state}. Command dropped.',
      );
      return;
    }

    final result = _interpret(command);

    switch (result) {
      case _InterpretSuccess(:final command):
        _log('[${command.metadata.commandId}] State → INTERPRETED | '
            'action=${command.intent.resolvedActionType} '
            'confidence=${command.intent.confidence.toStringAsFixed(2)} '
            'band=${command.intent.band}');
        try {
          await _bridge.receive(command);
        } catch (e, stack) {
          _recordViolation(
            command.metadata.commandId,
            'ExecutionBridge threw unexpectedly: $e\n$stack',
          );
          _log('[${command.metadata.commandId}] WARNING — bridge error isolated: $e');
        }

      case _InterpretFailure(:final reason):
        _recordViolation(command.metadata.commandId,
            'Interpretation failed: $reason');
        _log('[${command.metadata.commandId}] DROPPED — $reason');
    }
  }

  List<_InterpreterViolationEntry> get violations =>
      List.unmodifiable(_violations);

  void clearViolations() => _violations.clear();

  // --------------------------------------------------
  // INTERPRETATION DISPATCH
  // Routes to typed-path or unknown-resolution-path.
  // --------------------------------------------------

  _InterpretResult _interpret(MappedCommand command) {
    return switch (command.params) {
      UnknownParams() => _resolveUnknown(command),
      _               => _enrichTyped(command),
    };
  }

  // --------------------------------------------------
  // PATH A — TYPED COMMAND ENRICHMENT
  // For commands whose ActionType was already confirmed by the mapper.
  // The interpreter adds semantic enrichment and stamps high/certain confidence.
  // --------------------------------------------------

  _InterpretResult _enrichTyped(MappedCommand command) {
    final notes = <String>[];

    notes.add('ActionType confirmed by mapper: ${command.normalizedActionType}');

    final enrichment = _extractEnrichmentFromParams(command.params, notes);
    final confidence = _scoreTyped(command.params, notes);

    if (confidence < ZConfidence.minimum) {
      return _InterpretFailure(
          'Typed command scored below minimum confidence '
          '(${confidence.toStringAsFixed(2)}): ${notes.join('; ')}');
    }

    return _InterpretSuccess(_buildInterpretedCommand(
      command:    command,
      resolved:   command.normalizedActionType,
      confidence: confidence,
      enrichment: enrichment,
      notes:      notes,
    ));
  }

  // --------------------------------------------------
  // PATH B — UNKNOWN RESOLUTION
  // For voice / AI / plugin commands with ActionType.unknown.
  // Uses keyword scoring + semantic extraction to infer the action type.
  // --------------------------------------------------

  _InterpretResult _resolveUnknown(MappedCommand command) {
    final unknown = command.params as UnknownParams;
    final rawText = unknown.rawText ?? _flattenPayload(unknown.payload);
    final notes   = <String>[];

    if (rawText.isEmpty) {
      return _InterpretFailure(
          'UnknownParams has neither rawText nor resolvable payload.');
    }

    notes.add('Resolving unknown intent from rawText: "$rawText"');

    final tokens   = _tokenize(rawText);
    final scores   = _scoreAllTypes(tokens, notes);
    final best     = _pickBestScore(scores);

    if (best == null || best.score < ZConfidence.minimum) {
      notes.add('No action type reached minimum confidence threshold '
          '(${ZConfidence.minimum}).');
      return _InterpretFailure(
          'Could not resolve action type from: "$rawText". '
          'Notes: ${notes.join('; ')}');
    }

    notes.add('Resolved to ${best.type} with score '
        '${best.score.toStringAsFixed(2)}');

    final enrichment = _extractEnrichmentFromText(rawText, tokens, notes);

    return _InterpretSuccess(_buildInterpretedCommand(
      command:    command,
      resolved:   best.type,
      confidence: best.score,
      enrichment: enrichment.copyWith(rawTokens: tokens),
      notes:      notes,
    ));
  }

  // --------------------------------------------------
  // TYPED CONFIDENCE SCORING
  // Already-structured commands score high; the only deductions are for
  // internal anomalies (e.g. empty layerId, zero-size resize).
  // --------------------------------------------------

  double _scoreTyped(CommandParams params, List<String> notes) {
    return switch (params) {
      AddLayerParams p     => _scoreAddLayer(p, notes),
      DeleteLayerParams p  => _scoreLayerId(p.layerId, 'deleteLayer', notes),
      MoveLayerParams p    => _scoreMove(p, notes),
      ResizeLayerParams p  => _scoreResize(p, notes),
      StyleUpdateParams p  => _scoreStyle(p, notes),
      AiCommandParams p    => _scoreAiCommand(p, notes),
      ExportRequestParams p => _scoreExport(p, notes),
      UndoParams _         => ZConfidence.certain,
      RedoParams _         => ZConfidence.certain,
      TemplateRequestParams p => _scoreTemplate(p, notes),
      PluginCommandParams p   => _scorePlugin(p, notes),
      UnknownParams _      => ZConfidence.unresolvable, // should not reach here
    };
  }

  double _scoreAddLayer(AddLayerParams p, List<String> notes) {
    if (p.layerType.isEmpty) {
      notes.add('addLayer: layerType is empty — deducting confidence');
      return ZConfidence.moderate;
    }
    notes.add('addLayer: layerType="${p.layerType}" — valid');
    return ZConfidence.certain;
  }

  double _scoreLayerId(String id, String ctx, List<String> notes) {
    if (id.isEmpty) {
      notes.add('$ctx: layerId is empty — deducting confidence');
      return ZConfidence.moderate;
    }
    notes.add('$ctx: layerId="$id" — valid');
    return ZConfidence.certain;
  }

  double _scoreMove(MoveLayerParams p, List<String> notes) {
    if (p.layerId.isEmpty) {
      notes.add('moveLayer: layerId is empty');
      return ZConfidence.moderate;
    }
    if (p.dx == 0 && p.dy == 0) {
      notes.add('moveLayer: dx=0 dy=0 — no-op move, low confidence');
      return ZConfidence.weak;
    }
    notes.add('moveLayer: layerId="${p.layerId}" dx=${p.dx} dy=${p.dy} — valid');
    return ZConfidence.certain;
  }

  double _scoreResize(ResizeLayerParams p, List<String> notes) {
    if (p.layerId.isEmpty) {
      notes.add('resizeLayer: layerId is empty');
      return ZConfidence.moderate;
    }
    if (p.width <= 0 || p.height <= 0) {
      notes.add('resizeLayer: invalid dimensions width=${p.width} height=${p.height}');
      return ZConfidence.weak;
    }
    notes.add('resizeLayer: ${p.width}x${p.height} — valid');
    return ZConfidence.certain;
  }

  double _scoreStyle(StyleUpdateParams p, List<String> notes) {
    if (p.layerId.isEmpty) {
      notes.add('styleUpdate: layerId is empty');
      return ZConfidence.moderate;
    }
    if (p.styleProps.isEmpty) {
      notes.add('styleUpdate: styleProps map is empty — nothing to apply');
      return ZConfidence.weak;
    }
    notes.add('styleUpdate: ${p.styleProps.keys.length} props — valid');
    return ZConfidence.certain;
  }

  double _scoreAiCommand(AiCommandParams p, List<String> notes) {
    if (p.prompt.trim().isEmpty) {
      notes.add('aiCommand: prompt is empty');
      return ZConfidence.weak;
    }
    notes.add('aiCommand: prompt length=${p.prompt.length} — valid');
    return ZConfidence.strong;
  }

  double _scoreExport(ExportRequestParams p, List<String> notes) {
    const known = ['png', 'pdf', 'svg', 'jpg', 'jpeg', 'webp', 'gif'];
    final fmt   = p.format.toLowerCase().trim();
    if (!known.contains(fmt)) {
      notes.add('exportRequest: unrecognised format "$fmt" — moderate confidence');
      return ZConfidence.moderate;
    }
    notes.add('exportRequest: format="$fmt" — valid');
    return ZConfidence.certain;
  }

  double _scoreTemplate(TemplateRequestParams p, List<String> notes) {
    if (p.templateId.isEmpty) {
      notes.add('templateRequest: templateId is empty');
      return ZConfidence.moderate;
    }
    notes.add('templateRequest: templateId="${p.templateId}" — valid');
    return ZConfidence.certain;
  }

  double _scorePlugin(PluginCommandParams p, List<String> notes) {
    if (p.pluginId.isEmpty || p.commandKey.isEmpty) {
      notes.add('pluginCommand: pluginId or commandKey empty');
      return ZConfidence.moderate;
    }
    notes.add('pluginCommand: pluginId="${p.pluginId}" key="${p.commandKey}"');
    return ZConfidence.strong;
  }

  // --------------------------------------------------
  // KEYWORD SCORING ENGINE
  // Computes a weighted overlap score per ActionType against token set.
  // --------------------------------------------------

  List<_TypeScore> _scoreAllTypes(List<String> tokens, List<String> notes) {
    final results = <_TypeScore>[];
    final tokenSet = tokens.toSet();

    for (final entry in _kKeywordTable.entries) {
      final type   = entry.key;
      var   score  = 0.0;
      var   hits   = 0;

      for (final group in entry.value) {
        for (final kw in group.keywords) {
          // Support multi-word keywords via substring match on joined tokens.
          final matched = kw.contains(' ')
              ? tokens.join(' ').contains(kw)
              : tokenSet.contains(kw);
          if (matched) {
            score += group.weight;
            hits++;
            break; // count each group at most once per match
          }
        }
      }

      if (score > 0) {
        // Normalise: cap at 1.0, apply diminishing returns for multi-group hits.
        final normalised = (score * (1.0 - 0.05 * (hits - 1).clamp(0, 10)))
            .clamp(0.0, 1.0);
        results.add(_TypeScore(type, normalised));
        notes.add('  keyword score ${type.name}: '
            '${normalised.toStringAsFixed(2)} ($hits group hits)');
      }
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results;
  }

  _TypeScore? _pickBestScore(List<_TypeScore> scores) =>
      scores.isEmpty ? null : scores.first;

  // --------------------------------------------------
  // SEMANTIC ENRICHMENT — FROM PARAMS
  // Extracts hints from typed CommandParams (no rawText available here).
  // --------------------------------------------------

  SemanticEnrichment _extractEnrichmentFromParams(
      CommandParams params, List<String> notes) {
    switch (params) {
      case AddLayerParams p:
        final kind = _inferLayerKind(p.layerType);
        notes.add('Inferred layer kind: "$kind" from layerType="${p.layerType}"');
        return SemanticEnrichment(inferredLayerKind: kind);

      case StyleUpdateParams p:
        final color = _extractColorFromMap(p.styleProps);
        if (color != null) notes.add('Inferred color from styleProps: $color');
        return SemanticEnrichment(inferredColor: color);

      case ExportRequestParams p:
        return SemanticEnrichment(inferredExportFormat: p.format.toLowerCase());

      case AiCommandParams p:
        final enrichment = _extractEnrichmentFromText(p.prompt, _tokenize(p.prompt), notes);
        return enrichment;

      default:
        return const SemanticEnrichment();
    }
  }

  // --------------------------------------------------
  // SEMANTIC ENRICHMENT — FROM RAW TEXT
  // Used for voice / AI / unknown path where rawText is the only input.
  // --------------------------------------------------

  SemanticEnrichment _extractEnrichmentFromText(
      String text, List<String> tokens, List<String> notes) {
    // Colour extraction.
    final hexMatch     = _hexColorRegex.firstMatch(text);
    final namedMatch   = _namedColorRegex.firstMatch(text);
    final color        = hexMatch?.group(0) ?? namedMatch?.group(0);
    if (color != null) notes.add('Extracted color: "$color"');

    // Font size extraction.
    final sizeMatch    = _fontSizeRegex.firstMatch(text);
    final numMatch     = sizeMatch != null ? sizeMatch.group(1) : null;
    final fontSize     = numMatch != null ? double.tryParse(numMatch) : null;
    if (fontSize != null) notes.add('Extracted font size: $fontSize');

    // Export format extraction.
    final fmtMatch     = _exportFormatRegex.firstMatch(text);
    final exportFormat = fmtMatch?.group(0)?.toLowerCase();
    if (exportFormat != null) notes.add('Extracted export format: "$exportFormat"');

    // Layer ID extraction.
    final layerIds     = _layerIdRegex
        .allMatches(text)
        .map((m) => m.group(0)!)
        .toList();
    if (layerIds.isNotEmpty) notes.add('Mentioned layer IDs: $layerIds');

    // Inferred text content (everything after add/insert/write/type keywords).
    final inferredText = _extractInlineText(tokens, notes);

    // Inferred layer kind.
    final inferredKind = _inferLayerKindFromTokens(tokens);
    if (inferredKind != null) notes.add('Inferred layer kind: "$inferredKind"');

    return SemanticEnrichment(
      inferredLayerKind:    inferredKind,
      inferredColor:        color,
      inferredText:         inferredText,
      inferredFontSize:     fontSize,
      inferredExportFormat: exportFormat,
      mentionedLayerIds:    layerIds,
      rawTokens:            tokens,
      notes:                List.unmodifiable(notes),
    );
  }

  // --------------------------------------------------
  // TOKENIZER
  // Lowercases, strips punctuation (except # for hex), splits on whitespace.
  // --------------------------------------------------

  List<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r"[^\w\s#]"), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
  }

  // --------------------------------------------------
  // HELPERS
  // --------------------------------------------------

  String _inferLayerKind(String layerType) {
    final lt = layerType.toLowerCase();
    if (lt.contains('text') || lt.contains('label')) return 'text';
    if (lt.contains('image') || lt.contains('photo') || lt.contains('img')) {
      return 'image';
    }
    if (lt.contains('shape') || lt.contains('rect') ||
        lt.contains('circle') || lt.contains('polygon')) {
      return 'shape';
    }
    if (lt.contains('group')) return 'group';
    if (lt.contains('video')) return 'video';
    if (lt.contains('audio')) return 'audio';
    return 'generic';
  }

  String? _inferLayerKindFromTokens(List<String> tokens) {
    const kindMap = {
      'text':      'text',  'label':     'text',  'caption': 'text',
      'heading':   'text',  'title':     'text',
      'image':     'image', 'photo':     'image', 'picture': 'image',
      'img':       'image', 'sticker':   'image',
      'shape':     'shape', 'rect':      'shape', 'rectangle': 'shape',
      'circle':    'shape', 'ellipse':   'shape', 'polygon':   'shape',
      'line':      'shape', 'arrow':     'shape',
      'group':     'group', 'frame':     'group',
      'video':     'video', 'clip':      'video',
    };
    for (final token in tokens) {
      final kind = kindMap[token];
      if (kind != null) return kind;
    }
    return null;
  }

  String? _extractColorFromMap(Map<String, dynamic> props) {
    for (final key in ['color', 'colour', 'fill', 'background', 'stroke',
                       'textColor', 'borderColor']) {
      if (props.containsKey(key) && props[key] is String) {
        return props[key] as String;
      }
    }
    return null;
  }

  /// Extracts inline text content from token stream.
  /// Looks for tokens after trigger words like "text", "write", "type", "saying".
  String? _extractInlineText(List<String> tokens, List<String> notes) {
    const triggers = {'text', 'write', 'type', 'saying', 'says', 'label',
                      'caption', 'titled', 'title', 'named'};
    final idx = tokens.indexWhere((t) => triggers.contains(t));
    if (idx == -1 || idx >= tokens.length - 1) return null;
    final content = tokens.sublist(idx + 1).join(' ');
    if (content.isNotEmpty) {
      notes.add('Extracted inline text content: "$content"');
    }
    return content.isEmpty ? null : content;
  }

  String _flattenPayload(Map<String, dynamic> payload) =>
      payload.values.whereType<String>().join(' ');

  // --------------------------------------------------
  // INTERPRETED COMMAND BUILDER
  // --------------------------------------------------

  InterpretedCommand _buildInterpretedCommand({
    required MappedCommand    command,
    required ActionType       resolved,
    required double           confidence,
    required SemanticEnrichment enrichment,
    required List<String>     notes,
  }) {
    final intent = InterpretedIntent(
      resolvedActionType:  resolved,
      confidence:          confidence,
      band:                _bandFor(confidence),
      enrichment:          enrichment,
      interpretationNotes: List.unmodifiable(notes),
    );

    return InterpretedCommand(
      source:        command,
      intent:        intent,
      state:         CommandState.interpreted,
      interpretedAt: DateTime.now().toUtc(),
    );
  }

  // --------------------------------------------------
  // VIOLATION LOG
  // --------------------------------------------------

  void _recordViolation(String commandId, String reason) {
    _violations.add(_InterpreterViolationEntry(
      commandId: commandId,
      reason:    reason,
      timestamp: DateTime.now().toUtc(),
    ));
  }

  void _log(String message) {
    // ignore: avoid_print
    print('[IntentionInterpreter] $message');
  }
}

// ==================================================
// INTERNAL HELPERS
// ==================================================

class _TypeScore {
  const _TypeScore(this.type, this.score);
  final ActionType type;
  final double     score;
}

class _InterpreterViolationEntry {
  const _InterpreterViolationEntry({
    required this.commandId,
    required this.reason,
    required this.timestamp,
  });
  final String   commandId;
  final String   reason;
  final DateTime timestamp;
}

// ==================================================
// END OF controllers/intention_interpreter.dart
// Z-CANVAS — PHASE-13 — SEMANTIC ENGINE (MEANING LAYER)
// Powered by Zynquar
// ==================================================
