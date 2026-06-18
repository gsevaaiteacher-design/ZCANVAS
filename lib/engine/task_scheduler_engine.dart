// engines/task_scheduler_engine.dart
//
// PHASE-9 — TaskSchedulerEngine
//
// ===========================================================================
// OWNERSHIP CONTRACT
// ===========================================================================
//
// WHAT THIS FILE CAN DO:
//   • Analyze individual tasks and their declared properties
//   • Calculate priority scores for tasks (advisory values only)
//   • Analyze task dependencies and detect ordering constraints
//   • Build execution schedule plans (ordering recommendations only)
//   • Recommend retry strategies when a task has failed or is at risk
//   • Recommend cancellation when a task is unsafe or unresolvable
//   • Generate TaskSchedulePlan — a read-only advisory output
//   • Support future voice, robot, and AI copilot task planning
//
// WHAT THIS FILE CANNOT DO:
//   ❌ Execute any task or plan
//   ❌ Own or manage any task queue
//   ❌ Mutate application state
//   ❌ Create tasks
//   ❌ Modify or access LayerEngine
//   ❌ Modify or access HistoryEngine
//   ❌ Modify or access StorageEngine
//   ❌ Modify or access RenderEngine
//   ❌ Modify or access Canvas
//   ❌ Issue commands to other engines
//   ❌ Block execution of other engines
//
// WHAT THIS FILE CAN COMMUNICATE WITH:
//   ✔ EditorController (advisory / plan delivery only)
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
// AUTHORITY: TASK PRIORITIZATION AND EXECUTION PLANNING AUTHORITY.
//   This engine creates PLANS. It does not execute plans.
//   It does not own tasks. It does not create tasks.
//   EditorController remains the only execution authority.
//
// FAILURE ISOLATION:
//   If this engine fails, the editor MUST continue working uninterrupted.
//   The core system MUST NEVER depend on this engine.
// ===========================================================================

// ---------------------------------------------------------------------------
// SECTION 1 — ENUMERATIONS
// ---------------------------------------------------------------------------

/// Supported task types for scheduling analysis.
enum ScheduledTaskType {
  /// AI inference or processing task.
  aiTask,

  /// File or asset export task.
  exportTask,

  /// Data synchronization task.
  syncTask,

  /// Template rendering or loading task.
  templateTask,

  /// Third-party plugin execution task.
  pluginTask,

  /// Multi-step workflow task.
  workflowTask,

  /// Automated pipeline task.
  automationTask,

  /// Voice assistant processing task.
  voiceTask,

  /// Robot assistant processing task.
  robotTask,

  /// Placeholder for future task types.
  futureTask,
}

/// Declared priority tier of a task request.
/// Higher tiers receive higher base priority scores.
enum TaskPriorityTier {
  /// Lowest priority — run only when all higher-priority tasks are complete.
  background,

  /// Normal operating priority.
  normal,

  /// Above-normal; preferred over normal tasks.
  elevated,

  /// High priority; must complete before background/normal work.
  high,

  /// Highest priority; time-critical path.
  critical,
}

/// Reason category for a scheduling warning.
enum SchedulingWarningKind {
  /// A circular dependency was detected in the task graph.
  cyclicDependency,

  /// A declared dependency task is missing from the submitted batch.
  missingDependency,

  /// A task's priority is incompatible with its declared dependencies.
  priorityInversion,

  /// A task's resource requirements exceed safe advisory limits.
  resourceOverLimit,

  /// A task has been recommended for cancellation.
  cancellationRecommended,

  /// A task has been recommended for retry.
  retryRecommended,

  /// A general advisory notice.
  advisory,
}

/// Reason categories for a retry recommendation.
enum RetryReason {
  /// Previous execution exceeded declared duration bounds.
  timeout,

  /// Transient resource pressure made execution unsafe.
  resourcePressure,

  /// A dependency was not yet satisfied.
  dependencyNotReady,

  /// Task type benefits from a deferred retry (e.g. network sync).
  deferredRetry,

  /// Generic retry trigger.
  generic,
}

/// Reason categories for a cancellation recommendation.
enum CancellationReason {
  /// Unresolvable cyclic dependency detected.
  cyclicDependency,

  /// Resource requirements exceed all device advisory limits.
  resourceExceeded,

  /// Required dependencies are permanently missing.
  missingDependencies,

  /// Task type is blocked by policy (e.g. thermal critical state).
  policyBlocked,

  /// Caller-provided external reason.
  externalRequest,
}

// ---------------------------------------------------------------------------
// SECTION 2 — RESOURCE REQUIREMENTS DESCRIPTOR
// ---------------------------------------------------------------------------

