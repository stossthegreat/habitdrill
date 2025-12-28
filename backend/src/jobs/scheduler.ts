// src/jobs/scheduler.ts
// 🧠 OS brain-only scheduler: briefs, debriefs, nudges, and weekly insights

import { Queue, Worker, JobsOptions } from "bullmq";
import { redis } from "../utils/redis";
import { prisma } from "../utils/db";
import { aiService } from "../services/ai.service";
import { aiServiceV2 } from "../services/ai.service.v2";
import { coachMessageService } from "../services/coach-message.service";
import { notificationsService } from "../services/notifications.service";
import { voiceService } from "../services/voice.service";
import { nudgesService } from "../services/nudges.service";
import { premiumService } from "../services/premium.service";
import { BatchLogger } from "../utils/batch-logger";

const QUEUE = "scheduler";
export const schedulerQueue = new Queue(QUEUE, { connection: redis });

const PRO_FEATURES_ENABLED =
  (process.env.PRO_FEATURES_ENABLED || "true").toLowerCase() === "true";
const FREE_NOTIFICATIONS_ENABLED =
  (process.env.FREE_NOTIFICATIONS_ENABLED || "false").toLowerCase() === "true";

// Re-usable hourly repeat options (for ensure-* + auto-nudges-hourly)
function repeatHourly(): JobsOptions {
  return {
    repeat: { every: 60 * 60_000 },
    removeOnComplete: true,
    removeOnFail: true,
  };
}

// 🔌 Called from app bootstrap
export async function bootstrapSchedulers() {
  console.log("⏰ Schedulers active (OS brain only)");

  // Re-upsert daily brief / debrief / nudge schedules per user (respect tz)
  // Run every 6 hours instead of hourly to prevent duplicate job creation
  await schedulerQueue.add("ensure-daily-briefs", {}, {
    repeat: { every: 6 * 60 * 60_000 },
    removeOnComplete: true,
    removeOnFail: true,
  });
  await schedulerQueue.add("ensure-evening-debriefs", {}, {
    repeat: { every: 6 * 60 * 60_000 },
    removeOnComplete: true,
    removeOnFail: true,
  });
  await schedulerQueue.add("ensure-nudges", {}, {
    repeat: { every: 6 * 60 * 60_000 },
    removeOnComplete: true,
    removeOnFail: true,
  });

  // REMOVED: auto-nudges-hourly - this was causing duplicate nudges
  // We already have scheduled nudges at 10am, 2pm, and 6pm via ensure-nudges

  // Weekly memory consolidation (Sundays at midnight)
  await schedulerQueue.add("weekly-consolidation", {}, {
    repeat: { pattern: "0 0 * * 0" }, // Sunday 00:00
    removeOnComplete: true,
    removeOnFail: true,
  });

  // 🧠 Pattern learning (3am daily) - CRITICAL for AI OS brain
  // This job computes behavioral fingerprints, shame sensitivity, trigger chains
  // Without this, the AI never learns the user's patterns
  await schedulerQueue.add("pattern-learning", {}, {
    repeat: { pattern: "0 3 * * *" }, // 3am daily
    removeOnComplete: true,
    removeOnFail: true,
  });
  console.log("🧠 Pattern learning job scheduled (3am daily)");
}

// ─────────────────────────────────────────────
// JOB DEFINITIONS
// ─────────────────────────────────────────────

async function ensureDailyBriefJobs() {
  const logger = new BatchLogger('ensureDailyBriefJobs');
  
  const users = await prisma.user.findMany({ select: { id: true, tz: true } });
  logger.info(`Processing ${users.length} users`);
  
  for (const u of users) {
    try {
      const tz = u.tz || "Europe/London";
      await schedulerQueue.add(
        "daily-brief",
        { userId: u.id },
        {
          repeat: { pattern: "0 7 * * *", tz },
          jobId: `daily-brief:${u.id}`,
          removeOnComplete: true,
          removeOnFail: true,
        }
      );
      logger.success(u.id);
    } catch (err) {
      logger.error(u.id, err);
    }
  }
  
  logger.flush();
  return { ok: true, users: users.length };
}

