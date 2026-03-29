import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/violation.dart';
import 'sergeant_service.dart';

/// Generates drill sergeant messages via GPT-4 mini and speaks them via ElevenLabs
class SergeantVoiceService {
  static final AudioPlayer _audioPlayer = AudioPlayer();

  // API keys - set these from settings or environment
  static String? _openAiKey;
  static String? _elevenLabsKey;
  static String? _elevenLabsVoiceId;

  static void configure({
    required String openAiKey,
    required String elevenLabsKey,
    required String elevenLabsVoiceId,
  }) {
    _openAiKey = openAiKey;
    _elevenLabsKey = elevenLabsKey;
    _elevenLabsVoiceId = elevenLabsVoiceId;
  }

  static bool get isConfigured =>
      _openAiKey != null && _elevenLabsKey != null && _elevenLabsVoiceId != null;

  // ==================== GPT-4 MINI MESSAGE GENERATION ====================

  /// Generate a personalized drill sergeant message for a violation
  static Future<String> generateMessage(Violation violation) async {
    if (_openAiKey == null) {
      return _getFallbackMessage(violation);
    }

    try {
      final prompt = SergeantService.buildSergeantPrompt(violation);

      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_openAiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'messages': [
            {
              'role': 'system',
              'content': 'You are a tough but motivating drill sergeant. Keep responses under 3 sentences. Be intense and direct.',
            },
            {'role': 'user', 'content': prompt},
          ],
          'max_tokens': 150,
          'temperature': 0.8,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final message = data['choices'][0]['message']['content'] as String;
        debugPrint('AI Sergeant says: $message');
        return message.trim();
      } else {
        debugPrint('GPT-4 mini error: ${response.statusCode} ${response.body}');
        return _getFallbackMessage(violation);
      }
    } catch (e) {
      debugPrint('GPT-4 mini error: $e');
      return _getFallbackMessage(violation);
    }
  }

  // ==================== ELEVENLABS TEXT-TO-SPEECH ====================

  /// Convert text to speech using ElevenLabs and play it
  static Future<void> speakMessage(String message) async {
    if (_elevenLabsKey == null || _elevenLabsVoiceId == null) {
      debugPrint('ElevenLabs not configured, skipping voice');
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('https://api.elevenlabs.io/v1/text-to-speech/$_elevenLabsVoiceId'),
        headers: {
          'Content-Type': 'application/json',
          'xi-api-key': _elevenLabsKey!,
        },
        body: jsonEncode({
          'text': message,
          'model_id': 'eleven_monolingual_v1',
          'voice_settings': {
            'stability': 0.3,       // Lower = more intense/varied
            'similarity_boost': 0.8,
            'style': 0.7,           // High style for expressiveness
            'use_speaker_boost': true,
          },
        }),
      );

      if (response.statusCode == 200) {
        // Save audio to temp file and play
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/sergeant_${DateTime.now().millisecondsSinceEpoch}.mp3');
        await file.writeAsBytes(response.bodyBytes);

        await _audioPlayer.play(DeviceFileSource(file.path));
        debugPrint('Playing sergeant voice message');
      } else {
        debugPrint('ElevenLabs error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('ElevenLabs TTS error: $e');
    }
  }

  /// Generate message AND speak it
  static Future<String> generateAndSpeak(Violation violation) async {
    final message = await generateMessage(violation);
    await speakMessage(message);
    return message;
  }

  /// Stop any currently playing audio
  static Future<void> stop() async {
    await _audioPlayer.stop();
  }

  // ==================== FALLBACK MESSAGES ====================

  static String _getFallbackMessage(Violation violation) {
    final level = violation.escalationLevel;
    final habit = violation.habitTitle;
    final offense = violation.offenseNumber;

    if (level == 1) {
      return 'You missed "$habit". That\'s strike one. Get in here and earn it back with some exercises, soldier.';
    } else if (level == 2) {
      return 'AGAIN with "$habit"?! That\'s offense number $offense! You think this is a game?! Drop and give me everything!';
    } else {
      return '$offense TIMES you\'ve failed on "$habit"! UNACCEPTABLE! You are doing EVERY SINGLE REP and you will NOT complain! MOVE IT!';
    }
  }
}
