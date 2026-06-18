// ignore_for_file: avoid_catches_without_on_clauses

import 'dart:math';
import 'automation_engine.dart' show CommandObject;

// ── Workflow step state ───────────────────────────────────────
enum WorkflowStepState {
  pending,
  active,
  completed,
  skipped,
  failed,
  blocked,
}

// ── Workflow lifecycle state ──────────────────────────────────
enum WorkflowLifecycle {
  notStarted,
  inProgress,
  paused,
  completed,
  cancelled,
  failed,
}

// ── Trigger events ────────────────────────────────────────────
enum WorkflowTriggerEvent {
  userAction,
  systemEvent,
  timerElapsed,
  conditionMet,
  externalSignal,
  stepCompleted,
  stepFailed,
  cancel,
}

// ── UI hint types ─────────────────────────────────────────────
enum UiHintType {
  none,
  showPanel,
  highlightZone,
  showTooltip,
  requestInput,
  showConfirmation,
  showProgress,
  dismiss,
}

// ── UI hint — read-only suggestion for EditorController ───────
// WorkflowEngine never touches UI directly.
class UiHint {
  final UiHintType type;
  final String? message;
  final String? targetZoneId;
  final Map<String, dynamic> parameters;

  const UiHint({
    required this.type,
    this.message,
    this.targetZoneId,
    this.parameters = const {},
  });

  static const UiHint none = UiHint(type: UiHintType.none);

  Map<String, dynamic> toMap() => {
        'type': type.name,
        'message': message,
        'targetZoneId': targetZoneId,
        'parameters': parameters,
      };
}

// ── Workflow step definition ───────────────────────────────────
class WorkflowStep {
  final String stepId;
  final String title;
  final String description;
  final int order;
  final bool optional;
  final List<String> requiredPreconditions;
  final List<String> actionTypes;
  final UiHint hint;

  const WorkflowStep({
    required this.stepId,
    required this.title,
    required this.description,
    required this.order,
    this.optional = false,
    this.requiredPreconditions = const [],
    this.actionTypes = const [],
    this.hint = UiHint.none,
  });
}

// ── Workflow definition ────────────────────────────────────────
class WorkflowDefinition {
  final String workflowId;
  final String name;
  final String description;
  final List<WorkflowStep> steps;
  final bool allowSkipOptional;

  const WorkflowDefinition({
    required this.workflowId,
    required this.name,
    required this.description,
    required this.steps,
    this.allowSkipOptional = true,
  });

  WorkflowStep? stepById(String stepId) {
    try {
      return steps.firstWhere((s) => s.stepId == stepId);
    } catch (_) {
      return null;
    }
  }

  WorkflowStep? get firstStep =>
      steps.isEmpty ? null : steps.reduce((a, b) => a.order < b.order ? a : b);
}

// ── User context — read-only editor state snapshot ────────────
class WorkflowUserContext {
  final String? activeDesignId;
  final String? selectedLayerId;
  final List<String> completedStepIds;
  final Map<String, dynamic> sessionData;

  const WorkflowUserContext({
    this.activeDesignId,
    this.selectedLayerId,
    this.completedStepIds = const [],
    this.sessionData = const {},
  });

  bool hasCompleted(String stepId) => completedStepIds.contains(stepId);
}

// ── WorkflowRequest ────────────────────────────────────────────
class WorkflowRequest {
  final String requestId;
  final String workflowId;
  final String? currentStepId;
  final WorkflowLifecycle currentState;
  final WorkflowUserContext userContext;
  final WorkflowTriggerEvent triggerEvent;
  final Map<String, dynamic> eventPayload;

  const WorkflowRequest({
    required this.requestId,
    required this.workflowId,
    this.currentStepId,
    required this.currentState,
    required this.userContext,
    required this.triggerEvent,
    this.eventPayload = const {},
  });
}

// ── WorkflowResponse — mandatory output contract ──────────────
class WorkflowResponse {
  final bool success;
  final String workflowId;
  final WorkflowStep? nextStep;
  final UiHint uiHint;
  final List<CommandObject> commands;
  final WorkflowLifecycle newLifecycleState;
  final List<String> errors;
  final List<String> warnings;
  final WorkflowProgressReport progress;

