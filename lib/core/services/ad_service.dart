import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  // ── SET TO false — using real Ad Unit IDs ────────────────────────────────
  static const bool _useTestIds = false;

  // ── REAL AD UNIT IDs ──────────────────────────────────────────────────────
  static const String _realBannerId              = 'ca-app-pub-1811629379218218/9003178736';
  static const String _realInterstitialId        = 'ca-app-pub-1811629379218218/2469559974';
  static const String _realRewardedId            = 'ca-app-pub-1811629379218218/6899759577';
  static const String _realRewardedSkipId        = 'ca-app-pub-1811629379218218/1316260403';
  static const String _realNativeId              = 'ca-app-pub-1811629379218218/8112403930';
  static const String _realRewardedInterstitialId= 'ca-app-pub-1811629379218218/6377015396';
  static const String _realAppOpenId             = 'ca-app-pub-1811629379218218/3644008442';

  // ── GOOGLE TEST IDs ───────────────────────────────────────────────────────
  static const String _testBannerId              = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testInterstitialId        = 'ca-app-pub-3940256099942544/1033173712';
  static const String _testRewardedId            = 'ca-app-pub-3940256099942544/5224354917';
  static const String _testNativeId              = 'ca-app-pub-3940256099942544/2247696110';
  static const String _testAppOpenId             = 'ca-app-pub-3940256099942544/9257395921';

  static String get bannerId        => _useTestIds ? _testBannerId       : _realBannerId;
  static String get interstitialId  => _useTestIds ? _testInterstitialId : _realInterstitialId;
  static String get rewardedId      => _useTestIds ? _testRewardedId     : _realRewardedId;
  static String get rewardedSkipId  => _useTestIds ? _testRewardedId     : _realRewardedSkipId;
  static String get nativeId        => _useTestIds ? _testNativeId       : _realNativeId;
  static String get appOpenId       => _useTestIds ? _testAppOpenId      : _realAppOpenId;

  // ── STATE ─────────────────────────────────────────────────────────────────
  InterstitialAd? _interstitialAd;
  RewardedAd?     _rewardedAd;
  RewardedAd?     _rewardedSkipAd;
  AppOpenAd?      _appOpenAd;
  bool _interstitialReady     = false;
  bool _rewardedReady         = false;
  bool _rewardedSkipReady     = false;
  bool _appOpenReady          = false;

  bool get isRewardedReady     => _rewardedReady && _rewardedAd != null;
  bool get isRewardedSkipReady => _rewardedSkipReady && _rewardedSkipAd != null;

  // ── APP OPEN AD ───────────────────────────────────────────────────────────
  void loadAppOpenAd() {
    if (kIsWeb) return;
    AppOpenAd.load(
      adUnitId: appOpenId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd = ad;
          _appOpenReady = true;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose(); _appOpenReady = false;
            },
            onAdFailedToShowFullScreenContent: (ad, _) {
              ad.dispose(); _appOpenReady = false;
            },
          );
        },
        onAdFailedToLoad: (_) => _appOpenReady = false,
      ),
    );
  }

  void showAppOpenAd() {
    if (kIsWeb || !_appOpenReady || _appOpenAd == null) return;
    _appOpenAd!.show();
  }

  // ── INTERSTITIAL ──────────────────────────────────────────────────────────
  void loadInterstitial() {
    if (kIsWeb) return;
    InterstitialAd.load(
      adUnitId: interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialReady = true;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose(); _interstitialReady = false; loadInterstitial();
            },
            onAdFailedToShowFullScreenContent: (ad, _) {
              ad.dispose(); _interstitialReady = false;
            },
          );
        },
        onAdFailedToLoad: (_) => _interstitialReady = false,
      ),
    );
  }

  void showInterstitial({VoidCallback? onDismissed}) {
    if (kIsWeb || !_interstitialReady || _interstitialAd == null) {
      onDismissed?.call(); return;
    }
    if (onDismissed != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose(); _interstitialReady = false; loadInterstitial(); onDismissed();
        },
        onAdFailedToShowFullScreenContent: (ad, _) {
          ad.dispose(); _interstitialReady = false; onDismissed();
        },
      );
    }
    _interstitialAd!.show();
  }

  // ── REWARDED (support us button) ─────────────────────────────────────────
  void loadRewarded() {
    if (kIsWeb) return;
    RewardedAd.load(
      adUnitId: rewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) { _rewardedAd = ad; _rewardedReady = true; },
        onAdFailedToLoad: (_) => _rewardedReady = false,
      ),
    );
  }

  void showRewarded({required Function(RewardItem) onRewarded, VoidCallback? onDismissed}) {
    if (kIsWeb || !isRewardedReady) { onDismissed?.call(); return; }
    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose(); _rewardedReady = false; loadRewarded(); onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose(); _rewardedReady = false; onDismissed?.call();
      },
    );
    _rewardedAd!.show(onUserEarnedReward: (_, r) => onRewarded(r));
  }

  // ── REWARDED SKIP (skip wait button) ─────────────────────────────────────
  void loadRewardedSkip() {
    if (kIsWeb) return;
    RewardedAd.load(
      adUnitId: rewardedSkipId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) { _rewardedSkipAd = ad; _rewardedSkipReady = true; },
        onAdFailedToLoad: (_) => _rewardedSkipReady = false,
      ),
    );
  }

  void showRewardedSkip({required Function(RewardItem) onRewarded, VoidCallback? onDismissed}) {
    if (kIsWeb || !isRewardedSkipReady) { onDismissed?.call(); return; }
    _rewardedSkipAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose(); _rewardedSkipReady = false; loadRewardedSkip(); onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose(); _rewardedSkipReady = false; onDismissed?.call();
      },
    );
    _rewardedSkipAd!.show(onUserEarnedReward: (_, r) => onRewarded(r));
  }

  void disposeAll() {
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    _rewardedSkipAd?.dispose();
    _appOpenAd?.dispose();
  }
}

