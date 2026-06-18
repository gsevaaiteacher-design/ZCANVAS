// engines/resource_policy_engine.dart
//
// PHASE-9 — ResourcePolicyEngine
//
// ===========================================================================
// OWNERSHIP CONTRACT
// ===========================================================================
//
// WHAT THIS FILE CAN DO:
//   • Define memory usage policies per device profile and task type
//   • Define CPU usage policies per device profile and task type
//   • Define battery impact policies per device profile and task type
//   • Define thermal safety policies per device profile and task type
//   • Evaluate resource risk scores for incoming policy requests
//   • Generate optimization hints and recommendations (advisory only)
//   • Build ResourcePolicyReport — a read-only advisory output
//   • Support future voice, robot, and AI resource policy profiles
//
// WHAT THIS FILE CANNOT DO:
//   ❌ Approve or reject execution of any command or task
//   ❌ Mutate application state
//   ❌ Modify or access LayerEngine
//   ❌ Modify or access HistoryEngine
//   ❌ Modify or access StorageEngine
//   ❌ Modify or access RenderEngine
//   ❌ Modify or access ExportEngine
//   ❌ Modify or access Canvas
//   ❌ Control task execution in any form
//   ❌ Issue commands to other engines
//   ❌ Block execution of other engines
//
// WHAT THIS FILE CAN COMMUNICATE WITH:
//   ✔ EditorController (advisory / reporting only)
//   ✔ PHASE-9 peer engines (read-only data sharing; no commanding)
//     — accepts RuntimeSnapshot from RuntimeManagerEngine as read-only input
//
// WHAT THIS FILE CANNOT COMMUNICATE WITH:
//   ❌ LayerEngine
//   ❌ HistoryEngine
//   ❌ StorageEngine
//   ❌ RenderEngine
//   ❌ ExportEngine
//   ❌ Canvas
//
// AUTHORITY: DEVICE RESOURCE GOVERNANCE AUTHORITY.
//   This engine defines safe resource RECOMMENDATIONS.
//   Execution approval remains PHASE-8 responsibility.
//   EditorController remains the only execution authority.
//
// FAILURE ISOLATION:
//   If this engine fails, the editor MUST continue working uninterrupted.
//   The core system MUST NEVER depend on this engine.
// ===========================================================================

// Note: RuntimeSnapshot is accepted as a read-only input value.
// PHASE-9 engines may share read-only data per the Interdependency Law.
import 'runtime_manager_engine.dart' show RuntimeSnapshot, MemoryPressureLevel;

// ---------------------------------------------------------------------------
// SECTION 1 — ENUMERATIONS
// ---------------------------------------------------------------------------

/// Supported device capability profiles.
/// Used to calibrate policy thresholds per device class.
enum DeviceProfile {
  /// Entry-level device with constrained RAM, CPU, and battery.
  lowEndDevice,

  /// Mid-range device with moderate resources.
  midRangeDevice,

  /// High-end device with ample resources.
  highEndDevice,

  /// Tablet-class device with larger battery but variable RAM.
  tabletDevice,

  /// Desktop-class device with maximum available resources.
  desktopDevice,

  /// Placeholder for future device classes (AR, wearable, embedded, etc.).
  futureDeviceProfile,
}

/// Supported task types for resource demand analysis.
enum TaskType {
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

/// Thermal state levels reported by or inferred for the device.
enum ThermalState {
  /// Device is operating within normal temperature range.
  nominal,

  /// Device is slightly warm; minor throttling possible.
  fair,

  /// Device is warm; throttling likely.
  serious,

  /// Device is critically hot; severe throttling or shutdown risk.
  critical,

  /// Thermal state is unknown or unavailable.
  unknown,
}

/// Battery charge level bands used for policy evaluation.
enum BatteryLevel {
  /// Battery is critically low (< 10%).
  critical,

  /// Battery is low (10–25%).
  low,

  /// Battery is moderate (25–60%).
  moderate,

  /// Battery is healthy (60–100%).
  healthy,

  /// Device is connected to power; battery constraints relaxed.
  charging,

  /// Battery level is unknown.
  unknown,
}

/// Severity levels for policy warnings.
enum PolicyWarningSeverity { info, low, medium, high, critical }

/// Overall resource risk category derived from the risk score.
enum ResourceRiskCategory {
  /// Risk score 0–24: proceed freely.
  safe,

  /// Risk score 25–49: monitor.
  guarded,

  /// Risk score 50–74: advisory caution recommended.
  elevated,

