/**
 * SINGLE SOURCE OF TRUTH - Validator
 * All validation must use this implementation
 * Eliminates scattered validation logic across modules
 */

export interface ValidationRule<T = any> {
  name: string;
  validate: (value: T) => boolean | string;
}

export interface ValidationSchema<T = any> {
  [key: string]: ValidationRule<any>[];
}

export interface ValidationResult {
  isValid: boolean;
  errors: Record<string, string[]>;
}

export class Validator {
  private static rules = new Map<string, ValidationRule>();

  /**
   * Register reusable validation rule
   */
  static registerRule(rule: ValidationRule): void {
    this.rules.set(rule.name, rule);
  }

  /**
   * Validate object against schema
   */
  static validate<T extends Record<string, any>>(
    data: T,
    schema: ValidationSchema<T>
  ): ValidationResult {
    const errors: Record<string, string[]> = {};

    for (const [field, rules] of Object.entries(schema)) {
      const value = data[field];
      const fieldErrors: string[] = [];

      for (const rule of rules) {
        const result = rule.validate(value);
        if (result !== true) {
          fieldErrors.push(typeof result === 'string' ? result : `${field} validation failed`);
        }
      }

      if (fieldErrors.length > 0) {
        errors[field] = fieldErrors;
      }
    }

    return {
      isValid: Object.keys(errors).length === 0,
      errors,
    };
  }

  /**
   * Common validators (reusable across project)
   */
  static readonly COMMON = {
    required: (value: any): boolean => {
      return value !== null && value !== undefined && value !== '';
    },

    minLength: (min: number) => (value: string): boolean => {
      return value?.length >= min;
    },

    maxLength: (max: number) => (value: string): boolean => {
      return value?.length <= max;
    },

    email: (value: string): boolean => {
      return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
    },

    url: (value: string): boolean => {
      try {
        new URL(value);
        return true;
      } catch {
        return false;
      }
    },

    number: (value: any): boolean => {
      return typeof value === 'number' && !isNaN(value);
    },

    integer: (value: any): boolean => {
      return Number.isInteger(value);
    },

    positive: (value: number): boolean => {
      return value > 0;
    },

    enum: (allowedValues: string[]) => (value: string): boolean => {
      return allowedValues.includes(value);
    },
  };
}
