// ignore_for_file: avoid_catches_without_on_clauses

import 'dart:math';

// ── CommandObject — sole output format ────────────────────────
class CommandObject {
  final String commandId;
  final String commandType;
  final String? target;
  final Map<String, dynamic> payload;
  final DateTime timestamp;
  final int priority;
  final bool requiresConfirmation;
  final String sourceEngine;

  const CommandObject({
    required this.commandId,
    required this.commandType,
    this.target,
    required this.payload,
    required this.timestamp,
    required this.priority,
    required this.requiresConfirmation,
    required this.sourceEngine,
  });

  Map<String, dynamic> toMap() => {
        'commandId': commandId,
        'commandType': commandType,
        'target': target,
        'payload': payload,
        'timestamp': timestamp.toIso8601String(),
        'priority': priority,
        'requiresConfirmation': requiresConfirmation,
        'sourceEngine': sourceEngine,
      };
}

// ── AutomationAction — a single step in an automation ─────────
class AutomationAction {
  final String actionId;
  final String actionType;
  final String? targetLayerId;
  final Map<String, dynamic> parameters;
  final bool requiresConfirmation;
  final int priority;

  const AutomationAction({
    required this.actionId,
    required this.actionType,
    this.targetLayerId,
    this.parameters = const {},
    this.requiresConfirmation = false,
    this.priority = 5,
  });
}

// ── TriggerSource ─────────────────────────────────────────────
enum TriggerSource {
  user,
  system,
  scheduled,
  event,
  macro,
  plugin,
}

// ── Priority levels ───────────────────────────────────────────
enum AutomationPriority {
  low,
  normal,
  high,
  critical,
}

extension AutomationPriorityValue on AutomationPriority {
  int get numericValue {
    switch (this) {
      case AutomationPriority.low:      return 1;
      case AutomationPriority.normal:   return 5;
      case AutomationPriority.high:     return 8;
      case AutomationPriority.critical: return 10;
    }
  }
}

// ── ContextSnapshot — read-only editor state hint ─────────────
// AutomationEngine reads this for context; never mutates it.
class ContextSnapshot {
  final String? activeDesignId;
  final String? selectedLayerId;
  final List<String> visibleLayerIds;
  final Map<String, dynamic> editorState;

  const ContextSnapshot({
    this.activeDesignId,
    this.selectedLayerId,
    this.visibleLayerIds = const [],
    this.editorState = const {},
  });
}

// ── AutomationRequest — input contract ────────────────────────
class AutomationRequest {
  final String requestId;
  final TriggerSource triggerSource;
  final List<AutomationAction> actionList;
  final ContextSnapshot contextSnapshot;
  final AutomationPriority priorityLevel;

  const AutomationRequest({
    required this.requestId,
    required this.triggerSource,
    required this.actionList,
    required this.contextSnapshot,
    this.priorityLevel = AutomationPriority.normal,
  });
}

// ── ExecutionPlan ─────────────────────────────────────────────
class ExecutionStep {
  final int index;
  final AutomationAction action;
  final List<CommandObject> commands;
  final bool canRollback;

  const ExecutionStep({
    required this.index,
    required this.action,
    required this.commands,
    required this.canRollback,
  });
}

class ExecutionPlan {
  final String planId;
  final String requestId;
  final List<ExecutionStep> steps;
  final DateTime createdAt;
  final AutomationPriority priority;

  const ExecutionPlan({
    required this.planId,
    required this.requestId,
    required this.steps,
    required this.createdAt,
    required this.priority,
  });

  int get totalCommandCount =>
      steps.fold(0, (sum, s) => sum + s.commands.length);
}

// ── StepResult ────────────────────────────────────────────────
class StepResult {
  final bool success;
  final List<CommandObject> commands;
  final List<String> errors;
  final List<String> warnings;

  const StepResult._({
    required this.success,
    this.commands = const [],
    this.errors = const [],
    this.warnings = const [],
  });

  factory StepResult.ok(List<CommandObject> commands,
          {List<String> warnings = const []}) =>
      StepResult._(success: true, commands: commands, warnings: warnings);

  factory StepResult.failure(List<String> errors,
          {List<String> warnings = const []}) =>
      StepResult._(success: false, errors: errors, warnings: warnings);
}