  /// Risk score 75–89: strong advisory to defer or reduce scope.
  high,

  /// Risk score 90–100: advisory to abort or minimise operation.
  critical,
}

// ---------------------------------------------------------------------------
// SECTION 2 — RESOURCE DEMAND DESCRIPTOR
// ---------------------------------------------------------------------------

/// Describes the resource requirements of a task being evaluated.
final class ResourceDemand {
  const ResourceDemand({
    this.estimatedMemoryMb = 0,
    this.estimatedCpuPercent = 0,
    this.estimatedDurationSeconds = 0,
    this.requiresGpu = false,
    this.requiresNetwork = false,
    this.isBackgroundable = false,
    this.isCancellable = true,
    this.additionalDemands = const {},
  });

  /// Estimated peak memory allocation in megabytes.
  final double estimatedMemoryMb;

  /// Estimated peak CPU utilisation as a percentage (0–100).
  final double estimatedCpuPercent;

  /// Estimated task duration in seconds.
  final double estimatedDurationSeconds;

  /// True if the task requires GPU acceleration.
  final bool requiresGpu;

  /// True if the task requires network access.
  final bool requiresNetwork;

  /// True if the task can be safely moved to the background.
  final bool isBackgroundable;

  /// True if the task supports mid-execution cancellation.
  final bool isCancellable;

  /// Additional demand signals for future expansion.
  final Map<String, Object?> additionalDemands;
}

// ---------------------------------------------------------------------------
// SECTION 3 — INPUT CONTRACT
// ---------------------------------------------------------------------------

/// The sole input type accepted by ResourcePolicyEngine.
final class ResourcePolicyRequest {
  const ResourcePolicyRequest({
    required this.requestId,
    required this.deviceProfile,
    required this.taskType,
    required this.resourceDemand,
    this.runtimeSnapshot,
    this.thermalState = ThermalState.unknown,
    this.batteryLevel = BatteryLevel.unknown,
    this.availableMemoryMb,
    this.metadata = const {},
  });

  /// Unique identifier for this policy request.
  final String requestId;

  /// The device profile against which policies are evaluated.
  final DeviceProfile deviceProfile;

  /// The type of task whose resource demands are being evaluated.
  final TaskType taskType;

  /// The resource demands declared by the task.
  final ResourceDemand resourceDemand;

  /// Optional read-only runtime snapshot from RuntimeManagerEngine.
  /// Accepted per the PHASE-9 Interdependency Law (read-only data sharing).
  final RuntimeSnapshot? runtimeSnapshot;

  /// Current thermal state of the device, if known.
  final ThermalState thermalState;

  /// Current battery level band, if known.
  final BatteryLevel batteryLevel;

  /// Available system memory in megabytes, if known.
  final double? availableMemoryMb;

  /// Caller-supplied metadata for context; engine stores as-is.
  final Map<String, Object?> metadata;

  @override
  String toString() =>
      'ResourcePolicyRequest(id: $requestId, device: ${deviceProfile.name}, '
      'task: ${taskType.name})';
}

// ---------------------------------------------------------------------------
// SECTION 4 — POLICY EVALUATION INTERMEDIATES
// ---------------------------------------------------------------------------

/// Result of a single resource dimension policy evaluation.
final class PolicyEvaluation {
  const PolicyEvaluation({
    required this.dimension,
    required this.riskContribution,
    this.recommendedLimit,
    this.hints = const [],
    this.warnings = const [],
    this.passed = true,
  });

  /// The resource dimension evaluated (e.g. 'memory', 'cpu', 'battery').
  final String dimension;

  /// Risk points contributed by this dimension to the overall score (0–100).
  final double riskContribution;

  /// Advisory limit for this resource dimension (unit depends on dimension).
  final double? recommendedLimit;

  /// Optimization hints specific to this dimension.
  final List<String> hints;

  /// Warnings raised during this evaluation.
  final List<PolicyWarning> warnings;

  /// True when demand is within policy thresholds for this dimension.
  final bool passed;
}

/// A single advisory warning produced during policy evaluation.
final class PolicyWarning {
  const PolicyWarning({
    required this.warningId,
    required this.dimension,
    required this.message,
    required this.severity,
    this.context = const {},
  });

  final String warningId;

  /// The resource dimension that generated this warning.
  final String dimension;

  final String message;
  final PolicyWarningSeverity severity;
  final Map<String, Object?> context;

