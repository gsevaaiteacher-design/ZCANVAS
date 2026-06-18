/**
 * DependencyRegistry - Central registry for all dependencies
 * Implements the single source of truth for all module definitions
 * No event bus - pure dependency injection with strict layering
 */

export interface IRegistrable {
  getId(): string;
  initialize(registry: DependencyRegistry): Promise<void>;
}

export interface IServiceDefinition<T = any> {
  id: string;
  layer: 'repository' | 'engine' | 'controller' | 'ui';
  factory: (registry: DependencyRegistry) => T | Promise<T>;
  singleton?: boolean;
  dependencies?: string[];
}

export class DependencyRegistry {
  private services = new Map<string, any>();
  private definitions = new Map<string, IServiceDefinition>();
  private layerOrder = ['repository', 'engine', 'controller', 'ui'] as const;
  private instantiationOrder: string[] = [];
  private isInitialized = false;

  /**
   * Register a service definition
   * Enforces layer hierarchy - services can only depend on layers below them
   */
  register<T = any>(definition: IServiceDefinition<T>): void {
    if (this.isInitialized) {
      throw new Error(
        `Cannot register service '${definition.id}' after registry initialization`
      );
    }

    if (this.definitions.has(definition.id)) {
      throw new Error(
        `Service '${definition.id}' already registered. Remove duplicates.`
      );
    }

    this.validateLayerHierarchy(definition);
    this.definitions.set(definition.id, definition);
  }

  /**
   * Resolve a service from the registry
   * Lazy-loads singletons on first access
   */
  get<T = any>(id: string): T {
    if (!this.definitions.has(id)) {
      throw new Error(
        `Service '${id}' not found in registry. Check service registration.`
      );
    }

    const definition = this.definitions.get(id)!;

    if (definition.singleton) {
      if (!this.services.has(id)) {
        this.services.set(id, definition.factory(this));
      }
      return this.services.get(id) as T;
    }

    return definition.factory(this) as T;
  }

  /**
   * Get all service IDs for a specific layer
   */
  getByLayer(layer: 'repository' | 'engine' | 'controller' | 'ui'): string[] {
    return Array.from(this.definitions.values())
      .filter((def) => def.layer === layer)
      .map((def) => def.id);
  }

  /**
   * Validate that services respect layer hierarchy
   * Repository < Engine < Controller < UI
   */
  private validateLayerHierarchy(definition: IServiceDefinition): void {
    if (!definition.dependencies || definition.dependencies.length === 0) {
      return;
    }

    const currentLayerIndex = this.layerOrder.indexOf(definition.layer);

    for (const depId of definition.dependencies) {
      const depDef = this.definitions.get(depId);
      if (!depDef) {
        throw new Error(
          `Service '${definition.id}' depends on unregistered '${depId}'`
        );
      }

      const depLayerIndex = this.layerOrder.indexOf(depDef.layer);

      if (depLayerIndex >= currentLayerIndex) {
        throw new Error(
          `Layer violation: '${definition.id}' (${definition.layer}) cannot depend on '${depId}' (${depDef.layer}). ` +
          `Services can only depend on lower layers: repository < engine < controller < ui`
        );
      }
    }
  }

  /**
   * Build initialization order based on dependencies
   * Ensures services are initialized before services that depend on them
   */
  buildInitializationOrder(): string[] {
    const visited = new Set<string>();
    const order: string[] = [];

    const visit = (id: string, visiting = new Set<string>()) => {
      if (visited.has(id)) return;

      if (visiting.has(id)) {
        throw new Error(
          `Circular dependency detected: ${id} -> ${Array.from(visiting).join(' -> ')}`
        );
      }

      visiting.add(id);

      const def = this.definitions.get(id);
      if (def?.dependencies) {
        for (const dep of def.dependencies) {
          visit(dep, new Set(visiting));
        }
      }

      visiting.delete(id);
      visited.add(id);
      order.push(id);
    };

    // Initialize in layer order to respect hierarchy
    for (const layer of this.layerOrder) {
      for (const [id, def] of this.definitions) {
        if (def.layer === layer && !visited.has(id)) {
          visit(id);
        }
      }
    }

    this.instantiationOrder = order;
    return order;
  }

  /**
   * Get the initialization order
   */
  getInitializationOrder(): string[] {
    return [...this.instantiationOrder];
  }

  /**
   * Mark registry as initialized
   * Prevents new registrations after bootstrap
   */
  markInitialized(): void {
    this.isInitialized = true;
  }

  /**
   * Check if registry is initialized
   */
  initialized(): boolean {
    return this.isInitialized;
  }

  /**
   * Clear all services (for testing)
   */
  clear(): void {
    this.services.clear();
    this.definitions.clear();
    this.instantiationOrder = [];
    this.isInitialized = false;
  }

  /**
   * Get total count of registered services
   */
  count(): number {
    return this.definitions.size;
  }

  /**
   * Debug: Get all registered service definitions
   */
  getAllDefinitions(): Map<string, IServiceDefinition> {
    return new Map(this.definitions);
  }
}

export const createRegistry = (): DependencyRegistry => {
  return new DependencyRegistry();
};
