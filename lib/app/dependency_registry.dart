import 'package:get_it/get_it.dart';
import '../core/execution/action_executor.dart';
import '../core/execution/action_validator.dart';
import '../core/execution/editor_action_engine.dart';
import '../core/execution/execution_safety_layer.dart';
import '../core/history/history_guard.dart';
import '../core/history/history_manager.dart';
import '../core/history/recovery_engine.dart';
import '../core/history/snapshot_engine.dart';
import '../engine/render_engine.dart';
import '../engine/layer_engine.dart';
import '../engine/ai_engine.dart';
import '../engine/automation_engine.dart';
import '../engine/command_gateway_engine.dart';
import '../engine/context_memory_engine.dart';
import '../engine/debug_trace_engine.dart';
import '../engine/design_repository.dart';
import '../engine/execution_policy_engine.dart';
import '../engine/export_engine.dart';
import '../engine/history_engine.dart';
import '../engine/input_orchestrator_engine.dart';
import '../engine/insight_engine.dart';
import '../engine/plugin_engine.dart';
import '../engine/resource_policy_engine.dart';
import '../engine/responsive_layout_engine.dart';
import '../engine/runtime_manager_engine.dart';
import '../engine/suggestion_engine.dart';
import '../engine/sync_engine.dart';
import '../engine/system_health_engine.dart';
import '../engine/task_scheduler_engine.dart';
import '../engine/telemetry_engine.dart';
import '../engine/template_engine.dart';
import '../engine/workflow_engine.dart';
import '../controllers/action_router.dart';
import '../controllers/command_mapper.dart';
import '../controllers/editor_controller.dart';
import '../controllers/execution_bridge.dart';
import '../controllers/intention_interpreter.dart';
import '../Repository/storage_repository.dart';
import '../Repository/history_repository.dart';
import '../Repository/layer_repository.dart';
import '../Repository/template_repository.dart';
import '../models/design_model.dart';
import '../models/layer_model.dart';

/// Centralized Dependency Registry using GetIt
/// Layer hierarchy: Repository → Engine → Controller → UI
/// NO circular dependencies enforced
class DependencyRegistry {
  static final GetIt _getIt = GetIt.instance;
  static bool _initialized = false;

  /// Initialize all dependencies in correct order
  static Future<void> init() async {
    if (_initialized) return;

    try {
      // LAYER 1: REPOSITORY (Data Persistence - Bottom)
      _registerRepositories();

      // LAYER 2: CORE/EXECUTION (Business Logic Foundation)
      _registerCoreExecutionServices();

      // LAYER 3: CORE/HISTORY (History and Recovery)
      _registerHistoryServices();

      // LAYER 4: ENGINES (Business Logic - Complex Operations)
      _registerEngines();

      // LAYER 5: CONTROLLERS (Orchestration)
      _registerControllers();

      _initialized = true;
    } catch (e) {
      rethrow;
    }
  }

  /// LAYER 1: Repository Services (Data Access - No Dependencies)
  static void _registerRepositories() {
    // Storage Repository - Single source of truth for all storage
    _getIt.registerSingleton<StorageRepository>(
      StorageRepository(),
      instanceName: 'StorageRepository',
    );

    // History Repository - Built on top of Storage
    _getIt.registerSingleton<HistoryRepository>(
      HistoryRepository(
        storageRepository: _getIt<StorageRepository>(
          instanceName: 'StorageRepository',
        ),
      ),
      instanceName: 'HistoryRepository',
    );

    // Layer Repository - Layer-specific data
    _getIt.registerSingleton<LayerRepository>(
      LayerRepository(
        storageRepository: _getIt<StorageRepository>(
          instanceName: 'StorageRepository',
        ),
      ),
      instanceName: 'LayerRepository',
    );

    // Template Repository - Template management
    _getIt.registerSingleton<TemplateRepository>(
      TemplateRepository(
        storageRepository: _getIt<StorageRepository>(
          instanceName: 'StorageRepository',
        ),
      ),
      instanceName: 'TemplateRepository',
    );
  }

  /// LAYER 2: Core Execution Services (Foundation for all execution)
  static void _registerCoreExecutionServices() {
    // Action Validator
    _getIt.registerSingleton<ActionValidator>(
      ActionValidator(),
      instanceName: 'ActionValidator',
    );

    // Execution Safety Layer
    _getIt.registerSingleton<ExecutionSafetyLayer>(
      ExecutionSafetyLayer(
        validator: _getIt<ActionValidator>(instanceName: 'ActionValidator'),
      ),
      instanceName: 'ExecutionSafetyLayer',
    );

    // Action Executor - Core execution engine
    _getIt.registerSingleton<ActionExecutor>(
      ActionExecutor(
        safetyLayer: _getIt<ExecutionSafetyLayer>(
          instanceName: 'ExecutionSafetyLayer',
        ),
        validator: _getIt<ActionValidator>(instanceName: 'ActionValidator'),
      ),
      instanceName: 'ActionExecutor',
    );

    // Editor Action Engine
    _getIt.registerSingleton<EditorActionEngine>(
      EditorActionEngine(
        executor: _getIt<ActionExecutor>(instanceName: 'ActionExecutor'),
        validator: _getIt<ActionValidator>(instanceName: 'ActionValidator'),
      ),
      instanceName: 'EditorActionEngine',
    );
  }