/// Declared resource requirements for a task.
/// These are advisory estimates — the engine uses them for scheduling
/// analysis only; it does not enforce or execute resource limits.
final class TaskResourceRequirements {
  const TaskResourceRequirements({
    this.estimatedMemoryMb = 0,
    this.estimatedCpuPercent = 0,
    this.estimatedDurationSeconds = 0,
    this.requiresNetwork = false,
    this.requiresGpu = false,
    this.isBackgroundable = false,
    this.isCancellable = true,
    this.additionalRequirements = const {},
  });

  /// Estimated peak memory in megabytes.
  final double estimatedMemoryMb;

  /// Estimated peak CPU utilisation (0–100).
  final double estimatedCpuPercent;

  /// Estimated task duration in seconds.
  final double estimatedDurationSeconds;

  /// True if the task needs network connectivity.
  final bool requiresNetwork;

  /// True if the task needs GPU acceleration.
  final bool requiresGpu;

  /// True if the task can safely run in the background.
  final bool isBackgroundable;

  /// True if the task can be cancelled mid-execution.
  final bool isCancellable;

  /// Additional requirements for future expansion.
  final Map<String, Object?> additionalRequirements;
}

// ---------------------------------------------------------------------------
// SECTION 3 — INPUT CONTRACT
// ---------------------------------------------------------------------------

/// The sole input type accepted by TaskSchedulerEngine.
final class TaskRequest {
  const TaskRequest({
    required this.taskId,
    required this.taskType,
    required this.priority,
    this.resourceRequirements = const TaskResourceRequirements(),
    this.dependencies = const [],
    this.metadata = const {},
    this.submittedAt,
    this.maxRetryCount = 3,
    this.retryDelaySeconds = 5,
  });

  /// Unique identifier for this task. Must not be empty.
  final String taskId;

  /// The category of task being scheduled.
  final ScheduledTaskType taskType;

  /// Declared priority tier for this task.
  final TaskPriorityTier priority;

  /// Declared resource requirements for scheduling analysis.
  final TaskResourceRequirements resourceRequirements;

  /// IDs of tasks that must complete before this task may begin.
  final List<String> dependencies;

  /// Caller-supplied metadata; engine stores as-is.
  final Map<String, Object?> metadata;

  /// UTC timestamp when this task was submitted. Defaults to now if null.
  final DateTime? submittedAt;

  /// Maximum number of retry attempts the caller permits.
  final int maxRetryCount;

  /// Seconds to wait between retry attempts.
  final double retryDelaySeconds;

  @override
  String toString() =>
      'TaskRequest(id: $taskId, type: ${taskType.name}, '
      'priority: ${priority.name}, deps: ${dependencies.length})';
}

// ---------------------------------------------------------------------------
// SECTION 4 — SCHEDULING ANALYSIS INTERMEDIATES
// ---------------------------------------------------------------------------

/// Analysis result for a single task.
final class TaskAnalysis {
  const TaskAnalysis({
    required this.taskId,
    required this.taskType,
    required this.declaredPriority,
    required this.computedPriorityScore,
    this.isBackgroundable = false,
    this.isCancellable = true,
    this.estimatedDurationSeconds = 0,
    this.hasResourceConcern = false,
    this.analysisNotes = const [],
  });

  final String taskId;
  final ScheduledTaskType taskType;
  final TaskPriorityTier declaredPriority;

  /// Computed numeric priority score (0–100). Higher = schedule earlier.
  final double computedPriorityScore;

  final bool isBackgroundable;
  final bool isCancellable;
  final double estimatedDurationSeconds;
  final bool hasResourceConcern;

  /// Advisory notes from the analysis step.
  final List<String> analysisNotes;
}

/// Result of dependency analysis for a task batch.
final class DependencyAnalysis {
  const DependencyAnalysis({
    required this.taskId,
    this.resolvedDependencies = const [],
    this.missingDependencies = const [],
    this.cyclicDependencies = const [],
    this.dependencyDepth = 0,
    this.isResolvable = true,
  });

  /// The task this analysis describes.
  final String taskId;

  /// Dependency IDs that are present in the submitted batch.
  final List<String> resolvedDependencies;

  /// Dependency IDs declared but absent from the submitted batch.
  final List<String> missingDependencies;

  /// Task IDs involved in a detected cycle, if any.
  final List<String> cyclicDependencies;

  /// Depth of this task in the dependency graph (0 = no dependencies).
  final int dependencyDepth;

  /// False when dependencies cannot be resolved (cycle or missing required deps).
  final bool isResolvable;
}

/// A scheduling warning attached to a TaskSchedulePlan.
final class SchedulingWarning {
  const SchedulingWarning({
    required this.warningId,
    required this.kind,
    required this.message,
    this.affectedTaskIds = const [],
    this.context = const {},
  });