  @override
  String toString() =>
      'PolicyWarning(id: $warningId, dim: $dimension, '
      'severity: ${severity.name}, msg: $message)';
}

// ---------------------------------------------------------------------------
// SECTION 5 — OUTPUT CONTRACT
// ---------------------------------------------------------------------------

/// Recommended resource limits for a given request.
/// All values are advisory — EditorController decides whether to apply them.
final class RecommendedLimits {
  const RecommendedLimits({
    this.maxMemoryMb,
    this.maxCpuPercent,
    this.maxDurationSeconds,
    this.deferrable = false,
    this.shouldRunInBackground = false,
    this.additionalLimits = const {},
  });

  /// Advisory maximum memory allocation in megabytes.
  final double? maxMemoryMb;

  /// Advisory maximum CPU utilisation percentage.
  final double? maxCpuPercent;

  /// Advisory maximum task duration in seconds.
  final double? maxDurationSeconds;

  /// True when the engine advises deferring the task to a lower-pressure moment.
  final bool deferrable;

  /// True when the engine advises the task run in background if supported.
  final bool shouldRunInBackground;

  /// Additional advisory limits for future expansion.
  final Map<String, Object?> additionalLimits;
}

/// The sole output type produced by ResourcePolicyEngine.
///
/// This report is ADVISORY ONLY and NON-EXECUTABLE.
/// It carries no approval authority.
/// EditorController decides whether to act on any recommendation.
final class ResourcePolicyReport {
  const ResourcePolicyReport({
    required this.reportId,
    required this.requestId,
    required this.generatedAt,
    required this.deviceProfile,
    required this.taskType,
    required this.resourceRiskScore,
    required this.riskCategory,
    required this.recommendedLimits,
    this.optimizationHints = const [],
    this.resourceWarnings = const [],
    this.thermalWarnings = const [],
    this.batteryImpactEstimate,
    this.dimensionEvaluations = const [],
    this.isEmpty = false,
  });

  /// Creates an empty report used when the engine encounters an error.
  factory ResourcePolicyReport.empty({
    required String requestId,
    String reportId = 'empty',
  }) {
    return ResourcePolicyReport(
      reportId: reportId,
      requestId: requestId,
      generatedAt: DateTime.now(),
      deviceProfile: DeviceProfile.midRangeDevice,
      taskType: TaskType.futureTask,
      resourceRiskScore: 0,
      riskCategory: ResourceRiskCategory.safe,
      recommendedLimits: const RecommendedLimits(),
      isEmpty: true,
    );
  }

  /// Unique identifier for this report.
  final String reportId;

  /// The request ID this report responds to.
  final String requestId;

  /// UTC timestamp when this report was generated.
  final DateTime generatedAt;

  /// Device profile used during evaluation.
  final DeviceProfile deviceProfile;

  /// Task type evaluated.
  final TaskType taskType;

  /// Composite resource risk score (0–100). Higher = riskier.
  /// This is an analysis value — it does NOT authorize or deny anything.
  final double resourceRiskScore;

  /// Risk category derived from [resourceRiskScore].
  final ResourceRiskCategory riskCategory;

  /// Advisory resource limits for this task.
  final RecommendedLimits recommendedLimits;

  /// Advisory optimization hints for reducing resource pressure.
  final List<String> optimizationHints;

  /// Resource dimension warnings generated during evaluation.
  final List<PolicyWarning> resourceWarnings;

  /// Thermal-specific warnings generated during evaluation.
  final List<PolicyWarning> thermalWarnings;

  /// Estimated battery impact as a qualitative descriptor, if computed.
  final String? batteryImpactEstimate;

  /// Per-dimension evaluations for detailed advisory inspection.
  final List<PolicyEvaluation> dimensionEvaluations;

  /// True when the report contains no meaningful evaluation data.
  final bool isEmpty;

  /// Convenience: true if any critical warnings exist.
  bool get hasCriticalWarnings =>
      resourceWarnings.any((w) => w.severity == PolicyWarningSeverity.critical) ||
      thermalWarnings.any((w) => w.severity == PolicyWarningSeverity.critical);

  /// Convenience: true if risk is elevated or worse.
  bool get isElevatedRisk =>
      riskCategory == ResourceRiskCategory.elevated ||
      riskCategory == ResourceRiskCategory.high ||
      riskCategory == ResourceRiskCategory.critical;