  /// LAYER 3: History Services (Built on Execution)
  static void _registerHistoryServices() {
    // Snapshot Engine
    _getIt.registerSingleton<SnapshotEngine>(
      SnapshotEngine(
        historyRepository: _getIt<HistoryRepository>(
          instanceName: 'HistoryRepository',
        ),
      ),
      instanceName: 'SnapshotEngine',
    );

    // History Manager
    _getIt.registerSingleton<HistoryManager>(
      HistoryManager(
        repository: _getIt<HistoryRepository>(instanceName: 'HistoryRepository'),
        snapshotEngine: _getIt<SnapshotEngine>(instanceName: 'SnapshotEngine'),
      ),
      instanceName: 'HistoryManager',
    );

    // Recovery Engine
    _getIt.registerSingleton<RecoveryEngine>(
      RecoveryEngine(
        historyManager: _getIt<HistoryManager>(instanceName: 'HistoryManager'),
        storageRepository: _getIt<StorageRepository>(
          instanceName: 'StorageRepository',
        ),
      ),
      instanceName: 'RecoveryEngine',
    );

    // History Guard
    _getIt.registerSingleton<HistoryGuard>(
      HistoryGuard(
        historyManager: _getIt<HistoryManager>(instanceName: 'HistoryManager'),
        recoveryEngine: _getIt<RecoveryEngine>(instanceName: 'RecoveryEngine'),
      ),
      instanceName: 'HistoryGuard',
    );
  }

  /// LAYER 4: Engines (Business Logic - Complex Operations)
  static void _registerEngines() {
    // Design Repository Engine - Data access for designs
    _getIt.registerSingleton<DesignRepository>(
      DesignRepository(
        storageRepository: _getIt<StorageRepository>(
          instanceName: 'StorageRepository',
        ),
      ),
      instanceName: 'DesignRepository',
    );

    // Render Engine - Canvas rendering
    _getIt.registerSingleton<RenderEngine>(
      RenderEngine(
        designRepository: _getIt<DesignRepository>(
          instanceName: 'DesignRepository',
        ),
      ),
      instanceName: 'RenderEngine',
    );

    // Layer Engine - Layer management
    _getIt.registerSingleton<LayerEngine>(
      LayerEngine(
        layerRepository: _getIt<LayerRepository>(instanceName: 'LayerRepository'),
        renderEngine: _getIt<RenderEngine>(instanceName: 'RenderEngine'),
      ),
      instanceName: 'LayerEngine',
    );

    // Context Memory Engine
    _getIt.registerSingleton<ContextMemoryEngine>(
      ContextMemoryEngine(),
      instanceName: 'ContextMemoryEngine',
    );

    // AI Engine
    _getIt.registerSingleton<AIEngine>(
      AIEngine(
        contextMemory: _getIt<ContextMemoryEngine>(
          instanceName: 'ContextMemoryEngine',
        ),
      ),
      instanceName: 'AIEngine',
    );

    // Command Gateway Engine
    _getIt.registerSingleton<CommandGatewayEngine>(
      CommandGatewayEngine(),
      instanceName: 'CommandGatewayEngine',
    );

    // Automation Engine
    _getIt.registerSingleton<AutomationEngine>(
      AutomationEngine(
        commandGateway: _getIt<CommandGatewayEngine>(
          instanceName: 'CommandGatewayEngine',
        ),
      ),
      instanceName: 'AutomationEngine',
    );

    // Debug Trace Engine
    _getIt.registerSingleton<DebugTraceEngine>(
      DebugTraceEngine(),
      instanceName: 'DebugTraceEngine',
    );

    // Execution Policy Engine
    _getIt.registerSingleton<ExecutionPolicyEngine>(
      ExecutionPolicyEngine(),
      instanceName: 'ExecutionPolicyEngine',
    );

    // Export Engine
    _getIt.registerSingleton<ExportEngine>(
      ExportEngine(
        designRepository: _getIt<DesignRepository>(
          instanceName: 'DesignRepository',
        ),
      ),
      instanceName: 'ExportEngine',
    );

    // History Engine
    _getIt.registerSingleton<HistoryEngine>(
      HistoryEngine(
        historyManager: _getIt<HistoryManager>(instanceName: 'HistoryManager'),
      ),
      instanceName: 'HistoryEngine',
    );

    // Input Orchestrator Engine
    _getIt.registerSingleton<InputOrchestratorEngine>(
      InputOrchestratorEngine(),
      instanceName: 'InputOrchestratorEngine',
    );

    // Insight Engine
    _getIt.registerSingleton<InsightEngine>(
      InsightEngine(
        contextMemory: _getIt<ContextMemoryEngine>(
          instanceName: 'ContextMemoryEngine',
        ),
      ),
      instanceName: 'InsightEngine',
    );

    // Plugin Engine
    _getIt.registerSingleton<PluginEngine>(
      PluginEngine(),
      instanceName: 'PluginEngine',
    );

    // Resource Policy Engine
    _getIt.registerSingleton<ResourcePolicyEngine>(
      ResourcePolicyEngine(),
      instanceName: 'ResourcePolicyEngine',
    );

    // Responsive Layout Engine
    _getIt.registerSingleton<ResponsiveLayoutEngine>(
      ResponsiveLayoutEngine(),
      instanceName: 'ResponsiveLayoutEngine',
    );

    // Runtime Manager Engine
    _getIt.registerSingleton<RuntimeManagerEngine>(
      RuntimeManagerEngine(),
      instanceName: 'RuntimeManagerEngine',
    );

    // Suggestion Engine
    _getIt.registerSingleton<SuggestionEngine>(
      SuggestionEngine(
        aiEngine: _getIt<AIEngine>(instanceName: 'AIEngine'),
      ),
      instanceName: 'SuggestionEngine',
    );

    // Sync Engine
    _getIt.registerSingleton<SyncEngine>(
      SyncEngine(),
      instanceName: 'SyncEngine',
    );

    // System Health Engine
    _getIt.registerSingleton<SystemHealthEngine>(
      SystemHealthEngine(),
      instanceName: 'SystemHealthEngine',
    );

    // Task Scheduler Engine
    _getIt.registerSingleton<TaskSchedulerEngine>(
      TaskSchedulerEngine(),
      instanceName: 'TaskSchedulerEngine',
    );

    // Telemetry Engine
    _getIt.registerSingleton<TelemetryEngine>(
      TelemetryEngine(),
      instanceName: 'TelemetryEngine',
    );

    // Template Engine
    _getIt.registerSingleton<TemplateEngine>(
      TemplateEngine(
        templateRepository: _getIt<TemplateRepository>(
          instanceName: 'TemplateRepository',
        ),
      ),
      instanceName: 'TemplateEngine',
    );

    // Workflow Engine
    _getIt.registerSingleton<WorkflowEngine>(
      WorkflowEngine(
        taskScheduler: _getIt<TaskSchedulerEngine>(
          instanceName: 'TaskSchedulerEngine',
        ),
      ),
      instanceName: 'WorkflowEngine',
    );
  }

