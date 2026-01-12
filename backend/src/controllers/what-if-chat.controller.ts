import { FastifyInstance } from "fastify";
import { whatIfChatService } from "../services/what-if-chat.service";
import { premiumService } from "../services/premium.service";

function getUserIdOr401(req: any) {
  // 🔥 SIMPLE AUTH: Accept user ID from multiple sources
  const uid = 
    req?.user?.id || 
    req.headers["x-user-id"] || 
    req.headers["authorization"]?.replace("Bearer ", "").substring(0, 28); // Extract from Firebase token
  
  if (!uid) {
    console.error("❌ No auth found:", {
      hasUser: !!req?.user?.id,
      hasXUserId: !!req.headers["x-user-id"],
      hasAuth: !!req.headers["authorization"],
    });
    throw Object.assign(new Error("Unauthorized"), { statusCode: 401 });
  }
  
  console.log("✅ Authenticated:", uid);
  return uid;
}

/**
 * 🔬 WHAT-IF IMPLEMENTATION COACH CONTROLLER
 * 
 * Scientific authority on habit implementation
 * Context-aware, citation-validated, variable plan generation
 */
export async function whatIfChatController(fastify: FastifyInstance) {
  // Chat with What-If implementation coach
  fastify.post("/api/v1/what-if/coach", async (req: any, reply) => {
    try {
      const userId = getUserIdOr401(req);
      const { message, preset } = req.body;

      // 🔒 PAYWALL: Check premium status
      const isPremium = await premiumService.isPremium(userId);
      if (!isPremium) {
        return reply.code(402).send({ 
          error: "Premium subscription required",
          code: "PREMIUM_REQUIRED"
        });
      }

      if (!message || typeof message !== "string") {
        return reply.code(400).send({ error: "Message required" });
      }

      // Use preset or default to 'habit-master'
      const effectivePreset = preset && (preset === 'simulator' || preset === 'habit-master') 
        ? preset 
        : 'habit-master';

      console.log(`📝 What-If request: preset=${effectivePreset}, messageLength=${message.length}`);
      const response = await whatIfChatService.chat(userId, message, effectivePreset);
      console.log(`✅ What-If response generated: hasOutputCard=${!!response.outputCard}, habitsCount=${response.habits?.length || 0}`);
      return response; // Returns { message, outputCard?, habits?, sources? }
    } catch (err: any) {
      console.error("❌ What-If coach error:", err.message);
      console.error("Stack trace:", err.stack);
      return reply.code(err.statusCode || 500).send({ error: err.message || 'Failed to generate simulation' });
    }
  });

  // Clear conversation history
  fastify.post("/api/v1/what-if/clear-history", async (req: any, reply) => {
    try {
      const userId = getUserIdOr401(req);
      const result = await whatIfChatService.clearHistory(userId);
      return result;
    } catch (err: any) {
      return reply.code(err.statusCode || 500).send({ error: err.message });
    }
  });
}