  @override
  String toString() =>
      'ResourcePolicyReport(id: $reportId, risk: ${resourceRiskScore.toStringAsFixed(1)} '
      '[${riskCategory.name}], device: ${deviceProfile.name}, '
      'task: ${taskType.name}, warnings: ${resourceWarnings.length + thermalWarnings.length})';
}

// ---------------------------------------------------------------------------
// SECTION 6 — DEVICE PROFILE THRESHOLDS (internal)
// ---------------------------------------------------------------------------

/// Immutable threshold set for a device profile.
final class _DeviceThresholds {
  const _DeviceThresholds({
    required this.maxSafeMemoryMb,
    required this.maxSafeCpuPercent,
    required this.maxSafeDurationSeconds,
    required this.thermalSensitivity,
    required this.batterySensitivity,
    required this.cpuLimitPercent,
    required this.memoryLimitMb,
  });

  final double maxSafeMemoryMb;
  final double maxSafeCpuPercent;
  final double maxSafeDurationSeconds;

  /// 0.0 (insensitive) – 1.0 (very sensitive): scales thermal risk weight.
  final double thermalSensitivity;

  /// 0.0 (insensitive) – 1.0 (very sensitive): scales battery risk weight.
  final double batterySensitivity;

  /// Hard advisory CPU ceiling for this device class.
  final double cpuLimitPercent;

  /// Hard advisory memory ceiling for this device class.
  final double memoryLimitMb;
}

// ---------------------------------------------------------------------------
// SECTION 7 — RESOURCE POLICY ENGINE
// ---------------------------------------------------------------------------

/// ResourcePolicyEngine — PHASE-9 Governance Engine
///
/// DEVICE RESOURCE GOVERNANCE AUTHORITY.
///
/// This engine DEFINES safe resource recommendations.
/// It NEVER APPROVES execution. That authority belongs to PHASE-8 and
/// EditorController.
///
/// LAWS:
///   1. POLICY ONLY — recommendations, analysis, and reports.
///   2. NO EXECUTION — never triggers or approves any action.
///   3. NO APPROVAL AUTHORITY — risk scores and reports are advisory.
///   4. FAILURE SAFE — every method is non-throwing; errors yield
///      empty/safe defaults so the editor continues uninterrupted.
///   5. FULLY INDEPENDENT — does not depend on ResourcePolicyEngine or
///      TaskSchedulerEngine; functions in complete isolation.
final class ResourcePolicyEngine {
  ResourcePolicyEngine({String engineId = 'resource_policy_engine'})
      : _engineId = engineId;

  final String _engineId;
  int _reportCounter = 0;
  int _warningCounter = 0;

  // -------------------------------------------------------------------------
  // SECTION 7A — DEVICE PROFILE THRESHOLDS TABLE
  // -------------------------------------------------------------------------

  static const Map<DeviceProfile, _DeviceThresholds> _thresholds = {
    DeviceProfile.lowEndDevice: _DeviceThresholds(
      maxSafeMemoryMb: 128,
      maxSafeCpuPercent: 30,
      maxSafeDurationSeconds: 10,
      thermalSensitivity: 0.9,
      batterySensitivity: 0.9,
      cpuLimitPercent: 40,
      memoryLimitMb: 180,
    ),
    DeviceProfile.midRangeDevice: _DeviceThresholds(
      maxSafeMemoryMb: 256,
      maxSafeCpuPercent: 50,
      maxSafeDurationSeconds: 20,
      thermalSensitivity: 0.6,
      batterySensitivity: 0.6,
      cpuLimitPercent: 65,
      memoryLimitMb: 350,
    ),
    DeviceProfile.highEndDevice: _DeviceThresholds(
      maxSafeMemoryMb: 512,
      maxSafeCpuPercent: 70,
      maxSafeDurationSeconds: 60,
      thermalSensitivity: 0.3,
      batterySensitivity: 0.3,
      cpuLimitPercent: 85,
      memoryLimitMb: 700,
    ),
    DeviceProfile.tabletDevice: _DeviceThresholds(
      maxSafeMemoryMb: 384,
      maxSafeCpuPercent: 60,
      maxSafeDurationSeconds: 45,
      thermalSensitivity: 0.4,
      batterySensitivity: 0.5,
      cpuLimitPercent: 75,
      memoryLimitMb: 512,
    ),
    DeviceProfile.desktopDevice: _DeviceThresholds(
      maxSafeMemoryMb: 1024,
      maxSafeCpuPercent: 80,
      maxSafeDurationSeconds: 120,
      thermalSensitivity: 0.2,
      batterySensitivity: 0.1,
      cpuLimitPercent: 90,
      memoryLimitMb: 2048,
    ),
    DeviceProfile.futureDeviceProfile: _DeviceThresholds(
      maxSafeMemoryMb: 256,
      maxSafeCpuPercent: 50,
      maxSafeDurationSeconds: 20,
      thermalSensitivity: 0.5,
      batterySensitivity: 0.5,
      cpuLimitPercent: 65,
      memoryLimitMb: 350,
    ),
  };

