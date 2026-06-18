# ZCANVAS - Production-Ready Hierarchical Architecture

## Overview

This document describes the complete architectural pattern implemented in ZCANVAS. The system uses **strict hierarchical dependency injection** without an event bus, ensuring perfect decoupling and zero circular dependencies.

## Architecture Layers

### Layer 1: Repository Layer (Bottom)
**Responsibility:** Data persistence, retrieval, and transformation

- Can depend on: Nothing
- Cannot depend on: Engine, Controller, UI
- Implements: `IRepository<T>`
- Scope: Singleton
- Examples: Database connectors, file system readers, API clients

```typescript
// Example Repository
class UserRepository implements IRepository<User> {
  async findById(id: string): Promise<User | null> {
    // Direct database query
  }
}
```

### Layer 2: Engine Layer
**Responsibility:** Business logic, calculations, transformations, rules

- Can depend on: Repository
- Cannot depend on: Controller, UI
- Implements: `IEngine<TInput, TOutput>`
- Scope: Singleton
- Examples: Data processors, validators, calculators, algorithms

```typescript
// Example Engine
class UserValidationEngine implements IEngine<User, ValidationResult> {
  constructor(private userRepo: IRepository<User>) {}
  
  async execute(user: User): Promise<ValidationResult> {
    // Validate using repository data
  }
}
```

### Layer 3: Controller Layer
**Responsibility:** Orchestration, request handling, response formatting

- Can depend on: Repository, Engine
- Cannot depend on: UI
- Implements: `IController<TRequest, TResponse>`
- Scope: Singleton
- Examples: HTTP handlers, command processors, event handlers

```typescript
// Example Controller
class UserController implements IController<UserRequest, UserResponse> {
  constructor(
    private userRepo: IRepository<User>,
    private validationEngine: IEngine<User, ValidationResult>
  ) {}
  
  async handle(request: UserRequest): Promise<UserResponse> {
    // Orchestrate repository and engine calls
  }
}
```

### Layer 4: UI Layer (Top)
**Responsibility:** User presentation, interaction, rendering

