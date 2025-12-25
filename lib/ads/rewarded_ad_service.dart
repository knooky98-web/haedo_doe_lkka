import 'dart:developer' as dev;
import 'package:google_mobile_ads/google_mobile_ads.dart';

class RewardedAdService {
  RewardedAd? _ad;
  bool get isLoaded => _ad != null;

  static const String testUnitId = 'ca-app-pub-3940256099942544/5224354917';

  void load({String adUnitId = testUnitId}) {
    dev.log('🚀 load() CALLED unit=$adUnitId', name: 'ADS');

    RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          dev.log('✅ LOADED', name: 'ADS');
          _ad = ad;
          _ad!.setImmersiveMode(true);
        },
        onAdFailedToLoad: (err) {
          dev.log('❌ FAILED_TO_LOAD: ${err.code} - ${err.message}', name: 'ADS');
          _ad = null;
        },
      ),
    );
  }

  Future<void> show({
    required Future<void> Function() onRewarded,
    void Function()? onClosed,
    void Function()? onFailed,
  }) async {
    dev.log('🎬 show() called. isLoaded=$isLoaded', name: 'ADS');

    final ad = _ad;
    if (ad == null) {
      dev.log('⚠️ show() but ad is null', name: 'ADS');
      onFailed?.call();
      return;
    }

    bool rewarded = false; // ✅ 보상 받았는지 플래그

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        dev.log('🟢 onAdShowedFullScreenContent', name: 'ADS');
      },
      onAdImpression: (ad) {
        dev.log('👀 onAdImpression', name: 'ADS');
      },
      onAdClicked: (ad) {
        dev.log('🖱️ onAdClicked', name: 'ADS');
      },
      onAdDismissedFullScreenContent: (ad) {
        dev.log('🟥 onAdDismissedFullScreenContent rewarded=$rewarded', name: 'ADS');
        ad.dispose();
        _ad = null;

        // ✅ 다음을 위해 항상 재로드(안정성)
        load();

        onClosed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        dev.log('❌ FAILED_TO_SHOW: ${err.code} - ${err.message}', name: 'ADS');
        ad.dispose();
        _ad = null;

        // ✅ 다음을 위해 재로드
        load();

        onFailed?.call();
      },
    );

    try {
      await ad.show(
        onUserEarnedReward: (ad, reward) async {
          rewarded = true;
          dev.log('🎁 onUserEarnedReward type=${reward.type} amount=${reward.amount}', name: 'ADS');

          // ✅ 보상에서만 AI 실행 (여기가 정답)
          // (닫힘 콜백에서 AI 실행하면 타이밍 꼬임)
          await onRewarded();
        },
      );
    } catch (e) {
      // ✅ show() 자체가 예외를 던지는 경우도 있음
      dev.log('❌ EXCEPTION_IN_SHOW: $e', name: 'ADS');
      _ad = null;
      load();
      onFailed?.call();
    }
  }

  void dispose() {
    _ad?.dispose();
    _ad = null;
  }
}