  // -------------------------------------------------------------------------
  // SECTION 7B — TASK TYPE MULTIPLIERS
  // -------------------------------------------------------------------------

  /// Resource demand weight multipliers per task type.
  /// Applied to baseline risk scores to reflect per-task resource intensity.
  static const Map<TaskType, double> _taskMultipliers = {
    TaskType.aiTask: 1.5,
    TaskType.exportTask: 1.3,
    TaskType.syncTask: 0.8,
    TaskType.templateTask: 1.0,
    TaskType.pluginTask: 1.2,
    TaskType.workflowTask: 1.1,
    TaskType.automationTask: 1.1,
    TaskType.voiceTask: 0.7,
    TaskType.robotTask: 1.0,
    TaskType.futureTask: 1.0,
  };

  // -------------------------------------------------------------------------
  // SECTION 7C — MANDATORY FUNCTIONS
  // -------------------------------------------------------------------------

  /// Evaluates memory policy for the given request.
  ///
  /// Returns a [PolicyEvaluation] for the memory dimension.
  /// Never throws — errors produce a safe zero-risk evaluation.
  PolicyEvaluation evaluateMemoryPolicy(ResourcePolicyRequest request) {
    try {
      final thresholds = _thresholdFor(request.deviceProfile);
      final demand = request.resourceDemand.estimatedMemoryMb;
      final available = request.availableMemoryMb;
      final multiplier = _taskMultipliers[request.taskType] ?? 1.0;

      double risk = 0;
      final hints = <String>[];
      final warnings = <PolicyWarning>[];

      // Base risk from demand vs. safe threshold
      if (demand > 0 && thresholds.maxSafeMemoryMb > 0) {
        risk = ((demand / thresholds.maxSafeMemoryMb) * 100 * multiplier)
            .clamp(0, 100);
      }

      // Factor in available memory if provided
      if (available != null && available > 0 && demand > 0) {
        final utilizationAfter = demand / available;
        if (utilizationAfter > 0.8) {
          risk = (risk + 20).clamp(0, 100);
          warnings.add(_makeWarning(
            'memory',
            'Task would consume ${(utilizationAfter * 100).toStringAsFixed(0)}% '
                'of available memory (${available.toStringAsFixed(0)} MB).',
            utilizationAfter > 0.95
                ? PolicyWarningSeverity.critical
                : PolicyWarningSeverity.high,
          ));
        }
      }

      // Factor in runtime memory pressure
      final pressure = request.runtimeSnapshot?.memoryPressureLevel;
      if (pressure == MemoryPressureLevel.high ||
          pressure == MemoryPressureLevel.critical) {
        risk = (risk + 15).clamp(0, 100);
        hints.add('Advisory: Runtime memory pressure is ${pressure!.name}. '
            'Consider deferring or reducing task scope.');
      }

      if (demand > thresholds.maxSafeMemoryMb) {
        hints.add('Advisory: Demand (${demand.toStringAsFixed(0)} MB) exceeds '
            'safe threshold (${thresholds.maxSafeMemoryMb.toStringAsFixed(0)} MB) '
            'for ${request.deviceProfile.name}.');
      }

      return PolicyEvaluation(
        dimension: 'memory',
        riskContribution: risk,
        recommendedLimit: thresholds.memoryLimitMb,
        hints: List.unmodifiable(hints),
        warnings: List.unmodifiable(warnings),
        passed: demand <= thresholds.maxSafeMemoryMb,
      );
    } catch (_) {
      return const PolicyEvaluation(
        dimension: 'memory',
        riskContribution: 0,
        passed: true,
      );
    }
  }