  final String warningId;
  final SchedulingWarningKind kind;
  final String message;

  /// Task IDs to which this warning applies.
  final List<String> affectedTaskIds;

  final Map<String, Object?> context;

  @override
  String toString() =>
      'SchedulingWarning(id: $warningId, kind: ${kind.name}, msg: $message)';
}

/// A retry recommendation for a specific task.
final class RetryRecommendation {
  const RetryRecommendation({
    required this.taskId,
    required this.reason,
    required this.recommendedRetryCount,
    required this.recommendedDelaySeconds,
    this.notes = '',
  });

  final String taskId;
  final RetryReason reason;

  /// Advisory number of retry attempts. EditorController decides whether to apply.
  final int recommendedRetryCount;

  /// Advisory delay in seconds between attempts.
  final double recommendedDelaySeconds;

  /// Human-readable advisory note.
  final String notes;

  @override
  String toString() =>
      'RetryRecommendation(task: $taskId, reason: ${reason.name}, '
      'retries: $recommendedRetryCount, delay: ${recommendedDelaySeconds}s)';
}

/// A cancellation recommendation for a specific task.
final class CancellationRecommendation {
  const CancellationRecommendation({
    required this.taskId,
    required this.reason,
    required this.message,
    this.blockedTaskIds = const [],
  });

  final String taskId;
  final CancellationReason reason;

  /// Advisory explanation for EditorController.
  final String message;

  /// IDs of tasks that would be unblocked if this task is cancelled.
  final List<String> blockedTaskIds;

  @override
  String toString() =>
      'CancellationRecommendation(task: $taskId, reason: ${reason.name})';
}

// ---------------------------------------------------------------------------
// SECTION 5 — OUTPUT CONTRACT
// ---------------------------------------------------------------------------

/// The sole output type produced by TaskSchedulerEngine.
///
/// This plan is ADVISORY ONLY and NON-EXECUTABLE.
/// This engine does not own, execute, or queue any task.
/// EditorController decides whether and how to apply this plan.
final class TaskSchedulePlan {
  const TaskSchedulePlan({
    required this.planId,
    required this.generatedAt,
    this.recommendedExecutionOrder = const [],
    this.priorityMap = const {},
    this.dependencyGraph = const {},
    this.retryRecommendations = const [],
    this.cancellationRecommendations = const [],
    this.schedulingWarnings = const [],
    this.taskAnalyses = const [],
    this.dependencyAnalyses = const [],
    this.isEmpty = false,
  });

  /// Creates an empty plan returned when the engine encounters an error.
  factory TaskSchedulePlan.empty({String planId = 'empty'}) {
    return TaskSchedulePlan(
      planId: planId,
      generatedAt: DateTime.now(),
      isEmpty: true,
    );
  }

  /// Unique identifier for this plan.
  final String planId;

  /// UTC timestamp when this plan was generated.
  final DateTime generatedAt;

  /// Advisory ordered list of task IDs. Index 0 = schedule first.
  /// EditorController decides whether to follow this order.
  final List<String> recommendedExecutionOrder;

  /// Advisory map of taskId → computed priority score (0–100).
  final Map<String, double> priorityMap;

  /// Advisory dependency graph: taskId → list of prerequisite task IDs.
  final Map<String, List<String>> dependencyGraph;

  /// Advisory retry recommendations keyed by taskId.
  final List<RetryRecommendation> retryRecommendations;

  /// Advisory cancellation recommendations.
  final List<CancellationRecommendation> cancellationRecommendations;

  /// Scheduling warnings generated during plan construction.
  final List<SchedulingWarning> schedulingWarnings;

  /// Per-task analysis results for detailed advisory inspection.
  final List<TaskAnalysis> taskAnalyses;

  /// Per-task dependency analysis results.
  final List<DependencyAnalysis> dependencyAnalyses;

  /// True when the plan contains no meaningful scheduling data.
  final bool isEmpty;

  /// Convenience: true if any cyclic dependency was detected.
  bool get hasCyclicDependencies => schedulingWarnings
      .any((w) => w.kind == SchedulingWarningKind.cyclicDependency);

  /// Convenience: true if any task has missing dependencies.
  bool get hasMissingDependencies => schedulingWarnings
      .any((w) => w.kind == SchedulingWarningKind.missingDependency);

  @override
  String toString() =>
      'TaskSchedulePlan(id: $planId, tasks: ${recommendedExecutionOrder.length}, '
      'warnings: ${schedulingWarnings.length}, '
      'retries: ${retryRecommendations.length}, '
      'cancellations: ${cancellationRecommendations.length}, '
      'empty: $isEmpty)';
}

// ---------------------------------------------------------------------------
// SECTION 6 — TASK SCHEDULER ENGINE
// ---------------------------------------------------------------------------