  const WorkflowResponse({
    required this.success,
    required this.workflowId,
    this.nextStep,
    required this.uiHint,
    required this.commands,
    required this.newLifecycleState,
    this.errors = const [],
    this.warnings = const [],
    required this.progress,
  });

  factory WorkflowResponse.failure({
    required String workflowId,
    required List<String> errors,
    List<String> warnings = const [],
    WorkflowLifecycle state = WorkflowLifecycle.failed,
  }) =>
      WorkflowResponse(
        success: false,
        workflowId: workflowId,
        uiHint: UiHint.none,
        commands: const [],
        newLifecycleState: state,
        errors: errors,
        warnings: warnings,
        progress: WorkflowProgressReport.empty(),
      );
}

// ── Progress report ───────────────────────────────────────────
class WorkflowProgressReport {
  final int totalSteps;
  final int completedSteps;
  final int skippedSteps;
  final double percentComplete;

  const WorkflowProgressReport({
    required this.totalSteps,
    required this.completedSteps,
    required this.skippedSteps,
    required this.percentComplete,
  });

  factory WorkflowProgressReport.empty() => const WorkflowProgressReport(
        totalSteps: 0,
        completedSteps: 0,
        skippedSteps: 0,
        percentComplete: 0.0,
      );

  factory WorkflowProgressReport.compute({
    required List<WorkflowStep> allSteps,
    required List<String> completedIds,
    required List<String> skippedIds,
  }) {
    final total = allSteps.length;
    final completed = completedIds.length;
    final skipped = skippedIds.length;
    final pct = total == 0 ? 0.0 : ((completed + skipped) / total * 100).clamp(0.0, 100.0);
    return WorkflowProgressReport(
      totalSteps: total,
      completedSteps: completed,
      skippedSteps: skipped,
      percentComplete: pct,
    );
  }
}

// ── Step validation result ────────────────────────────────────
class StepValidationResult {
  final bool valid;
  final List<String> errors;
  final List<String> warnings;
  final List<String> unmetPreconditions;

  const StepValidationResult.ok({this.warnings = const []})
      : valid = true,
        errors = const [],
        unmetPreconditions = const [];

  const StepValidationResult.fail(this.errors,
      {this.warnings = const [], this.unmetPreconditions = const []})
      : valid = false;
}

// ── State transition ──────────────────────────────────────────
class StateTransition {
  final WorkflowLifecycle from;
  final WorkflowLifecycle to;
  final String? stepId;
  final String reason;
  final DateTime transitionedAt;

  const StateTransition({
    required this.from,
    required this.to,
    this.stepId,
    required this.reason,
    required this.transitionedAt,
  });
}

// ── ID generator ──────────────────────────────────────────────
class _WfIdGen {
  static final Random _rng = Random.secure();

