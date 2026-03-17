import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'app.dart';
import 'core/services/ad_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    await MobileAds.instance.initialize();
    // Preload App Open ad for next app launch
    AdService().loadAppOpenAd();
    // Preload interstitial ready for after first chat
    AdService().loadInterstitial();
    // Preload rewarded ads
    AdService().loadRewarded();
    AdService().loadRewardedSkip();
    // Show app open ad on launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AdService().showAppOpenAd();
    });
  }
  runApp(const StrangchatomyApp());
}