/// TaskSchedulerEngine — PHASE-9 Governance Engine
///
/// TASK PRIORITIZATION AND EXECUTION PLANNING AUTHORITY.
///
/// This engine creates PLANS. It does not execute plans.
/// It does not own tasks. It does not create tasks.
///
/// LAWS:
///   1. PLANS ONLY — ordering, priority, retry, and cancellation recommendations.
///   2. NO EXECUTION — never triggers, queues, or approves any task.
///   3. NO TASK OWNERSHIP — tasks belong to the caller (EditorController).
///   4. FAILURE SAFE — every method is non-throwing; errors yield
///      empty/safe defaults so the editor continues uninterrupted.
///   5. FULLY INDEPENDENT — does not depend on RuntimeManagerEngine or
///      ResourcePolicyEngine; functions in complete isolation.
final class TaskSchedulerEngine {
  TaskSchedulerEngine({String engineId = 'task_scheduler_engine'})
      : _engineId = engineId;

  final String _engineId;
  int _planCounter = 0;
  int _warningCounter = 0;

  // -------------------------------------------------------------------------
  // SECTION 6A — BASE PRIORITY SCORES BY TASK TYPE AND TIER
  // -------------------------------------------------------------------------

  /// Base priority contribution from task type (0–40 points).
  static const Map<ScheduledTaskType, double> _taskTypeBaseScore = {
    ScheduledTaskType.voiceTask: 38,
    ScheduledTaskType.robotTask: 35,
    ScheduledTaskType.aiTask: 30,
    ScheduledTaskType.workflowTask: 28,
    ScheduledTaskType.automationTask: 25,
    ScheduledTaskType.exportTask: 22,
    ScheduledTaskType.pluginTask: 18,
    ScheduledTaskType.templateTask: 15,
    ScheduledTaskType.syncTask: 12,
    ScheduledTaskType.futureTask: 10,
  };

  /// Priority tier contribution (0–60 points).
  static const Map<TaskPriorityTier, double> _tierScore = {
    TaskPriorityTier.critical: 60,
    TaskPriorityTier.high: 45,
    TaskPriorityTier.elevated: 30,
    TaskPriorityTier.normal: 15,
    TaskPriorityTier.background: 0,
  };

  // -------------------------------------------------------------------------
  // SECTION 6B — MANDATORY FUNCTIONS
  // -------------------------------------------------------------------------

  /// Analyzes a single [TaskRequest] and returns a [TaskAnalysis].
  ///
  /// Produces a computed priority score and advisory notes.
  /// Never throws — errors return a minimal safe analysis.
  TaskAnalysis analyzeTask(TaskRequest request) {
    try {
      final score = calculatePriority(request);
      final notes = <String>[];
      bool hasResourceConcern = false;

      final res = request.resourceRequirements;

      if (res.estimatedMemoryMb > 512) {
        notes.add('Advisory: High memory demand (${res.estimatedMemoryMb.toStringAsFixed(0)} MB). '
            'Consider chunking or deferring.');
        hasResourceConcern = true;
      }

      if (res.estimatedCpuPercent > 70) {
        notes.add('Advisory: High CPU demand (${res.estimatedCpuPercent.toStringAsFixed(0)}%). '
            'Consider batching with lower-priority tasks.');
        hasResourceConcern = true;
      }

      if (res.estimatedDurationSeconds > 60) {
        notes.add('Advisory: Long estimated duration '
            '(${res.estimatedDurationSeconds.toStringAsFixed(0)}s). '
            'Background execution recommended if supported.');
      }

      if (request.dependencies.isEmpty) {
        notes.add('No declared dependencies — eligible for immediate scheduling.');
      } else {
        notes.add('Depends on ${request.dependencies.length} task(s): '
            '${request.dependencies.join(', ')}');
      }

      return TaskAnalysis(
        taskId: request.taskId,
        taskType: request.taskType,
        declaredPriority: request.priority,
        computedPriorityScore: score,
        isBackgroundable: res.isBackgroundable,
        isCancellable: res.isCancellable,
        estimatedDurationSeconds: res.estimatedDurationSeconds,
        hasResourceConcern: hasResourceConcern,
        analysisNotes: List.unmodifiable(notes),
      );
    } catch (_) {
      return TaskAnalysis(
        taskId: request.taskId,
        taskType: request.taskType,
        declaredPriority: request.priority,
        computedPriorityScore: 0,
      );
    }
  }

