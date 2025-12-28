// =============================================================================
// PATTERN LEARNING WORKER
// =============================================================================
// Nightly job that computes expensive pattern analysis for each user.
// This runs at 3am and updates the LearnedUserModel in UserFacts.
//
// What it computes:
// - Behavioral fingerprint (recovery style, challenge response, celebration trap)
// - Shame sensitivity score
// - Trigger chains (sequences that lead to slips)
// - Commitment resolution (check pending commitments)
// - Message effectiveness patterns
//
// This separates expensive computation from real-time serving.
// =============================================================================

import { prisma } from "../utils/db";
import { redis } from "../utils/redis";
import { deepUserModel, LearnedUserModel, BehavioralFingerprint, ShameSensitivity, TriggerChain } from "../services/deep-user-model.service";
import { memoryService } from "../services/memory.service";
import { BatchLogger } from "../utils/batch-logger";

// =============================================================================
// TYPES
// =============================================================================

interface LearningResult {
  userId: string;
  success: boolean;
  error?: string;
  dataPointsProcessed: number;
  updatedFields: string[];
}

interface GhostPeriod {
  startDate: Date;
  endDate: Date;
  durationDays: number;
  triggeredBy?: string; // Event type that preceded the ghost
  recoveredWith?: string; // First event after ghost
}

interface SlipSequence {
  events: Array<{
    type: string;
    ts: Date;
    payload: any;
  }>;
  ledToGhost: boolean;
  ghostDuration?: number;
}

// =============================================================================
// WORKER CLASS
// =============================================================================

class PatternLearningWorker {
  
  // ---------------------------------------------------------------------------
  // MAIN ENTRY POINT
  // ---------------------------------------------------------------------------
  
  /**
   * Process all active users.
   * Call this from a scheduled job (e.g., 3am daily).
   */
  async processAllUsers(): Promise<{ processed: number; errors: number }> {
    const logger = new BatchLogger('PatternLearning');
    
    // Get users active in last 7 days
    const sevenDaysAgo = new Date(Date.now() - 7 * 86400000);
    const users = await prisma.user.findMany({
      where: {
        OR: [
          { updatedAt: { gte: sevenDaysAgo } },
          // Also include users with recent events
        ],
      },
      select: { id: true },
    });
    
    logger.info(`Processing ${users.length} active users`);
    
    for (const user of users) {
      try {
        const result = await this.processUser(user.id);
        if (result.success) {
          logger.success(user.id);
        } else {
          logger.error(user.id, result.error || 'Unknown error');
        }
      } catch (error) {
        logger.error(user.id, error);
      }
      
      // Small delay to avoid overwhelming the database
      await this.sleep(100);
    }
    
    logger.flush();
    const stats = logger.getStats();
    
    return { processed: stats.succeeded, errors: stats.failed };
  }
  
  /**
   * Process a single user.
   */
  async processUser(userId: string): Promise<LearningResult> {
    const updatedFields: string[] = [];
    
    try {
      // Get events for learning (last 30 days)
      const events = await this.getEventsForLearning(userId, 30);
      
      if (events.length < 10) {
        // Not enough data to learn meaningful patterns
        return {
          userId,
          success: true,
          dataPointsProcessed: events.length,
          updatedFields: [],
        };
      }
      
      // Get existing learned model
      const existingModel = await deepUserModel.getLearnedModel(userId);
      
      // 1. Compute behavioral fingerprint
      const fingerprint = await this.computeBehavioralFingerprint(userId, events);
      if (fingerprint) {
        updatedFields.push("fingerprint");
      }
      
      // 2. Compute shame sensitivity
      const shameSensitivity = await this.computeShameSensitivity(userId, events);
      if (shameSensitivity) {
        updatedFields.push("shameSensitivity");
      }
      
      // 3. Detect trigger chains
      const triggerChains = await this.detectTriggerChains(userId, events);
      if (triggerChains.length > 0) {
        updatedFields.push("triggerChains");
      }
      
      // 4. Resolve pending commitments
      await this.resolveCommitments(userId, events, existingModel);
      updatedFields.push("commitments");
      
      // 5. Analyze message effectiveness
      const messagePatterns = await this.analyzeMessageEffectiveness(userId, events);
      if (messagePatterns.length > 0) {
        updatedFields.push("messagePatterns");
      }
      
      // 6. Compute confidence level
      const confidenceLevel = this.computeConfidenceLevel(events.length);
      
      // Update the learned model
      await deepUserModel.updateLearnedModel(userId, {
        fingerprint: fingerprint || existingModel?.fingerprint,
        shameSensitivity: shameSensitivity || existingModel?.shameSensitivity,
        triggerChains: triggerChains.length > 0 ? triggerChains : existingModel?.triggerChains || [],
        messagePatterns: messagePatterns.length > 0 ? messagePatterns : existingModel?.messagePatterns || [],
        dataPointsUsed: events.length,
        confidenceLevel,
      });
      
      // Invalidate caches
      await redis.del(`deep_model:${userId}`);
      await redis.del(`learned_model:${userId}`);
      
      return {
        userId,
        success: true,
        dataPointsProcessed: events.length,
        updatedFields,
      };
      
    } catch (error: any) {
      return {
        userId,
        success: false,
        error: error.message,
        dataPointsProcessed: 0,
        updatedFields: [],
      };
    }
  }
  
