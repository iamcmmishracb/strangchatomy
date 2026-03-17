import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/session_service.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/app_utils.dart';
import '../../../core/routes/app_router.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_input_bar.dart';
import '../../../core/services/ad_service.dart';

// ── Report reason mapping ─────────────────────────────────────────────────────
// UI label  →  backend enum value (must match routes/sessions.js validReasons)
const _reportReasons = {
  'Harassment / Abuse':    'harassment',
  'Inappropriate Content': 'inappropriate_content',
  'Spam / Bot':            'spam',
  'Underage User':         'underage',
  'Hate Speech':           'hate_speech',
  'Threat':                'threat',
  'Other':                 'other',
};

class ChatScreen extends StatefulWidget {
  final String sessionId;
  final String partnerName;
  final Gender? partnerGender;

  const ChatScreen({
    super.key,
    required this.sessionId,
    required this.partnerName,
    this.partnerGender,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final _scrollController = ScrollController();
  final _service          = SessionService();
  final _apiService       = ApiService();
  final List<MessageModel> _messages = [];

  StreamSubscription? _messageSub;
  StreamSubscription? _typingSub;
  StreamSubscription? _sessionSub;

  bool _isPartnerTyping = false;
  int  _sessionSeconds  = 0;
  Timer? _timer;
  bool _chatEnded = false;
  late AnimationController _typingController;

  // Live count display
  static final _rnd = Random();
  int    _liveCount     = 18000 + _rnd.nextInt(6000);
  Timer? _liveCountTimer;

  // Report state
  bool _isSubmittingReport = false;

  @override
  void initState() {
    super.initState();
    _typingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _sessionSub = _service.sessionStream.listen((session) {
      if (session == null && !_chatEnded) {
        if (mounted) setState(() => _chatEnded = true);
      }
    });

    _messageSub = _service.messageStream.listen((msg) {
      setState(() {
        final idx = _messages.indexWhere((m) => m.messageId == msg.messageId);
        if (idx != -1) _messages[idx] = msg;
        else           _messages.add(msg);
      });
      _scrollToBottom();
    });

    _typingSub = _service.typingStream.listen((isTyping) {
      setState(() => _isPartnerTyping = isTyping);
      if (isTyping) _scrollToBottom();
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _sessionSeconds++);
    });

    _liveCountTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) setState(() => _liveCount += (_rnd.nextInt(41) - 20));
    });
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _typingSub?.cancel();
    _sessionSub?.cancel();
    _timer?.cancel();
    _liveCountTimer?.cancel();
    _scrollController.dispose();
    _typingController.dispose();
    super.dispose();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

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

  void _sendMessage(String content) {
    if (content.trim().isEmpty) return;
    if (!_service.isChatEnabled) {
      AppUtils.showSnackBar(context, 'Chat has ended. Cannot send messages.');
      return;
    }
    _service.sendMessage(content.trim());
    _scrollToBottom();
  }

  void _endChat() {
    _service.disconnect().then((_) {
      if (mounted) setState(() => _chatEnded = true);
    });
  }

  void _startNewChat() => context.go(AppRoutes.matching);

  // ── Report flow ───────────────────────────────────────────────────────────

  void _reportUser() {
    String? _selectedReason; // UI label selected by user
    final _commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Header ──────────────────────────────────────────────────
                Text('Report User',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(
                  'Your report is anonymous and reviewed by our team within 24 hours.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),

                // ── Step 1: choose reason ────────────────────────────────────
                if (_selectedReason == null) ...[
                  ..._reportReasons.keys.map((label) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.flag_outlined,
                        color: AppColors.error, size: 18),
                    title: Text(label,
                        style: Theme.of(context).textTheme.bodyLarge),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textMuted, size: 18),
                    onTap: () => setModal(() => _selectedReason = label),
                  )),
                ]

                // ── Step 2: optional description + submit ────────────────────
                else ...[
                  Row(children: [
                    GestureDetector(
                      onTap: () => setModal(() => _selectedReason = null),
                      child: const Icon(Icons.arrow_back_rounded,
                          color: AppColors.textSecondary, size: 20),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedReason!,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: AppColors.error),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  Text('Add details (optional)',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _commentController,
                    maxLines: 4,
                    maxLength: 500,
                    decoration: const InputDecoration(
                        hintText: 'Describe what happened...'),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isSubmittingReport
                          ? null
                          : () => _submitReport(
                                ctx: ctx,
                                uiLabel: _selectedReason!,
                                description: _commentController.text.trim(),
                              ),
                      child: _isSubmittingReport
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Submit Report'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Called when user taps Submit in the report sheet.
  /// Calls POST /api/sessions/report which:
  ///   1. Creates a Report record in MongoDB
  ///   2. Flags the Session (prevents TTL auto-deletion)
  ///   3. Marks all Messages as retainedForCompliance
  Future<void> _submitReport({
    required BuildContext ctx,
    required String uiLabel,
    required String description,
  }) async {
    // Map the UI label to the backend enum value
    final backendReason = _reportReasons[uiLabel] ?? 'other';

    // Get the reported user's ID from the current session
    final currentSession = _service.currentSession;
    final reportedUserId = currentSession?.user2Id;

    if (reportedUserId == null || reportedUserId.isEmpty) {
      Navigator.pop(ctx);
      AppUtils.showSnackBar(
        context,
        'Could not identify user to report. Please try again.',
        isError: true,
      );
      return;
    }

    setState(() => _isSubmittingReport = true);

    try {
      await _apiService.reportUser(
        reportedUserId: reportedUserId,
        sessionId:      widget.sessionId,
        reason:         backendReason,
        description:    description.isNotEmpty ? description : null,
      );

      if (mounted) Navigator.pop(ctx);
      if (mounted) {
        AppUtils.showSnackBar(
          context,
          'Report submitted. Our team will review it within 24 hours. Thank you for keeping Strangchatomy safe.',
        );
      }
    } on ApiException catch (e) {
      if (mounted) Navigator.pop(ctx);
      if (mounted) {
        AppUtils.showSnackBar(
          context,
          'Failed to submit report: ${e.message}',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmittingReport = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          if (_isPartnerTyping) _buildTypingIndicator(),
          if (_chatEnded)       _buildDisconnectBanner(),
          ChatInputBar(
            sessionService:  _service,
            onSend:          _sendMessage,
            onEndChat:       _endChat,
            onStartNewChat:  _startNewChat,
            chatEnded:       _chatEnded,
            partnerName:     widget.partnerName,
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      leadingWidth: 56,
      leading: IconButton(
        onPressed: () => context.go(AppRoutes.home),
        icon: const Icon(Icons.home_outlined),
      ),
      title: Row(children: [
        AvatarWidget(
          name:   widget.partnerName,
          gender: widget.partnerGender,
          size:   36,
          fontSize: 14,
        ),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.partnerName,
              style: Theme.of(context).textTheme.titleMedium),
          Row(children: [
            Container(
              width: 6, height: 6,
              decoration: BoxDecoration(
                color: _chatEnded ? AppColors.error : AppColors.online,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              _chatEnded ? 'Disconnected' : 'Online',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _chatEnded ? AppColors.error : AppColors.online,
                fontSize: 11,
              ),
            ),
          ]),
        ]),
      ]),
      actions: [
        // Live user count badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.success.withOpacity(0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 5, height: 5,
              decoration: const BoxDecoration(
                  color: AppColors.online, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(
              '${(_liveCount / 1000).toStringAsFixed(1)}k',
              style: const TextStyle(
                  color: AppColors.online,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ]),
        ),
        // Report / options menu
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded),
          color: Theme.of(context).cardColor,
          onSelected: (v) { if (v == 'report') _reportUser(); },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'report',
              child: Row(children: [
                const Icon(Icons.flag_outlined,
                    color: AppColors.error, size: 18),
                const SizedBox(width: 8),
                Text('Report User',
                    style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color)),
              ]),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMessageList() {
    if (_messages.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.chat_bubble_outline_rounded,
              color: AppColors.textMuted, size: 48),
          const SizedBox(height: 12),
          Text('Connected! Say hello 👋',
              style: Theme.of(context).textTheme.bodyMedium),
        ]),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (_, i) {
        final msg = _messages[i];
        final showTimestamp = i == 0 ||
            _messages[i]
                .sentAt
                .difference(_messages[i - 1].sentAt)
                .inMinutes > 5;
        // Show native ad card every 8 messages
        if (i > 0 && i % 8 == 0) {
          return Column(
            children: [
              const NativeAdCard(),
              MessageBubble(message: msg, showTimestamp: showTimestamp),
            ],
          );
        }
        return MessageBubble(message: msg, showTimestamp: showTimestamp);
      },
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 4),
      child: Row(children: [
        AvatarWidget(
          name:     widget.partnerName,
          gender:   widget.partnerGender,
          size:     24,
          fontSize: 10,
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) => AnimatedBuilder(
              animation: _typingController,
              builder: (_, __) {
                final val = (_typingController.value + i * 0.33) % 1.0;
                return Container(
                  margin: EdgeInsets.only(right: i < 2 ? 3 : 0),
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.textMuted.withOpacity(0.4 + val * 0.6),
                  ),
                );
              },
            )),
          ),
        ),
      ]),
    );
  }

  Widget _buildDisconnectBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.1),
        border: Border(top: BorderSide(color: AppColors.error.withOpacity(0.3))),
      ),
      child: Row(children: [
        Icon(Icons.close_rounded, color: AppColors.error, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              '${widget.partnerName} has disconnected',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.error, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'This conversation has ended',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ]),
        ),
      ]),
    );
  }
}
