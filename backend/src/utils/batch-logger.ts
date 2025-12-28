// =============================================================================
// BATCH LOGGER UTILITY
// =============================================================================
// Reduces log volume by batching operations and logging summaries instead of
// individual items. Errors are always logged immediately for debugging.
//
// Usage:
//   const logger = new BatchLogger('JobName', 50);
//   for (const item of items) {
//     try {
//       await processItem(item);
//       logger.success(item.id);
//     } catch (err) {
//       logger.error(item.id, err);
//     }
//   }
//   logger.flush();
// =============================================================================

export interface BatchLoggerStats {
  total: number;
  succeeded: number;
  failed: number;
  skipped: number;
}

export class BatchLogger {
  private jobName: string;
  private batchSize: number;
  private stats: BatchLoggerStats = {
    total: 0,
    succeeded: 0,
    failed: 0,
    skipped: 0,
  };
  private currentBatch: string[] = [];
  private batchNumber: number = 0;
  private startTime: number;

  constructor(jobName: string, batchSize?: number) {
    this.jobName = jobName;
    this.batchSize = batchSize || parseInt(process.env.LOG_BATCH_SIZE || "50", 10);
    this.startTime = Date.now();
  }

  /**
   * Record a successful operation
   */
  success(itemId?: string): void {
    this.stats.total++;
    this.stats.succeeded++;
    
    if (itemId) {
      this.currentBatch.push(itemId);
    }

    if (this.currentBatch.length >= this.batchSize) {
      this.flushBatch();
    }
  }

  /**
   * Record a skipped operation
   */
  skip(itemId?: string, reason?: string): void {
    this.stats.total++;
    this.stats.skipped++;
    
    if (itemId && reason) {
      this.currentBatch.push(`${itemId} (skipped: ${reason})`);
    }

    if (this.currentBatch.length >= this.batchSize) {
      this.flushBatch();
    }
  }

  /**
   * Record an error - always logged immediately
   */
  error(itemId: string, error: any): void {
    this.stats.total++;
    this.stats.failed++;
    
    console.error(`❌ ${this.jobName} failed for ${itemId}:`, error instanceof Error ? error.message : error);
  }

  /**
   * Flush current batch to logs
   */
  private flushBatch(): void {
    if (this.currentBatch.length === 0) return;

    this.batchNumber++;
    const rangeStart = this.stats.total - this.currentBatch.length + 1;
    const rangeEnd = this.stats.total;
    
    console.log(`✅ ${this.jobName} batch ${this.batchNumber}: processed ${rangeStart}-${rangeEnd} (${this.currentBatch.length} items)`);
    
    this.currentBatch = [];
  }

  /**
   * Flush remaining items and log final summary
   */
  flush(): void {
    // Flush any remaining batch
    if (this.currentBatch.length > 0) {
      this.flushBatch();
    }

    // Log final summary
    const duration = Date.now() - this.startTime;
    const durationStr = duration > 1000 ? `${(duration / 1000).toFixed(1)}s` : `${duration}ms`;
    
    console.log(
      `📊 ${this.jobName} complete: ` +
      `${this.stats.succeeded} succeeded, ` +
      `${this.stats.failed} failed, ` +
      `${this.stats.skipped} skipped ` +
      `(${this.stats.total} total in ${durationStr})`
    );
  }

  /**
   * Get current stats
   */
  getStats(): BatchLoggerStats {
    return { ...this.stats };
  }

  /**
   * Log a simple info message (not batched)
   */
  info(message: string): void {
    console.log(`ℹ️ ${this.jobName}: ${message}`);
  }

  /**
   * Log a warning message (not batched)
   */
  warn(message: string): void {
    console.warn(`⚠️ ${this.jobName}: ${message}`);
  }
}