  // ---------------------------------------------------------------------------
  // BEHAVIORAL FINGERPRINT
  // ---------------------------------------------------------------------------
  
  private async computeBehavioralFingerprint(
    userId: string, 
    events: any[]
  ): Promise<BehavioralFingerprint | null> {
    // Detect ghost periods
    const ghostPeriods = this.detectGhostPeriods(events);
    
    if (ghostPeriods.length < 2) {
      // Not enough ghost/return cycles to learn patterns
      return null;
    }
    
    // Compute recovery style
    const recoveryStyle = this.analyzeRecoveryStyle(events, ghostPeriods);
    
    // Compute challenge response
    const challengeResponse = this.analyzeChallengeResponse(events);
    
    // Compute celebration trap
    const celebrationTrap = this.analyzeCelebrationTrap(events);
    
    // Compute slip signature
    const slipSignature = this.analyzeSlipSignature(events, ghostPeriods);
    
    // Compute motivation profile
    const motivationProfile = this.analyzeMotivationProfile(events);
    
    return {
      recoveryStyle,
      challengeResponse,
      celebrationTrap,
      slipSignature,
      motivationProfile,
      dataPoints: events.length,
      lastUpdated: new Date(),
    };
  }
  
  private detectGhostPeriods(events: any[]): GhostPeriod[] {
    const sortedEvents = [...events].sort((a, b) => 
      new Date(a.ts).getTime() - new Date(b.ts).getTime()
    );
    
    const ghostPeriods: GhostPeriod[] = [];
    const GHOST_THRESHOLD_HOURS = 72; // 3 days
    
    for (let i = 1; i < sortedEvents.length; i++) {
      const prevTime = new Date(sortedEvents[i - 1].ts).getTime();
      const currTime = new Date(sortedEvents[i].ts).getTime();
      const gapHours = (currTime - prevTime) / 3600000;
      
      if (gapHours >= GHOST_THRESHOLD_HOURS) {
        ghostPeriods.push({
          startDate: new Date(prevTime),
          endDate: new Date(currTime),
          durationDays: Math.floor(gapHours / 24),
          triggeredBy: sortedEvents[i - 1].type,
          recoveredWith: sortedEvents[i].type,
        });
      }
    }
    
    return ghostPeriods;
  }
  
