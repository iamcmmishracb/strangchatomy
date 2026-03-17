import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/session_service.dart';
import '../../../core/utils/app_utils.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/providers/theme_provider.dart';
import '../../info/screens/about_screen.dart';
import '../../../core/services/ad_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  Gender _selectedGender = Gender.preferNotToSay;
  bool _agreedToTerms = false;
  int _liveCount = 18000 + Random().nextInt(6000);
  Timer? _liveCountTimer;
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..forward();
    _liveCountTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) setState(() => _liveCount += (Random().nextInt(41) - 20));
    });
    _pulseAnimation = Tween(begin: 0.95, end: 1.05).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _fadeAnimation = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    _nameController.dispose();
    _liveCountTimer?.cancel();
    super.dispose();
  }

  void _startChat() {
    if (_formKey.currentState?.validate() != true) return;
    if (!_agreedToTerms) {
      AppUtils.showSnackBar(context, 'Please agree to the Terms & Privacy Policy to continue.', isError: true);
      return;
    }
    final user = UserModel.anonymous(userId: const Uuid().v4(), displayName: _nameController.text.trim(), gender: _selectedGender);
    SessionService().setCurrentUser(user);
    context.go(AppRoutes.matching);
  }

  bool get _isDark => context.watch<ThemeProvider>().isDark;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 600;
    final bgGrad = _isDark ? AppColors.backgroundGradient : AppColors.lightBackgroundGradient;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: bgGrad),
        child: Stack(
          children: [
            Positioned(top: -80, right: -80, child: _blob(300, AppColors.primary.withOpacity(0.06))),
            Positioned(bottom: -60, left: -60, child: _blob(250, AppColors.accent.withOpacity(0.05))),

            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: isWide ? size.width * 0.3 : 24, vertical: 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ScaleTransition(scale: _pulseAnimation, child: _buildLogo()),
                        const SizedBox(height: 10),
                        Text(
                          AppConstants.appName,
                          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                            foreground: Paint()..shader = const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]).createShader(const Rect.fromLTWH(0, 0, 200, 60)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(AppConstants.appTagline, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary)),
                        const SizedBox(height: 8),
                        // Live count badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.success.withOpacity(0.4)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(width: 7, height: 7, decoration: const BoxDecoration(color: AppColors.online, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Text('${(_liveCount / 1000).toStringAsFixed(1)}k people chatting right now', style: const TextStyle(color: AppColors.online, fontSize: 12, fontWeight: FontWeight.w600)),
                          ]),
                        ),

                        const SizedBox(height: 14),

                        // Form card
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: _isDark ? AppColors.surfaceCard : AppColors.lightSurfaceCard,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _isDark ? AppColors.border : AppColors.lightBorder),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(_isDark ? 0.3 : 0.08), blurRadius: 20, offset: const Offset(0, 8))],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Your Nickname', style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _nameController,
                                  maxLength: 50,
                                  decoration: const InputDecoration(hintText: 'Enter a display name...', prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.textMuted), counterText: ''),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return 'Please enter a nickname';
                                    if (v.trim().length < 2) return 'Must be at least 2 characters';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                Text('I am a...', style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: 8),
                                Row(children: [
                                  _genderChip(Gender.male, '👨', 'Male', AppColors.male),
                                  const SizedBox(width: 8),
                                  _genderChip(Gender.female, '👩', 'Female', AppColors.female),
                                  const SizedBox(width: 8),
                                  _genderChip(Gender.preferNotToSay, '🧑', 'Other', AppColors.other),
                                ]),
                                const SizedBox(height: 24),

                                // ── AGREEMENT BOX ──────────────────────────────
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: _isDark ? AppColors.surfaceElevated : AppColors.lightSurfaceElevated,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _agreedToTerms ? AppColors.primary.withOpacity(0.6) : (_isDark ? AppColors.border : AppColors.lightBorder),
                                      width: _agreedToTerms ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Before you start', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 13)),
                                      const SizedBox(height: 8),
                                      Text(
                                        '• You must be 18 years of age or older.\n'
                                        '• Do not share personal information.\n'
                                        '• Harassment, abuse, or inappropriate content is not tolerated.\n'
                                        '• Chats are anonymous and not stored.',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.6),
                                      ),
                                      const SizedBox(height: 12),
                                      GestureDetector(
                                        onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
                                        child: Row(
                                          children: [
                                            AnimatedContainer(
                                              duration: const Duration(milliseconds: 200),
                                              width: 22, height: 22,
                                              decoration: BoxDecoration(
                                                color: _agreedToTerms ? AppColors.primary : Colors.transparent,
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: _agreedToTerms ? AppColors.primary : AppColors.textMuted, width: 1.5),
                                              ),
                                              child: _agreedToTerms ? const Icon(Icons.check_rounded, size: 14, color: Color(0xFF001A18)) : null,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: RichText(
                                                text: TextSpan(
                                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4),
                                                  children: [
                                                    const TextSpan(text: 'I agree to the '),
                                                    WidgetSpan(child: GestureDetector(onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TermsOfUseScreen())), child: const Text('Terms of Use', style: TextStyle(color: AppColors.primary, fontSize: 12)))),
                                                    const TextSpan(text: ' and '),
                                                    WidgetSpan(child: GestureDetector(onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())), child: const Text('Privacy Policy', style: TextStyle(color: AppColors.primary, fontSize: 12)))),
                                                    const TextSpan(text: '. I confirm I am 18+.'),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 20),
                                GradientButton(
                                  label: 'Start Chat',
                                  onPressed: _startChat,
                                  icon: const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),
                        TextButton(onPressed: () => context.go(AppRoutes.dashboard), child: const Text('Profile & Settings')),
                        const SizedBox(height: 8),
                        const AdBannerWidget(),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Top web nav
            if (isWide)
              Positioned(
                top: 0, left: 0, right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                          const Icon(Icons.chat_bubble_rounded, color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(AppConstants.appName, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.primary)),
                        ]),
                        Row(children: [
                          TextButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BlogScreen())), child: const Text('Blog')),
                          TextButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FAQScreen())), child: const Text('FAQ')),
                          TextButton(onPressed: () => context.go(AppRoutes.dashboard), child: const Text('Settings')),
                        ]),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() => Container(
    width: 80, height: 80,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF0080FF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 24)],
    ),
    child: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 36),
  );

  Widget _blob(double size, Color color) => Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color));

  Widget _genderChip(Gender gender, String emoji, String label, Color color) {
    final isSelected = _selectedGender == gender;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedGender = gender),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.15) : (_isDark ? AppColors.surfaceElevated : AppColors.lightSurfaceElevated),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? color : (_isDark ? AppColors.border : AppColors.lightBorder), width: isSelected ? 1.5 : 1),
          ),
          child: Column(children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, color: isSelected ? color : AppColors.textMuted, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400)),
          ]),
        ),
      ),
    );
  }
}