  static String next(String prefix) {
    final bytes = List<int>.generate(6, (_) => _rng.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '$prefix-$hex-${DateTime.now().microsecondsSinceEpoch}';
  }
}

// ── Built-in workflow registry ────────────────────────────────
class _WorkflowRegistry {
  static final Map<String, WorkflowDefinition> _definitions = {
    'new_design': WorkflowDefinition(
      workflowId: 'new_design',
      name: 'New Design Setup',
      description: 'Guided flow for starting a new design from scratch.',
      steps: [
        const WorkflowStep(
          stepId: 'choose_canvas',
          title: 'Choose Canvas Size',
          description: 'Select the canvas ratio and dimensions.',
          order: 1,
          actionTypes: ['apply_template'],
          hint: UiHint(
            type: UiHintType.showPanel,
            message: 'Select a canvas size to begin.',
            targetZoneId: 'canvas_size_panel',
          ),
        ),
        const WorkflowStep(
          stepId: 'add_background',
          title: 'Add Background',
          description: 'Set a background colour or image for your design.',
          order: 2,
          optional: true,
          actionTypes: ['add_layer', 'change_color'],
          hint: UiHint(
            type: UiHintType.highlightZone,
            message: 'Add a background to your canvas.',
            targetZoneId: 'background_zone',
          ),
        ),
        const WorkflowStep(
          stepId: 'add_content',
          title: 'Add Content',
          description: 'Add text, images, or shapes.',
          order: 3,
          requiredPreconditions: ['choose_canvas'],
          actionTypes: ['add_layer'],
          hint: UiHint(
            type: UiHintType.showTooltip,
            message: 'Tap the + button to add your first element.',
          ),
        ),
        const WorkflowStep(
          stepId: 'review',
          title: 'Review Design',
          description: 'Review and finalise your design.',
          order: 4,
          requiredPreconditions: ['add_content'],
          actionTypes: [],
          hint: UiHint(
            type: UiHintType.showConfirmation,
            message: 'Your design looks great! Ready to export?',
          ),
        ),
      ],
    ),
    'template_apply': WorkflowDefinition(
      workflowId: 'template_apply',
      name: 'Apply Template',
      description: 'Guided flow for applying and customising a template.',
      steps: [
        const WorkflowStep(
          stepId: 'select_template',
          title: 'Select Template',
          description: 'Browse and choose a template.',
          order: 1,
          actionTypes: ['apply_template'],
          hint: UiHint(
            type: UiHintType.showPanel,
            message: 'Choose a template to start with.',
            targetZoneId: 'template_panel',
          ),
        ),
        const WorkflowStep(
          stepId: 'customise_text',
          title: 'Customise Text',
          description: 'Replace placeholder text with your own content.',
          order: 2,
          requiredPreconditions: ['select_template'],
          actionTypes: ['update_layer', 'change_font'],
          hint: UiHint(
            type: UiHintType.highlightZone,
            message: 'Tap any text element to edit it.',
            targetZoneId: 'text_layers',
          ),
        ),
        const WorkflowStep(
          stepId: 'customise_colors',
          title: 'Customise Colours',
          description: 'Adjust the colour scheme to match your brand.',
          order: 3,
          optional: true,
          requiredPreconditions: ['select_template'],
          actionTypes: ['change_color'],
          hint: UiHint(
            type: UiHintType.showPanel,
            message: 'Pick your brand colours.',
            targetZoneId: 'color_panel',
          ),
        ),
        const WorkflowStep(
          stepId: 'replace_images',
          title: 'Replace Images',
          description: 'Swap placeholder images with your own.',
          order: 4,
          optional: true,
          requiredPreconditions: ['select_template'],
          actionTypes: ['update_layer'],
          hint: UiHint(
            type: UiHintType.highlightZone,
            message: 'Tap any image to replace it.',
            targetZoneId: 'image_layers',
          ),
        ),
        const WorkflowStep(
          stepId: 'finalise',
          title: 'Finalise',
          description: 'Review and export your customised design.',
          order: 5,
          requiredPreconditions: ['customise_text'],
          actionTypes: [],
          hint: UiHint(
            type: UiHintType.showProgress,
            message: 'Design ready! You can now export.',
          ),
        ),
      ],
    ),
    'batch_edit': WorkflowDefinition(
      workflowId: 'batch_edit',
      name: 'Batch Layer Edit',
      description: 'Guided flow for editing multiple layers at once.',
      steps: [
        const WorkflowStep(
          stepId: 'select_layers',
          title: 'Select Layers',
          description: 'Choose the layers you want to edit.',
          order: 1,
          actionTypes: ['select_layer'],
          hint: UiHint(
            type: UiHintType.showTooltip,
            message: 'Select one or more layers to edit.',
          ),
        ),
        const WorkflowStep(
          stepId: 'apply_batch',
          title: 'Apply Changes',
          description: 'Choose the operation to apply to selected layers.',
          order: 2,
          requiredPreconditions: ['select_layers'],
          actionTypes: [
            'batch_update', 'change_color', 'change_font',
            'show_layer', 'hide_layer', 'lock_layer',
          ],
          hint: UiHint(
            type: UiHintType.showPanel,
            message: 'Choose an operation to apply to all selected layers.',
            targetZoneId: 'batch_panel',
          ),
        ),
        const WorkflowStep(
          stepId: 'confirm_batch',
          title: 'Confirm',
          description: 'Review batch changes before applying.',
          order: 3,
          requiredPreconditions: ['apply_batch'],
          actionTypes: [],
          hint: UiHint(
            type: UiHintType.showConfirmation,
            message: 'Apply these changes to all selected layers?',
          ),
        ),
      ],
    ),
  };

