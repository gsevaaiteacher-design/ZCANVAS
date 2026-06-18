// ignore_for_file: avoid_catches_without_on_clauses

// ============================================================
// AIEngine — Phase-4 Intent Translation Authority
// ============================================================
// OWNS: prompt parsing, intent extraction, editor command
//       generation, command validation, confidence scoring.
// MUST NOT: modify layers, call LayerEngine, HistoryEngine,
//           RenderEngine, StorageEngine, SyncEngine,
//           ExportEngine, or execute any command directly.
// OUTPUT: structured EditorCommand ONLY.
// ONLY COMMUNICATES WITH: EditorController.
// ============================================================

import 'dart:math';

// ── Supported action identifiers ─────────────────────────────
// Contract-locked set. No action outside this list is valid.
enum AIAction {
  addLayer,
  deleteLayer,
  moveLayer,
  resizeLayer,
  rotateLayer,
  changeColor,
  changeFont,
  duplicateLayer,
  lockLayer,
  unlockLayer,
  showLayer,
  hideLayer,
}

extension AIActionStringValue on AIAction {
  String get value {
    switch (this) {
      case AIAction.addLayer:        return 'add_layer';
      case AIAction.deleteLayer:     return 'delete_layer';
      case AIAction.moveLayer:       return 'move_layer';
      case AIAction.resizeLayer:     return 'resize_layer';
      case AIAction.rotateLayer:     return 'rotate_layer';
      case AIAction.changeColor:     return 'change_color';
      case AIAction.changeFont:      return 'change_font';
      case AIAction.duplicateLayer:  return 'duplicate_layer';
      case AIAction.lockLayer:       return 'lock_layer';
      case AIAction.unlockLayer:     return 'unlock_layer';
      case AIAction.showLayer:       return 'show_layer';
      case AIAction.hideLayer:       return 'hide_layer';
    }
  }

  static AIAction? fromString(String raw) {
    const map = {
      'add_layer':       AIAction.addLayer,
      'delete_layer':    AIAction.deleteLayer,
      'move_layer':      AIAction.moveLayer,
      'resize_layer':    AIAction.resizeLayer,
      'rotate_layer':    AIAction.rotateLayer,
      'change_color':    AIAction.changeColor,
      'change_font':     AIAction.changeFont,
      'duplicate_layer': AIAction.duplicateLayer,
      'lock_layer':      AIAction.lockLayer,
      'unlock_layer':    AIAction.unlockLayer,
      'show_layer':      AIAction.showLayer,
      'hide_layer':      AIAction.hideLayer,
    };
    return map[raw.toLowerCase().trim()];
  }
}

// ── Command source ────────────────────────────────────────────
enum CommandSource { ui, ai, system }

// ── Command status ────────────────────────────────────────────
enum CommandStatus { valid, invalid }

// ── Editor command — the sole output of AIEngine ─────────────
// Matches the global command format defined in the contract.
class EditorCommand {
  final String commandId;
  final CommandSource source;
  final AIAction action;
  final String? targetLayerId;
  final Map<String, dynamic> payload;
  final DateTime timestamp;
  final double confidence;    // 0.0–1.0
  final CommandStatus status;
  final List<String> validationErrors;
  final List<String> warnings;

  const EditorCommand({
    required this.commandId,
    required this.source,
    required this.action,
    this.targetLayerId,
    required this.payload,
    required this.timestamp,
    required this.confidence,
    required this.status,
    this.validationErrors = const [],
    this.warnings = const [],
  });

  Map<String, dynamic> toMap() => {
        'commandId': commandId,
        'source': source.name.toUpperCase(),
        'action': action.value,
        'targetLayerId': targetLayerId,
        'payload': payload,
        'timestamp': timestamp.toIso8601String(),
        'confidence': confidence,
        'status': status.name,
      };
}

// ── Parse result ──────────────────────────────────────────────
class ParseResult {
  final bool success;
  final EditorCommand? command;
  final List<String> errors;
  final List<String> warnings;

  const ParseResult._({
    required this.success,
    this.command,
    this.errors = const [],
    this.warnings = const [],
  });

  factory ParseResult.ok(EditorCommand command,
          {List<String> warnings = const []}) =>
      ParseResult._(success: true, command: command, warnings: warnings);

  factory ParseResult.failure(List<String> errors,
          {List<String> warnings = const []}) =>
      ParseResult._(success: false, errors: errors, warnings: warnings);
}

