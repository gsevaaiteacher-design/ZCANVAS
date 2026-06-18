/**
 * CodeDeduplicator
 * Analyzes codebase and identifies duplicate logic across modules
 * Provides recommendations for consolidation
 * 
 * This tool should be run to identify all redundant code
 * and merge them into single, definitive sources
 */

export interface DuplicateAnalysis {
  type: 'function' | 'class' | 'interface' | 'logic';
  path: string[];
  similarity: number; // 0-1
  occurrences: number;
  recommendation: string;
}

export interface DeduplicationReport {
  totalModules: number;
  duplicatesFound: number;
  duplicateLines: number;
  analysis: DuplicateAnalysis[];
  consolidationPlan: ConsolidationStep[];
}

export interface ConsolidationStep {
  id: string;
  type: 'merge' | 'extract' | 'remove';
  source: string[];
  target: string;
  description: string;
  priority: 'critical' | 'high' | 'medium' | 'low';
}

export class CodeDeduplicator {
  /**
   * Common patterns that often get duplicated
   */
  private static readonly DUPLICATE_PATTERNS = [
    // Validation logic
    { pattern: /validate|validator|validation/i, category: 'validation' },
    // Error handling
    { pattern: /error|exception|catch|throw/i, category: 'error' },
    // Transformation logic
    { pattern: /transform|map|convert|serialize/i, category: 'transformation' },
    // Query/retrieval
    { pattern: /query|fetch|get|find|retrieve/i, category: 'query' },
    // Caching
    { pattern: /cache|memoize|memo|store/i, category: 'cache' },
    // Logging
    { pattern: /log|debug|info|warn/i, category: 'logging' },
  ];

  /**
   * Analyze codebase for duplicates
   * (Mock implementation - in real usage, parse AST)
   */
  static analyzeForDuplicates(
    modules: Map<string, string>
  ): DuplicateAnalysis[] {
    const duplicates: DuplicateAnalysis[] = [];

    const moduleArray = Array.from(modules.entries());

    // Compare each module with others
    for (let i = 0; i < moduleArray.length; i++) {
      for (let j = i + 1; j < moduleArray.length; j++) {
        const [path1, code1] = moduleArray[i];
        const [path2, code2] = moduleArray[j];

        const similarity = this.calculateSimilarity(code1, code2);

        if (similarity > 0.7) {
          // More than 70% similar
          duplicates.push({
            type: 'logic',
            path: [path1, path2],
            similarity,
            occurrences: 2,
            recommendation: `Merge common logic from ${path1} and ${path2} into a shared utility module`,
          });
        }
      }
    }

    return duplicates;
  }

  /**
   * Calculate similarity between two code blocks (simplified)
   */
  private static calculateSimilarity(code1: string, code2: string): number {
    const lines1 = code1.split('\n').filter((l) => l.trim());
    const lines2 = code2.split('\n').filter((l) => l.trim());

    let matches = 0;
    for (const line of lines1) {
      if (lines2.some((l) => l === line)) {
        matches++;
      }
    }

    const total = Math.max(lines1.length, lines2.length);
    return total === 0 ? 0 : matches / total;
  }

  /**
   * Generate consolidation plan
   */
  static generateConsolidationPlan(
    duplicates: DuplicateAnalysis[]
  ): ConsolidationStep[] {
    const steps: ConsolidationStep[] = [];

    // Group by category
    const categories = new Map<string, DuplicateAnalysis[]>();

    for (const dup of duplicates) {
      const category = this.categorizeCode(dup);
      if (!categories.has(category)) {
        categories.set(category, []);
      }
      categories.get(category)!.push(dup);
    }

    // Create consolidation steps
    let stepId = 1;
    for (const [category, dups] of categories) {
      if (dups.length > 0) {
        steps.push({
          id: `step-${stepId++}`,
          type: 'extract',
          source: dups.flatMap((d) => d.path),
          target: `lib/core/common/${category}.ts`,
          description: `Extract and consolidate all ${category} logic into single module`,
          priority: dups[0].similarity > 0.9 ? 'critical' : 'high',
        });
      }
    }

    return steps.sort((a, b) => {
      const priorityOrder = { critical: 0, high: 1, medium: 2, low: 3 };
      return priorityOrder[a.priority] - priorityOrder[b.priority];
    });
  }

  /**
   * Categorize code by its purpose
   */
  private static categorizeCode(dup: DuplicateAnalysis): string {
    for (const pattern of this.DUPLICATE_PATTERNS) {
      if (
        dup.recommendation.match(pattern.pattern) ||
        dup.path.some((p) => p.match(pattern.pattern))
      ) {
        return pattern.category;
      }
    }
    return 'generic';
  }

  /**
   * Generate deduplication report
   */
  static generateReport(
    modules: Map<string, string>
  ): DeduplicationReport {
    const analysis = this.analyzeForDuplicates(modules);
    const consolidation = this.generateConsolidationPlan(analysis);

    const totalDuplicateLines = analysis.reduce(
      (sum, dup) => sum + Math.floor(150 * dup.similarity),
      0
    );

    return {
      totalModules: modules.size,
      duplicatesFound: analysis.length,
      duplicateLines: totalDuplicateLines,
      analysis,
      consolidationPlan: consolidation,
    };
  }
}
