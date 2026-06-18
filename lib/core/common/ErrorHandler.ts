/**
 * SINGLE SOURCE OF TRUTH - Error Handler
 * All error handling must use this implementation
 * Prevents scattered try-catch blocks and error logging
 */

export enum ErrorSeverity {
  LOW = 'low',
  MEDIUM = 'medium',
  HIGH = 'high',
  CRITICAL = 'critical',
}

export interface AppError extends Error {
  code: string;
  severity: ErrorSeverity;
  context?: Record<string, any>;
  originalError?: Error;
}

export class ApplicationError extends Error implements AppError {
  code: string;
  severity: ErrorSeverity;
  context?: Record<string, any>;
  originalError?: Error;

  constructor(
    message: string,
    code: string,
    severity: ErrorSeverity = ErrorSeverity.MEDIUM,
    context?: Record<string, any>,
    originalError?: Error
  ) {
    super(message);
    this.name = 'ApplicationError';
    this.code = code;
    this.severity = severity;
    this.context = context;
    this.originalError = originalError;
  }
}

export class ErrorHandler {
  private static errorHandlers = new Map<string, (err: AppError) => void>();

  /**
   * Register handler for specific error code
   */
  static registerHandler(
    code: string,
    handler: (err: AppError) => void
  ): void {
    this.errorHandlers.set(code, handler);
  }

  /**
   * Handle error with appropriate handler
   */
  static handle(error: AppError | Error): void {
    const appError = this.normalize(error);

    // Try specific handler first
    if (this.errorHandlers.has(appError.code)) {
      this.errorHandlers.get(appError.code)!(appError);
      return;
    }

    // Fall back to severity-based handling
    this.handleBySeverity(appError);
  }

  /**
   * Handle based on severity
   */
  private static handleBySeverity(error: AppError): void {
    switch (error.severity) {
      case ErrorSeverity.CRITICAL:
        console.error('🚨 CRITICAL ERROR:', error.message, error.context);
        process.exit(1);
        break;
      case ErrorSeverity.HIGH:
        console.error('❌ ERROR:', error.message, error.context);
        break;
      case ErrorSeverity.MEDIUM:
        console.warn('⚠️  WARNING:', error.message);
        break;
      case ErrorSeverity.LOW:
        console.log('ℹ️  INFO:', error.message);
        break;
    }
  }

  /**
   * Normalize error to AppError
   */
  static normalize(error: AppError | Error | any): AppError {
    if (error instanceof ApplicationError) {
      return error;
    }

    return new ApplicationError(
      error?.message || 'Unknown error',
      error?.code || 'UNKNOWN_ERROR',
      ErrorSeverity.MEDIUM,
      undefined,
      error instanceof Error ? error : undefined
    );
  }
}
