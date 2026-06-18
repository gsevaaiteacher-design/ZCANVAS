/**
 * SystemBootstrap - Single entry point for the entire application
 * Manages the complete initialization sequence:
 * 1. Repository layer (data source)
 * 2. Engine layer (business logic)
 * 3. Controller layer (orchestration)
 * 4. UI layer (presentation)
 *
 * This is the ONLY place where the wiring happens.
 * All other modules are purely functional, not aware of initialization.
 */

import { DependencyRegistry, IServiceDefinition } from '../registry/DependencyRegistry';

export interface BootstrapConfig {
  servicePath?: string;
  logger?: IBootstrapLogger;
  strict?: boolean; // Enforce strict layer validation
}

export interface IBootstrapLogger {
  info(message: string): void;
  warn(message: string): void;
  error(message: string, err?: Error): void;
  debug(message: string): void;
}

class DefaultLogger implements IBootstrapLogger {
  info(message: string): void {
    console.log(`[INFO] ${message}`);
  }
  warn(message: string): void {
    console.warn(`[WARN] ${message}`);
  }
  error(message: string, err?: Error): void {
    console.error(`[ERROR] ${message}`, err);
  }
  debug(message: string): void {
    console.debug(`[DEBUG] ${message}`);
  }
}

export class SystemBootstrap {
  private registry: DependencyRegistry;
  private config: BootstrapConfig;
  private logger: IBootstrapLogger;
  private isBooted = false;
  private bootedAt = 0;
  private serviceDefinitions: Map<string, IServiceDefinition> = new Map();

  constructor(config: BootstrapConfig = {}) {
    this.registry = new DependencyRegistry();
    this.config = {
      servicePath: 'lib/services',
      strict: true,
      ...config,
    };
    this.logger = config.logger || new DefaultLogger();
  }

  /**
   * Register all service definitions
   * This should be called before bootstrap()
   */
  registerServices(definitions: IServiceDefinition[]): SystemBootstrap {
    if (this.isBooted) {
      throw new Error('Cannot register services after bootstrap');
    }

    this.logger.info(`Registering ${definitions.length} services...`);

    for (const definition of definitions) {
      try {
        this.registry.register(definition);
        this.serviceDefinitions.set(definition.id, definition);
        this.logger.debug(
          `Registered: ${definition.id} [${definition.layer}]${definition.dependencies?.length ? ` -> [${definition.dependencies.join(', ')}]` : ''}`
        );
      } catch (error) {
        this.logger.error(
          `Failed to register service '${definition.id}'`,
          error as Error
        );
        throw error;
      }
    }

    return this;
  }

  /**
   * Main bootstrap sequence
   * Initializes the entire system in correct order
   */
  async bootstrap(): Promise<void> {
    if (this.isBooted) {
      this.logger.warn('System already booted, skipping bootstrap');
      return;
    }

    this.bootedAt = Date.now();
    this.logger.info('🚀 Starting system bootstrap...');

    try {
      // Step 1: Build initialization order
      this.logger.info('📋 Building initialization order...');
      const initOrder = this.registry.buildInitializationOrder();
      this.logger.debug(`Initialization sequence: ${initOrder.join(' -> ')}`);

      // Step 2: Initialize repository layer (data source)
      await this.initializeLayer('repository', initOrder);

      // Step 3: Initialize engine layer (business logic)
      await this.initializeLayer('engine', initOrder);

      // Step 4: Initialize controller layer (orchestration)
      await this.initializeLayer('controller', initOrder);

      // Step 5: Initialize UI layer (presentation)
      await this.initializeLayer('ui', initOrder);

      // Step 6: Mark registry as locked
      this.registry.markInitialized();

      this.isBooted = true;
      const elapsed = Date.now() - this.bootedAt;
      this.logger.info(`✅ System bootstrap complete in ${elapsed}ms`);
      this.logBootstrapSummary();
    } catch (error) {
      this.logger.error('❌ Bootstrap failed', error as Error);
      throw error;
    }
  }

  /**
   * Initialize a specific layer
   */
  private async initializeLayer(
    layer: 'repository' | 'engine' | 'controller' | 'ui',
    initOrder: string[]
  ): Promise<void> {
    const layerServices = this.registry.getByLayer(layer);

    if (layerServices.length === 0) {
      this.logger.debug(`No services for layer: ${layer}`);
      return;
    }

    this.logger.info(`📦 Initializing ${layer} layer (${layerServices.length} services)...`);

    for (const serviceId of layerServices) {
      if (!initOrder.includes(serviceId)) continue;

      try {
        // Access service to trigger lazy initialization
        const service = this.registry.get(serviceId);

        // If service implements IRegistrable, call initialize
        if (service && typeof service.initialize === 'function') {
          this.logger.debug(`  Initializing: ${serviceId}`);
          await service.initialize(this.registry);
        }

        this.logger.debug(`  ✓ ${serviceId}`);
      } catch (error) {
        this.logger.error(`Failed to initialize ${serviceId}`, error as Error);
        throw error;
      }
    }
  }

  /**
   * Get initialized registry
   * Available only after bootstrap()
   */
  getRegistry(): DependencyRegistry {
    if (!this.isBooted) {
      throw new Error(
        'Cannot access registry before bootstrap. Call bootstrap() first.'
      );
    }
    return this.registry;
  }

  /**
   * Get a service from the registry
   */
  getService<T = any>(id: string): T {
    return this.registry.get<T>(id);
  }

  /**
   * Check if system is booted
   */
  isBootstrapped(): boolean {
    return this.isBooted;
  }

  /**
   * Get boot time in milliseconds
   */
  getBootTime(): number {
    if (!this.isBooted) return 0;
    return Date.now() - this.bootedAt;
  }

  /**
   * Log bootstrap summary
   */
  private logBootstrapSummary(): void {
    const layers = ['repository', 'engine', 'controller', 'ui'] as const;
    const summary: Record<string, number> = {};

    for (const layer of layers) {
      const count = this.registry.getByLayer(layer).length;
      if (count > 0) {
        summary[layer] = count;
      }
    }

    this.logger.info(
      `📊 Bootstrap Summary: ${JSON.stringify(summary)} | Total: ${this.registry.count()} services`
    );
  }
}

/**
 * Singleton instance of bootstrap
 */
let bootstrapInstance: SystemBootstrap | null = null;

/**
 * Get or create bootstrap instance
 */
export const getBootstrap = (config?: BootstrapConfig): SystemBootstrap => {
  if (!bootstrapInstance) {
    bootstrapInstance = new SystemBootstrap(config);
  }
  return bootstrapInstance;
};

/**
 * Reset bootstrap instance (for testing)
 */
export const resetBootstrap = (): void => {
  bootstrapInstance = null;
};