// ── Intent ────────────────────────────────────────────────────
class Intent {
  final AIAction action;
  final String? targetLayerId;
  final Map<String, dynamic> extractedParams;
  final double rawConfidence;    // pre-validation confidence

  const Intent({
    required this.action,
    this.targetLayerId,
    this.extractedParams = const {},
    required this.rawConfidence,
  });
}

// ── Command validation result ─────────────────────────────────
class CommandValidationResult {
  final bool valid;
  final List<String> errors;
  final List<String> warnings;

  const CommandValidationResult.ok({this.warnings = const []})
      : valid = true,
        errors = const [];

  const CommandValidationResult.fail(this.errors,
      {this.warnings = const []})
      : valid = false;
}

// ── Keyword → action mapping ──────────────────────────────────
// Maps normalised prompt keywords to the supported action set.
// Ordered longest-match first within each group so more specific
// phrases win over shorter ones.
class _IntentKeywords {
  static const Map<String, AIAction> _map = {
    // add / create
    'add layer':         AIAction.addLayer,
    'add a layer':       AIAction.addLayer,
    'create layer':      AIAction.addLayer,
    'insert layer':      AIAction.addLayer,
    'new layer':         AIAction.addLayer,
    'add text':          AIAction.addLayer,
    'add image':         AIAction.addLayer,
    'add shape':         AIAction.addLayer,
    'add icon':          AIAction.addLayer,
    'add sticker':       AIAction.addLayer,
    // delete / remove
    'delete layer':      AIAction.deleteLayer,
    'remove layer':      AIAction.deleteLayer,
    'delete this':       AIAction.deleteLayer,
    'remove this':       AIAction.deleteLayer,
    'delete selected':   AIAction.deleteLayer,
    'remove selected':   AIAction.deleteLayer,
    'erase layer':       AIAction.deleteLayer,
    // move
    'move layer':        AIAction.moveLayer,
    'move this':         AIAction.moveLayer,
    'reposition':        AIAction.moveLayer,
    'shift layer':       AIAction.moveLayer,
    'drag layer':        AIAction.moveLayer,
    'move to':           AIAction.moveLayer,
    'place at':          AIAction.moveLayer,
    // resize
    'resize layer':      AIAction.resizeLayer,
    'resize this':       AIAction.resizeLayer,
    'scale layer':       AIAction.resizeLayer,
    'scale this':        AIAction.resizeLayer,
    'make bigger':       AIAction.resizeLayer,
    'make smaller':      AIAction.resizeLayer,
    'increase size':     AIAction.resizeLayer,
    'decrease size':     AIAction.resizeLayer,
    'change size':       AIAction.resizeLayer,
    // rotate
    'rotate layer':      AIAction.rotateLayer,
    'rotate this':       AIAction.rotateLayer,
    'turn layer':        AIAction.rotateLayer,
    'spin layer':        AIAction.rotateLayer,
    'rotate by':         AIAction.rotateLayer,
    'rotate to':         AIAction.rotateLayer,
    // color
    'change color':      AIAction.changeColor,
    'change colour':     AIAction.changeColor,
    'set color':         AIAction.changeColor,
    'set colour':        AIAction.changeColor,
    'update color':      AIAction.changeColor,
    'color this':        AIAction.changeColor,
    'colour this':       AIAction.changeColor,
    'fill color':        AIAction.changeColor,
    'background color':  AIAction.changeColor,
    // font
    'change font':       AIAction.changeFont,
    'set font':          AIAction.changeFont,
    'update font':       AIAction.changeFont,
    'font size':         AIAction.changeFont,
    'change typeface':   AIAction.changeFont,
    'change text size':  AIAction.changeFont,
    // duplicate
    'duplicate layer':   AIAction.duplicateLayer,
    'copy layer':        AIAction.duplicateLayer,
    'clone layer':       AIAction.duplicateLayer,
    'duplicate this':    AIAction.duplicateLayer,
    'copy this':         AIAction.duplicateLayer,
    // lock / unlock
    'lock layer':        AIAction.lockLayer,
    'lock this':         AIAction.lockLayer,
    'protect layer':     AIAction.lockLayer,
    'unlock layer':      AIAction.unlockLayer,
    'unlock this':       AIAction.unlockLayer,
    'unprotect layer':   AIAction.unlockLayer,
    // show / hide
    'show layer':        AIAction.showLayer,
    'make visible':      AIAction.showLayer,
    'reveal layer':      AIAction.showLayer,
    'unhide layer':      AIAction.showLayer,
    'hide layer':        AIAction.hideLayer,
    'make invisible':    AIAction.hideLayer,
    'conceal layer':     AIAction.hideLayer,
    'invisible layer':   AIAction.hideLayer,
  };