  static WorkflowDefinition? resolve(String workflowId) =>
      _definitions[workflowId];

  static bool contains(String workflowId) =>
      _definitions.containsKey(workflowId);

  static List<String> get knownIds => _definitions.keys.toList();
}

// ── Allowed lifecycle transitions ─────────────────────────────
const Map<WorkflowLifecycle, Set<WorkflowLifecycle>> _kValidTransitions = {
  WorkflowLifecycle.notStarted:  {WorkflowLifecycle.inProgress, WorkflowLifecycle.cancelled},
  WorkflowLifecycle.inProgress:  {WorkflowLifecycle.paused, WorkflowLifecycle.completed, WorkflowLifecycle.cancelled, WorkflowLifecycle.failed},
  WorkflowLifecycle.paused:      {WorkflowLifecycle.inProgress, WorkflowLifecycle.cancelled},
  WorkflowLifecycle.completed:   {},
  WorkflowLifecycle.cancelled:   {},
  WorkflowLifecycle.failed:      {WorkflowLifecycle.inProgress},
};

// ── WorkflowEngine ─────────────────────────────────────────────
class WorkflowEngine {
  static const String _engineId = 'WorkflowEngine';

  // Internal transition log (read-only, no state mutation outside).
  final List<StateTransition> _transitionLog = [];

  List<StateTransition> get transitionLog =>
      List.unmodifiable(_transitionLog);

  // ── startWorkflow ─────────────────────────────────────────────

  WorkflowResponse startWorkflow(WorkflowRequest request) {
    try {
      if (!_WorkflowRegistry.contains(request.workflowId)) {
        return WorkflowResponse.failure(
          workflowId: request.workflowId,
          errors: [
            'Workflow "${request.workflowId}" is not registered. '
                'Known: ${_WorkflowRegistry.knownIds.join(', ')}.'
          ],
        );
      }

      if (request.currentState != WorkflowLifecycle.notStarted) {
        return WorkflowResponse.failure(
          workflowId: request.workflowId,
          errors: [
            'startWorkflow requires currentState=notStarted '
                '(got ${request.currentState.name}).'
          ],
        );
      }

      final definition = _WorkflowRegistry.resolve(request.workflowId)!;
      final firstStep = definition.firstStep;
      if (firstStep == null) {
        return WorkflowResponse.failure(
          workflowId: request.workflowId,
          errors: ['Workflow "${request.workflowId}" has no steps.'],
        );
      }

      final transition = transitionState(
        from: WorkflowLifecycle.notStarted,
        to: WorkflowLifecycle.inProgress,
        stepId: firstStep.stepId,
        reason: 'Workflow started.',
      );

      final instruction = generateNextInstruction(
        definition: definition,
        targetStep: firstStep,
        userContext: request.userContext,
      );

      final progress = WorkflowProgressReport.compute(
        allSteps: definition.steps,
        completedIds: request.userContext.completedStepIds,
        skippedIds: [],
      );

      return WorkflowResponse(
        success: true,
        workflowId: request.workflowId,
        nextStep: firstStep,
        uiHint: instruction.uiHint,
        commands: instruction.commands,
        newLifecycleState: transition.to,
        warnings: instruction.warnings,
        progress: progress,
      );
    } catch (e) {
      return WorkflowResponse.failure(
        workflowId: request.workflowId,
        errors: ['Unexpected error starting workflow: $e'],
      );
    }
  }

  // ── continueWorkflow ──────────────────────────────────────────