  /// Calculates an advisory numeric priority score (0–100) for a task.
  ///
  /// Score = tier base + task-type base, adjusted for backgroundability.
  /// Never throws — returns 0 on error.
  double calculatePriority(TaskRequest request) {
    try {
      final tierBase = _tierScore[request.priority] ?? 15;
      final typeBase =
          _taskTypeBaseScore[request.taskType] ?? 10;

      double score = tierBase + typeBase;

      // Background-eligible tasks are deprioritised when they are non-critical.
      if (request.resourceRequirements.isBackgroundable &&
          request.priority != TaskPriorityTier.critical) {
        score -= 5;
      }

      // Penalise tasks with many unresolved dependencies slightly to prefer
      // leaf tasks (no dependencies) first.
      final depPenalty = request.dependencies.length * 2.0;
      score -= depPenalty;

      return score.clamp(0, 100);
    } catch (_) {
      return 0;
    }
  }

  /// Analyzes dependencies for a [TaskRequest] within a known set of
  /// all submitted task IDs ([allTaskIds]).
  ///
  /// Detects missing dependencies and cycles.
  /// Never throws — returns a safe unresolvable analysis on error.
  DependencyAnalysis analyzeDependencies(
    TaskRequest request, {
    required Set<String> allTaskIds,
    Map<String, Set<String>> resolvedGraph = const {},
  }) {
    try {
      final resolved = <String>[];
      final missing = <String>[];

      for (final dep in request.dependencies) {
        if (allTaskIds.contains(dep)) {
          resolved.add(dep);
        } else {
          missing.add(dep);
        }
      }

      final cycles = _detectCycles(
        taskId: request.taskId,
        graph: resolvedGraph,
        allTaskIds: allTaskIds,
      );

      final depth = _computeDepth(
        taskId: request.taskId,
        graph: resolvedGraph,
        visited: {},
      );

      final isResolvable = missing.isEmpty && cycles.isEmpty;

      return DependencyAnalysis(
        taskId: request.taskId,
        resolvedDependencies: List.unmodifiable(resolved),
        missingDependencies: List.unmodifiable(missing),
        cyclicDependencies: List.unmodifiable(cycles),
        dependencyDepth: depth,
        isResolvable: isResolvable,
      );
    } catch (_) {
      return DependencyAnalysis(
        taskId: request.taskId,
        isResolvable: false,
      );
    }
  }

  /// Builds a complete [TaskSchedulePlan] for a batch of [TaskRequest]s.
  ///
  /// Performs analysis, dependency resolution, topological ordering, and
  /// warning generation for all submitted tasks.
  ///
  /// Returns [TaskSchedulePlan.empty] if any error occurs.
  /// The returned value is always non-null and safe to consume.
  TaskSchedulePlan buildExecutionPlan(List<TaskRequest> requests) {
    try {
      if (requests.isEmpty) {
        return TaskSchedulePlan(
          planId: _planId(),
          generatedAt: DateTime.now(),
        );
      }

      final allIds = requests.map((r) => r.taskId).toSet();
      final warnings = <SchedulingWarning>[];
      final taskAnalyses = <TaskAnalysis>[];
      final depAnalyses = <DependencyAnalysis>[];
      final priorityMap = <String, double>{};
      final dependencyGraph = <String, List<String>>{};

      // Step 1: analyse each task individually
      for (final req in requests) {
        final analysis = analyzeTask(req);
        taskAnalyses.add(analysis);
        priorityMap[req.taskId] = analysis.computedPriorityScore;
      }

      // Step 2: build dependency graph
      for (final req in requests) {
        dependencyGraph[req.taskId] = List.unmodifiable(req.dependencies);
      }

      // Step 3: dependency analysis per task
      final graphAsSet = dependencyGraph.map(
        (k, v) => MapEntry(k, v.toSet()),
      );
      for (final req in requests) {
        final depAnalysis = analyzeDependencies(
          req,
          allTaskIds: allIds,
          resolvedGraph: graphAsSet,
        );
        depAnalyses.add(depAnalysis);

        if (depAnalysis.missingDependencies.isNotEmpty) {
          warnings.add(_makeWarning(
            SchedulingWarningKind.missingDependency,
            'Task "${req.taskId}" has unresolved dependencies: '
                '${depAnalysis.missingDependencies.join(', ')}',
            affectedTaskIds: [req.taskId, ...depAnalysis.missingDependencies],
          ));
        }

        if (depAnalysis.cyclicDependencies.isNotEmpty) {
          warnings.add(_makeWarning(
            SchedulingWarningKind.cyclicDependency,
            'Cyclic dependency detected involving task "${req.taskId}": '
                '${depAnalysis.cyclicDependencies.join(' → ')}',
            affectedTaskIds: depAnalysis.cyclicDependencies,
          ));
        }
      }

      // Step 4: priority inversion check
      _checkPriorityInversions(requests, dependencyGraph, warnings);

      // Step 5: topological ordering (Kahn's algorithm — advisory order only)
      final orderedIds = _topologicalOrder(
        taskIds: allIds,
        dependencyGraph: dependencyGraph,
        priorityMap: priorityMap,
      );

      // Step 6: resource concern warnings
      for (final analysis in taskAnalyses) {
        if (analysis.hasResourceConcern) {
          warnings.add(_makeWarning(
            SchedulingWarningKind.resourceOverLimit,
            'Task "${analysis.taskId}" has elevated resource demands. '
                'Advisory: review before scheduling.',
            affectedTaskIds: [analysis.taskId],
          ));
        }
      }

      return TaskSchedulePlan(
        planId: _planId(),
        generatedAt: DateTime.now(),
        recommendedExecutionOrder: List.unmodifiable(orderedIds),
        priorityMap: Map.unmodifiable(priorityMap),
        dependencyGraph: Map.unmodifiable(
          dependencyGraph.map((k, v) => MapEntry(k, List.unmodifiable(v))),
        ),
        schedulingWarnings: List.unmodifiable(warnings),
        taskAnalyses: List.unmodifiable(taskAnalyses),
        dependencyAnalyses: List.unmodifiable(depAnalyses),
        isEmpty: false,
      );
    } catch (_) {
      return TaskSchedulePlan.empty(planId: _planId());
    }
  }