// ── RollbackResult ────────────────────────────────────────────
class RollbackResult {
  final bool success;
  final List<CommandObject> rollbackCommands;
  final List<String> errors;

  const RollbackResult._({
    required this.success,
    this.rollbackCommands = const [],
    this.errors = const [],
  });

  factory RollbackResult.ok(List<CommandObject> cmds) =>
      RollbackResult._(success: true, rollbackCommands: cmds);

  factory RollbackResult.failure(List<String> errors) =>
      RollbackResult._(success: false, errors: errors);

  factory RollbackResult.notSupported() =>
      RollbackResult._(
          success: true,
          rollbackCommands: [],
          errors: ['Step does not support rollback.']);
}

// ── ExecutionResult ───────────────────────────────────────────
class ExecutionResult {
  final bool success;
  final String requestId;
  final List<CommandObject> commands;
  final List<String> errors;
  final List<String> warnings;
  final int stepsCompleted;
  final int stepsTotal;
  final List<CommandObject> rollbackCommands;

  const ExecutionResult({
    required this.success,
    required this.requestId,
    required this.commands,
    this.errors = const [],
    this.warnings = const [],
    required this.stepsCompleted,
    required this.stepsTotal,
    this.rollbackCommands = const [],
  });
}

// ── Validation result ─────────────────────────────────────────
class AutomationValidationResult {
  final bool valid;
  final List<String> errors;
  final List<String> warnings;

  const AutomationValidationResult.ok({this.warnings = const []})
      : valid = true,
        errors = const [];

  const AutomationValidationResult.fail(this.errors,
      {this.warnings = const []})
      : valid = false;
}

// ── Validation of execution result ───────────────────────────
class ExecutionValidationResult {
  final bool valid;
  final List<String> errors;
  final List<String> warnings;

  const ExecutionValidationResult.ok({this.warnings = const []})
      : valid = true,
        errors = const [];

  const ExecutionValidationResult.fail(this.errors,
      {this.warnings = const []})
      : valid = false;
}

// ── ID generator ──────────────────────────────────────────────
class _IdGen {
  static final Random _rng = Random.secure();

  static String next(String prefix) {
    final bytes = List<int>.generate(8, (_) => _rng.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '$prefix-$hex-${DateTime.now().microsecondsSinceEpoch}';
  }
}

// ── Allowed action types ──────────────────────────────────────
const Set<String> _kAllowedActionTypes = {
  'add_layer',
  'delete_layer',
  'update_layer',
  'move_layer',
  'resize_layer',
  'rotate_layer',
  'duplicate_layer',
  'show_layer',
  'hide_layer',
  'lock_layer',
  'unlock_layer',
  'change_color',
  'change_font',
  'select_layer',
  'clear_selection',
  'apply_template',
  'batch_update',
  'reorder_layers',
};

// ── Rollback inverse mapping ──────────────────────────────────
const Map<String, String> _kRollbackInverse = {
  'add_layer':    'delete_layer',
  'delete_layer': 'add_layer',
  'show_layer':   'hide_layer',
  'hide_layer':   'show_layer',
  'lock_layer':   'unlock_layer',
  'unlock_layer': 'lock_layer',
};

// ── AutomationEngine ──────────────────────────────────────────
class AutomationEngine {
  static const String _engineId = 'AutomationEngine';

  // ── Public entry point ────────────────────────────────────────

