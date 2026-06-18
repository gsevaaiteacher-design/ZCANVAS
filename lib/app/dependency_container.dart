// ============================================================
// PHASE-21 — DEPENDENCY CONTAINER CONTRACT
// FILE: app/dependency_container.dart
// SYSTEM COMPOSITION AUTHORITY
//
// YEH FILE POORE PROJECT MEIN AKELI JAGAH HAI JAHAN:
//   new StorageEngine()
//   new LayerRepository()
//   new DesignRepository()
//   new LayerEngine()
//   new HistoryEngine()
//   new TemplateEngine()
//   new RenderEngine()
//   new ExportEngine()
//   new SyncEngine()
//   new AIEngine()
//   new EditorController()
//   DependencyRegistry()
// — create ho sakte hain. Koi doosri file nahi.
//
// GUARANTEED WIRING CHAIN:
//   Storage → Repository → Engine → Controller → UI
//
// FORBIDDEN everywhere else:
//   UI → LayerEngine       (direct)
//   UI → StorageEngine     (direct)
//   AI → LayerEngine       (direct)
//   AI → Canvas            (direct)
//   Engine → StorageEngine (direct)
// ============================================================

// ── Apne project ki existing files ke import paths yahan adjust karein ──────
library;

// Core Registry & Guards
import 'package:z_canvas/app/dependency_registry.dart';
import 'package:z_canvas/app/integration_guard.dart';

// Storage & Repositories
import 'package:z_canvas/engine/storage_engine.dart';
import 'package:z_canvas/Repository/layer_repository.dart';
import 'package:z_canvas/engine/design_repository.dart';
import 'package:z_canvas/engine/history_engine.dart'; 
import 'package:z_canvas/engine/template_engine.dart';

// Core Engines
import 'package:z_canvas/engine/layer_engine.dart';
import 'package:z_canvas/engine/render_engine.dart';
import 'package:z_canvas/engine/export_engine.dart';
import 'package:z_canvas/engine/sync_engine.dart';
import 'package:z_canvas/engine/ai_engine.dart';

// Optional Engines
import 'package:z_canvas/engine/telemetry_engine.dart';
import 'package:z_canvas/engine/debug_trace_engine.dart';
import 'package:z_canvas/engine/system_health_engine.dart';
import 'package:z_canvas/engine/suggestion_engine.dart';
import 'package:z_canvas/engine/insight_engine.dart';
import 'package:z_canvas/engine/input_orchestrator_engine.dart';
import 'package:z_canvas/engine/command_gateway_engine.dart';
import 'package:z_canvas/engine/execution_policy_engine.dart';
import 'package:z_canvas/engine/context_memory_engine.dart';
import 'package:z_canvas/engine/runtime_manager_engine.dart';
import 'package:z_canvas/engine/resource_policy_engine.dart';
import 'package:z_canvas/engine/task_scheduler_engine.dart';
import 'package:z_canvas/engine/automation_engine.dart';
import 'package:z_canvas/engine/plugin_engine.dart';
import 'package:z_canvas/engine/workflow_engine.dart';
import 'package:z_canvas/engine/responsive_layout_engine.dart';

// Controller
import 'package:z_canvas/controllers/editor_controller.dart';

// ============================================================
// REGISTRY KEYS — Saare dependency keys ek jagah
// ============================================================

abstract final class RegistryKeys {
  // Repositories
  static const String layerRepository    = 'layer_repository';
  static const String designRepository   = 'design_repository';
  static const String historyRepository  = 'history_repository';
  static const String templateRepository = 'template_repository';

  // Core Engines
  static const String storageEngine  = 'storage_engine';
  static const String layerEngine    = 'layer_engine';
  static const String historyEngine  = 'history_engine';
  static const String templateEngine = 'template_engine';
  static const String renderEngine   = 'render_engine';
  static const String exportEngine   = 'export_engine';
  static const String syncEngine     = 'sync_engine';
  static const String aiEngine       = 'ai_engine';

