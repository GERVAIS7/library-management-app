import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Wraps AdMob banner + interstitial logic. Follows the Day 12 rule:
/// a failure here must NEVER break the rest of the app.
///
/// IMPORTANT: google_mobile_ads only works on Android/iOS. Every method
/// here checks kIsWeb FIRST (before touching dart:io Platform, which
/// throws "Unsupported operation" on web) so this is safe to call from
/// a build that also runs in Chrome during development.
class AdService {
  // Google's official test ad unit IDs (safe to ship during development).
  static String get bannerAdUnitId {
    if (kIsWeb) return '';
    if (Platform.isAndroid) return 'ca-app-pub-3940256099942544/6300978111';
    return 'ca-app-pub-3940256099942544/2934735716'; // iOS test banner
  }

  static String get interstitialAdUnitId {
    if (kIsWeb) return '';
    if (Platform.isAndroid) return 'ca-app-pub-3940256099942544/1033173712';
    return 'ca-app-pub-3940256099942544/4411468910'; // iOS test interstitial
  }

  InterstitialAd? _interstitialAd;
  bool _isInterstitialReady = false;

  static Future<void> initialize() async {
    if (kIsWeb) return; // Ads are not supported on web; skip entirely.
    await MobileAds.instance.initialize();
  }

  /// Returns null on web (caller should skip rendering a banner there).
  BannerAd? createBannerAd({required void Function() onFailed}) {
    if (kIsWeb) return null;
    return BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdFailedToLoad: (ad, error) {
          // Graceful failure: dispose and let the caller hide/ignore it.
          ad.dispose();
          onFailed();
        },
      ),
    )..load();
  }

  /// Preloads an interstitial. Call this ahead of time (e.g. on screen init)
  /// so it's ready when a completed action (like creating a Loan) happens.
  /// No-op on web.
  void loadInterstitial() {
    if (kIsWeb) return;
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialReady = true;
        },
        onAdFailedToLoad: (error) {
          _isInterstitialReady = false;
          _interstitialAd = null;
          // Silently fail — the app continues without the ad.
        },
      ),
    );
  }

  /// Shows the interstitial if ready; otherwise does nothing (app flow
  /// continues uninterrupted). Always reloads the next one afterward.
  /// No-op on web.
  void showInterstitialIfReady() {
    if (kIsWeb) return;
    if (_isInterstitialReady && _interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _isInterstitialReady = false;
          loadInterstitial(); // preload the next one
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _isInterstitialReady = false;
          loadInterstitial();
        },
      );
      _interstitialAd!.show();
    } else {
      // Not ready — fail silently, try to warm up for next time.
      loadInterstitial();
    }
  }

  void dispose() {
    _interstitialAd?.dispose();
  }
}