- Can depend on: Repository, Engine, Controller
- Cannot depend on: Anything (it's the top)
- Implements: `IUIComponent<TProps, TState>`
- Scope: Usually instance-per-request
- Examples: Components, pages, views, forms

```typescript
// Example UI Component
class UserFormComponent implements IUIComponent<UserFormProps, UserFormState> {
  constructor(private userController: IController<UserRequest, UserResponse>) {}
  
  async render(props: UserFormProps): Promise<string> {
    // Use controller to handle user actions
  }
}
```

## Wiring Pattern

### Single Entry Point: SystemBootstrap

The entire application is wired through one entry point:

```typescript
import { getBootstrap, SERVICE_DEFINITIONS } from 'lib';

async function main() {
  // 1. Get bootstrap instance
  const bootstrap = getBootstrap();
  
  // 2. Register all services (from service registry)
  bootstrap.registerServices(SERVICE_DEFINITIONS);
  
  // 3. Execute initialization sequence
  await bootstrap.bootstrap();
  // This automatically:
  //   - Builds dependency graph
  //   - Validates layer hierarchy
  //   - Initializes Repository layer
  //   - Initializes Engine layer
  //   - Initializes Controller layer
  //   - Initializes UI layer
  //   - Locks registry for production
  
  // 4. Access services
  const registry = bootstrap.getRegistry();
  const userController = bootstrap.getService('controller:user');
}

main().catch(console.error);
```

### Service Registration Pattern

All services are defined in `lib/services/index.ts`:

```typescript
export const SERVICE_DEFINITIONS: IServiceDefinition[] = [
  // Repository layer (no dependencies)
  {
    id: 'repository:user',
    layer: 'repository',
    factory: () => new UserRepository(),
    singleton: true,
  },
  
  // Engine layer (depends on repository)
  {
    id: 'engine:user-validation',
    layer: 'engine',
    factory: (registry) => new UserValidationEngine(
      registry.get('repository:user')
    ),
    singleton: true,
    dependencies: ['repository:user'],
  },
  
  // Controller layer (depends on engine)
  {
    id: 'controller:user',
    layer: 'controller',
    factory: (registry) => new UserController(
      registry.get('repository:user'),
      registry.get('engine:user-validation')
    ),
    singleton: true,
    dependencies: ['repository:user', 'engine:user-validation'],
  },
  
  // UI layer (depends on controller)
  {
    id: 'ui:user-form',
    layer: 'ui',
    factory: (registry) => new UserFormComponent(
      registry.get('controller:user')
    ),
    singleton: true,
    dependencies: ['controller:user'],
  },
];
```

## Deduplication Strategy

All common functionality must be extracted into single sources:

### 1. Logging
All modules use `createLogger()` from `lib/core/common/Logger`:

```typescript
import { createLogger } from 'lib';

class MyService {
  private logger = createLogger('MyService');
  
  async execute() {
    this.logger.info('Starting execution');
  }
}
```

### 2. Error Handling
All modules use `ErrorHandler` from `lib/core/common/ErrorHandler`:

```typescript
import { ApplicationError, ErrorHandler, ErrorSeverity } from 'lib';

try {
  // operation
} catch (error) {
  const appError = new ApplicationError(
    'Operation failed',
    'OP_FAILED',
    ErrorSeverity.HIGH,
    { operation: 'specific_op' }
  );
  ErrorHandler.handle(appError);
}
```

### 3. Validation
All modules use `Validator` from `lib/core/common/Validator`:

```typescript
import { Validator } from 'lib';

const result = Validator.validate(data, {
  email: [Validator.COMMON.required, Validator.COMMON.email],
  age: [Validator.COMMON.number, Validator.COMMON.positive],
});
```

## Layer Violation Prevention

The `DependencyRegistry` enforces strict hierarchy:

```typescript
// ❌ This will throw an error during registration:
{
  id: 'repository:user',
  layer: 'repository',
  factory: () => new UserRepository(),
  dependencies: ['controller:api'], // ERROR: cannot depend on higher layer!
}

// ✅ This is correct:
{
  id: 'engine:processor',
  layer: 'engine',
  dependencies: ['repository:data'], // OK: depending on lower layer
}
```

## Initialization Sequence

1. **Registry Creation** - Create empty registry
2. **Service Registration** - Register all service definitions
3. **Dependency Resolution** - Build initialization order
4. **Repository Layer Initialization** - Initialize all repository services
5. **Engine Layer Initialization** - Initialize all engine services
6. **Controller Layer Initialization** - Initialize all controller services
7. **UI Layer Initialization** - Initialize all UI services
8. **Registry Lock** - Prevent new registrations (production safety)

## Circular Dependency Detection

The system automatically detects circular dependencies:

```typescript
// ❌ This will be caught during bootstrap:
// Service A depends on B
// Service B depends on C
// Service C depends on A
// Error: Circular dependency detected: A -> B -> C -> A
```

## Testing Pattern

```typescript
import { DependencyRegistry } from 'lib';

describe('MyService', () => {
  let registry: DependencyRegistry;
  
  beforeEach(() => {
    registry = new DependencyRegistry();
    // Register only mocks needed for test
    registry.register({
      id: 'repository:user',
      layer: 'repository',
      factory: () => mockUserRepository(),
      singleton: true,
    });
  });
  
  afterEach(() => {
    registry.clear();
  });
  
  it('should process user data', async () => {
    // Test your service
  });
});
```

## Migration Guide from Old System

### Step 1: Extract Duplicates
Run `CodeDeduplicator.analyzeForDuplicates()` to identify all redundant code.

### Step 2: Create Common Modules
Move all common logic to `lib/core/common/`:
- Logger → `lib/core/common/Logger.ts`
- ErrorHandler → `lib/core/common/ErrorHandler.ts`
- Validator → `lib/core/common/Validator.ts`
- Other utilities → individual files

### Step 3: Refactor Services
Organize services by layer:
- Repository → `lib/repositories/`
- Engine → `lib/engines/`
- Controller → `lib/controllers/`
- UI → `lib/ui/`

### Step 4: Create Service Definitions
Add all services to `SERVICE_DEFINITIONS` in `lib/services/index.ts`

### Step 5: Update Entry Point
Replace existing entry point with:
```typescript
import { getBootstrap, SERVICE_DEFINITIONS } from 'lib';

async function main() {
  const bootstrap = getBootstrap();
  bootstrap.registerServices(SERVICE_DEFINITIONS);
  await bootstrap.bootstrap();
  // Application is now ready
}
```

## Production Checklist

- [ ] All services registered in `SERVICE_DEFINITIONS`
- [ ] No circular dependencies
- [ ] All common logic deduplicated
- [ ] Layer hierarchy enforced
- [ ] Error handling standardized
- [ ] Logging standardized
- [ ] Validation standardized
- [ ] No direct class instantiation (use registry)
- [ ] Bootstrap called before accessing any service
- [ ] Registry is locked after bootstrap

## Performance Considerations

1. **Lazy Loading**: Services are instantiated on first access
2. **Singletons**: Reusable services are registered as singletons
3. **Dependency Resolution**: Cached to O(1) after first build
4. **Memory**: Only used services are instantiated

## Future Enhancements

1. Async Service Initialization
2. Service Lifecycle Hooks (start, stop, destroy)
3. Service Interceptors
4. Service Middleware
5. Health Checks per Layer
6. Metrics and Monitoring
