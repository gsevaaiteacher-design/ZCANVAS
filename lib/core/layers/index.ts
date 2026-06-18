/**
 * Layer definitions and contracts
 * Strict hierarchical architecture: Repository < Engine < Controller < UI
 * Each layer has a clear responsibility and interface
 */

/**
 * REPOSITORY LAYER
 * Responsibility: Data persistence, retrieval, and transformation
 * Can depend on: Nothing (bottom of hierarchy)
 * Cannot depend on: Engine, Controller, UI
 */
export interface IRepository<T = any> {
  /** Get item by ID */
  findById(id: string): Promise<T | null>;
  
  /** Get all items */
  findAll(): Promise<T[]>;
  
  /** Create new item */
  create(data: Partial<T>): Promise<T>;
  
  /** Update existing item */
  update(id: string, data: Partial<T>): Promise<T>;
  
  /** Delete item */
  delete(id: string): Promise<boolean>;
  
  /** Execute raw query (optional) */
  query?(sql: string, params?: any[]): Promise<any[]>;
}

/**
 * ENGINE LAYER
 * Responsibility: Business logic, calculations, transformations, rules
 * Can depend on: Repository
 * Cannot depend on: Controller, UI
 */
export interface IEngine<TInput = any, TOutput = any> {
  /** Process input and return output */
  execute(input: TInput): Promise<TOutput>;
  
  /** Validate input before execution */
  validate?(input: TInput): boolean | string;
  
  /** Get engine metadata */
  getMetadata(): EngineMetadata;
}

export interface EngineMetadata {
  id: string;
  name: string;
  version: string;
  description?: string;
  inputSchema?: any;
  outputSchema?: any;
}

/**
 * CONTROLLER LAYER
 * Responsibility: Orchestration, request handling, response formatting
 * Can depend on: Repository, Engine
 * Cannot depend on: UI
 */
export interface IController<TRequest = any, TResponse = any> {
  /** Handle incoming request */
  handle(request: TRequest): Promise<TResponse>;
  
  /** Get controller metadata */
  getMetadata(): ControllerMetadata;
}

export interface ControllerMetadata {
  id: string;
  name: string;
  version: string;
  endpoint?: string;
  method?: string;
}

/**
 * UI LAYER
 * Responsibility: User presentation, interaction, rendering
 * Can depend on: Repository, Engine, Controller
 * Cannot depend on: Nothing above UI (it's the top layer)
 */
export interface IUIComponent<TProps = any, TState = any> {
  /** Render component */
  render(props: TProps): Promise<string | object>;
  
  /** Handle user interaction */
  handleEvent?(event: UIEvent): Promise<void>;
  
  /** Get component metadata */
  getMetadata(): UIComponentMetadata;
}

export interface UIEvent {
  type: string;
  target?: any;
  data?: any;
}

export interface UIComponentMetadata {
  id: string;
  name: string;
  version: string;
  componentType?: string;
}

/**
 * COMMON INTERFACES
 */

/** Service that can be initialized */
export interface IInitializable {
  initialize(): Promise<void>;
}

/** Service with lifecycle */
export interface ILifecycleAware extends IInitializable {
  start?(): Promise<void>;
  stop?(): Promise<void>;
  destroy?(): Promise<void>;
}

/** Service with validation */
export interface IValidatable {
  validate(): boolean | string[];
}

/** Service with health check */
export interface IHealthCheckable {
  healthCheck(): Promise<HealthStatus>;
}

export interface HealthStatus {
  status: 'healthy' | 'degraded' | 'unhealthy';
  message?: string;
  details?: Record<string, any>;
}