  ExecutionResult runAutomation(AutomationRequest request) {
    try {
      final validation = validateAutomationRequest(request);
      if (!validation.valid) {
        return ExecutionResult(
          success: false,
          requestId: request.requestId,
          commands: const [],
          errors: validation.errors,
          warnings: validation.warnings,
          stepsCompleted: 0,
          stepsTotal: request.actionList.length,
        );
      }

      final plan = buildExecutionPlan(request);
      final allCommands = <CommandObject>[];
      final rollbackCommands = <CommandObject>[];
      final errors = <String>[];
      final warnings = List<String>.from(validation.warnings);
      int completed = 0;

      for (final step in plan.steps) {
        final stepResult = executeStep(step, request.contextSnapshot);

        if (stepResult.success) {
          allCommands.addAll(stepResult.commands);
          warnings.addAll(stepResult.warnings);
          completed++;

          // Accumulate rollback commands in reverse order.
          if (step.canRollback) {
            final rb = rollbackStep(step);
            rollbackCommands.insertAll(0, rb.rollbackCommands);
          }
        } else {
          errors.addAll(stepResult.errors);
          warnings.addAll(stepResult.warnings);
          // Failure isolation: stop pipeline but do not throw.
          break;
        }
      }

      final resultValidation = validateExecutionResult(
        commands: allCommands,
        requestId: request.requestId,
        stepsCompleted: completed,
        stepsTotal: plan.steps.length,
      );

      warnings.addAll(resultValidation.warnings);

      return ExecutionResult(
        success: errors.isEmpty && resultValidation.valid,
        requestId: request.requestId,
        commands: List.unmodifiable(allCommands),
        errors: [...errors, ...resultValidation.errors],
        warnings: warnings,
        stepsCompleted: completed,
        stepsTotal: plan.steps.length,
        rollbackCommands: List.unmodifiable(rollbackCommands),
      );
    } catch (e) {
      return ExecutionResult(
        success: false,
        requestId: request.requestId,
        commands: const [],
        errors: ['Unexpected error in AutomationEngine: $e'],
        stepsCompleted: 0,
        stepsTotal: request.actionList.length,
      );
    }
  }

  // ── Validation ────────────────────────────────────────────────

  AutomationValidationResult validateAutomationRequest(
      AutomationRequest request) {
    final errors = <String>[];
    final warnings = <String>[];

    if (request.requestId.trim().isEmpty) {
      errors.add('AutomationRequest.requestId must not be empty.');
    }
    if (request.actionList.isEmpty) {
      errors.add('AutomationRequest.actionList must contain at least one action.');
    }

    final seenIds = <String>{};
    for (int i = 0; i < request.actionList.length; i++) {
      final action = request.actionList[i];

      if (action.actionId.trim().isEmpty) {
        errors.add('Action at index $i has an empty actionId.');
      } else if (!seenIds.add(action.actionId)) {
        errors.add('Duplicate actionId "${action.actionId}" at index $i.');
      }

      if (action.actionType.trim().isEmpty) {
        errors.add('Action "${action.actionId}" has an empty actionType.');
      } else if (!_kAllowedActionTypes.contains(action.actionType)) {
        errors.add(
            'Action "${action.actionId}" has unsupported actionType '
            '"${action.actionType}". '
            'Allowed: ${_kAllowedActionTypes.join(', ')}.');
      }

      if (action.priority < 1 || action.priority > 10) {
        warnings.add(
            'Action "${action.actionId}" priority ${action.priority} is '
            'outside [1, 10]; will be clamped.');
      }

      _validateActionParameters(action, errors, warnings);
    }

    if (errors.isEmpty) {
      return AutomationValidationResult.ok(warnings: warnings);
    }
    return AutomationValidationResult.fail(errors, warnings: warnings);
  }

  // ── Execution plan ────────────────────────────────────────────

  ExecutionPlan buildExecutionPlan(AutomationRequest request) {
    final planId = _IdGen.next('plan');
    final now = DateTime.now().toUtc();
    final basePriority = request.priorityLevel.numericValue;

    final steps = <ExecutionStep>[];

    for (int i = 0; i < request.actionList.length; i++) {
      final action = request.actionList[i];
      final effectivePriority =
          (action.priority.clamp(1, 10) + basePriority) ~/ 2;

      final commands = _buildCommandsForAction(
        action: action,
        index: i,
        effectivePriority: effectivePriority,
        now: now.add(Duration(microseconds: i)),
      );

      steps.add(ExecutionStep(
        index: i,
        action: action,
        commands: commands,
        canRollback: _kRollbackInverse.containsKey(action.actionType),
      ));
    }

    return ExecutionPlan(
      planId: planId,
      requestId: request.requestId,
      steps: steps,
      createdAt: now,
      priority: request.priorityLevel,
    );
  }

  // ── Step execution ────────────────────────────────────────────