  private analyzeRecoveryStyle(
    events: any[], 
    ghostPeriods: GhostPeriod[]
  ): BehavioralFingerprint["recoveryStyle"] {
    const evidence: string[] = [];
    
    // Analyze how they recover after each ghost period
    const recoveryPatterns = ghostPeriods.map(ghost => {
      const afterGhost = events.filter(e => {
        const ts = new Date(e.ts).getTime();
        const ghostEnd = ghost.endDate.getTime();
        return ts >= ghostEnd && ts < ghostEnd + 7 * 86400000; // First week after
      });
      
      // Count daily completions in first week
      const dailyCompletions: number[] = [];
      for (let day = 0; day < 7; day++) {
        const dayStart = ghost.endDate.getTime() + day * 86400000;
        const dayEnd = dayStart + 86400000;
        const completions = afterGhost.filter(e => {
          const ts = new Date(e.ts).getTime();
          return ts >= dayStart && ts < dayEnd && 
                 (e.type === "habit_tick" || e.type === "habit_action") &&
                 (e.payload as any)?.completed;
        }).length;
        dailyCompletions.push(completions);
      }
      
      return dailyCompletions;
    });
    
    // Determine recovery style based on patterns
    let type: "gradual" | "sudden" | "oscillating" = "gradual";
    let avgRecoveryDays = 3;
    let crashRiskAfterRestart = 0.3;
    
    if (recoveryPatterns.length > 0) {
      // Check for sudden recovery (high first day, then maintains)
      const avgFirstDay = recoveryPatterns.reduce((sum, p) => sum + p[0], 0) / recoveryPatterns.length;
      const avgSecondDay = recoveryPatterns.reduce((sum, p) => sum + p[1], 0) / recoveryPatterns.length;
      
      if (avgFirstDay > 2 && avgSecondDay > 2) {
        type = "sudden";
        evidence.push("High activity immediately after returning");
        
        // Check if sudden recoveries tend to crash
        const crashCount = recoveryPatterns.filter(p => {
          const firstThreeDays = p.slice(0, 3).reduce((a, b) => a + b, 0);
          const lastThreeDays = p.slice(4, 7).reduce((a, b) => a + b, 0);
          return lastThreeDays < firstThreeDays * 0.5;
        }).length;
        
        crashRiskAfterRestart = crashCount / recoveryPatterns.length;
        if (crashRiskAfterRestart > 0.5) {
          evidence.push("Tends to crash after initial restart burst");
        }
      } else if (avgFirstDay < 1 && avgSecondDay > avgFirstDay) {
        type = "gradual";
        evidence.push("Slow, steady recovery pattern");
      }
      
      // Check for oscillating (inconsistent)
      const varianceCheck = recoveryPatterns.filter(p => {
        const variance = this.computeVariance(p);
        return variance > 2;
      }).length;
      
      if (varianceCheck > recoveryPatterns.length * 0.5) {
        type = "oscillating";
        evidence.push("Inconsistent recovery — good days and bad days");
      }
      
      // Calculate average recovery days
      avgRecoveryDays = Math.round(
        recoveryPatterns.reduce((sum, p) => {
          const firstGoodDay = p.findIndex(d => d >= 2);
          return sum + (firstGoodDay === -1 ? 7 : firstGoodDay);
        }, 0) / recoveryPatterns.length
      );
    }
    
    return {
      type,
      avgRecoveryDays,
      needsSmallWins: type === "gradual",
      crashRiskAfterRestart,
      evidence,
    };
  }
  
  private analyzeChallengeResponse(events: any[]): BehavioralFingerprint["challengeResponse"] {
    const evidence: string[] = [];
    
    // Find nudge events and what happened after
    const nudgeEvents = events.filter(e => e.type === "nudge" || e.type === "coach_nudge");
    
    let riseCount = 0;
    let retreatCount = 0;
    let freezeCount = 0;
    
    for (const nudge of nudgeEvents) {
      const nudgeTime = new Date(nudge.ts).getTime();
      
      // Look at events in the 6 hours after nudge
      const afterNudge = events.filter(e => {
        const ts = new Date(e.ts).getTime();
        return ts > nudgeTime && ts < nudgeTime + 6 * 3600000;
      });
      
      // Check for habit completions
      const completions = afterNudge.filter(e => 
        (e.type === "habit_tick" || e.type === "habit_action") &&
        (e.payload as any)?.completed
      ).length;
      
      // Check for ghost (no activity)
      const anyActivity = afterNudge.length > 0;
      
      if (completions > 0) {
        riseCount++;
      } else if (!anyActivity) {
        retreatCount++;
      } else {
        freezeCount++;
      }
    }
    
    const total = riseCount + retreatCount + freezeCount;
    if (total === 0) {
      return {
        type: "rise",
        confidence: 0.3,
        evidence: ["Not enough nudge data to determine pattern"],
      };
    }
    
    const riseRate = riseCount / total;
    const retreatRate = retreatCount / total;
    
    let type: "rise" | "retreat" | "freeze";
    if (riseRate >= 0.5) {
      type = "rise";
      evidence.push(`Completes habits after ${Math.round(riseRate * 100)}% of nudges`);
    } else if (retreatRate >= 0.4) {
      type = "retreat";
      evidence.push(`Goes quiet after ${Math.round(retreatRate * 100)}% of nudges`);
    } else {
      type = "freeze";
      evidence.push("Often reads nudges but doesn't act immediately");
    }
    
    return {
      type,
      confidence: Math.min(total / 10, 1), // More nudges = more confidence
      evidence,
    };
  }
  