  // Optional Engines
  static const String telemetryEngine         = 'telemetry_engine';
  static const String debugTraceEngine        = 'debug_trace_engine';
  static const String systemHealthEngine      = 'system_health_engine';
  static const String suggestionEngine        = 'suggestion_engine';
  static const String insightEngine           = 'insight_engine';
  static const String inputOrchestratorEngine = 'input_orchestrator_engine';
  static const String commandGatewayEngine    = 'command_gateway_engine';
  static const String executionPolicyEngine   = 'execution_policy_engine';
  static const String contextMemoryEngine     = 'context_memory_engine';
  static const String runtimeManagerEngine    = 'runtime_manager_engine';
  static const String resourcePolicyEngine    = 'resource_policy_engine';
  static const String taskSchedulerEngine     = 'task_scheduler_engine';
  static const String automationEngine        = 'automation_engine';
  static const String pluginEngine            = 'plugin_engine';
  static const String workflowEngine          = 'workflow_engine';
  static const String responsiveLayoutEngine  = 'responsive_layout_engine';

  // Controller
  static const String editorController = 'editor_controller';

  // Required keys — inke bina boot abort
  static const Set<String> _required = {
    layerRepository,
    designRepository,
    storageEngine,
    layerEngine,
    historyEngine,
    templateEngine,
    renderEngine,
    exportEngine,
    syncEngine,
    aiEngine,
    editorController,
  };
}

// ============================================================
// DEPENDENCY REGISTRY — Exactly once, only inside DependencyContainer
// ============================================================

final class _RegistryLockedError extends Error {
  @override
  String toString() => 'DependencyRegistry is locked — no more registrations.';
}

final class _RegistryIncompleteError extends Error {
  _RegistryIncompleteError(this.missing);
  final Set<String> missing;
  @override
  String toString() =>
      'DependencyRegistry incomplete — boot aborted. Missing: $missing';
}

final class DependencyRegistry {
  DependencyRegistry._internal();

  final Map<String, Object> _store = {};
  bool _locked = false;

  // ── Register ──────────────────────────────────────────────

  void register(String key, Object instance) {
    if (_locked) throw _RegistryLockedError();
    _store[key] = instance;
  }

  /// Optional — null hone par sirf warning, boot fail nahi
  void registerOptional(String key, Object? instance) {
    if (_locked) throw _RegistryLockedError();
    if (instance == null) {
      // ignore: avoid_print
      print('[DependencyRegistry] WARNING: optional "$key" not provided.');
      return;
    }
    _store[key] = instance;
  }

  // ── Resolve ───────────────────────────────────────────────

  T resolve<T extends Object>(String key) {
    final v = _store[key];
    if (v == null) throw StateError('Key "$key" not registered.');
    if (v is! T) throw TypeError();
    return v;
  }

  T? resolveOptional<T extends Object>(String key) {
    final v = _store[key];
    if (v == null) return null;
    if (v is! T) throw TypeError();
    return v;
  }

  bool has(String key) => _store.containsKey(key);

  // ── STEP-14: Assert completeness ──────────────────────────

  void assertComplete() {
    final missing = RegistryKeys._required
        .where((k) => !_store.containsKey(k))
        .toSet();
    if (missing.isNotEmpty) throw _RegistryIncompleteError(missing);
  }

  // ── STEP-15: Lock ──────────────────────────────────────────

  void lock() => _locked = true;

  bool get isLocked => _locked;
}

// ============================================================
// INTEGRATION GUARD — STEP-13
// Validate karo dependency graph boot se pehle
// ============================================================

final class _IntegrationViolation {
  const _IntegrationViolation(this.rule, this.detail);
  final String rule;
  final String detail;
  @override
  String toString() => '[$rule] $detail';
}

final class _IntegrationGuardError extends Error {
  _IntegrationGuardError(this.violations);
  final List<_IntegrationViolation> violations;
  @override
  String toString() =>
      'IntegrationGuard failed — boot aborted:\n'
      '${violations.map((v) => '  $v').join('\n')}';
}