  StepResult executeStep(
      ExecutionStep step, ContextSnapshot contextSnapshot) {
    try {
      if (step.commands.isEmpty) {
        return StepResult.failure(
          ['Step ${step.index} (${step.action.actionType}) '
              'produced no commands.'],
        );
      }

      // Resolve target: prefer action's explicit target,
      // fall back to context selected layer.
      final resolvedTarget = step.action.targetLayerId ??
          contextSnapshot.selectedLayerId;

      // Actions that require a target but have none.
      const targetRequired = {
        'delete_layer', 'update_layer', 'move_layer', 'resize_layer',
        'rotate_layer', 'duplicate_layer', 'show_layer', 'hide_layer',
        'lock_layer', 'unlock_layer', 'change_color', 'change_font',
        'select_layer',
      };

      final warnings = <String>[];

      if (targetRequired.contains(step.action.actionType) &&
          (resolvedTarget == null || resolvedTarget.trim().isEmpty)) {
        warnings.add(
            'Step ${step.index}: "${step.action.actionType}" has no target; '
            'EditorController will use active selection.');
      }

      // Stamp resolved target into a copy of each command's payload
      // so the EditorController validation gate has full information.
      final stamped = step.commands.map((cmd) {
        if (resolvedTarget == null) return cmd;
        return CommandObject(
          commandId: cmd.commandId,
          commandType: cmd.commandType,
          target: resolvedTarget,
          payload: {...cmd.payload, 'resolvedTarget': resolvedTarget},
          timestamp: cmd.timestamp,
          priority: cmd.priority,
          requiresConfirmation: cmd.requiresConfirmation,
          sourceEngine: cmd.sourceEngine,
        );
      }).toList();

      return StepResult.ok(stamped, warnings: warnings);
    } catch (e) {
      return StepResult.failure(
          ['Step ${step.index} threw: $e']);
    }
  }

  // ── Rollback ──────────────────────────────────────────────────

  RollbackResult rollbackStep(ExecutionStep step) {
    final inverse = _kRollbackInverse[step.action.actionType];
    if (inverse == null) {
      return RollbackResult.notSupported();
    }

    try {
      final rollbackCommands = step.commands.map((cmd) {
        return CommandObject(
          commandId: _IdGen.next('rb'),
          commandType: inverse,
          target: cmd.target,
          payload: {
            ...cmd.payload,
            'rollbackOf': cmd.commandId,
            'originalAction': step.action.actionType,
          },
          timestamp: DateTime.now().toUtc(),
          priority: cmd.priority,
          requiresConfirmation: true,
          sourceEngine: _engineId,
        );
      }).toList();

      return RollbackResult.ok(rollbackCommands);
    } catch (e) {
      return RollbackResult.failure(['Rollback failed for step '
          '${step.index}: $e']);
    }
  }

  // ── Result validation ─────────────────────────────────────────

  ExecutionValidationResult validateExecutionResult({
    required List<CommandObject> commands,
    required String requestId,
    required int stepsCompleted,
    required int stepsTotal,
  }) {
    final errors = <String>[];
    final warnings = <String>[];

    if (requestId.trim().isEmpty) {
      errors.add('ExecutionResult.requestId must not be empty.');
    }
    if (stepsCompleted < 0) {
      errors.add('stepsCompleted must be >= 0.');
    }
    if (stepsTotal < 0) {
      errors.add('stepsTotal must be >= 0.');
    }
    if (stepsCompleted > stepsTotal) {
      errors.add(
          'stepsCompleted ($stepsCompleted) exceeds stepsTotal ($stepsTotal).');
    }
    if (stepsCompleted < stepsTotal) {
      warnings.add(
          'Partial execution: $stepsCompleted of $stepsTotal steps completed. '
          'EditorController should handle partial state gracefully.');
    }

    final seenIds = <String>{};
    for (final cmd in commands) {
      if (cmd.commandId.trim().isEmpty) {
        errors.add('A CommandObject has an empty commandId.');
      } else if (!seenIds.add(cmd.commandId)) {
        errors.add('Duplicate commandId "${cmd.commandId}" in output.');
      }
      if (cmd.commandType.trim().isEmpty) {
        errors.add('CommandObject "${cmd.commandId}" has empty commandType.');
      }
      if (cmd.sourceEngine != _engineId) {
        warnings.add(
            'CommandObject "${cmd.commandId}" has unexpected sourceEngine '
            '"${cmd.sourceEngine}" (expected "$_engineId").');
      }
      if (cmd.priority < 1 || cmd.priority > 10) {
        warnings.add(
            'CommandObject "${cmd.commandId}" priority ${cmd.priority} '
            'is outside [1, 10].');
      }
      _validateCommandPayloadSafety(cmd, errors, warnings);
    }

    if (errors.isEmpty) {
      return ExecutionValidationResult.ok(warnings: warnings);
    }
    return ExecutionValidationResult.fail(errors, warnings: warnings);
  }

