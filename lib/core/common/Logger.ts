/**
 * SINGLE SOURCE OF TRUTH - Logger
 * All logging in the system must use this implementation
 * No module should have its own logger implementation
 */

export enum LogLevel {
  DEBUG = 0,
  INFO = 1,
  WARN = 2,
  ERROR = 3,
}

export interface ILogger {
  debug(message: string, context?: any): void;
  info(message: string, context?: any): void;
  warn(message: string, context?: any): void;
  error(message: string, error?: Error | any, context?: any): void;
}

export class Logger implements ILogger {
  private minLevel: LogLevel;
  private context: string;

  constructor(context: string, minLevel: LogLevel = LogLevel.DEBUG) {
    this.context = context;
    this.minLevel = minLevel;
  }

  debug(message: string, context?: any): void {
    if (this.minLevel <= LogLevel.DEBUG) {
      console.debug(`[${this.context}] 🔍 ${message}`, context || '');
    }
  }

  info(message: string, context?: any): void {
    if (this.minLevel <= LogLevel.INFO) {
      console.info(`[${this.context}] ℹ️  ${message}`, context || '');
    }
  }

  warn(message: string, context?: any): void {
    if (this.minLevel <= LogLevel.WARN) {
      console.warn(`[${this.context}] ⚠️  ${message}`, context || '');
    }
  }

  error(message: string, error?: Error | any, context?: any): void {
    if (this.minLevel <= LogLevel.ERROR) {
      console.error(
        `[${this.context}] ❌ ${message}`,
        error,
        context || ''
      );
    }
  }
}

/**
 * Global logger factory
 */
export const createLogger = (context: string, level?: LogLevel): ILogger => {
  return new Logger(context, level);
};