  /// Evaluates CPU policy for the given request.
  ///
  /// Returns a [PolicyEvaluation] for the CPU dimension.
  /// Never throws — errors produce a safe zero-risk evaluation.
  PolicyEvaluation evaluateCpuPolicy(ResourcePolicyRequest request) {
    try {
      final thresholds = _thresholdFor(request.deviceProfile);
      final demand = request.resourceDemand.estimatedCpuPercent;
      final multiplier = _taskMultipliers[request.taskType] ?? 1.0;

      double risk = 0;
      final hints = <String>[];
      final warnings = <PolicyWarning>[];

      if (demand > 0 && thresholds.maxSafeCpuPercent > 0) {
        risk = ((demand / thresholds.maxSafeCpuPercent) * 100 * multiplier)
            .clamp(0, 100);
      }

      if (demand > thresholds.cpuLimitPercent) {
        warnings.add(_makeWarning(
          'cpu',
          'Task CPU demand (${demand.toStringAsFixed(0)}%) exceeds advisory '
              'ceiling (${thresholds.cpuLimitPercent.toStringAsFixed(0)}%) '
              'for ${request.deviceProfile.name}.',
          demand > thresholds.maxSafeCpuPercent * 1.5
              ? PolicyWarningSeverity.high
              : PolicyWarningSeverity.medium,
        ));
      }

      if (demand > thresholds.maxSafeCpuPercent) {
        hints.add('Advisory: Consider chunking or yielding to reduce sustained '
            'CPU load on ${request.deviceProfile.name}.');
      }

      if (request.resourceDemand.isBackgroundable && demand > 50) {
        hints.add('Advisory: Task is backgroundable — '
            'running in background may reduce foreground CPU contention.');
      }

      return PolicyEvaluation(
        dimension: 'cpu',
        riskContribution: risk,
        recommendedLimit: thresholds.cpuLimitPercent,
        hints: List.unmodifiable(hints),
        warnings: List.unmodifiable(warnings),
        passed: demand <= thresholds.maxSafeCpuPercent,
      );
    } catch (_) {
      return const PolicyEvaluation(
        dimension: 'cpu',
        riskContribution: 0,
        passed: true,
      );
    }
  }

  /// Evaluates battery policy for the given request.
  ///
  /// Returns a [PolicyEvaluation] for the battery dimension.
  /// Never throws — errors produce a safe zero-risk evaluation.
  PolicyEvaluation evaluateBatteryPolicy(ResourcePolicyRequest request) {
    try {
      final thresholds = _thresholdFor(request.deviceProfile);
      final battery = request.batteryLevel;
      final demand = request.resourceDemand;
      final sensitivity = thresholds.batterySensitivity;

      double risk = 0;
      final hints = <String>[];
      final warnings = <PolicyWarning>[];

      // Base risk from battery level
      final batteryRisk = _batteryLevelRisk(battery);
      risk = (batteryRisk * sensitivity * 100).clamp(0, 100);

      // Increase risk for high-cpu / long-duration tasks on low battery
      if (battery == BatteryLevel.low || battery == BatteryLevel.critical) {
        final durationFactor =
            (demand.estimatedDurationSeconds / thresholds.maxSafeDurationSeconds)
                .clamp(0.0, 2.0);
        risk = (risk + durationFactor * 20 * sensitivity).clamp(0, 100);

        warnings.add(_makeWarning(
          'battery',
          'Battery level is ${battery.name}. '
              'High-drain tasks may reduce device availability.',
          battery == BatteryLevel.critical
              ? PolicyWarningSeverity.critical
              : PolicyWarningSeverity.high,
        ));
        hints.add('Advisory: Defer non-critical tasks until battery is charged.');
      }

      if (battery == BatteryLevel.charging) {
        risk = (risk * 0.3).clamp(0, 100);
        hints.add('Advisory: Device is charging — battery constraints relaxed.');
      }

      final impactEstimate = _batteryImpactLabel(
        battery: battery,
        cpuPercent: demand.estimatedCpuPercent,
        durationSeconds: demand.estimatedDurationSeconds,
        sensitivity: sensitivity,
      );

      return PolicyEvaluation(
        dimension: 'battery',
        riskContribution: risk,
        hints: List.unmodifiable(hints),
        warnings: List.unmodifiable(warnings),
        passed: battery != BatteryLevel.critical,
        recommendedLimit: null,
      );
    } catch (_) {
      return const PolicyEvaluation(
        dimension: 'battery',
        riskContribution: 0,
        passed: true,
      );
    }
  }