  // ── Private helpers ───────────────────────────────────────────

  List<CommandObject> _buildCommandsForAction({
    required AutomationAction action,
    required int index,
    required int effectivePriority,
    required DateTime now,
  }) {
    final commandId = _IdGen.next('cmd');
    final clampedPriority = effectivePriority.clamp(1, 10);

    return [
      CommandObject(
        commandId: commandId,
        commandType: action.actionType,
        target: action.targetLayerId,
        payload: Map<String, dynamic>.unmodifiable({
          ...action.parameters,
          'actionId': action.actionId,
          'stepIndex': index,
        }),
        timestamp: now,
        priority: clampedPriority,
        requiresConfirmation: action.requiresConfirmation,
        sourceEngine: _engineId,
      ),
    ];
  }

  void _validateActionParameters(
      AutomationAction action,
      List<String> errors,
      List<String> warnings) {
    const forbidden = [
      'layerengine', 'historyengine', 'renderengine',
      'storageengine', 'aiengine', 'templateengine',
      'syncengine', 'exportengine', 'buildcontext',
      'canvas', 'widget',
    ];

    for (final key in action.parameters.keys) {
      if (forbidden.contains(key.toLowerCase())) {
        errors.add(
            'Action "${action.actionId}" parameter "$key" references a '
            'forbidden engine or context object.');
      }
    }

    switch (action.actionType) {
      case 'move_layer':
        final hasDx = action.parameters.containsKey('dx');
        final hasDy = action.parameters.containsKey('dy');
        if (!hasDx && !hasDy) {
          warnings.add(
              'Action "${action.actionId}" (move_layer) has no dx/dy; '
              'EditorController will request position.');
        }
        break;
      case 'resize_layer':
        final hasW = action.parameters.containsKey('width');
        final hasH = action.parameters.containsKey('height');
        final hasSF = action.parameters.containsKey('scaleFactor');
        if (!hasW && !hasH && !hasSF) {
          warnings.add(
              'Action "${action.actionId}" (resize_layer) has no size params; '
              'EditorController will request dimensions.');
        }
        break;
      case 'rotate_layer':
        if (!action.parameters.containsKey('angleDegrees')) {
          warnings.add(
              'Action "${action.actionId}" (rotate_layer) has no angleDegrees.');
        }
        break;
      case 'change_color':
        if (!action.parameters.containsKey('color')) {
          warnings.add(
              'Action "${action.actionId}" (change_color) has no color value.');
        }
        break;
      case 'change_font':
        final hasFamily = action.parameters.containsKey('fontFamily');
        final hasSize = action.parameters.containsKey('fontSize');
        if (!hasFamily && !hasSize) {
          warnings.add(
              'Action "${action.actionId}" (change_font) has no fontFamily '
              'or fontSize.');
        }
        break;
      case 'add_layer':
        if (!action.parameters.containsKey('layerType')) {
          warnings.add(
              'Action "${action.actionId}" (add_layer) has no layerType; '
              'EditorController will request type.');
        }
        break;
      default:
        break;
    }
  }

  void _validateCommandPayloadSafety(
      CommandObject cmd,
      List<String> errors,
      List<String> warnings) {
    const forbidden = [
      'layerengine', 'historyengine', 'renderengine',
      'storageengine', 'buildcontext', 'canvas', 'widget',
    ];
    for (final key in cmd.payload.keys) {
      if (forbidden.contains(key.toLowerCase())) {
        errors.add(
            'CommandObject "${cmd.commandId}" payload key "$key" '
            'references a forbidden engine or context object.');
      }
    }
    for (final entry in cmd.payload.entries) {
      final v = entry.value;
      final safe = v == null ||
          v is num ||
          v is String ||
          v is bool ||
          (v is List &&
              v.every((e) => e is num || e is String || e is bool)) ||
          v is Map<String, dynamic>;
      if (!safe) {
        errors.add(
            'CommandObject "${cmd.commandId}" payload["${entry.key}"] '
            'contains non-serialisable type ${v.runtimeType}.');
      }
    }
  }
}