  /// Returns (action, matchedPhrase, confidence boost) or null.
  static (AIAction, String, double)? match(String normalised) {
    // Try longest phrase first for most specific match.
    final sorted = _map.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final phrase in sorted) {
      if (normalised.contains(phrase)) {
        return (_map[phrase]!, phrase, 0.0);
      }
    }
    return null;
  }
}

// ── Parameter extractors ──────────────────────────────────────
class _ParamExtractor {
  // Numeric extractor: returns first number found in text.
  static double? number(String text) {
    final match = RegExp(r'(-?\d+(?:\.\d+)?)').firstMatch(text);
    return match != null ? double.tryParse(match.group(1)!) : null;
  }

  // Two-number extractor: returns first pair of numbers (e.g. "200 300").
  static (double, double)? numberPair(String text) {
    final matches =
        RegExp(r'(-?\d+(?:\.\d+)?)').allMatches(text).toList();
    if (matches.length >= 2) {
      final a = double.tryParse(matches[0].group(1)!);
      final b = double.tryParse(matches[1].group(1)!);
      if (a != null && b != null) return (a, b);
    }
    return null;
  }

  // Hex color extractor.
  static String? hexColor(String text) {
    final match =
        RegExp(r'#([0-9a-fA-F]{6}|[0-9a-fA-F]{3})\b').firstMatch(text);
    return match != null ? match.group(0) : null;
  }

  // Named color extractor (basic palette).
  static const Map<String, String> _namedColors = {
    'red': '#FF0000',
    'green': '#00FF00',
    'blue': '#0000FF',
    'white': '#FFFFFF',
    'black': '#000000',
    'yellow': '#FFFF00',
    'orange': '#FF8C00',
    'purple': '#800080',
    'pink': '#FFC0CB',
    'grey': '#808080',
    'gray': '#808080',
    'cyan': '#00FFFF',
    'magenta': '#FF00FF',
    'brown': '#8B4513',
    'navy': '#001F5B',
    'teal': '#008080',
  };

  static String? namedColor(String text) {
    for (final entry in _namedColors.entries) {
      if (text.contains(entry.key)) return entry.value;
    }
    return null;
  }

  // Layer type extractor.
  static String? layerType(String text) {
    const types = [
      'text', 'image', 'shape', 'icon', 'sticker',
      'frame', 'overlay', 'background',
    ];
    for (final t in types) {
      if (text.contains(t)) return t;
    }
    return null;
  }

  // Font family extractor.
  static String? fontFamily(String text) {
    const knownFonts = [
      'roboto', 'inter', 'lato', 'montserrat', 'opensans', 'open sans',
      'raleway', 'poppins', 'nunito', 'playfair', 'merriweather',
      'oswald', 'ubuntu', 'georgia', 'arial', 'helvetica',
      'times', 'courier',
    ];
    for (final f in knownFonts) {
      if (text.contains(f)) {
        return f.split(' ').map((w) =>
            w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}'
        ).join(' ');
      }
    }
    return null;
  }

  // Direction extractor for move.
  static Map<String, double>? direction(String text) {
    final pair = numberPair(text);
    if (pair != null) return {'dx': pair.$1, 'dy': pair.$2};

    if (text.contains('up'))    return {'dx': 0, 'dy': -20};
    if (text.contains('down'))  return {'dx': 0, 'dy': 20};
    if (text.contains('left'))  return {'dx': -20, 'dy': 0};
    if (text.contains('right')) return {'dx': 20, 'dy': 0};
    return null;
  }
}

// ── UUID-like ID generator ────────────────────────────────────
class _IdGen {
  static final Random _rng = Random.secure();

  static String next() {
    final bytes = List<int>.generate(16, (_) => _rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant
    String hex(int n) => n.toRadixString(16).padLeft(2, '0');
    final b = bytes.map(hex).join();
    return '${b.substring(0, 8)}-${b.substring(8, 12)}-'
        '${b.substring(12, 16)}-${b.substring(16, 20)}-'
        '${b.substring(20)}';
  }
}

// ── AIEngine ──────────────────────────────────────────────────
class AIEngine {
  // Minimum confidence below which a command is marked invalid.
  static const double _confidenceThreshold = 0.35;