  /// Evaluates thermal policy for the given request.
  ///
  /// Returns a [PolicyEvaluation] for the thermal dimension.
  /// Never throws — errors produce a safe zero-risk evaluation.
  PolicyEvaluation evaluateThermalPolicy(ResourcePolicyRequest request) {
    try {
      final thresholds = _thresholdFor(request.deviceProfile);
      final thermal = request.thermalState;
      final sensitivity = thresholds.thermalSensitivity;

      double risk = 0;
      final hints = <String>[];
      final warnings = <PolicyWarning>[];

      switch (thermal) {
        case ThermalState.nominal:
          risk = 0;
        case ThermalState.fair:
          risk = (20 * sensitivity).clamp(0, 100);
          hints.add('Advisory: Device is warm. Monitor thermal state.');
        case ThermalState.serious:
          risk = (55 * sensitivity).clamp(0, 100);
          warnings.add(_makeWarning(
            'thermal',
            'Device thermal state is serious. Throttling is likely. '
                'Advisory: reduce workload.',
            PolicyWarningSeverity.high,
          ));
          hints.add('Advisory: Defer heavy computation until device cools.');
        case ThermalState.critical:
          risk = (90 * sensitivity).clamp(0, 100);
          warnings.add(_makeWarning(
            'thermal',
            'Device thermal state is CRITICAL. Severe throttling or shutdown risk. '
                'Advisory: abort or minimise operation immediately.',
            PolicyWarningSeverity.critical,
          ));
          hints.add('Advisory: Abort or postpone task; device is critically hot.');
        case ThermalState.unknown:
          risk = (10 * sensitivity).clamp(0, 100);
          hints.add('Advisory: Thermal state unknown — conservative limits applied.');
      }

      return PolicyEvaluation(
        dimension: 'thermal',
        riskContribution: risk,
        hints: List.unmodifiable(hints),
        warnings: List.unmodifiable(warnings),
        passed: thermal != ThermalState.critical,
      );
    } catch (_) {
      return const PolicyEvaluation(
        dimension: 'thermal',
        riskContribution: 0,
        passed: true,
      );
    }
  }

  /// Calculates a composite resource risk score (0–100) from individual
  /// dimension evaluations.
  ///
  /// Weights:
  ///   Memory  30%
  ///   CPU     30%
  ///   Battery 20%
  ///   Thermal 20%
  ///
  /// Returns 0 if any error occurs.
  double calculateRiskScore({
    required PolicyEvaluation memoryEval,
    required PolicyEvaluation cpuEval,
    required PolicyEvaluation batteryEval,
    required PolicyEvaluation thermalEval,
  }) {
    try {
      const memoryWeight = 0.30;
      const cpuWeight = 0.30;
      const batteryWeight = 0.20;
      const thermalWeight = 0.20;

      final score = (memoryEval.riskContribution * memoryWeight) +
          (cpuEval.riskContribution * cpuWeight) +
          (batteryEval.riskContribution * batteryWeight) +
          (thermalEval.riskContribution * thermalWeight);

      return score.clamp(0, 100);
    } catch (_) {
      return 0;
    }
  }

  /// Generates advisory optimization hints from all dimension evaluations.
  ///
  /// De-duplicates hints and returns an unmodifiable list.
  /// Never throws.
  List<String> generateRecommendations({
    required PolicyEvaluation memoryEval,
    required PolicyEvaluation cpuEval,
    required PolicyEvaluation batteryEval,
    required PolicyEvaluation thermalEval,
    required ResourcePolicyRequest request,
  }) {
    try {
      final seen = <String>{};
      final recs = <String>[];

      void addUnique(String hint) {
        if (seen.add(hint)) recs.add(hint);
      }

      for (final hint in [
        ...memoryEval.hints,
        ...cpuEval.hints,
        ...batteryEval.hints,
        ...thermalEval.hints,
      ]) {
        addUnique(hint);
      }

      // Cross-dimension recommendations
      if (!memoryEval.passed && !cpuEval.passed) {
        addUnique(
          'Advisory: Both memory and CPU demands exceed safe thresholds for '
          '${request.deviceProfile.name}. '
          'Strongly consider deferring or splitting this task.',
        );
      }

      if (request.resourceDemand.isCancellable) {
        addUnique(
          'Advisory: Task supports cancellation — '
          'EditorController may cancel safely if conditions worsen.',
        );
      }

      return List.unmodifiable(recs);
    } catch (_) {
      return const [];
    }
  }