  /// LAYER 5: Controllers (Orchestration)
  static void _registerControllers() {
    // Action Router
    _getIt.registerSingleton<ActionRouter>(
      ActionRouter(
        executor: _getIt<ActionExecutor>(instanceName: 'ActionExecutor'),
      ),
      instanceName: 'ActionRouter',
    );

    // Command Mapper
    _getIt.registerSingleton<CommandMapper>(
      CommandMapper(
        commandGateway: _getIt<CommandGatewayEngine>(
          instanceName: 'CommandGatewayEngine',
        ),
      ),
      instanceName: 'CommandMapper',
    );

    // Intention Interpreter
    _getIt.registerSingleton<IntentionInterpreter>(
      IntentionInterpreter(
        aiEngine: _getIt<AIEngine>(instanceName: 'AIEngine'),
      ),
      instanceName: 'IntentionInterpreter',
    );

    // Execution Bridge
    _getIt.registerSingleton<ExecutionBridge>(
      ExecutionBridge(
        executor: _getIt<ActionExecutor>(instanceName: 'ActionExecutor'),
        interpreter: _getIt<IntentionInterpreter>(
          instanceName: 'IntentionInterpreter',
        ),
      ),
      instanceName: 'ExecutionBridge',
    );

    // Editor Controller - Main orchestrator
    _getIt.registerSingleton<EditorController>(
      EditorController(
        renderEngine: _getIt<RenderEngine>(instanceName: 'RenderEngine'),
        layerEngine: _getIt<LayerEngine>(instanceName: 'LayerEngine'),
        historyManager: _getIt<HistoryManager>(instanceName: 'HistoryManager'),
        actionRouter: _getIt<ActionRouter>(instanceName: 'ActionRouter'),
        executionBridge: _getIt<ExecutionBridge>(
          instanceName: 'ExecutionBridge',
        ),
      ),
      instanceName: 'EditorController',
    );
  }

  /// Get a service instance by name
  static T get<T>(String instanceName) {
    return _getIt.get<T>(instanceName: instanceName);
  }

  /// Check if initialized
  static bool get isInitialized => _initialized;
}