  /// Generates an advisory retry recommendation for a [TaskRequest].
  ///
  /// [failureReason] describes why the previous attempt failed.
  /// Returns a [RetryRecommendation] with advisory retry count and delay.
  /// Never throws.
  RetryRecommendation recommendRetry(
    TaskRequest request, {
    RetryReason failureReason = RetryReason.generic,
    int attemptsSoFar = 0,
  }) {
    try {
      final remaining = (request.maxRetryCount - attemptsSoFar).clamp(0, request.maxRetryCount);
      final delay = _retryDelay(
        reason: failureReason,
        baseDelay: request.retryDelaySeconds,
        attempt: attemptsSoFar,
      );

      final notes = _retryNotes(
        taskType: request.taskType,
        reason: failureReason,
        remaining: remaining,
      );

      return RetryRecommendation(
        taskId: request.taskId,
        reason: failureReason,
        recommendedRetryCount: remaining,
        recommendedDelaySeconds: delay,
        notes: notes,
      );
    } catch (_) {
      return RetryRecommendation(
        taskId: request.taskId,
        reason: RetryReason.generic,
        recommendedRetryCount: 0,
        recommendedDelaySeconds: 0,
        notes: 'Retry analysis unavailable.',
      );
    }
  }

  /// Generates an advisory cancellation recommendation for a [TaskRequest].
  ///
  /// [reason] describes why cancellation is being recommended.
  /// [blockedTaskIds] lists tasks that depend on this task and would be unblocked.
  /// Never throws.
  CancellationRecommendation recommendCancellation(
    TaskRequest request, {
    required CancellationReason reason,
    List<String> blockedTaskIds = const [],
  }) {
    try {
      final message = _cancellationMessage(reason, request.taskId);
      return CancellationRecommendation(
        taskId: request.taskId,
        reason: reason,
        message: message,
        blockedTaskIds: List.unmodifiable(blockedTaskIds),
      );
    } catch (_) {
      return CancellationRecommendation(
        taskId: request.taskId,
        reason: reason,
        message: 'Cancellation recommended for task "${request.taskId}".',
      );
    }
  }