void _runIntegrationGuard(DependencyRegistry registry) {
  final violations = <_IntegrationViolation>[];

  // Rule 1: Required keys present
  for (final key in RegistryKeys._required) {
    if (!registry.has(key)) {
      violations.add(_IntegrationViolation(
        'MISSING_KEY', '"$key" required but not registered',
      ));
    }
  }

  // Rule 2: Repository isolation
  // LayerEngine registered → LayerRepository must exist
  if (registry.has(RegistryKeys.layerEngine) &&
      !registry.has(RegistryKeys.layerRepository)) {
    violations.add(const _IntegrationViolation(
      'REPOSITORY_ISOLATION',
      'LayerEngine registered without LayerRepository — '
          'Engine may not bypass repository layer',
    ));
  }
  // TemplateEngine registered → DesignRepository must exist
  if (registry.has(RegistryKeys.templateEngine) &&
      !registry.has(RegistryKeys.designRepository)) {
    violations.add(const _IntegrationViolation(
      'REPOSITORY_ISOLATION',
      'TemplateEngine registered without DesignRepository',
    ));
  }
  // HistoryEngine registered → HistoryRepository must exist
  if (registry.has(RegistryKeys.historyEngine) &&
      !registry.has(RegistryKeys.historyRepository)) {
    violations.add(const _IntegrationViolation(
      'REPOSITORY_ISOLATION',
      'HistoryEngine registered without HistoryRepository',
    ));
  }

  // Rule 3: EditorController authority
  if (!registry.has(RegistryKeys.editorController)) {
    violations.add(const _IntegrationViolation(
      'CONTROLLER_AUTHORITY',
      'EditorController missing — no execution authority exists',
    ));
  }

  if (violations.isNotEmpty) throw _IntegrationGuardError(violations);
}

// ============================================================
// DEPENDENCY CONTAINER — Poore project ki ek aur akeli wiring
// ============================================================

final class DependencyContainer {
  DependencyContainer._();

  late final DependencyRegistry _registry;

  /// routes.dart yahan se resolve kar sakta hai — register nahi
  DependencyRegistry get registry => _registry;

  /// Shortcut — UI ke liye execution authority
  EditorController get editor =>
      _registry.resolve<EditorController>(RegistryKeys.editorController);

  // ── Factory ────────────────────────────────────────────────────────────────

  static Future<DependencyContainer> create() async {
    final c = DependencyContainer._();
    await c._wire();
    return c;
  }

  // ── Full wiring — PHASE-21 Step 01 → 15 ───────────────────────────────────