  private analyzeCelebrationTrap(events: any[]): BehavioralFingerprint["celebrationTrap"] {
    const evidence: string[] = [];
    
    // Find streak milestone events
    const streakMilestones: Array<{ ts: Date; streak: number }> = [];
    
    for (const event of events) {
      if (event.type === "habit_tick" || event.type === "habit_action") {
        const payload = event.payload as any;
        if (payload?.streak && payload.streak % 7 === 0 && payload.streak >= 7) {
          streakMilestones.push({
            ts: new Date(event.ts),
            streak: payload.streak,
          });
        }
      }
    }
    
    if (streakMilestones.length < 2) {
      return {
        type: "maintain",
        riskDaysAfterStreak: [7, 14, 30],
        evidence: ["Not enough streak data"],
      };
    }
    
    // Check what happens in the 3 days after each milestone
    let coastCount = 0;
    let accelerateCount = 0;
    let maintainCount = 0;
    
    for (const milestone of streakMilestones) {
      const afterMilestone = events.filter(e => {
        const ts = new Date(e.ts).getTime();
        const msTime = milestone.ts.getTime();
        return ts > msTime && ts < msTime + 3 * 86400000;
      });
      
      const completions = afterMilestone.filter(e =>
        (e.type === "habit_tick" || e.type === "habit_action") &&
        (e.payload as any)?.completed
      ).length;
      
      // Compare to typical daily completion rate
      const avgDailyCompletions = events.filter(e =>
        (e.type === "habit_tick" || e.type === "habit_action") &&
        (e.payload as any)?.completed
      ).length / 30;
      
      const expectedIn3Days = avgDailyCompletions * 3;
      
      if (completions < expectedIn3Days * 0.5) {
        coastCount++;
      } else if (completions > expectedIn3Days * 1.2) {
        accelerateCount++;
      } else {
        maintainCount++;
      }
    }
    
    let type: "coast" | "accelerate" | "maintain";
    const total = coastCount + accelerateCount + maintainCount;
    
    if (coastCount / total > 0.4) {
      type = "coast";
      evidence.push("Tends to ease up after hitting milestones");
    } else if (accelerateCount / total > 0.4) {
      type = "accelerate";
      evidence.push("Gains momentum after hitting milestones");
    } else {
      type = "maintain";
      evidence.push("Maintains steady pace regardless of milestones");
    }
    
    return {
      type,
      riskDaysAfterStreak: type === "coast" ? [1, 2, 3] : [7, 14, 30],
      evidence,
    };
  }
  
  private analyzeSlipSignature(
    events: any[], 
    ghostPeriods: GhostPeriod[]
  ): BehavioralFingerprint["slipSignature"] {
    const warningBehaviors: string[] = [];
    const typicalExcuses: string[] = [];
    
    // Analyze events before each ghost period
    for (const ghost of ghostPeriods) {
      const beforeGhost = events.filter(e => {
        const ts = new Date(e.ts).getTime();
        const ghostStart = ghost.startDate.getTime();
        return ts < ghostStart && ts > ghostStart - 48 * 3600000;
      });
      
      // Look for patterns
      const shortSessions = beforeGhost.filter(e => 
        e.type === "app_session" && (e.payload as any)?.durationSeconds < 30
      ).length;
      
      if (shortSessions > 2) {
        warningBehaviors.push("Short app sessions (checking without engaging)");
      }
      
      // Look for missed habits
      const missedHabits = beforeGhost.filter(e =>
        (e.type === "habit_tick" || e.type === "habit_action") &&
        !(e.payload as any)?.completed
      ).length;
      
      if (missedHabits > 3) {
        warningBehaviors.push("Multiple missed habits in short period");
      }
    }
    
    // Calculate average ghost duration
    const avgGhostDuration = ghostPeriods.length > 0
      ? ghostPeriods.reduce((sum, g) => sum + g.durationDays, 0) / ghostPeriods.length
      : 3;
    
    // Find return trigger (most common first event after ghost)
    const returnTypes: Record<string, number> = {};
    for (const ghost of ghostPeriods) {
      const firstEvent = events.find(e => 
        new Date(e.ts).getTime() >= ghost.endDate.getTime()
      );
      if (firstEvent) {
        returnTypes[firstEvent.type] = (returnTypes[firstEvent.type] || 0) + 1;
      }
    }
    
    const returnTrigger = Object.entries(returnTypes)
      .sort(([, a], [, b]) => b - a)[0]?.[0] || null;
    
    return {
      warningBehaviors: [...new Set(warningBehaviors)],
      typicalExcuses,
      avgGhostDuration: Math.round(avgGhostDuration),
      returnTrigger,
      confidence: Math.min(ghostPeriods.length / 5, 1),
    };
  }
  