  // ── Public entry points ───────────────────────────────────────

  /// Full pipeline: prompt → validated EditorCommand.
  ParseResult parsePrompt(String prompt, {String? targetLayerId}) {
    try {
      if (prompt.trim().isEmpty) {
        return ParseResult.failure(['Prompt must not be empty.']);
      }

      final intent = extractIntent(prompt, targetLayerId: targetLayerId);
      if (intent == null) {
        return ParseResult.failure(
          ['No recognisable editor action found in prompt: "$prompt".'],
          warnings: [
            'Supported actions: '
                '${AIAction.values.map((a) => a.value).join(', ')}.'
          ],
        );
      }

      final command = generateEditorCommand(intent);
      final validation = validateGeneratedCommand(command);

      if (!validation.valid) {
        final rejected = command.toMap();
        rejected['status'] = CommandStatus.invalid.name;
        return ParseResult.failure(
          validation.errors,
          warnings: validation.warnings,
        );
      }

      return ParseResult.ok(command, warnings: validation.warnings);
    } catch (e) {
      return ParseResult.failure(
          ['Unexpected error during prompt parsing: $e']);
    }
  }

  // ── Intent extraction ─────────────────────────────────────────

  /// Extracts a structured Intent from raw natural language.
  /// Returns null when no valid action can be identified.
  Intent? extractIntent(String prompt, {String? targetLayerId}) {
    final normalised = prompt.toLowerCase().trim();

    final match = _IntentKeywords.match(normalised);
    if (match == null) return null;

    final (action, matchedPhrase, _) = match;

    // Base confidence from phrase-length heuristic:
    // longer match = more specific = higher confidence.
    final phraseScore = (matchedPhrase.split(' ').length / 5.0).clamp(0.2, 0.8);
    final lengthPenalty = (prompt.trim().split(' ').length > 30) ? 0.1 : 0.0;
    final rawConfidence = (phraseScore - lengthPenalty).clamp(0.0, 1.0);

    final params = _extractParams(action, normalised);

    return Intent(
      action: action,
      targetLayerId: targetLayerId ?? _extractLayerId(normalised),
      extractedParams: params,
      rawConfidence: rawConfidence,
    );
  }

  // ── Command generation ────────────────────────────────────────

  /// Converts a resolved Intent into a structured EditorCommand.
  EditorCommand generateEditorCommand(Intent intent) {
    final commandId = _IdGen.next();
    final timestamp = DateTime.now().toUtc();

    // Adjust confidence: penalise missing target for actions that need one.
    final needsTarget = _actionRequiresTarget(intent.action);
    final hasTarget = intent.targetLayerId != null &&
        intent.targetLayerId!.trim().isNotEmpty;

    double confidence = intent.rawConfidence;
    final warnings = <String>[];

    if (needsTarget && !hasTarget) {
      confidence = (confidence * 0.6).clamp(0.0, 1.0);
      warnings.add(
          'Action "${intent.action.value}" typically requires a targetLayerId. '
          'EditorController will use the currently selected layer.');
    }

    final finalConfidence = confidence.clamp(0.0, 1.0);
    final status = finalConfidence >= _confidenceThreshold
        ? CommandStatus.valid
        : CommandStatus.invalid;

    return EditorCommand(
      commandId: commandId,
      source: CommandSource.ai,
      action: intent.action,
      targetLayerId: hasTarget ? intent.targetLayerId : null,
      payload: Map<String, dynamic>.unmodifiable(intent.extractedParams),
      timestamp: timestamp,
      confidence: finalConfidence,
      status: status,
      warnings: warnings,
    );
  }

  // ── Command validation ────────────────────────────────────────