  /// Builds and returns a complete [ResourcePolicyReport] for the request.
  ///
  /// Internally calls all four mandatory evaluation functions and
  /// [calculateRiskScore], then assembles the advisory report.
  ///
  /// Returns [ResourcePolicyReport.empty] if any error occurs.
  /// The returned value is always non-null and safe to consume.
  ResourcePolicyReport buildResourceReport(ResourcePolicyRequest request) {
    try {
      _reportCounter++;
      final reportId = '${_engineId}_report_$_reportCounter';

      final memEval = evaluateMemoryPolicy(request);
      final cpuEval = evaluateCpuPolicy(request);
      final batEval = evaluateBatteryPolicy(request);
      final thrEval = evaluateThermalPolicy(request);

      final score = calculateRiskScore(
        memoryEval: memEval,
        cpuEval: cpuEval,
        batteryEval: batEval,
        thermalEval: thrEval,
      );

      final category = _riskCategory(score);

      final recommendations = generateRecommendations(
        memoryEval: memEval,
        cpuEval: cpuEval,
        batteryEval: batEval,
        thermalEval: thrEval,
        request: request,
      );

      final thresholds = _thresholdFor(request.deviceProfile);
      final demand = request.resourceDemand;

      final limits = RecommendedLimits(
        maxMemoryMb: thresholds.memoryLimitMb,
        maxCpuPercent: thresholds.cpuLimitPercent,
        maxDurationSeconds: thresholds.maxSafeDurationSeconds,
        deferrable: category == ResourceRiskCategory.high ||
            category == ResourceRiskCategory.critical,
        shouldRunInBackground:
            demand.isBackgroundable && category != ResourceRiskCategory.safe,
      );

      final allResourceWarnings = [
        ...memEval.warnings,
        ...cpuEval.warnings,
        ...batEval.warnings,
      ];

      final allThermalWarnings = [...thrEval.warnings];

      final batteryImpact = _batteryImpactLabel(
        battery: request.batteryLevel,
        cpuPercent: demand.estimatedCpuPercent,
        durationSeconds: demand.estimatedDurationSeconds,
        sensitivity: thresholds.batterySensitivity,
      );

      return ResourcePolicyReport(
        reportId: reportId,
        requestId: request.requestId,
        generatedAt: DateTime.now(),
        deviceProfile: request.deviceProfile,
        taskType: request.taskType,
        resourceRiskScore: score,
        riskCategory: category,
        recommendedLimits: limits,
        optimizationHints: recommendations,
        resourceWarnings: List.unmodifiable(allResourceWarnings),
        thermalWarnings: List.unmodifiable(allThermalWarnings),
        batteryImpactEstimate: batteryImpact,
        dimensionEvaluations: List.unmodifiable([
          memEval,
          cpuEval,
          batEval,
          thrEval,
        ]),
        isEmpty: false,
      );
    } catch (_) {
      return ResourcePolicyReport.empty(requestId: request.requestId);
    }
  }

  // -------------------------------------------------------------------------
  // SECTION 8 — PRIVATE HELPERS
  // -------------------------------------------------------------------------

  _DeviceThresholds _thresholdFor(DeviceProfile profile) =>
      _thresholds[profile] ??
      _thresholds[DeviceProfile.midRangeDevice]!;

  ResourceRiskCategory _riskCategory(double score) {
    if (score < 25) return ResourceRiskCategory.safe;
    if (score < 50) return ResourceRiskCategory.guarded;
    if (score < 75) return ResourceRiskCategory.elevated;
    if (score < 90) return ResourceRiskCategory.high;
    return ResourceRiskCategory.critical;
  }

  double _batteryLevelRisk(BatteryLevel level) {
    switch (level) {
      case BatteryLevel.charging:
        return 0.0;
      case BatteryLevel.healthy:
        return 0.05;
      case BatteryLevel.moderate:
        return 0.20;
      case BatteryLevel.low:
        return 0.55;
      case BatteryLevel.critical:
        return 0.90;
      case BatteryLevel.unknown:
        return 0.10;
    }
  }

  String _batteryImpactLabel({
    required BatteryLevel battery,
    required double cpuPercent,
    required double durationSeconds,
    required double sensitivity,
  }) {
    if (battery == BatteryLevel.charging) return 'Negligible (charging)';

    final drainScore = (cpuPercent / 100.0) *
        (durationSeconds / 60.0) *
        sensitivity;

    if (drainScore < 0.05) return 'Minimal';
    if (drainScore < 0.2) return 'Low';
    if (drainScore < 0.5) return 'Moderate';
    if (drainScore < 1.0) return 'High';
    return 'Very High';
  }

  PolicyWarning _makeWarning(
    String dimension,
    String message,
    PolicyWarningSeverity severity, {
    Map<String, Object?> context = const {},
  }) {
    _warningCounter++;
    return PolicyWarning(
      warningId: '${_engineId}_warn_${_warningCounter}_$dimension',
      dimension: dimension,
      message: message,
      severity: severity,
      context: context,
    );
  }
}