  private analyzeMotivationProfile(events: any[]): BehavioralFingerprint["motivationProfile"] {
    const evidence: string[] = [];
    
    // Look at what correlates with high completion
    const chatMessages = events.filter(e => e.type === "chat_message");
    
    let progressMentions = 0;
    let fearMentions = 0;
    let identityMentions = 0;
    
    for (const msg of chatMessages) {
      const text = ((msg.payload as any)?.text || "").toLowerCase();
      
      if (text.includes("streak") || text.includes("progress") || text.includes("improvement")) {
        progressMentions++;
      }
      if (text.includes("afraid") || text.includes("worried") || text.includes("don't want to")) {
        fearMentions++;
      }
      if (text.includes("i am") || text.includes("type of person") || text.includes("who i")) {
        identityMentions++;
      }
    }
    
    let primary: "progress" | "fear" | "identity" | "social" | "competition" | "unknown" = "unknown";
    
    if (progressMentions > fearMentions && progressMentions > identityMentions) {
      primary = "progress";
      evidence.push("Responds to streak numbers and progress tracking");
    } else if (fearMentions > progressMentions && fearMentions > identityMentions) {
      primary = "fear";
      evidence.push("Motivated by avoiding negative outcomes");
    } else if (identityMentions > 0) {
      primary = "identity";
      evidence.push("Uses identity-based language");
    }
    
    return {
      primary,
      secondary: null,
      evidence,
    };
  }
  
  // ---------------------------------------------------------------------------
  // SHAME SENSITIVITY
  // ---------------------------------------------------------------------------
  
  private async computeShameSensitivity(
    userId: string, 
    events: any[]
  ): Promise<ShameSensitivity | null> {
    let score = 0.5; // Start neutral
    let dataPoints = 0;
    
    const ghostPeriods = this.detectGhostPeriods(events);
    const nudgeEvents = events.filter(e => e.type === "nudge" || e.type === "coach_nudge");
    
    // Evidence flags
    let ghostsAfterMissedStreak = false;
    let ghostsAfterConfrontation = false;
    let deletesHabitsAfterFailure = false;
    let respondsToSoftReentry = false;
    let ignoresAfterMultipleNudges = false;
    
    // Check for ghosting after nudges
    for (const nudge of nudgeEvents) {
      const nudgeTime = new Date(nudge.ts).getTime();
      
      // Check if ghost started within 48 hours of nudge
      const ghostAfter = ghostPeriods.find(g =>
        g.startDate.getTime() > nudgeTime &&
        g.startDate.getTime() < nudgeTime + 48 * 3600000
      );
      
      if (ghostAfter) {
        ghostsAfterConfrontation = true;
        score += 0.1;
        dataPoints++;
      }
    }
    
    // Check for ghosting after streak breaks
    const streakBreakEvents = events.filter(e =>
      e.type === "habit_tick" &&
      (e.payload as any)?.previousStreak > 7 &&
      (e.payload as any)?.streak === 0
    );
    
    for (const breakEvent of streakBreakEvents) {
      const breakTime = new Date(breakEvent.ts).getTime();
      
      const ghostAfter = ghostPeriods.find(g =>
        g.startDate.getTime() > breakTime &&
        g.startDate.getTime() < breakTime + 48 * 3600000
      );
      
      if (ghostAfter) {
        ghostsAfterMissedStreak = true;
        score += 0.15;
        dataPoints++;
      }
    }
    
    // Check for ignoring multiple nudges in a row
    const nudgesByDay: Record<string, number> = {};
    for (const nudge of nudgeEvents) {
      const day = new Date(nudge.ts).toDateString();
      nudgesByDay[day] = (nudgesByDay[day] || 0) + 1;
    }
    
    const daysWithMultipleNudges = Object.values(nudgesByDay).filter(c => c >= 2).length;
    if (daysWithMultipleNudges > 3) {
      // Check if they responded to any
      const completionsAfterNudgeDays = events.filter(e => {
        if (e.type !== "habit_tick" && e.type !== "habit_action") return false;
        if (!(e.payload as any)?.completed) return false;
        
        const day = new Date(e.ts).toDateString();
        return nudgesByDay[day] >= 2;
      }).length;
      
      if (completionsAfterNudgeDays < daysWithMultipleNudges) {
        ignoresAfterMultipleNudges = true;
        score += 0.1;
        dataPoints++;
      }
    }
    
    // Clamp score
    score = Math.min(Math.max(score, 0), 1);
    
    // Determine max intensity
    let maxMessageIntensity: number;
    if (score > 0.7) {
      maxMessageIntensity = 4;
    } else if (score > 0.5) {
      maxMessageIntensity = 6;
    } else {
      maxMessageIntensity = 8;
    }
    
    return {
      score,
      ghostsAfterMissedStreak,
      ghostsAfterConfrontation,
      deletesHabitsAfterFailure,
      respondsToSoftReentry,
      ignoresAfterMultipleNudges,
      maxMessageIntensity,
      requiresSoftLanding: score > 0.5,
      confidence: Math.min(dataPoints / 10, 1),
      dataPoints,
    };
  }
  