async function ensureEveningDebriefJobs() {
  const logger = new BatchLogger('ensureEveningDebriefJobs');
  
  const users = await prisma.user.findMany({ select: { id: true, tz: true } });
  logger.info(`Processing ${users.length} users`);
  
  for (const u of users) {
    try {
      const tz = u.tz || "Europe/London";
      await schedulerQueue.add(
        "evening-debrief",
        { userId: u.id },
        {
          repeat: { pattern: "0 21 * * *", tz },
          jobId: `evening-debrief:${u.id}`,
          removeOnComplete: true,
          removeOnFail: true,
        }
      );
      logger.success(u.id);
    } catch (err) {
      logger.error(u.id, err);
    }
  }
  
  logger.flush();
  return { ok: true, users: users.length };
}

async function ensureNudgeJobs() {
  const logger = new BatchLogger('ensureNudgeJobs');
  logger.info(`Starting at ${new Date().toISOString()}`);
  
  const users = await prisma.user.findMany({
    select: { id: true, tz: true, nudgesEnabled: true },
  });
  
  logger.info(`Found ${users.length} total users`);

  for (const u of users) {
    if (!u.nudgesEnabled) {
      logger.skip(u.id, 'nudges disabled');
      continue;
    }
    
    try {
      const tz = u.tz || "Europe/London";

      // Remove existing nudge jobs for this user to prevent duplicates
      const jobIds = [
        `nudge-morning:${u.id}`,
        `nudge-afternoon:${u.id}`,
        `nudge-evening:${u.id}`,
      ];
      
      for (const jobId of jobIds) {
        try {
          const job = await schedulerQueue.getJob(jobId);
          if (job) {
            await job.remove();
          }
        } catch (err) {
          // Job doesn't exist, that's fine
        }
      }

      // Morning nudge (10am)
      await schedulerQueue.add(
        "nudge",
        { userId: u.id, trigger: "morning_momentum" },
        {
          repeat: { pattern: "0 10 * * *", tz },
          jobId: `nudge-morning:${u.id}`,
          removeOnComplete: { count: 10 },
          removeOnFail: { count: 10 },
        }
      );

      // Afternoon nudge (2pm)
      await schedulerQueue.add(
        "nudge",
        { userId: u.id, trigger: "afternoon_drift" },
        {
          repeat: { pattern: "0 14 * * *", tz },
          jobId: `nudge-afternoon:${u.id}`,
          removeOnComplete: { count: 10 },
          removeOnFail: { count: 10 },
        }
      );

      // Evening nudge (6pm)
      await schedulerQueue.add(
        "nudge",
        { userId: u.id, trigger: "evening_closeout" },
        {
          repeat: { pattern: "0 18 * * *", tz },
          jobId: `nudge-evening:${u.id}`,
          removeOnComplete: { count: 10 },
          removeOnFail: { count: 10 },
        }
      );
      
      logger.success(u.id);
    } catch (err) {
      logger.error(u.id, err);
    }
  }
  
  logger.flush();
  return { ok: true, users: users.length };
}

async function runDailyBrief(userId: string) {
  // 🔒 PAYWALL: Temporarily disabled for testing
  // TODO: Re-enable before production launch
  // const isPremium = await premiumService.isPremium(userId);
  // if (!isPremium) {
  //   return { ok: true, skipped: true, reason: "not_premium" };
  // }

  try {
    // 🧠 AI OS v2: Use new coach engine with fallback to legacy
    let text: string;
    try {
      text = await aiServiceV2.generateMorningBrief(userId);
    } catch (err) {
      console.warn(`⚠️ runDailyBrief AI OS v2 fallback for ${userId}:`, err instanceof Error ? err.message : err);
      text = await aiService.generateMorningBrief(userId).catch(() => "Good morning.");
    }

    let audioUrl: string | null = null;
    try {
      audioUrl = await voiceService.ttsToUrl(userId, text, "future-you");
    } catch {
      audioUrl = null;
    }

    // Store as CoachMessage (kind = brief)
    await coachMessageService.createMessage(userId, "brief", text, { audioUrl });

    // Backwards compat event
    await prisma.event.create({
      data: { userId, type: "morning_brief", payload: { text, audioUrl } },
    });

    await notificationsService.send(userId, "Morning Brief", text.slice(0, 180));
    return { ok: true };
  } catch (err) {
    console.error(`❌ runDailyBrief failed for ${userId}:`, err);
    throw err;
  }
}

