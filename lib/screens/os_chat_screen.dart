import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../design/tokens.dart';
import '../services/api_client.dart';
import '../services/messages_service.dart';
import '../services/premium_service.dart';
import '../models/coach_message.dart' as model;
import '../widgets/paywall_dialog.dart';
import '../widgets/premium_paywall_screen.dart';

/// Unified message type for timeline (OS messages + chat)
class TimelineMessage {
  final String id;
  final String type; // 'os_brief', 'os_nudge', 'os_debrief', 'os_letter', 'user', 'ai'
  final String text;
  final DateTime timestamp;
  final bool isRead;
  final model.MessageKind? osKind;

  TimelineMessage({
    required this.id,
    required this.type,
    required this.text,
    required this.timestamp,
    this.isRead = true,
    this.osKind,
  });
}

class OSChatScreen extends ConsumerStatefulWidget {
  const OSChatScreen({super.key});

  @override
  ConsumerState<OSChatScreen> createState() => _OSChatScreenState();
}

class _OSChatScreenState extends ConsumerState<OSChatScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final MessagesService _messagesService = MessagesService();
  
  List<TimelineMessage> _timeline = [];
  bool _isLoading = false;
  bool _initialized = false;
  String _currentPhase = 'Observer'; // Default phase
  
  

  @override
  void initState() {
    super.initState();
    _initializeMessages();
    // ✅ Ensure scroll starts at top (show full header)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  

  Future<void> _initializeMessages() async {
    try {
      debugPrint('🔄 Initializing OS Chat...');
      await _messagesService.init();
      debugPrint('✅ Messages service initialized');
      
      await _loadTimeline();
      debugPrint('✅ Timeline loaded: ${_timeline.length} messages');
      
      setState(() => _initialized = true);
      // Don't auto-scroll on init - let header stay visible
      debugPrint('✅ OS Chat initialized successfully');
    } catch (e) {
      debugPrint('❌ Failed to initialize OS Chat: $e');
      setState(() => _initialized = true); // Still mark as initialized to show UI
    }
  }

  Future<void> _loadTimeline() async {
    // Load OS messages (briefs, nudges, debriefs, letters)
    // ✅ FILTER: Only show UNREAD messages in chat
    final osMessages = _messagesService.getAllMessages().where((msg) => !msg.isRead).toList();
    
    // Convert OS messages to timeline messages
    final timelineFromOS = osMessages.map((msg) {
      String type;
      switch (msg.kind) {
        case model.MessageKind.brief:
          type = 'os_brief';
          break;
        case model.MessageKind.nudge:
          type = 'os_nudge';
          break;
        case model.MessageKind.debrief:
        case model.MessageKind.mirror:
          type = 'os_debrief';
          break;
        case model.MessageKind.letter:
          type = 'os_letter';
          break;
        default:
          type = 'os_message';
      }
      
      return TimelineMessage(
        id: msg.id,
        type: type,
        text: '${msg.title}\n\n${msg.body}',
        timestamp: msg.createdAt,
        isRead: msg.isRead,
        osKind: msg.kind,
      );
    }).toList();

    // Merge and sort by timestamp (newest first for display, but we'll reverse for chat UI)
    _timeline = [...timelineFromOS];
    _timeline.sort((a, b) => a.timestamp.compareTo(b.timestamp)); // Oldest first (chat style)
    
    setState(() {});
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isLoading) return;

    // 🔒 PAYWALL: Let backend handle premium check, show paywall on 402 error
    // Removed frontend premium check - backend will return 402 if not premium

    // Add user message to timeline
    final userMessage = TimelineMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: 'user',
      text: text,
      timestamp: DateTime.now(),
    );

    setState(() {
      _timeline.add(userMessage);
      _isLoading = true;
    });

    _inputController.clear();
    _scrollToBottom();

    try {
      // Send to AI OS chat endpoint
      final response = await ApiClient.sendChatMessageV2(text);

      if (response.success && response.data != null) {
        final aiText = response.data!['message'] as String? ?? 'No response';
        final phase = response.data!['phase'] as String?;
        
        if (phase != null) {
          setState(() {
            _currentPhase = phase.substring(0, 1).toUpperCase() + phase.substring(1);
          });
        }

        final aiMessage = TimelineMessage(
          id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
          type: 'ai',
          text: aiText,
          timestamp: DateTime.now(),
        );

        setState(() {
          _timeline.add(aiMessage);
          _isLoading = false;
        });

        _scrollToBottom();
      } else {
        // Check if it's a paywall error
        if (response.error?.contains('Premium') == true || response.error?.contains('premium') == true) {
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => const PaywallDialog(feature: 'AI Chat'),
            );
          }
        } else {
          throw Exception(response.error ?? 'Unknown error');
        }
        
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        // Check if it's a premium error in the exception message
        if (e.toString().toLowerCase().contains('premium')) {
          Navigator.of(context).push(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (context) => const PremiumPaywallScreen(feature: 'AI Chat'),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to send message: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
      setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: Colors.black, // ✅ Pure black like other premium screens
      resizeToAvoidBottomInset: false,
      body: !_initialized
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.emerald),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Initializing OS...',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                // Content - stays fixed, doesn't move with keyboard
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  bottom: 220, // Fixed space for input + bottom nav
                  child: CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      // Header
                      _buildHeader(),
                      
                      
                      // Timeline messages or welcome message
                      _timeline.isEmpty 
                        ? SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.xl),
                              child: Center(
                                child: Column(
                                  children: [
                                    const SizedBox(height: AppSpacing.xxl),
                                    // ✅ Cinematic empty state with glow - BRAIN LOGO
                                    Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        gradient: AppColors.emeraldGradient,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.emerald.withOpacity(0.5),
                                            blurRadius: 40,
                                            spreadRadius: 10,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        LucideIcons.brain,
                                        size: 40,
                                        color: Colors.white,
                                      ),
                                    )
                                        .animate(onPlay: (controller) => controller.repeat(reverse: true))
                                        .scale(
                                          begin: const Offset(1.0, 1.0),
                                          end: const Offset(1.1, 1.1),
                                          duration: 2000.ms,
                                        )
                                        .then()
                                        .shimmer(duration: 1500.ms),
                                    const SizedBox(height: AppSpacing.xl),
                                    ShaderMask(
                                      shaderCallback: (bounds) => AppColors.emeraldGradient.createShader(bounds),
                                      child: Text(
                                        'Your OS is Online',
                                        style: AppTextStyles.h2.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                    Text(
                                      'I watch your patterns. I keep you accountable.\nI remember everything. Let\'s talk.',
                                      style: AppTextStyles.body.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: AppSpacing.xl),
                                    // ✅ Suggested prompts
                                    Wrap(
                                      spacing: AppSpacing.sm,
                                      runSpacing: AppSpacing.sm,
                                      alignment: WrapAlignment.center,
                                      children: [
                                        _buildSuggestionChip('Why did I skip today?'),
                                        _buildSuggestionChip('What\'s my biggest pattern?'),
                                        _buildSuggestionChip('Am I making progress?'),
                                        _buildSuggestionChip('What should I focus on?'),
                                      ],
                                    ),
                                    const SizedBox(height: AppSpacing.xxl),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : SliverPadding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final message = _timeline[index];
                                  return _buildTimelineMessage(message);
                                },
                                childCount: _timeline.length,
                              ),
                            ),
                          ),

                      // ✅ Cinematic loading indicator
                      if (_isLoading)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: AppSpacing.sm,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.emerald.withOpacity(0.15),
                                        AppColors.emerald.withOpacity(0.05),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                                    border: Border.all(
                                      color: AppColors.emerald.withOpacity(0.4),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.emerald.withOpacity(0.2),
                                        blurRadius: 16,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.emerald),
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      Text(
                                        'OS processing...',
                                        style: AppTextStyles.body.copyWith(
                                          color: AppColors.emerald,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                    .animate(onPlay: (controller) => controller.repeat())
                                    .shimmer(duration: 1500.ms, color: AppColors.emerald.withOpacity(0.3)),
                              ],
                            ),
                          ),
                        ),

                      // Flexible filler to prevent grey space when scrolling
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Container(
                          color: Colors.black, // Match background
                          child: const SizedBox(height: 200), // Minimum height
                        ),
                      ),
                    ],
                  ),
                ),

                // Input area - ONLY this rises with keyboard
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: keyboardHeight > 0 ? keyboardHeight : 100, // Sits ON TOP of keyboard when open, above nav when closed
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      border: Border(
                        top: BorderSide(color: AppColors.emerald.withOpacity(0.3)),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.emerald.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.glassBackground,
                              borderRadius: BorderRadius.circular(AppBorderRadius.xl),
                              border: Border.all(
                                color: AppColors.emerald.withOpacity(0.2),
                              ),
                            ),
                            child: TextField(
                              controller: _inputController,
                              style: AppTextStyles.body,
                              maxLines: null,
                              decoration: InputDecoration(
                                hintText: 'Message your OS...',
                                hintStyle: AppTextStyles.body.copyWith(
                                  color: AppColors.textQuaternary,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.md,
                                ),
                              ),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        
                        // 📤 SEND BUTTON - Animated pulse
                        GestureDetector(
                          onTap: _sendMessage,
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: AppColors.emeraldGradient,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.emerald.withOpacity(0.5),
                                  blurRadius: 20,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              LucideIcons.send,
                              color: Colors.white,
                              size: 20,
                            ),
                          )
                              .animate(onPlay: (controller) => controller.repeat(reverse: true))
                              .shimmer(duration: 2000.ms, color: Colors.white.withOpacity(0.3)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    return SliverAppBar(
      expandedHeight: 140,
      floating: true,
      snap: false,
      pinned: false, // ✅ Header stays visible, only disappears when user scrolls
      backgroundColor: Colors.black,
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xl + 30, // ✅ Reduced from 40 to 30 (push up 10px)
            AppSpacing.lg,
            AppSpacing.lg, // ✅ Increased from md to lg for more bottom space
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black,
                AppColors.emerald.withOpacity(0.03),
              ],
            ),
            border: Border(
              bottom: BorderSide(
                color: AppColors.emerald.withOpacity(0.3),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              // ✅ Animated breathing brain icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: AppColors.emeraldGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.emerald.withOpacity(0.6),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  LucideIcons.brain,
                  color: Colors.white,
                  size: 28,
                ),
              )
                  .animate(onPlay: (controller) => controller.repeat(reverse: true))
                  .scale(
                    begin: const Offset(1.0, 1.0),
                    end: const Offset(1.08, 1.08),
                    duration: 2000.ms,
                    curve: Curves.easeInOut,
                  )
                  .then()
                  .shimmer(duration: 1500.ms, color: Colors.white.withOpacity(0.2)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center, // ✅ Center vertically for better layout
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => AppColors.emeraldGradient.createShader(bounds),
                      child: Text(
                        'AI OPERATING SYSTEM',
                        style: AppTextStyles.h3.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8), // ✅ Increased from 6 to 8 for better spacing
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: AppColors.emeraldGradient,
                            borderRadius: BorderRadius.circular(AppBorderRadius.sm),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.emerald.withOpacity(0.3),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Text(
                            _currentPhase.toUpperCase(),
                            style: AppTextStyles.captionSmall.copyWith(
                              color: Colors.black,
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: AppColors.emerald,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.emerald,
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        )
                            .animate(onPlay: (controller) => controller.repeat())
                            .fadeOut(duration: 1000.ms)
                            .then()
                            .fadeIn(duration: 1000.ms),
                        const SizedBox(width: 6),
                        Text(
                          'ACTIVE',
                          style: AppTextStyles.captionSmall.copyWith(
                            color: AppColors.emerald,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineMessage(TimelineMessage message) {
    // Handle different message types
    switch (message.type) {
      case 'os_brief':
        return _buildOSMessage(
          message: message,
          icon: LucideIcons.sunrise,
          color: const Color(0xFFFFB020), // Orange for morning
          label: 'MORNING BRIEF',
        );
      case 'os_nudge':
        return _buildOSMessage(
          message: message,
          icon: LucideIcons.alertCircle,
          color: const Color(0xFFEF4444), // Red for nudge
          label: 'NUDGE',
        );
      case 'os_debrief':
        return _buildOSMessage(
          message: message,
          icon: LucideIcons.moon,
          color: const Color(0xFF8B5CF6), // Purple for evening
          label: 'EVENING DEBRIEF',
        );
      case 'os_letter':
        return _buildOSMessage(
          message: message,
          icon: LucideIcons.mail,
          color: const Color(0xFF06B6D4), // Cyan for letter
          label: 'WEEKLY LETTER',
        );
      case 'user':
        return _buildUserMessage(message);
      case 'ai':
        return _buildAIMessage(message);
      default:
        return _buildAIMessage(message);
    }
  }

  Widget _buildOSMessage({
    required TimelineMessage message,
    required IconData icon,
    required Color color,
    required String label,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.glassBackground,
          borderRadius: BorderRadius.circular(AppBorderRadius.xl),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppBorderRadius.xl - 2),
                  topRight: Radius.circular(AppBorderRadius.xl - 2),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(AppBorderRadius.md),
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    label,
                    style: AppTextStyles.captionSmall.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatTime(message.timestamp),
                    style: AppTextStyles.captionSmall.copyWith(
                      color: AppColors.textQuaternary,
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: SelectableText(
                message.text,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textPrimary,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0),
    );
  }

  Widget _buildUserMessage(TimelineMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                gradient: AppColors.emeraldGradient,
                borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                border: Border.all(
                  color: AppColors.emerald.withOpacity(0.3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.emerald.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SelectableText(
                message.text,
                style: AppTextStyles.body.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.1, end: 0),
          ),
        ],
      ),
    );
  }

  Widget _buildAIMessage(TimelineMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.glassBackground,
                    AppColors.emerald.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                border: Border.all(
                  color: AppColors.emerald.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.emerald.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    message.text,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: message.text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Copied!'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        icon: Icon(
                          LucideIcons.copy,
                          size: 14,
                          color: AppColors.emerald.withOpacity(0.6),
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1, end: 0),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return GestureDetector(
      onTap: () {
        _inputController.text = text;
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.emerald.withOpacity(0.1),
              AppColors.emerald.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(AppBorderRadius.full),
          border: Border.all(
            color: AppColors.emerald.withOpacity(0.3),
          ),
        ),
        child: Text(
          text,
          style: AppTextStyles.captionSmall.copyWith(
            color: AppColors.emerald,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ).animate().fadeIn(delay: 200.ms).scale(begin: const Offset(0.8, 0.8));
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}';
    }
  }
}