  // ---------------------------------------------------------------------------
  // TRIGGER CHAINS
  // ---------------------------------------------------------------------------
  
  private async detectTriggerChains(userId: string, events: any[]): Promise<TriggerChain[]> {
    const ghostPeriods = this.detectGhostPeriods(events);
    
    if (ghostPeriods.length < 2) {
      return [];
    }
    
    // Collect sequences that led to ghosts
    const slipSequences: SlipSequence[] = [];
    
    for (const ghost of ghostPeriods) {
      const beforeGhost = events
        .filter(e => {
          const ts = new Date(e.ts).getTime();
          const ghostStart = ghost.startDate.getTime();
          return ts < ghostStart && ts > ghostStart - 48 * 3600000;
        })
        .sort((a, b) => new Date(a.ts).getTime() - new Date(b.ts).getTime());
      
      if (beforeGhost.length >= 2) {
        slipSequences.push({
          events: beforeGhost,
          ledToGhost: true,
          ghostDuration: ghost.durationDays,
        });
      }
    }
    
    // Find common patterns
    const patternCounts: Record<string, { count: number; sequences: SlipSequence[] }> = {};
    
    for (const seq of slipSequences) {
      // Create a simple signature: first 3 event types
      const signature = seq.events
        .slice(0, 3)
        .map(e => e.type)
        .join(" -> ");
      
      if (!patternCounts[signature]) {
        patternCounts[signature] = { count: 0, sequences: [] };
      }
      patternCounts[signature].count++;
      patternCounts[signature].sequences.push(seq);
    }
    
    // Convert to TriggerChain format
    const chains: TriggerChain[] = [];
    
    for (const [signature, data] of Object.entries(patternCounts)) {
      if (data.count >= 2) {
        const eventTypes = signature.split(" -> ");
        
        chains.push({
          id: `chain_${signature.replace(/ -> /g, "_")}`,
          name: this.generateChainName(eventTypes),
          pattern: eventTypes.map((type, i) => ({
            eventType: type,
            condition: `type === "${type}"`,
            required: i === 0, // Only first event required
            windowHours: 24,
          })),
          occurrences: data.count,
          ledToSlip: data.count, // All these led to ghost
          slipProbability: 1,
          avgTimeToSlip: data.sequences.reduce((sum, s) => sum + (s.ghostDuration || 3), 0) / data.count * 24,
          interventionPoint: 0,
          recommendedIntervention: "soft_nudge",
          firstDetected: new Date(),
          lastOccurred: new Date(Math.max(...data.sequences.map(s => 
            new Date(s.events[0]?.ts || Date.now()).getTime()
          ))),
          confidence: Math.min(data.count / 5, 1),
        });
      }
    }
    
    return chains.slice(0, 5); // Top 5 chains
  }
  
  private generateChainName(eventTypes: string[]): string {
    const typeLabels: Record<string, string> = {
      "habit_tick": "miss",
      "habit_action": "action",
      "app_session": "session",
      "nudge": "nudge",
      "brief": "brief",
    };
    
    const labels = eventTypes.map(t => typeLabels[t] || t);
    
    if (labels.includes("miss") && labels.length >= 2) {
      return "missed_habit_spiral";
    }
    if (labels.includes("session")) {
      return "disengagement_drift";
    }
    
    return "slip_pattern";
  }
  
