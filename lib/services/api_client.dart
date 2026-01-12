import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/habit.dart';
import 'local_storage.dart';

class ApiClient {
  // Future-You OS Backend Integration
  static const String _baseUrl = 'https://futureyou-production.up.railway.app'; // Railway URL
  static const String _localUrl = 'http://localhost:8080'; // For local development
  static const Duration _timeout = Duration(seconds: 180); // 🔥 3 MINUTES! Let AI finish output cards!
  
  // Firebase Authentication
  static Future<String?> _getFirebaseToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('⚠️ No Firebase user signed in');
        return null;
      }
      return await user.getIdToken();
    } catch (e) {
      debugPrint('❌ Error getting Firebase token: $e');
      return null;
    }
  }
  
  static String? get userId => FirebaseAuth.instance.currentUser?.uid;
  
  // Public POST method for direct API calls
  static Future<http.Response> post(String endpoint, Map<String, dynamic> data) async {
    return _post(endpoint, data);
  }
  
  // Get headers with Firebase token
  static Future<Map<String, String>> get _headers async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    final token = await _getFirebaseToken();
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    } else {
      debugPrint('⚠️ Making API call without authentication token');
    }
    
    // 🔥 FALLBACK: Send user ID as header (for backends without Firebase Admin)
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      headers['x-user-id'] = uid;
    }
    
    return headers;
  }
  
  // Generic HTTP methods
  static Future<http.Response> _get(String endpoint) async {
    try {
      final uri = Uri.parse('$_baseUrl$endpoint');
      final headers = await _headers;
      final response = await http.get(uri, headers: headers).timeout(_timeout);
      return response;
    } catch (e) {
      debugPrint('GET request failed: $e');
      rethrow;
    }
  }
  
  static Future<http.Response> _post(String endpoint, Map<String, dynamic> data) async {
    try {
      final uri = Uri.parse('$_baseUrl$endpoint');
      final headers = await _headers;
      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(data),
      ).timeout(_timeout);
      return response;
    } catch (e) {
      debugPrint('POST request failed: $e');
      rethrow;
    }
  }
  
  static Future<http.Response> _put(String endpoint, Map<String, dynamic> data) async {
    try {
      final uri = Uri.parse('$_baseUrl$endpoint');
      final headers = await _headers;
      final response = await http.put(
        uri,
        headers: headers,
        body: jsonEncode(data),
      ).timeout(_timeout);
      return response;
    } catch (e) {
      debugPrint('PUT request failed: $e');
      rethrow;
    }
  }
  
  static Future<http.Response> _delete(String endpoint) async {
    try {
      final uri = Uri.parse('$_baseUrl$endpoint');
      final headers = await _headers;
      final response = await http.delete(uri, headers: headers).timeout(_timeout);
      return response;
    } catch (e) {
      debugPrint('DELETE request failed: $e');
      rethrow;
    }
  }
  
  // Habit API endpoints
  static Future<ApiResponse<Habit>> createHabit(Habit habit) async {
    try {
      final response = await _post('/habits', habit.toJson());
      
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return ApiResponse.success(Habit.fromJson(data));
      } else {
        return ApiResponse.error('Failed to create habit: ${response.statusCode}');
      }
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }
  
  static Future<ApiResponse<Habit>> updateHabit(Habit habit) async {
    try {
      final response = await _put('/habits/${habit.id}', habit.toJson());
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ApiResponse.success(Habit.fromJson(data));
      } else {
        return ApiResponse.error('Failed to update habit: ${response.statusCode}');
      }
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }
  
  static Future<ApiResponse<void>> deleteHabit(String habitId) async {
    try {
      final response = await _delete('/habits/$habitId');
      
      if (response.statusCode == 200 || response.statusCode == 204) {
        return ApiResponse.success(null);
      } else {
        return ApiResponse.error('Failed to delete habit: ${response.statusCode}');
      }
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }
  
  static Future<ApiResponse<List<Habit>>> getHabits() async {
    try {
      final response = await _get('/habits');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final habits = data.map((json) => Habit.fromJson(json)).toList();
        return ApiResponse.success(habits);
      } else {
        return ApiResponse.error('Failed to fetch habits: ${response.statusCode}');
      }
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }
  
  static Future<ApiResponse<void>> logAction(String habitId, bool completed, DateTime timestamp) async {
    try {
      final data = {
        'habitId': habitId,
        'completed': completed,
        'timestamp': timestamp.toIso8601String(),
      };
      
      final response = await _post('/habits/log', data);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiResponse.success(null);
      } else {
        return ApiResponse.error('Failed to log action: ${response.statusCode}');
      }
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }
  
  // Chat API endpoints
  static Future<ApiResponse<ChatResponse>> sendChatMessage(String message) async {
    try {
      final data = {
        'message': message,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      final response = await _post('/chat/send', data);
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return ApiResponse.success(ChatResponse.fromJson(responseData));
      } else {
        return ApiResponse.error('Failed to send message: ${response.statusCode}');
      }
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }
  
  static Future<ApiResponse<List<ChatMessage>>> getChatHistory() async {
    try {
      final response = await _get('/chat/history');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final messages = data.map((json) => ChatMessage.fromJson(json)).toList();
        return ApiResponse.success(messages);
      } else {
        return ApiResponse.error('Failed to fetch chat history: ${response.statusCode}');
      }
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }
  
  // Sync API endpoints
  static Future<ApiResponse<SyncResponse>> syncAll(List<Habit> localHabits) async {
    try {
      final data = {
        'habits': localHabits.map((h) => h.toJson()).toList(),
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      final response = await _post('/sync/all', data);
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return ApiResponse.success(SyncResponse.fromJson(responseData));
      } else {
        return ApiResponse.error('Failed to sync: ${response.statusCode}');
      }
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }
  
  // Analytics API endpoints
  static Future<ApiResponse<AnalyticsData>> getAnalytics(DateTime startDate, DateTime endDate) async {
    try {
      final queryParams = {
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
      };
      
      final uri = Uri.parse('$_baseUrl/analytics').replace(queryParameters: queryParams);
      final headers = await _headers;
      final response = await http.get(uri, headers: headers).timeout(_timeout);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ApiResponse.success(AnalyticsData.fromJson(data));
      } else {
        return ApiResponse.error('Failed to fetch analytics: ${response.statusCode}');
      }
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  // Coach API endpoints - Future-You OS Brain Layer
  static Future<ApiResponse<void>> syncCoachData(List<Habit> habits, List<HabitCompletion> completions) async {
    try {
      print('═══════════════════════════════════════════════════════════');
      print('🚀 FLUTTER: Calling /api/v1/coach/sync');
      print('📊 Sending: ${habits.length} habits, ${completions.length} completions');
      
      final data = {
        'habits': habits.map((h) => h.toJson()).toList(),
        'completions': completions.map((c) => c.toJson()).toList(),
      };
      
      print('📋 Completions data: ${data['completions']}');
      print('🌐 Base URL: $_baseUrl');
      print('═══════════════════════════════════════════════════════════');
      
      final response = await _post('/api/v1/coach/sync', data);
      
      print('✅ Response status: ${response.statusCode}');
      print('✅ Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        return ApiResponse.success(null);
      } else {
        print('❌ Sync failed: ${response.statusCode} - ${response.body}');
        return ApiResponse.error('Failed to sync coach data: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Network error in syncCoachData: $e');
      return ApiResponse.error('Network error: $e');
    }
  }

  static Future<ApiResponse<List<CoachMessage>>> getCoachMessages() async {
    try {
      final response = await _get('/api/v1/coach/messages');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final messages = (data['messages'] as List)
            .map((json) => CoachMessage.fromJson(json))
            .toList();
        return ApiResponse.success(messages);
      } else {
        return ApiResponse.error('Failed to fetch coach messages: ${response.statusCode}');
      }
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  // 📊 Get OS Metrics (discipline, streak, system strength)
  static Future<ApiResponse<Map<String, dynamic>>> getOSMetrics() async {
    try {
      final response = await _get('/api/v1/user/metrics');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return ApiResponse.success(data);
      } else {
        return ApiResponse.error('Failed to fetch metrics: ${response.statusCode}');
      }
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  // Helper method to update base URL after Railway deployment
  static void updateBaseUrl(String newBaseUrl) {
    // This would require making _baseUrl non-final and adding a setter
    // For now, users should update the _baseUrl constant directly
    debugPrint('Update _baseUrl constant to: $newBaseUrl');
  }

  // AI chat with optional voice (backend: POST /v1/chat)
  static Future<ApiResponse<AiChatResult>> chatWithVoice(String message, { String mode = 'balanced', bool includeVoice = true }) async {
    try {
      final body = {
        'message': message,
        'mode': mode,
        'includeVoice': includeVoice,
      };
      final resp = await _post('/v1/chat', body);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final reply = (data['reply'] ?? '').toString();
        final voiceUrl = (data['voice'] != null && data['voice']['url'] != null) ? data['voice']['url'] as String : null;
        return ApiResponse.success(AiChatResult(reply: reply, voiceUrl: voiceUrl));
      } else {
        return ApiResponse.error('Chat failed: ${resp.statusCode}');
      }
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  // Messages API - Get all coach messages (briefs, nudges, debriefs)
  static Future<http.Response> getMessages(String userId) async {
    return await _get('/api/v1/coach/messages');
  }

  // Mark message as read
  static Future<http.Response> markMessageAsRead(String messageId) async {
    return await _post('/api/v1/coach/messages/$messageId/read', {});
  }

  // Sync user identity to backend (name, age, burning question)
  static Future<void> syncIdentityToBackend() async {
    final name = LocalStorageService.getSetting<String>('userName');
    final age = LocalStorageService.getSetting<int>('userAge');
    final burningQuestion = LocalStorageService.getSetting<String>('burningQuestion');
    
    if (name == null) return; // Not captured yet
    
    final synced = LocalStorageService.getSetting<bool>('identitySynced', defaultValue: false);
    if (synced == true) return; // Already synced
    
    try {
      await _post('/api/v1/user/identity', {
        'name': name,
        'age': age,
        'burningQuestion': burningQuestion,
      });
      await LocalStorageService.saveSetting('identitySynced', true);
      debugPrint('✓ Identity synced to backend');
    } catch (e) {
      debugPrint('Failed to sync identity: $e');
    }
  }

  // 🔥 NEW: Save user identity directly (for onboarding)
  static Future<void> saveUserIdentity({
    required String? name,
    required int? age,
    required String? burningQuestion,
  }) async {
    try {
      await _post('/api/v1/user/identity', {
        'name': name,
        'age': age,
        'burningQuestion': burningQuestion,
      });
      await LocalStorageService.saveSetting('identitySynced', true);
      debugPrint('✅ Identity saved to backend: $name');
    } catch (e) {
      debugPrint('⚠️ Failed to save identity: $e');
      rethrow;
    }
  }

  // Get purpose-aligned What-If goals
  static Future<ApiResponse<Map<String, dynamic>>> getPurposeAlignedGoals() async {
    try {
      final response = await _get('/api/v1/whatif/purpose-goals');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return ApiResponse.success(data);
      } else {
        return ApiResponse.error('Failed to load custom goals');
      }
    } catch (e) {
      debugPrint('Failed to get purpose-aligned goals: $e');
      return ApiResponse.error(e.toString());
    }
  }

  // 🎯 NEW: Future-You Freeform Chat (7 lenses)
  static Future<ApiResponse<Map<String, dynamic>>> sendFutureYouMessage(String message) async {
    try {
      final response = await _post('/api/v1/future-you/freeform', {'message': message});
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return ApiResponse.success(data);
      } else {
        return ApiResponse.error('Failed to send message');
      }
    } catch (e) {
      debugPrint('Future-You chat error: $e');
      return ApiResponse.error(e.toString());
    }
  }

  // 🌊 STREAMING: Future-You Chat (word by word)
  static Stream<String> sendFutureYouMessageStream(String message) async* {
    try {
      final headers = await _headers;
      final client = http.Client();
      
      final request = http.Request(
        'POST',
        Uri.parse('$_baseUrl/api/v1/future-you/freeform/stream'),
      )
        ..headers.addAll(headers)
        ..body = jsonEncode({'message': message});

      final response = await client.send(request);
      final responseText = await response.stream.bytesToString();
      
      client.close();
      
      // Parse SSE stream
      final lines = responseText.split('\n');
      for (final line in lines) {
        if (line.startsWith('data: ')) {
          final data = line.substring(6);
          if (data == '[DONE]') break;
          
          try {
            final json = jsonDecode(data);
            if (json['text'] != null) {
              yield json['text'] as String;
            } else if (json['error'] != null) {
              throw Exception(json['error']);
            }
          } catch (_) {
            // Skip malformed JSON
          }
        }
      }
    } catch (e) {
      debugPrint('Future-You stream error: $e');
      yield '❌ Error: ${e.toString()}';
    }
  }

  // 🧠 NEW: 7-Phase Discovery Flow
  static Future<ApiResponse<Map<String, dynamic>>> sendPhaseFlowMessage(String message) async {
    try {
      final response = await _post('/api/v1/future-you/flow', {'message': message});
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return ApiResponse.success(data);
      } else {
        return ApiResponse.error('Failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Phase flow error: $e');
      return ApiResponse.error(e.toString());
    }
  }

  // Get phase status
  static Future<ApiResponse<Map<String, dynamic>>> getPhaseStatus() async {
    try {
      final response = await _get('/api/v1/future-you/phase-status');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return ApiResponse.success(data);
      } else {
        return ApiResponse.error('Failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Phase status error: $e');
      return ApiResponse.error(e.toString());
    }
  }

  // ================================
  // 📖 FUTURE-YOU UNIFIED ENGINE API (NEW BACKEND /api/futureyou/*)
  // ================================
  
  /// Start or continue a phase conversation
  static Future<ApiResponse<Map<String, dynamic>>> enginePhaseStart({
    required String phase,
    List<Map<String, String>>? scenes,
    String? idemKey,
  }) async {
    try {
      final body = {
        'phase': phase,
        if (scenes != null) 'scenes': scenes,
        if (idemKey != null) 'idemKey': idemKey,
      };
      final response = await _post('/api/futureyou/engine/phase', body);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return ApiResponse.success(data);
      }
      return ApiResponse.error('Phase start failed: ${response.statusCode}');
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  /// Generate a chapter for a phase
  static Future<ApiResponse<Map<String, dynamic>>> generateChapter({
    required String phase,
    String? title,
    String? body,
    String? idemKey,
  }) async {
    try {
      final reqBody = {
        'phase': phase,
        if (title != null) 'title': title,
        if (body != null) 'body': body,
        if (idemKey != null) 'idemKey': idemKey,
      };
      final response = await _post('/api/futureyou/chapters', reqBody);
      
      if (response.statusCode == 200 || response.statusCode == 202) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return ApiResponse.success(data);
      }
      return ApiResponse.error('Chapter generation failed: ${response.statusCode}');
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  /// List all chapters for the current user
  static Future<ApiResponse<List<dynamic>>> listChapters() async {
    try {
      final response = await _get('/api/futureyou/chapters');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final chapters = data['chapters'] as List<dynamic>;
        return ApiResponse.success(chapters);
      }
      return ApiResponse.error('List chapters failed: ${response.statusCode}');
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  /// Compile a book from chapters
  static Future<ApiResponse<Map<String, dynamic>>> compileBook({
    List<String>? includePhases,
    String? title,
    String? idemKey,
  }) async {
    try {
      final body = {
        if (includePhases != null) 'includePhases': includePhases,
        if (title != null) 'title': title,
        if (idemKey != null) 'idemKey': idemKey,
      };
      final response = await _post('/api/futureyou/book/compile', body);
      
      if (response.statusCode == 200 || response.statusCode == 202) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return ApiResponse.success(data);
      }
      return ApiResponse.error('Book compilation failed: ${response.statusCode}');
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  /// Get the latest compiled book
  static Future<ApiResponse<Map<String, dynamic>>> getLatestBook() async {
    try {
      final response = await _get('/api/futureyou/book/latest');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return ApiResponse.success(data);
      }
      return ApiResponse.error('Get latest book failed: ${response.statusCode}');
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  // Get vault items
  static Future<ApiResponse<List<dynamic>>> getVaultItems({int limit = 20}) async {
    try {
      final response = await _get('/api/v1/future-you/vault?limit=$limit');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return ApiResponse.success(data['items'] ?? []);
      } else {
        return ApiResponse.error('Failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Vault items error: $e');
      return ApiResponse.error(e.toString());
    }
  }

  // ================================
  // 🎯 LIFE'S TASK DISCOVERY API
  // ================================

  /// Send conversation message to Life's Task AI (excavation mode)
  static Future<ApiResponse<Map<String, dynamic>>> lifeTaskConverse({
    required int chapterNumber,
    required List<Map<String, dynamic>> messages,
    required String sessionStartTime,
  }) async {
    try {
      final response = await _post('/api/lifetask/converse', {
        'chapterNumber': chapterNumber,
        'messages': messages,
        'sessionStartTime': sessionStartTime,
      });
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return ApiResponse.success(data);
      }
      return ApiResponse.error('Conversation failed: ${response.statusCode}');
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  /// Generate prose chapter for Life's Task
  static Future<ApiResponse<Map<String, dynamic>>> lifeTaskGenerateChapter({
    required int chapterNumber,
    required List<Map<String, dynamic>> conversationTranscript,
    required Map<String, dynamic> extractedPatterns,
  }) async {
    try {
      final response = await _post('/api/lifetask/chapters/generate', {
        'chapterNumber': chapterNumber,
        'conversationTranscript': conversationTranscript,
        'extractedPatterns': extractedPatterns,
      });
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return ApiResponse.success(data);
      }
      return ApiResponse.error('Chapter generation failed: ${response.statusCode}');
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  /// Save completed Life's Task chapter
  static Future<ApiResponse<void>> lifeTaskSaveChapter({
    required int chapterNumber,
    required List<Map<String, dynamic>> conversationTranscript,
    required Map<String, dynamic> extractedPatterns,
    required String proseText,
    required int timeSpentMinutes,
  }) async {
    try {
      final response = await _post('/api/lifetask/chapters/save', {
        'chapterNumber': chapterNumber,
        'conversationTranscript': conversationTranscript,
        'extractedPatterns': extractedPatterns,
        'proseText': proseText,
        'timeSpentMinutes': timeSpentMinutes,
      });
      
      if (response.statusCode == 200) {
        return ApiResponse.success(null);
      }
      return ApiResponse.error('Save failed: ${response.statusCode}');
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  /// Get all Life's Task chapters
  static Future<ApiResponse<List<dynamic>>> lifeTaskGetChapters() async {
    try {
      final response = await _get('/api/lifetask/chapters');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        return ApiResponse.success(data);
      }
      return ApiResponse.error('Failed to fetch chapters: ${response.statusCode}');
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  /// Compile Life's Task book
  static Future<ApiResponse<Map<String, dynamic>>> lifeTaskCompileBook() async {
    try {
      final response = await _post('/api/lifetask/book/compile', {});
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return ApiResponse.success(data);
      }
      return ApiResponse.error('Book compilation failed: ${response.statusCode}');
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  // 🔬 NEW: What-If Implementation Coach
  static Future<ApiResponse<Map<String, dynamic>>> sendWhatIfMessage(
    String message, {
    String? preset,
  }) async {
    try {
      final data = {'message': message};
      if (preset != null) {
        data['preset'] = preset;
      }
      
      final response = await _post('/api/v1/what-if/coach', data);
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        return ApiResponse.success(responseData);
      } else {
        return ApiResponse.error('Failed to send message');
      }
    } catch (e) {
      debugPrint('What-If coach error: $e');
      return ApiResponse.error(e.toString());
    }
  }

  // 🌊 STREAMING: What-If Chat (word by word)
  static Stream<String> sendWhatIfMessageStream(
    String message, {
    String? preset,
  }) async* {
    try {
      final data = {'message': message};
      if (preset != null) {
        data['preset'] = preset;
      }

      final headers = await _headers;
      final client = http.Client();
      
      final request = http.Request(
        'POST',
        Uri.parse('$_baseUrl/api/v1/what-if/coach/stream'),
      )
        ..headers.addAll(headers)
        ..body = jsonEncode(data);

      final response = await client.send(request);
      final responseText = await response.stream.bytesToString();
      
      client.close();
      
      // Parse SSE stream
      final lines = responseText.split('\n');
      for (final line in lines) {
        if (line.startsWith('data: ')) {
          final data = line.substring(6);
          if (data == '[DONE]') break;
          
          try {
            final json = jsonDecode(data);
            if (json['text'] != null) {
              yield json['text'] as String;
            } else if (json['error'] != null) {
              throw Exception(json['error']);
            }
          } catch (_) {
            // Skip malformed JSON
          }
        }
      }
    } catch (e) {
      debugPrint('What-If stream error: $e');
      yield '❌ Error: ${e.toString()}';
    }
  }

  // Chat with Future You (enhanced endpoint) - Returns properly parsed response
  static Future<ApiResponse<Map<String, dynamic>>> sendChatMessageV2(String message) async {
    // Ensure identity is synced before sending message
    await syncIdentityToBackend();
    
    try {
      // Use v2 endpoint with premium checks
      final response = await _post('/api/v2/future-you/freeform', {'message': message});
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        // v2 endpoint returns { message: "..." } so wrap it properly
        return ApiResponse.success({
          'message': data['message'],
          'phase': 'observer', // v2 doesn't return phase, default to observer
        });
      } else if (response.statusCode == 402) {
        // Premium required
        return ApiResponse.error('Premium subscription required');
      } else {
        return ApiResponse.error('Chat failed: ${response.statusCode}');
      }
    } on TimeoutException {
      return ApiResponse.error('Request timed out. Please try again.');
    } on SocketException {
      return ApiResponse.error('No internet connection.');
    } catch (e) {
      return ApiResponse.error('Network error: $e');
    }
  }

  // 🔊 ElevenLabs Voice Generation
  static Future<ApiResponse<Map<String, dynamic>>> generateVoice({
    required String text,
    String voiceKey = 'marcus',
  }) async {
    try {
      debugPrint('📤 API CALL: POST /api/v1/speech/generate - Voice: $voiceKey, Text length: ${text.length}');
      
      final response = await _post('/api/v1/speech/generate', {
        'text': text,
        'voiceKey': voiceKey,
      });
      
      debugPrint('📥 API RESPONSE: Status ${response.statusCode}, Body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('✅ Voice generation SUCCESS - Data keys: ${data.keys.toList()}');
        return ApiResponse.success(data);
      } else {
        debugPrint('❌ Voice generation failed: ${response.statusCode} - ${response.body}');
        return ApiResponse.error('Voice generation failed: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Voice generation error: $e');
      debugPrint('Stack trace: $stackTrace');
      return ApiResponse.error('Network error: $e');
    }
  }

  // Save What-If output card to Vault
  static Future<ApiResponse<void>> saveToVault({
    required String content,
    List<dynamic>? sections,
    List<dynamic>? habits,
  }) async {
    try {
      final response = await _post('/api/v1/reflections/vault', {
        'content': content,
        'sections': sections,
        'habits': habits,
      });
      
      if (response.statusCode == 200) {
        return ApiResponse.success(null);
      } else {
        return ApiResponse.error('Failed to save to vault: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Save to vault error: $e');
      return ApiResponse.error(e.toString());
    }
  }

  // Delete user account
  static Future<void> deleteAccount() async {
    try {
      final response = await _delete('/api/v1/user/account');
      
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to delete account: ${response.statusCode}');
      }
      
      debugPrint('✅ Account deleted from backend');
    } catch (e) {
      debugPrint('❌ Delete account error: $e');
      rethrow;
    }
  }
}

// Response wrapper class
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? error;
  
  ApiResponse.success(this.data) : success = true, error = null;
  ApiResponse.error(this.error) : success = false, data = null;
}

// Chat related models
class ChatMessage {
  final String id;
  final String role; // 'user' or 'future' or 'card'
  final String text;
  final DateTime timestamp;
  final Map<String, dynamic>? outputCard; // NEW: For beautiful output cards
  final List<dynamic>? habits; // NEW: For habit commit
  
  ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.timestamp,
    this.outputCard,
    this.habits,
  });
  
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      role: json['role'],
      text: json['text'],
      timestamp: DateTime.parse(json['timestamp']),
      outputCard: json['outputCard'],
      habits: json['habits'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      if (outputCard != null) 'outputCard': outputCard,
      if (habits != null) 'habits': habits,
    };
  }
}

class ChatResponse {
  final String message;
  final List<QuickCommit>? quickCommits;
  
  ChatResponse({
    required this.message,
    this.quickCommits,
  });
  
  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    return ChatResponse(
      message: json['message'],
      quickCommits: json['quickCommits'] != null
          ? (json['quickCommits'] as List)
              .map((q) => QuickCommit.fromJson(q))
              .toList()
          : null,
    );
  }
}

class QuickCommit {
  final String label;
  final String type;
  final String title;
  final String time;
  
  QuickCommit({
    required this.label,
    required this.type,
    required this.title,
    required this.time,
  });
  
  factory QuickCommit.fromJson(Map<String, dynamic> json) {
    return QuickCommit(
      label: json['label'],
      type: json['type'],
      title: json['title'],
      time: json['time'],
    );
  }
}

// Sync related models
class SyncResponse {
  final List<Habit> updatedHabits;
  final List<String> deletedHabitIds;
  final DateTime lastSyncTime;
  
  SyncResponse({
    required this.updatedHabits,
    required this.deletedHabitIds,
    required this.lastSyncTime,
  });
  
  factory SyncResponse.fromJson(Map<String, dynamic> json) {
    return SyncResponse(
      updatedHabits: (json['updatedHabits'] as List)
          .map((h) => Habit.fromJson(h))
          .toList(),
      deletedHabitIds: List<String>.from(json['deletedHabitIds']),
      lastSyncTime: DateTime.parse(json['lastSyncTime']),
    );
  }
}

// Analytics related models
class AnalyticsData {
  final double averageFulfillment;
  final int totalHabits;
  final int completedHabits;
  final int currentStreak;
  final int longestStreak;
  final Map<String, double> weeklyTrends;
  
  AnalyticsData({
    required this.averageFulfillment,
    required this.totalHabits,
    required this.completedHabits,
    required this.currentStreak,
    required this.longestStreak,
    required this.weeklyTrends,
  });
  
  factory AnalyticsData.fromJson(Map<String, dynamic> json) {
    return AnalyticsData(
      averageFulfillment: json['averageFulfillment'].toDouble(),
      totalHabits: json['totalHabits'],
      completedHabits: json['completedHabits'],
      currentStreak: json['currentStreak'],
      longestStreak: json['longestStreak'],
      weeklyTrends: Map<String, double>.from(json['weeklyTrends']),
    );
  }
}

// AI chat response with optional voice
class AiChatResult {
  final String reply;
  final String? voiceUrl;
  AiChatResult({ required this.reply, this.voiceUrl });
}

// Coach related models - Future-You OS Brain Layer
class HabitCompletion {
  final String habitId;
  final String? habitTitle;
  final DateTime date;
  final bool done;
  final int? streak;
  final DateTime? completedAt;
  
  HabitCompletion({
    required this.habitId,
    this.habitTitle,
    required this.date,
    required this.done,
    this.streak,
    this.completedAt,
  });
  
  factory HabitCompletion.fromJson(Map<String, dynamic> json) {
    return HabitCompletion(
      habitId: json['habitId'],
      habitTitle: json['habitTitle'],
      date: DateTime.parse(json['date']),
      done: json['done'],
      streak: json['streak'],
      completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt']) : null,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'habitId': habitId,
      'habitTitle': habitTitle,
      'date': date.toIso8601String(),
      'done': done,
      'streak': streak,
      'completedAt': completedAt?.toIso8601String(),
    };
  }
}

enum CoachMessageKind { nudge, brief, debrief, mirror, letter }

class CoachMessage {
  final String id;
  final String userId;
  final CoachMessageKind kind;
  final String title;
  final String body;
  final Map<String, dynamic>? meta;
  final DateTime createdAt;
  final DateTime? readAt;
  
  CoachMessage({
    required this.id,
    required this.userId,
    required this.kind,
    required this.title,
    required this.body,
    this.meta,
    required this.createdAt,
    this.readAt,
  });
  
  factory CoachMessage.fromJson(Map<String, dynamic> json) {
    return CoachMessage(
      id: json['id'],
      userId: json['userId'],
      kind: CoachMessageKind.values.firstWhere(
        (e) => e.name == json['kind'],
        orElse: () => CoachMessageKind.nudge,
      ),
      title: json['title'],
      body: json['body'],
      meta: json['meta'],
      createdAt: DateTime.parse(json['createdAt']),
      readAt: json['readAt'] != null ? DateTime.parse(json['readAt']) : null,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'kind': kind.name,
      'title': title,
      'body': body,
      'meta': meta,
      'createdAt': createdAt.toIso8601String(),
      'readAt': readAt?.toIso8601String(),
    };
  }
}
