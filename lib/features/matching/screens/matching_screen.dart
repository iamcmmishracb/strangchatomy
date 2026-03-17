import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/session_service.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/services/ad_service.dart';

class MatchingScreen extends StatefulWidget {
  const MatchingScreen({super.key});
  @override
  State<MatchingScreen> createState() => _MatchingScreenState();
}

class _MatchingScreenState extends State<MatchingScreen> with TickerProviderStateMixin {
  late AnimationController _ringController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;
  Timer? _dotsTimer;
  Timer? _elapsedTimer;
  Timer? _counterTimer;
  int _dots = 1;
  int _elapsed = 0;
  int _liveCount = 0;
  bool _searching = true;
  bool _found = false;

  // Simulate a big live counter between 18,000 – 24,000
  static final _rnd = Random();
  static int _baseCount = 18000 + _rnd.nextInt(6000);

  @override
  void initState() {
    super.initState();
    _liveCount = _baseCount;

    _ringController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..forward();
    _fadeAnim = Tween(begin: 0.0, end: 1.0).animate(_fadeController);

    _dotsTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() => _dots = (_dots % 3) + 1);
    });
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed++);
    });
    // Fluctuate live count every 3s ±20
    _counterTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) setState(() => _liveCount += (_rnd.nextInt(41) - 20));
    });

    _startMatching();
    // Preload ads
    AdService().loadRewarded();
    AdService().loadInterstitial();
  }

  Future<void> _startMatching() async {
    try {
      final session = await SessionService().startMatching();
      if (!mounted) return;
      setState(() { _found = true; _searching = false; });
      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted) {
        context.go('/chat/${session.sessionId}',
            extra: {'partnerName': session.partnerName, 'partnerGender': session.partnerGender});
      }
    } catch (e) {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  void dispose() {
    _ringController.dispose();
    _fadeController.dispose();
    _dotsTimer?.cancel();
    _elapsedTimer?.cancel();
    _counterTimer?.cancel();
    super.dispose();
  }

  String _formatCount(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgGrad = isDark ? AppColors.backgroundGradient : AppColors.lightBackgroundGradient;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: bgGrad),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Live count badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.success.withOpacity(0.4)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(width: 7, height: 7, decoration: const BoxDecoration(color: AppColors.online, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text('${_formatCount(_liveCount)} chatting now', style: const TextStyle(color: AppColors.online, fontSize: 12, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                      TextButton.icon(
                        onPressed: () => context.go(AppRoutes.home),
                        icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 16),
                        label: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Animated rings
                SizedBox(
                  width: 220, height: 220,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _ringController,
                        builder: (_, __) => Transform.scale(
                          scale: 0.8 + _ringController.value * 0.4,
                          child: Container(
                            width: 200, height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: (_found ? AppColors.success : AppColors.primary).withOpacity((1 - _ringController.value) * 0.5), width: 2),
                            ),
                          ),
                        ),
                      ),
                      AnimatedBuilder(
                        animation: _ringController,
                        builder: (_, __) {
                          final v = (_ringController.value + 0.3) % 1.0;
                          return Transform.scale(
                            scale: 0.6 + v * 0.4,
                            child: Container(
                              width: 160, height: 160,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: (_found ? AppColors.success : AppColors.primary).withOpacity((1 - v) * 0.4), width: 2),
                              ),
                            ),
                          );
                        },
                      ),
                      Container(
                        width: 90, height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: _found ? [AppColors.success, const Color(0xFF16A34A)] : [AppColors.primary, const Color(0xFF0080FF)],
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                          ),
                          boxShadow: [BoxShadow(color: (_found ? AppColors.success : AppColors.primary).withOpacity(0.4), blurRadius: 24)],
                        ),
                        child: Icon(_found ? Icons.check_rounded : Icons.search_rounded, color: Colors.white, size: 38),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                if (_found) ...[
                  Text('Match Found! 🎉', style: Theme.of(context).textTheme.headlineLarge?.copyWith(color: AppColors.success)),
                  const SizedBox(height: 8),
                  Text('Connecting you now...', style: Theme.of(context).textTheme.bodyMedium),
                ] else if (_searching) ...[
                  Text('Finding you a match${'.' * _dots}', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Text('${_elapsed > 2 ? '${_elapsed}s' : 'Please wait...'}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
                ] else ...[
                  Text('Something went wrong', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () { setState(() { _searching = true; _elapsed = 0; }); _startMatching(); },
                    child: const Text('Try Again'),
                  ),
                ],

                const Spacer(),

                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('100% anonymous · No account needed', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
                ),
                // Rewarded ad — skip wait button
                if (_searching && AdService().isRewardedReady)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextButton.icon(
                      onPressed: () {
                        AdService().showRewarded(
                          onRewarded: (_) {},
                          onDismissed: () {},
                        );
                      },
                      icon: const Icon(Icons.play_circle_outline_rounded, size: 16, color: AppColors.primary),
                      label: const Text('Watch ad to support us', style: TextStyle(color: AppColors.primary, fontSize: 12)),
                    ),
                  ),
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