  // ---------------------------------------------------------------------------
  // COMMITMENT RESOLUTION
  // ---------------------------------------------------------------------------
  
  private async resolveCommitments(
    userId: string, 
    events: any[],
    existingModel: LearnedUserModel | null
  ): Promise<void> {
    const commitments = existingModel?.commitments || [];
    
    for (const commitment of commitments) {
      if (commitment.status !== "pending") continue;
      
      // Check if commitment has expired
      if (commitment.dueBy && new Date(commitment.dueBy) < new Date()) {
        // Look for evidence it was kept
        const afterCommitment = events.filter(e => {
          const ts = new Date(e.ts).getTime();
          const commitTime = new Date(commitment.madeAt).getTime();
          const dueTime = commitment.dueBy ? new Date(commitment.dueBy).getTime() : commitTime + 86400000;
          return ts > commitTime && ts < dueTime;
        });
        
        const keptEvidence = afterCommitment.find(e =>
          (e.type === "habit_tick" || e.type === "habit_action") &&
          (e.payload as any)?.completed
        );
        
        if (keptEvidence) {
          await deepUserModel.resolveCommitment(userId, commitment.id, true, keptEvidence.id);
        } else {
          await deepUserModel.resolveCommitment(userId, commitment.id, false);
        }
      }
    }
  }
  
  // ---------------------------------------------------------------------------
  // MESSAGE EFFECTIVENESS
  // ---------------------------------------------------------------------------
  
  private async analyzeMessageEffectiveness(
    userId: string, 
    events: any[]
  ): Promise<LearnedUserModel["messagePatterns"]> {
    const patterns: LearnedUserModel["messagePatterns"] = [];
    
    const messageTypes = ["brief", "nudge", "debrief", "letter"] as const;
    
    for (const messageType of messageTypes) {
      const messages = events.filter(e => 
        e.type === messageType || 
        e.type === `coach_${messageType}` ||
        e.type === `morning_${messageType}` ||
        e.type === `evening_${messageType}`
      );
      
      if (messages.length < 5) continue;
      
      // Calculate response rate
      let respondedCount = 0;
      let totalCompletionsAfter = 0;
      
      for (const msg of messages) {
        const msgTime = new Date(msg.ts).getTime();
        
        // Look for activity in 6 hours after message
        const afterMsg = events.filter(e => {
          const ts = new Date(e.ts).getTime();
          return ts > msgTime && ts < msgTime + 6 * 3600000;
        });
        
        if (afterMsg.length > 0) respondedCount++;
        
        const completions = afterMsg.filter(e =>
          (e.type === "habit_tick" || e.type === "habit_action") &&
          (e.payload as any)?.completed
        ).length;
        
        totalCompletionsAfter += completions;
      }
      
      patterns.push({
        messageType,
        avgOpenRate: respondedCount / messages.length,
        avgTimeToOpen: 0, // Would need read timestamps
        avgReadDepth: 0, // Would need scroll tracking
        responseRate: respondedCount / messages.length,
        effectivenessByIntensity: [],
        optimalIntensity: 5,
        optimalTimeOfDay: null,
      });
    }
    
    return patterns;
  }
  
  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------
  
  private async getEventsForLearning(userId: string, days: number): Promise<any[]> {
    const since = new Date(Date.now() - days * 86400000);
    
    return prisma.event.findMany({
      where: {
        userId,
        ts: { gte: since },
      },
      orderBy: { ts: "asc" },
    });
  }
  
  private computeConfidenceLevel(eventCount: number): "insufficient" | "low" | "medium" | "high" {
    if (eventCount < 20) return "insufficient";
    if (eventCount < 50) return "low";
    if (eventCount < 150) return "medium";
    return "high";
  }
  
  private computeVariance(numbers: number[]): number {
    if (numbers.length === 0) return 0;
    const mean = numbers.reduce((a, b) => a + b, 0) / numbers.length;
    return numbers.reduce((sum, n) => sum + Math.pow(n - mean, 2), 0) / numbers.length;
  }
  
  private sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}

// =============================================================================
// EXPORT SINGLETON
// =============================================================================

export const patternLearningWorker = new PatternLearningWorker();

// =============================================================================
// CRON JOB FUNCTION
// =============================================================================

/**
 * Entry point for scheduled job.
 * Call this from your scheduler at 3am daily.
 */
export async function runPatternLearning(): Promise<{ processed: number; errors: number }> {
  return patternLearningWorker.processAllUsers();
}