async function runEveningDebrief(userId: string) {
  // 🔒 PAYWALL: Temporarily disabled for testing
  // TODO: Re-enable before production launch
  // const isPremium = await premiumService.isPremium(userId);
  // if (!isPremium) {
  //   return { ok: true, skipped: true, reason: "not_premium" };
  // }

  try {
    // 🧠 AI OS v2: Use new coach engine with fallback to legacy
    let text: string;
    try {
      text = await aiServiceV2.generateEveningDebrief(userId);
    } catch (err) {
      console.warn(`⚠️ runEveningDebrief AI OS v2 fallback for ${userId}:`, err instanceof Error ? err.message : err);
      text = await aiService.generateEveningDebrief(userId).catch(() => "Evening debrief.");
    }

    let audioUrl: string | null = null;
    try {
      audioUrl = await voiceService.ttsToUrl(userId, text, "future-you");
    } catch {
      audioUrl = null;
    }

    // Store as CoachMessage (kind = debrief)
    await coachMessageService.createMessage(userId, "debrief", text, { audioUrl });

    // Backwards compat event
    await prisma.event.create({
      data: { userId, type: "evening_debrief", payload: { text, audioUrl } },
    });

    await notificationsService.send(userId, "Evening Debrief", text.slice(0, 180));
    return { ok: true };
  } catch (err) {
    console.error(`❌ runEveningDebrief failed for ${userId}:`, err);
    throw err;
  }
}

async function runNudge(userId: string, trigger: string) {
  // 🔒 PAYWALL: Only send nudges to premium users
  // TEMP: Disabled for testing - re-enable before production launch
  // const isPremium = await premiumService.isPremium(userId);
  // if (!isPremium) {
  //   return { ok: true, skipped: true, reason: "not_premium" };
  // }

  try {
    // ✅ ANTI-DUPLICATE CHECK: Don't send another nudge if one was just sent
    const recentNudges = await prisma.coachMessage.findMany({
      where: {
        userId,
        kind: "nudge",
        createdAt: {
          gte: new Date(Date.now() - 15 * 60 * 1000), // Last 15 minutes
        },
      },
      orderBy: { createdAt: "desc" },
      take: 1,
    });

    if (recentNudges.length > 0) {
      const minutesAgo = Math.floor((Date.now() - recentNudges[0].createdAt.getTime()) / 1000 / 60);
      return { ok: true, skipped: true, reason: "duplicate_prevention", minutesAgo };
    }
    
    // 🧠 AI OS v2: Use new coach engine with fallback to legacy
    let text: string;
    try {
      text = await aiServiceV2.generateNudge(userId, trigger);
    } catch (err) {
      console.warn(`⚠️ runNudge AI OS v2 fallback for ${userId}:`, err instanceof Error ? err.message : err);
      text = await aiService.generateNudge(userId, trigger).catch(() => "Check in with yourself.");
    }

    // Store as CoachMessage (kind = nudge)
    const msg = await coachMessageService.createMessage(userId, "nudge", text, { trigger });

    // Backwards compat event
    await prisma.event.create({
      data: { userId, type: "nudge", payload: { text, trigger } },
    });

    await notificationsService.send(userId, "Nudge", text.slice(0, 180));
    
    return { ok: true, messageId: msg.id };
  } catch (err) {
    console.error(`❌ runNudge failed for ${userId}:`, err);
    throw err;
  }
}

async function autoNudgesHourly() {
  const users = await prisma.user.findMany({
    select: { id: true, plan: true },
  });

  for (const u of users) {
    if (u.plan !== "PRO" && !FREE_NOTIFICATIONS_ENABLED) continue;

    const res = await nudgesService.generateNudges(u.id);
    const n = Array.isArray(res)
      ? res[0]
      : (res as any).nudges?.[0];

    if (!n?.message) continue;

    await notificationsService.send(
      u.id,
      "Nudge",
      n.message.slice(0, 180)
    );
  }
  return { ok: true };
}