  WorkflowResponse continueWorkflow(WorkflowRequest request) {
    try {
      if (!_WorkflowRegistry.contains(request.workflowId)) {
        return WorkflowResponse.failure(
          workflowId: request.workflowId,
          errors: ['Workflow "${request.workflowId}" is not registered.'],
        );
      }

      if (request.currentState == WorkflowLifecycle.completed ||
          request.currentState == WorkflowLifecycle.cancelled) {
        return WorkflowResponse.failure(
          workflowId: request.workflowId,
          errors: [
            'Workflow is already ${request.currentState.name}; '
                'cannot continue.'
          ],
          state: request.currentState,
        );
      }

      final definition = _WorkflowRegistry.resolve(request.workflowId)!;

      // Resolve current step.
      final currentStep = request.currentStepId != null
          ? definition.stepById(request.currentStepId!)
          : null;

      // Validate the step before transitioning.
      if (currentStep != null) {
        final stepValidation = validateStep(
          step: currentStep,
          userContext: request.userContext,
          definition: definition,
        );
        if (!stepValidation.valid) {
          return WorkflowResponse(
            success: false,
            workflowId: request.workflowId,
            nextStep: currentStep,
            uiHint: currentStep.hint,
            commands: const [],
            newLifecycleState: request.currentState,
            errors: stepValidation.errors,
            warnings: stepValidation.warnings,
            progress: WorkflowProgressReport.compute(
              allSteps: definition.steps,
              completedIds: request.userContext.completedStepIds,
              skippedIds: [],
            ),
          );
        }
      }

      // Determine next step.
      final nextStep = _resolveNextStep(
        definition: definition,
        currentStepId: request.currentStepId,
        userContext: request.userContext,
        triggerEvent: request.triggerEvent,
      );

      // Determine new lifecycle state.
      final WorkflowLifecycle newState;
      if (nextStep == null) {
        newState = WorkflowLifecycle.completed;
      } else {
        newState = WorkflowLifecycle.inProgress;
      }

      final transition = transitionState(
        from: request.currentState,
        to: newState,
        stepId: nextStep?.stepId,
        reason: nextStep != null
            ? 'Advancing to step "${nextStep.stepId}".'
            : 'All steps completed.',
      );

      if (nextStep == null) {
        final progress = WorkflowProgressReport.compute(
          allSteps: definition.steps,
          completedIds: [
            ...request.userContext.completedStepIds,
            if (request.currentStepId != null) request.currentStepId!,
          ],
          skippedIds: [],
        );
        return WorkflowResponse(
          success: true,
          workflowId: request.workflowId,
          nextStep: null,
          uiHint: const UiHint(
            type: UiHintType.dismiss,
            message: 'Workflow complete!',
          ),
          commands: const [],
          newLifecycleState: transition.to,
          progress: progress,
        );
      }

      final instruction = generateNextInstruction(
        definition: definition,
        targetStep: nextStep,
        userContext: request.userContext,
      );

      final progress = WorkflowProgressReport.compute(
        allSteps: definition.steps,
        completedIds: [
          ...request.userContext.completedStepIds,
          if (request.currentStepId != null) request.currentStepId!,
        ],
        skippedIds: [],
      );

      return WorkflowResponse(
        success: true,
        workflowId: request.workflowId,
        nextStep: nextStep,
        uiHint: instruction.uiHint,
        commands: instruction.commands,
        newLifecycleState: transition.to,
        warnings: instruction.warnings,
        progress: progress,
      );
    } catch (e) {
      return WorkflowResponse.failure(
        workflowId: request.workflowId,
        errors: ['Unexpected error in continueWorkflow: $e'],
      );
    }
  }

  // ── validateStep ──────────────────────────────────────────────

  StepValidationResult validateStep({
    required WorkflowStep step,
    required WorkflowUserContext userContext,
    required WorkflowDefinition definition,
  }) {
    final errors = <String>[];
    final warnings = <String>[];
    final unmet = <String>[];

    if (step.stepId.trim().isEmpty) {
      errors.add('WorkflowStep.stepId must not be empty.');
    }
    if (step.title.trim().isEmpty) {
      warnings.add('WorkflowStep "${step.stepId}" has no title.');
    }

    // Check preconditions.
    for (final precondition in step.requiredPreconditions) {
      if (!userContext.hasCompleted(precondition)) {
        unmet.add(precondition);
      }
    }
    if (unmet.isNotEmpty) {
      errors.add(
          'Step "${step.stepId}" has unmet preconditions: '
          '${unmet.join(', ')}. Complete those steps first.');
    }

    // Active design required for most steps.
    if (step.actionTypes.isNotEmpty &&
        userContext.activeDesignId == null) {
      warnings.add(
          'Step "${step.stepId}" has actionTypes but no activeDesignId '
          'in context; EditorController should confirm design is open.');
    }

    if (errors.isEmpty) {
      return StepValidationResult.ok(warnings: warnings);
    }
    return StepValidationResult.fail(errors,
        warnings: warnings, unmetPreconditions: unmet);
  }

