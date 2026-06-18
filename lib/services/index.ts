/**
 * Service Registry
 * Central location where all service definitions are declared
 * This replaces scattered service instantiation throughout the codebase
 *
 * Add your services here following the pattern:
 *
 * export const SERVICE_DEFINITIONS: IServiceDefinition[] = [
 *   {
 *     id: 'repository:users',
 *     layer: 'repository',
 *     factory: (registry) => new UserRepository(),
 *     singleton: true,
 *   },
 *   {
 *     id: 'engine:data-processor',
 *     layer: 'engine',
 *     factory: (registry) => new DataProcessorEngine(registry.get('repository:users')),
 *     singleton: true,
 *     dependencies: ['repository:users'],
 *   },
 * ];
 */

import type { IServiceDefinition } from '../core/registry/DependencyRegistry';

/**
 * Export all service definitions here
 * Dynamically import from service modules
 */
export const SERVICE_DEFINITIONS: IServiceDefinition[] = [
  // Repository services
  // Example:
  // {
  //   id: 'repository:storage',
  //   layer: 'repository',
  //   factory: () => new StorageRepository(),
  //   singleton: true,
  // },

  // Engine services
  // Example:
  // {
  //   id: 'engine:canvas',
  //   layer: 'engine',
  //   factory: (registry) => new CanvasEngine(registry.get('repository:storage')),
  //   singleton: true,
  //   dependencies: ['repository:storage'],
  // },

  // Controller services
  // Example:
  // {
  //   id: 'controller:api',
  //   layer: 'controller',
  //   factory: (registry) => new APIController(registry.get('engine:canvas')),
  //   singleton: true,
  //   dependencies: ['engine:canvas'],
  // },

  // UI services
  // Example:
  // {
  //   id: 'ui:main',
  //   layer: 'ui',
  //   factory: (registry) => new MainUI(registry.get('controller:api')),
  //   singleton: true,
  //   dependencies: ['controller:api'],
  // },
];