  /// Validates a generated EditorCommand for structural correctness
  /// and safety. Does NOT execute the command.
  CommandValidationResult validateGeneratedCommand(EditorCommand command) {
    final errors = <String>[];
    final warnings = List<String>.from(command.warnings);

    // commandId must be non-empty.
    if (command.commandId.trim().isEmpty) {
      errors.add('EditorCommand.commandId must not be empty.');
    }

    // Source must be AI for AIEngine-generated commands.
    if (command.source != CommandSource.ai) {
      errors.add(
          'Commands generated by AIEngine must have source=AI '
          '(got ${command.source.name}).');
    }

    // Confidence range.
    if (command.confidence < 0.0 || command.confidence > 1.0) {
      errors.add(
          'EditorCommand.confidence must be in [0.0, 1.0] '
          '(got ${command.confidence}).');
    }

    // Low-confidence warning (not an error — EditorController decides).
    if (command.confidence < _confidenceThreshold &&
        command.confidence >= 0.0) {
      errors.add(
          'Confidence ${command.confidence.toStringAsFixed(2)} is below '
          'minimum threshold $_confidenceThreshold. Command marked invalid.');
    } else if (command.confidence < 0.55) {
      warnings.add(
          'Low confidence (${command.confidence.toStringAsFixed(2)}). '
          'EditorController should confirm before executing.');
    }

    // Action must be one of the supported set.
    final actionStr = AIActionStringValue.fromString(command.action.value);
    if (actionStr == null) {
      errors.add(
          'Action "${command.action.value}" is not in the supported action set.');
    }

    // Payload safety: must not contain engine references or executable code.
    _validatePayloadSafety(command.payload, errors, warnings);

    // Action-specific payload checks.
    _validateActionPayload(command.action, command.payload, errors, warnings);

    if (errors.isEmpty) {
      return CommandValidationResult.ok(warnings: warnings);
    }
    return CommandValidationResult.fail(errors, warnings: warnings);
  }

  // ── Private helpers ───────────────────────────────────────────

  bool _actionRequiresTarget(AIAction action) {
    const targetRequired = {
      AIAction.deleteLayer,
      AIAction.moveLayer,
      AIAction.resizeLayer,
      AIAction.rotateLayer,
      AIAction.changeColor,
      AIAction.changeFont,
      AIAction.duplicateLayer,
      AIAction.lockLayer,
      AIAction.unlockLayer,
      AIAction.showLayer,
      AIAction.hideLayer,
    };
    return targetRequired.contains(action);
  }

  /// Extract layerId from prompt using simple heuristics.
  /// Real integration relies on EditorController passing the selected layer.
  String? _extractLayerId(String normalised) {
    // Pattern: "layer <id>" or "layer_<id>"
    final match =
        RegExp(r'layer[_ ]([a-z0-9_\-]+)', caseSensitive: false)
            .firstMatch(normalised);
    return match?.group(1);
  }

  Map<String, dynamic> _extractParams(AIAction action, String text) {
    switch (action) {
      case AIAction.addLayer:
        final type = _ParamExtractor.layerType(text);
        return {
          if (type != null) 'layerType': type,
        };

      case AIAction.moveLayer:
        final dir = _ParamExtractor.direction(text);
        return {
          if (dir != null) ...dir,
        };

      case AIAction.resizeLayer:
        final pair = _ParamExtractor.numberPair(text);
        final single = _ParamExtractor.number(text);
        if (pair != null) {
          return {'width': pair.$1, 'height': pair.$2};
        } else if (single != null) {
          if (text.contains('bigger') || text.contains('increase')) {
            return {'scaleFactor': (single / 100.0 + 1.0).clamp(1.0, 10.0)};
          } else if (text.contains('smaller') || text.contains('decrease')) {
            return {'scaleFactor': (1.0 - single / 100.0).clamp(0.01, 1.0)};
          }
          return {'scaleFactor': single};
        }
        return {};

      case AIAction.rotateLayer:
        final angle = _ParamExtractor.number(text);
        return {
          if (angle != null) 'angleDegrees': angle % 360,
        };

      case AIAction.changeColor:
        final hex = _ParamExtractor.hexColor(text);
        final named = _ParamExtractor.namedColor(text);
        final resolved = hex ?? named;
        return {
          if (resolved != null) 'color': resolved,
        };

      case AIAction.changeFont:
        final size = _ParamExtractor.number(text);
        final family = _ParamExtractor.fontFamily(text);
        return {
          if (family != null) 'fontFamily': family,
          if (size != null) 'fontSize': size,
        };

      // No additional payload needed for these actions.
      case AIAction.deleteLayer:
      case AIAction.duplicateLayer:
      case AIAction.lockLayer:
      case AIAction.unlockLayer:
      case AIAction.showLayer:
      case AIAction.hideLayer:
        return {};
    }
  }