// ── BANNER WIDGET ─────────────────────────────────────────────────────────────
class AdBannerWidget extends StatefulWidget {
  const AdBannerWidget({super.key});
  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  BannerAd? _banner;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) return;
    _banner = BannerAd(
      adUnitId: AdService.bannerId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) { if (mounted) setState(() => _loaded = true); },
        onAdFailedToLoad: (ad, _) => ad.dispose(),
      ),
    )..load();
  }

  @override
  void dispose() { _banner?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || !_loaded || _banner == null) return const SizedBox.shrink();
    return Container(
      alignment: Alignment.center,
      width: _banner!.size.width.toDouble(),
      height: _banner!.size.height.toDouble(),
      child: AdWidget(ad: _banner!),
    );
  }
}

// ── NATIVE AD CARD ────────────────────────────────────────────────────────────
class NativeAdCard extends StatefulWidget {
  const NativeAdCard({super.key});
  @override
  State<NativeAdCard> createState() => _NativeAdCardState();
}

class _NativeAdCardState extends State<NativeAdCard> {
  NativeAd? _native;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) return;
    _native = NativeAd(
      adUnitId: AdService.nativeId,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (_) { if (mounted) setState(() => _loaded = true); },
        onAdFailedToLoad: (ad, _) => ad.dispose(),
      ),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.small,
        mainBackgroundColor: const Color(0xFF1A1233),
        cornerRadius: 12,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: const Color(0xFFFFFFFF),
          backgroundColor: const Color(0xFF6C55F0),
          style: NativeTemplateFontStyle.bold,
          size: 13,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: const Color(0xFFFFFFFF),
          style: NativeTemplateFontStyle.bold,
          size: 14,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: const Color(0xFFAAAAAA),
          style: NativeTemplateFontStyle.normal,
          size: 12,
        ),
      ),
    )..load();
  }

  @override
  void dispose() { _native?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || !_loaded || _native == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(height: 90, child: AdWidget(ad: _native!)),
      ),
    );
  }
}