  /// Generates a complete [TaskSchedulePlan] enriched with retry and
  /// cancellation recommendations.
  ///
  /// Wraps [buildExecutionPlan] and augments it with retry/cancellation
  /// advisories derived from the dependency analysis.
  ///
  /// Returns [TaskSchedulePlan.empty] if any error occurs.
  TaskSchedulePlan generateSchedulePlan(List<TaskRequest> requests) {
    try {
      final basePlan = buildExecutionPlan(requests);
      if (basePlan.isEmpty) return basePlan;

      final requestMap = {for (final r in requests) r.taskId: r};
      final retryRecs = <RetryRecommendation>[];
      final cancelRecs = <CancellationRecommendation>[];
      final extraWarnings = <SchedulingWarning>[];

      for (final depAnalysis in basePlan.dependencyAnalyses) {
        final request = requestMap[depAnalysis.taskId];
        if (request == null) continue;

        if (depAnalysis.cyclicDependencies.isNotEmpty) {
          // Cyclic dependency — recommend cancellation, not retry.
          final rec = recommendCancellation(
            request,
            reason: CancellationReason.cyclicDependency,
            blockedTaskIds: depAnalysis.cyclicDependencies,
          );
          cancelRecs.add(rec);
          extraWarnings.add(_makeWarning(
            SchedulingWarningKind.cancellationRecommended,
            'Advisory: Cancel task "${request.taskId}" — '
                'cyclic dependency is unresolvable.',
            affectedTaskIds: [request.taskId],
          ));
        } else if (depAnalysis.missingDependencies.isNotEmpty) {
          // Missing deps — recommend retry after dependencies are available.
          final rec = recommendRetry(
            request,
            failureReason: RetryReason.dependencyNotReady,
          );
          retryRecs.add(rec);
          extraWarnings.add(_makeWarning(
            SchedulingWarningKind.retryRecommended,
            'Advisory: Retry task "${request.taskId}" once missing '
                'dependencies are available.',
            affectedTaskIds: [request.taskId],
          ));
        }
      }

      return TaskSchedulePlan(
        planId: basePlan.planId,
        generatedAt: basePlan.generatedAt,
        recommendedExecutionOrder: basePlan.recommendedExecutionOrder,
        priorityMap: basePlan.priorityMap,
        dependencyGraph: basePlan.dependencyGraph,
        retryRecommendations: List.unmodifiable(retryRecs),
        cancellationRecommendations: List.unmodifiable(cancelRecs),
        schedulingWarnings: List.unmodifiable([
          ...basePlan.schedulingWarnings,
          ...extraWarnings,
        ]),
        taskAnalyses: basePlan.taskAnalyses,
        dependencyAnalyses: basePlan.dependencyAnalyses,
        isEmpty: false,
      );
    } catch (_) {
      return TaskSchedulePlan.empty(planId: _planId());
    }
  }

  // -------------------------------------------------------------------------
  // SECTION 7 — PRIVATE HELPERS
  // -------------------------------------------------------------------------

  /// Topological sort (Kahn's algorithm) with priority tie-breaking.
  /// Returns advisory ordering — EditorController is not obliged to follow it.
  List<String> _topologicalOrder({
    required Set<String> taskIds,
    required Map<String, List<String>> dependencyGraph,
    required Map<String, double> priorityMap,
  }) {
    // Build in-degree map
    final inDegree = <String, int>{
      for (final id in taskIds) id: 0,
    };

    // dependencyGraph[taskId] = list of tasks that taskId depends on.
    // So each entry in the list is a prerequisite of taskId.
    // We need: for each prerequisite → taskId, increment taskId's in-degree.
    for (final entry in dependencyGraph.entries) {
      for (final _ in entry.value) {
        inDegree[entry.key] = (inDegree[entry.key] ?? 0) + 1;
      }
    }

    // Build reverse graph: prerequisite → list of dependents
    final reverseGraph = <String, List<String>>{};
    for (final entry in dependencyGraph.entries) {
      for (final dep in entry.value) {
        reverseGraph.putIfAbsent(dep, () => []).add(entry.key);
      }
    }

    // Start with all tasks that have no dependencies, sorted by priority desc.
    final ready = taskIds
        .where((id) => (inDegree[id] ?? 0) == 0)
        .toList()
      ..sort((a, b) =>
          (priorityMap[b] ?? 0).compareTo(priorityMap[a] ?? 0));

    final ordered = <String>[];

    while (ready.isNotEmpty) {
      // Pop highest-priority ready task
      final current = ready.removeAt(0);
      ordered.add(current);

      // Reduce in-degree of dependents
      for (final dependent in (reverseGraph[current] ?? [])) {
        inDegree[dependent] = (inDegree[dependent] ?? 1) - 1;
        if ((inDegree[dependent] ?? 0) <= 0) {
          // Insert into ready list sorted by priority
          final insertAt = ready.indexWhere(
            (id) => (priorityMap[id] ?? 0) < (priorityMap[dependent] ?? 0),
          );
          if (insertAt < 0) {
            ready.add(dependent);
          } else {
            ready.insert(insertAt, dependent);
          }
        }
      }
    }

    // Any tasks not added (cycles) are appended at the end.
    for (final id in taskIds) {
      if (!ordered.contains(id)) ordered.add(id);
    }

    return ordered;
  }

  /// Detects cycles involving [taskId] using DFS on the resolved graph.
  List<String> _detectCycles({
    required String taskId,
    required Map<String, Set<String>> graph,
    required Set<String> allTaskIds,
  }) {
    final visited = <String>{};
    final path = <String>[];
    final cycleNodes = <String>[];

    bool dfs(String node) {
      if (path.contains(node)) {
        cycleNodes.addAll(path.sublist(path.indexOf(node)));
        return true;
      }
      if (visited.contains(node)) return false;

      visited.add(node);
      path.add(node);

      for (final dep in (graph[node] ?? <String>{})) {
        if (allTaskIds.contains(dep) && dfs(dep)) return true;
      }

      path.remove(node);
      return false;
    }

    dfs(taskId);
    return List.unmodifiable(cycleNodes);
  }

