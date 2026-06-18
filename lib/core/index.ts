/**
 * Core module exports
 * Central hub for all architectural infrastructure
 */

// Registry
export {
  DependencyRegistry,
  IRegistrable,
  IServiceDefinition,
  createRegistry,
} from './registry/DependencyRegistry';

// Bootstrap
export {
  SystemBootstrap,
  getBootstrap,
  resetBootstrap,
  BootstrapConfig,
  IBootstrapLogger,
} from './bootstrap/SystemBootstrap';

// Layers
export {
  IRepository,
  IEngine,
  EngineMetadata,
  IController,
  ControllerMetadata,
  IUIComponent,
  UIEvent,
  UIComponentMetadata,
  IInitializable,
  ILifecycleAware,
  IValidatable,
  IHealthCheckable,
  HealthStatus,
} from './layers/index';

// Common
export {
  Logger,
  createLogger,
  ILogger,
  LogLevel,
} from './common/Logger';

export {
  ApplicationError,
  ErrorHandler,
  AppError,
  ErrorSeverity,
} from './common/ErrorHandler';

export {
  Validator,
  ValidationRule,
  ValidationSchema,
  ValidationResult,
} from './common/Validator';

// Deduplication
export {
  CodeDeduplicator,
  DuplicateAnalysis,
  DeduplicationReport,
  ConsolidationStep,
} from './deduplication/CodeDeduplicator';