/**
 * 🧠 PATTERN LEARNING - Nightly job that makes the AI OS brain actually learn
 * 
 * This computes:
 * - Behavioral fingerprints (recovery style, challenge response, celebration trap)
 * - Shame sensitivity scores
 * - Trigger chains (sequences that lead to slips)
 * - Message effectiveness patterns
 * 
 * WITHOUT THIS JOB, THE AI NEVER LEARNS USER PATTERNS.
 */
async function runPatternLearning() {
  try {
    // Dynamic import to avoid circular dependencies
    const { patternLearningWorker } = await import("../workers/pattern-learning.worker");
    const result = await patternLearningWorker.processAllUsers();
    return result;
  } catch (err) {
    console.error(`❌ Pattern learning failed:`, err);
    return { processed: 0, errors: 1 };
  }
}

async function runWeeklyConsolidation() {
  const logger = new BatchLogger('runWeeklyConsolidation');
  
  const users = await prisma.user.findMany({ select: { id: true } });
  logger.info(`Processing ${users.length} users`);

  for (const u of users) {
    try {
      const { insightsService } = await import("../services/insights.service");
      const result = await insightsService.weeklyConsolidation(u.id);
      if (result.ok) {
        // Notify about weekly letter if generated
        if (result.letterText) {
          await notificationsService.send(
            u.id,
            "📜 Weekly Letter from Future You",
            result.letterText.slice(0, 180)
          );
        } else if (result.reflection) {
          // Fallback to reflection if letter generation failed
          await notificationsService.send(
            u.id,
            "📊 Weekly Insights",
            result.reflection.slice(0, 180)
          );
        }
        logger.success(u.id);
      } else {
        logger.skip(u.id, 'no insights generated');
      }
    } catch (err) {
      logger.error(u.id, err);
    }
  }

  logger.flush();
  return { ok: true, processed: users.length };
}

// ─────────────────────────────────────────────
// WORKER - ONLY START WHEN EXPLICITLY CALLED
// ─────────────────────────────────────────────

let workerInstance: Worker | null = null;

/**
 * 🚨 CRITICAL: Start the worker ONLY from worker.ts
 * This prevents duplicate workers when server.ts imports this file
 */
export function startWorker() {
  if (workerInstance) {
    console.log("⚠️ Worker already running, skipping duplicate instantiation");
    return workerInstance;
  }

  console.log("🏭 STARTING SCHEDULER WORKER...");
  
  workerInstance = new Worker(
    QUEUE,
    async (job) => {
      // Only log non-nudge jobs or use minimal logging for nudges
      const shouldLogDetails = job.name !== "nudge" && job.name !== "daily-brief" && job.name !== "evening-debrief";
      
      if (shouldLogDetails) {
        console.log(`🏭 Processing: ${job.name} [${job.id}]`);
      }
      
      switch (job.name) {
        case "ensure-daily-briefs":
          return ensureDailyBriefJobs();
        case "ensure-evening-debriefs":
          return ensureEveningDebriefJobs();
        case "ensure-nudges":
          return ensureNudgeJobs();
        case "daily-brief":
          return runDailyBrief(job.data.userId);
        case "evening-debrief":
          return runEveningDebrief(job.data.userId);
        case "nudge":
          return runNudge(job.data.userId, job.data.trigger);
        // REMOVED: auto-nudges-hourly case - no longer used
        case "weekly-consolidation":
          return runWeeklyConsolidation();
        case "pattern-learning":
          console.log(`🧠 Pattern Learning starting...`);
          const patternResult = await runPatternLearning();
          console.log(`🧠 Pattern Learning complete: ${patternResult.processed} processed, ${patternResult.errors} errors`);
          return patternResult;
        default:
          return;
      }
    },
    { 
      connection: redis,
      // CRITICAL: Ensure only ONE worker processes each job
      concurrency: 1,
    }
  );

  console.log("🧠 Scheduler Worker Started (OS Brain Only)");
  return workerInstance;
}