  void _validatePayloadSafety(
      Map<String, dynamic> payload,
      List<String> errors,
      List<String> warnings) {
    const forbiddenKeys = [
      'layerEngine', 'historyEngine', 'renderEngine',
      'storageEngine', 'syncEngine', 'exportEngine',
      'editorController', 'aiEngine', 'templateEngine',
      'buildContext', 'canvas', 'widget',
    ];
    for (final key in payload.keys) {
      if (forbiddenKeys.contains(key.toLowerCase())) {
        errors.add('Payload key "$key" references a forbidden engine or '
            'context object.');
      }
    }

    // Values must be serialisable primitives, not callables/objects.
    for (final entry in payload.entries) {
      final v = entry.value;
      final isSerializable = v == null ||
          v is num ||
          v is String ||
          v is bool ||
          (v is List && v.every((e) => e is num || e is String || e is bool)) ||
          v is Map<String, dynamic>;
      if (!isSerializable) {
        errors.add(
            'Payload value for key "${entry.key}" is not a serialisable '
            'primitive (got ${v.runtimeType}).');
      }
    }
  }

  void _validateActionPayload(
      AIAction action,
      Map<String, dynamic> payload,
      List<String> errors,
      List<String> warnings) {
    switch (action) {
      case AIAction.moveLayer:
        final hasDx = payload.containsKey('dx');
        final hasDy = payload.containsKey('dy');
        if (!hasDx && !hasDy) {
          warnings.add(
              'move_layer payload has no dx/dy; '
              'EditorController should request position from user.');
        } else {
          if (hasDx) {
            final dx = payload['dx'];
            if (dx is! num) {
              errors.add('move_layer payload.dx must be numeric.');
            }
          }
          if (hasDy) {
            final dy = payload['dy'];
            if (dy is! num) {
              errors.add('move_layer payload.dy must be numeric.');
            }
          }
        }
        break;

      case AIAction.resizeLayer:
        final hasWidth = payload.containsKey('width');
        final hasHeight = payload.containsKey('height');
        final hasScale = payload.containsKey('scaleFactor');
        if (!hasWidth && !hasHeight && !hasScale) {
          warnings.add(
              'resize_layer payload has no dimensions or scaleFactor; '
              'EditorController should request dimensions from user.');
        }
        if (hasScale) {
          final sf = payload['scaleFactor'];
          if (sf is num && sf <= 0) {
            errors.add('resize_layer payload.scaleFactor must be > 0.');
          }
        }
        if (hasWidth) {
          final w = payload['width'];
          if (w is num && w <= 0) {
            errors.add('resize_layer payload.width must be > 0.');
          }
        }
        if (hasHeight) {
          final h = payload['height'];
          if (h is num && h <= 0) {
            errors.add('resize_layer payload.height must be > 0.');
          }
        }
        break;

      case AIAction.rotateLayer:
        final angle = payload['angleDegrees'];
        if (angle == null) {
          warnings.add(
              'rotate_layer payload has no angleDegrees; '
              'EditorController should request angle from user.');
        } else if (angle is num && (angle < 0 || angle > 360)) {
          errors.add(
              'rotate_layer payload.angleDegrees must be in [0, 360] '
              '(got $angle).');
        }
        break;

      case AIAction.changeColor:
        final color = payload['color'];
        if (color == null) {
          warnings.add(
              'change_color payload has no color value; '
              'EditorController should request color from user.');
        } else if (color is String &&
            !RegExp(r'^#([0-9a-fA-F]{6}|[0-9a-fA-F]{3})$')
                .hasMatch(color)) {
          errors.add(
              'change_color payload.color must be a valid hex string '
              '(got "$color").');
        }
        break;

      case AIAction.changeFont:
        final size = payload['fontSize'];
        if (size is num && size <= 0) {
          errors.add('change_font payload.fontSize must be > 0.');
        }
        if (!payload.containsKey('fontFamily') &&
            !payload.containsKey('fontSize')) {
          warnings.add(
              'change_font payload has neither fontFamily nor fontSize; '
              'EditorController should request font details from user.');
        }
        break;

      case AIAction.addLayer:
        if (!payload.containsKey('layerType')) {
          warnings.add(
              'add_layer payload has no layerType; '
              'EditorController should request layer type from user.');
        }
        break;

      // No payload required or enforced.
      case AIAction.deleteLayer:
      case AIAction.duplicateLayer:
      case AIAction.lockLayer:
      case AIAction.unlockLayer:
      case AIAction.showLayer:
      case AIAction.hideLayer:
        break;
    }
  }
}
