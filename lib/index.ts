/**
 * ZCANVAS - Production Ready System Entry Point
 *
 * Architecture:
 * ============
 * UI Layer (Presentation)
 *  ↓
 * Controller Layer (Orchestration)
 *  ↓
 * Engine Layer (Business Logic)
 *  ↓
 * Repository Layer (Data Persistence)
 *
 * Key principles:
 * - NO circular dependencies
 * - NO event bus (pure DI)
 * - Single entry point (SystemBootstrap)
 * - Registry-based service discovery
 * - Strict layer hierarchy enforcement
 * - Complete deduplication (single source of truth)
 */

export * from './core/index';
export * from './services/index';

// Quick start example:
//
// import { getBootstrap, SERVICE_DEFINITIONS } from 'lib';
//
// async function startApplication() {
//   const bootstrap = getBootstrap();
//   bootstrap.registerServices(SERVICE_DEFINITIONS);
//   await bootstrap.bootstrap();
//   
//   const registry = bootstrap.getRegistry();
//   const myService = bootstrap.getService('service:id');
// }
//
// startApplication().catch(console.error);
