import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/utils/app_utils.dart';
import '../../../core/services/ad_service.dart';

class PostChatScreen extends StatefulWidget {
  final Map<String, dynamic>? sessionData;
  const PostChatScreen({super.key, this.sessionData});

  @override
  State<PostChatScreen> createState() => _PostChatScreenState();
}

class _PostChatScreenState extends State<PostChatScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _scaleAnim = CurvedAnimation(parent: _animController, curve: Curves.elasticOut);
    _animController.forward();
    // Show interstitial ad when chat ends
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AdService().showInterstitial();
    });
  }

  @override
  void dispose() { _animController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgGrad = isDark ? AppColors.backgroundGradient : AppColors.lightBackgroundGradient;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: bgGrad),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _scaleAnim,
                  child: Container(
                    width: 90, height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [AppColors.primary.withOpacity(0.2), AppColors.primary.withOpacity(0.05)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      border: Border.all(color: AppColors.primary.withOpacity(0.4), width: 2),
                    ),
                    child: const Icon(Icons.chat_bubble_rounded, color: AppColors.primary, size: 40),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Chat Ended', style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 10),
                Text(
                  'This conversation has been permanently deleted.\nStrangchatomy never stores your chats.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 28),

                // Privacy notice
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Your anonymity is protected. No data about this chat was stored.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, height: 1.5))),
                  ]),
                ),

                const SizedBox(height: 40),

                GradientButton(
                  label: 'Find New Chat',
                  onPressed: () => context.go(AppRoutes.matching),
                  icon: const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(height: 12),
                TextButton(onPressed: () => context.go(AppRoutes.home), child: const Text('Go Home')),
                const SizedBox(height: 16),
                const AdBannerWidget(),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