  // ── transitionState ───────────────────────────────────────────

  StateTransition transitionState({
    required WorkflowLifecycle from,
    required WorkflowLifecycle to,
    String? stepId,
    required String reason,
  }) {
    final allowed = _kValidTransitions[from] ?? {};
    final transition = StateTransition(
      from: from,
      to: allowed.contains(to) ? to : from, // guard: keep current if invalid
      stepId: stepId,
      reason: allowed.contains(to)
          ? reason
          : 'Transition $from → $to is not allowed; remaining in $from.',
      transitionedAt: DateTime.now().toUtc(),
    );
    _transitionLog.add(transition);
    return transition;
  }

  // ── generateNextInstruction ───────────────────────────────────

  _StepInstruction generateNextInstruction({
    required WorkflowDefinition definition,
    required WorkflowStep targetStep,
    required WorkflowUserContext userContext,
  }) {
    final warnings = <String>[];
    final commands = <CommandObject>[];
    final now = DateTime.now().toUtc();

    // Build one CommandObject per actionType in the step.
    for (int i = 0; i < targetStep.actionTypes.length; i++) {
      final actionType = targetStep.actionTypes[i];
      commands.add(CommandObject(
        commandId: _WfIdGen.next('wf-cmd'),
        commandType: actionType,
        target: userContext.selectedLayerId,
        payload: Map<String, dynamic>.unmodifiable({
          'stepId': targetStep.stepId,
          'workflowId': definition.workflowId,
          'stepOrder': targetStep.order,
          'actionIndex': i,
        }),
        timestamp: now.add(Duration(microseconds: i)),
        priority: 5,
        requiresConfirmation: false,
        sourceEngine: _engineId,
      ));
    }

    // No commands for pure UI/review steps — that is intentional.
    if (commands.isEmpty && targetStep.actionTypes.isNotEmpty) {
      warnings.add(
          'Step "${targetStep.stepId}" declared ${targetStep.actionTypes.length} '
          'actionType(s) but generated no commands; check step configuration.');
    }

    return _StepInstruction(
      uiHint: targetStep.hint,
      commands: commands,
      warnings: warnings,
    );
  }

  // ── Private helpers ───────────────────────────────────────────

  WorkflowStep? _resolveNextStep({
    required WorkflowDefinition definition,
    required String? currentStepId,
    required WorkflowUserContext userContext,
    required WorkflowTriggerEvent triggerEvent,
  }) {
    if (triggerEvent == WorkflowTriggerEvent.cancel) return null;

    final ordered = List<WorkflowStep>.from(definition.steps)
      ..sort((a, b) => a.order.compareTo(b.order));

    if (currentStepId == null) {
      return ordered.isEmpty ? null : ordered.first;
    }

    final currentIndex =
        ordered.indexWhere((s) => s.stepId == currentStepId);
    if (currentIndex < 0) return ordered.isEmpty ? null : ordered.first;

    // Walk forward; skip optional steps whose preconditions are unmet.
    for (int i = currentIndex + 1; i < ordered.length; i++) {
      final candidate = ordered[i];

      if (userContext.hasCompleted(candidate.stepId)) continue;

      final unmetPreconditions = candidate.requiredPreconditions
          .where((p) => !userContext.hasCompleted(p))
          .toList();

      if (unmetPreconditions.isNotEmpty) {
        if (candidate.optional && definition.allowSkipOptional) continue;
        // Return blocked step so EditorController can surface the error.
        return candidate;
      }

      return candidate;
    }

    return null; // All steps done → workflow complete.
  }
}

// ── Internal step instruction ─────────────────────────────────
class _StepInstruction {
  final UiHint uiHint;
  final List<CommandObject> commands;
  final List<String> warnings;

  const _StepInstruction({
    required this.uiHint,
    required this.commands,
    required this.warnings,
  });
}