  Future<void> _wire() async {

    // ══════════════════════════════════════════════════════════
    // STEP-01  Create DependencyRegistry — exactly once here
    // ══════════════════════════════════════════════════════════

    _registry = DependencyRegistry._internal();

    // ══════════════════════════════════════════════════════════
    // STEP-02  Create Storage Layer
    // ══════════════════════════════════════════════════════════

    final StorageEngine storageEngine = StorageEngine();

    // ══════════════════════════════════════════════════════════
    // STEP-03  Create Repository Layer
    //
    // StorageEngine → Repository → Engine (chain)
    // Engine kabhi seedha StorageEngine nahi pakdega
    // ══════════════════════════════════════════════════════════

    final LayerRepository    layerRepository    = LayerRepository(storageEngine);
    final DesignRepository   designRepository   = DesignRepository(storageEngine);
    final HistoryRepository  historyRepository  = HistoryRepository(storageEngine);
    final TemplateRepository templateRepository = TemplateRepository(storageEngine);

    // ══════════════════════════════════════════════════════════
    // STEP-04  Register Repository Layer
    // ══════════════════════════════════════════════════════════

    _registry.register(RegistryKeys.layerRepository,    layerRepository);
    _registry.register(RegistryKeys.designRepository,   designRepository);
    _registry.register(RegistryKeys.historyRepository,  historyRepository);
    _registry.register(RegistryKeys.templateRepository, templateRepository);

    // ══════════════════════════════════════════════════════════
    // STEP-05  Create Core Engines
    // STEP-06  Inject Repository Dependencies
    //
    // LayerEngine    ← LayerRepository    (StorageEngine nahi)
    // HistoryEngine  ← HistoryRepository  (StorageEngine nahi)
    // TemplateEngine ← DesignRepository   (StorageEngine nahi)
    // ══════════════════════════════════════════════════════════

    final LayerEngine    layerEngine    = LayerEngine(repository: layerRepository);
    final HistoryEngine  historyEngine  = HistoryEngine(repository: historyRepository);
    final TemplateEngine templateEngine = TemplateEngine(
      designRepository:   designRepository,
      templateRepository: templateRepository,
    );
    final RenderEngine   renderEngine   = RenderEngine();
    final ExportEngine   exportEngine   = ExportEngine();
    final SyncEngine     syncEngine     = SyncEngine();   // optional cloud — offline-safe
    final AIEngine       aiEngine       = AIEngine();     // intent → commands only, never executes

    // ══════════════════════════════════════════════════════════
    // STEP-07  Register Core Engines
    // ══════════════════════════════════════════════════════════

    _registry.register(RegistryKeys.storageEngine,  storageEngine);
    _registry.register(RegistryKeys.layerEngine,    layerEngine);
    _registry.register(RegistryKeys.historyEngine,  historyEngine);
    _registry.register(RegistryKeys.templateEngine, templateEngine);
    _registry.register(RegistryKeys.renderEngine,   renderEngine);
    _registry.register(RegistryKeys.exportEngine,   exportEngine);
    _registry.register(RegistryKeys.syncEngine,     syncEngine);
    _registry.register(RegistryKeys.aiEngine,       aiEngine);

    // ══════════════════════════════════════════════════════════
    // STEP-08  Create Optional Engines
    // ══════════════════════════════════════════════════════════

    final TelemetryEngine?         telemetryEngine         = TelemetryEngine();
    final DebugTraceEngine?        debugTraceEngine        = DebugTraceEngine();
    final SystemHealthEngine?      systemHealthEngine      = SystemHealthEngine();
    final SuggestionEngine?        suggestionEngine        = SuggestionEngine();
    final InsightEngine?           insightEngine           = InsightEngine();
    final InputOrchestratorEngine? inputOrchestratorEngine = InputOrchestratorEngine();
    final CommandGatewayEngine?    commandGatewayEngine    = CommandGatewayEngine();
    final ExecutionPolicyEngine?   executionPolicyEngine   = ExecutionPolicyEngine();
    final ContextMemoryEngine?     contextMemoryEngine     = ContextMemoryEngine();
    final RuntimeManagerEngine?    runtimeManagerEngine    = RuntimeManagerEngine();
    final ResourcePolicyEngine?    resourcePolicyEngine    = ResourcePolicyEngine();
    final TaskSchedulerEngine?     taskSchedulerEngine     = TaskSchedulerEngine();
    final AutomationEngine?        automationEngine        = AutomationEngine();
    final PluginEngine?            pluginEngine            = PluginEngine();
    final WorkflowEngine?          workflowEngine          = WorkflowEngine();
    final ResponsiveLayoutEngine?  responsiveLayoutEngine  = ResponsiveLayoutEngine();

    // ══════════════════════════════════════════════════════════
    // STEP-09  Register Optional Engines
    //
    // Null hone par sirf warning — boot kabhi fail nahi hoga
    // ══════════════════════════════════════════════════════════

    _registry.registerOptional(RegistryKeys.telemetryEngine,         telemetryEngine);
    _registry.registerOptional(RegistryKeys.debugTraceEngine,        debugTraceEngine);
    _registry.registerOptional(RegistryKeys.systemHealthEngine,      systemHealthEngine);
    _registry.registerOptional(RegistryKeys.suggestionEngine,        suggestionEngine);
    _registry.registerOptional(RegistryKeys.insightEngine,           insightEngine);
    _registry.registerOptional(RegistryKeys.inputOrchestratorEngine, inputOrchestratorEngine);
    _registry.registerOptional(RegistryKeys.commandGatewayEngine,    commandGatewayEngine);
    _registry.registerOptional(RegistryKeys.executionPolicyEngine,   executionPolicyEngine);
    _registry.registerOptional(RegistryKeys.contextMemoryEngine,     contextMemoryEngine);
    _registry.registerOptional(RegistryKeys.runtimeManagerEngine,    runtimeManagerEngine);
    _registry.registerOptional(RegistryKeys.resourcePolicyEngine,    resourcePolicyEngine);
    _registry.registerOptional(RegistryKeys.taskSchedulerEngine,     taskSchedulerEngine);
    _registry.registerOptional(RegistryKeys.automationEngine,        automationEngine);
    _registry.registerOptional(RegistryKeys.pluginEngine,            pluginEngine);
    _registry.registerOptional(RegistryKeys.workflowEngine,          workflowEngine);
    _registry.registerOptional(RegistryKeys.responsiveLayoutEngine,  responsiveLayoutEngine);

    // ══════════════════════════════════════════════════════════
    // STEP-10  Create EditorController
    // STEP-11  Inject Engine Dependencies (constructor injection only)
    //
    // EditorController ← sare engines
    // EditorController kabhi seedha StorageEngine nahi pakdega
    //
    // EXECUTION AUTHORITY LAWS:
    //   ALLOWED:   UI  → EditorController → Engine
    //   ALLOWED:   AI  → EditorController → Engine
    //   FORBIDDEN: UI  → Engine    (direct)
    //   FORBIDDEN: UI  → Canvas    (direct)
    //   FORBIDDEN: AI  → Engine    (direct)
    //   FORBIDDEN: AI  → Canvas    (direct)
    // ══════════════════════════════════════════════════════════

    final EditorController editorController = EditorController(
      // Core (required)
      layerEngine:    layerEngine,
      historyEngine:  historyEngine,
      templateEngine: templateEngine,
      renderEngine:   renderEngine,
      exportEngine:   exportEngine,
      syncEngine:     syncEngine,
      aiEngine:       aiEngine,

      // Optional (null-safe — engine nahi mila toh feature gracefully skip)
      telemetry:         telemetryEngine,
      debugTrace:        debugTraceEngine,
      systemHealth:      systemHealthEngine,
      suggestion:        suggestionEngine,
      insight:           insightEngine,
      inputOrchestrator: inputOrchestratorEngine,
      commandGateway:    commandGatewayEngine,
      executionPolicy:   executionPolicyEngine,
      contextMemory:     contextMemoryEngine,
      runtimeManager:    runtimeManagerEngine,
      resourcePolicy:    resourcePolicyEngine,
      taskScheduler:     taskSchedulerEngine,
      automation:        automationEngine,
      plugin:            pluginEngine,
      workflow:          workflowEngine,
      responsiveLayout:  responsiveLayoutEngine,
    );

    // ══════════════════════════════════════════════════════════
    // STEP-12  Register EditorController
    // ══════════════════════════════════════════════════════════

    _registry.register(RegistryKeys.editorController, editorController);

    // ══════════════════════════════════════════════════════════
    // STEP-13  Run IntegrationGuard
    // Dependency graph + repository isolation + controller
    // authority validate karo — violation = boot abort
    // ══════════════════════════════════════════════════════════

    _runIntegrationGuard(_registry);

    // ══════════════════════════════════════════════════════════
    // STEP-14  Assert Registry Completeness
    // Koi required key missing = boot abort
    // ══════════════════════════════════════════════════════════

    _registry.assertComplete();

    // ══════════════════════════════════════════════════════════
    // STEP-15  Lock Registry
    // Ab koi bhi register nahi kar sakta
    // EditorController hi akela execution authority hai
    // ══════════════════════════════════════════════════════════

    _registry.lock();
  }
}

// ============================================================
// USAGE — main.dart ya app bootstrap mein aise use karein:
//
//   void main() async {
//     WidgetsFlutterBinding.ensureInitialized();
//     final container = await DependencyContainer.create();
//     runApp(MyApp(container: container));
//   }
//
// routes.dart mein resolve karo — create mat karo:
//
//   final editor = container.registry
//       .resolve<EditorController>(RegistryKeys.editorController);
//
//   // Ya shortcut:
//   final editor = container.editor;
//
// FORBIDDEN in routes.dart / screens / widgets / engines:
//   DependencyRegistry()   ← architecture violation
//   LayerEngine(...)       ← architecture violation
//   StorageEngine(...)     ← architecture violation
// ============================================================