  /// Computes the depth of [taskId] in the dependency graph (0 = no deps).
  int _computeDepth(
    String taskId, {
    required Map<String, Set<String>> graph,
    required Set<String> visited,
  }) {
    if (visited.contains(taskId)) return 0;
    visited.add(taskId);

    final deps = graph[taskId] ?? {};
    if (deps.isEmpty) return 0;

    int maxDepth = 0;
    for (final dep in deps) {
      final d = _computeDepth(dep, graph: graph, visited: visited);
      if (d > maxDepth) maxDepth = d;
    }
    return maxDepth + 1;
  }

  /// Checks for priority inversions: a high-priority task depending on a
  /// lower-priority task.
  void _checkPriorityInversions(
    List<TaskRequest> requests,
    Map<String, List<String>> graph,
    List<SchedulingWarning> warnings,
  ) {
    final tierOrder = {
      TaskPriorityTier.background: 0,
      TaskPriorityTier.normal: 1,
      TaskPriorityTier.elevated: 2,
      TaskPriorityTier.high: 3,
      TaskPriorityTier.critical: 4,
    };
    final tierMap = {for (final r in requests) r.taskId: r.priority};

    for (final request in requests) {
      final myTier = tierOrder[request.priority] ?? 1;
      for (final depId in (graph[request.taskId] ?? [])) {
        final depTier = tierOrder[tierMap[depId]] ?? 1;
        if (myTier > depTier) {
          warnings.add(_makeWarning(
            SchedulingWarningKind.priorityInversion,
            'Priority inversion: task "${request.taskId}" (${request.priority.name}) '
                'depends on lower-priority task "$depId" '
                '(${tierMap[depId]?.name ?? 'unknown'}). '
                'Advisory: review dependency ordering.',
            affectedTaskIds: [request.taskId, depId],
          ));
        }
      }
    }
  }

  double _retryDelay({
    required RetryReason reason,
    required double baseDelay,
    required int attempt,
  }) {
    // Exponential back-off capped at 300 s.
    final exponential = baseDelay * (1 << attempt.clamp(0, 6));
    switch (reason) {
      case RetryReason.timeout:
        return (exponential * 1.5).clamp(0, 300);
      case RetryReason.resourcePressure:
        return (exponential * 2.0).clamp(0, 300);
      case RetryReason.dependencyNotReady:
        return (baseDelay * 2.0).clamp(0, 60);
      case RetryReason.deferredRetry:
        return 30;
      case RetryReason.generic:
        return exponential.clamp(0, 300);
    }
  }

  String _retryNotes({
    required ScheduledTaskType taskType,
    required RetryReason reason,
    required int remaining,
  }) {
    if (remaining == 0) {
      return 'No retry attempts remaining. Advisory: consider cancellation.';
    }
    final reasonDesc = switch (reason) {
      RetryReason.timeout => 'previous attempt timed out',
      RetryReason.resourcePressure => 'resource pressure was too high',
      RetryReason.dependencyNotReady => 'dependencies were not yet satisfied',
      RetryReason.deferredRetry => 'deferred retry is appropriate for this task type',
      RetryReason.generic => 'previous attempt did not complete',
    };
    return 'Advisory: retry task (${taskType.name}) — $reasonDesc. '
        '$remaining attempt(s) remaining.';
  }

  String _cancellationMessage(CancellationReason reason, String taskId) {
    return switch (reason) {
      CancellationReason.cyclicDependency =>
        'Advisory: Cancel task "$taskId" — unresolvable cyclic dependency detected.',
      CancellationReason.resourceExceeded =>
        'Advisory: Cancel task "$taskId" — resource demands exceed all advisory limits.',
      CancellationReason.missingDependencies =>
        'Advisory: Cancel task "$taskId" — required dependencies are permanently missing.',
      CancellationReason.policyBlocked =>
        'Advisory: Cancel task "$taskId" — blocked by active resource or thermal policy.',
      CancellationReason.externalRequest =>
        'Advisory: Cancel task "$taskId" — external cancellation requested.',
    };
  }

  SchedulingWarning _makeWarning(
    SchedulingWarningKind kind,
    String message, {
    List<String> affectedTaskIds = const [],
    Map<String, Object?> context = const {},
  }) {
    _warningCounter++;
    return SchedulingWarning(
      warningId: '${_engineId}_warn_$_warningCounter',
      kind: kind,
      message: message,
      affectedTaskIds: List.unmodifiable(affectedTaskIds),
      context: context,
    );
  }

  String _planId() {
    _planCounter++;
    return '${_engineId}_plan_$_planCounter';
  }
}
