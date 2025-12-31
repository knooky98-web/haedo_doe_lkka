import 'dart:developer' as dev;
import 'package:flutter/foundation.dart'; // kReleaseMode
import 'package:google_mobile_ads/google_mobile_ads.dart';

class RewardedAdService {
  RewardedAd? _ad;
  bool get isLoaded => _ad != null;

  // ✅ Google 공식 테스트 리워드 광고 유닛(개발용)
  static const String testUnitId = 'ca-app-pub-3940256099942544/5224354917';

  // ✅ 네 AdMob "보상형 광고 단위 ID" (실제값)
  static const String realUnitId = 'ca-app-pub-6290370736855622/6583377104';

  /// ✅ 디버그=테스트 / 릴리즈=실유닛 자동 선택
  static String get defaultUnitId => kReleaseMode ? realUnitId : testUnitId;

  void load({String? adUnitId}) {
    final unit = adUnitId ?? defaultUnitId;
    dev.log('🚀 load() CALLED unit=$unit', name: 'ADS');

    RewardedAd.load(
      adUnitId: unit,
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

    bool rewarded = false;

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

        // ✅ 다음을 위해 항상 재로드
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
          dev.log(
            '🎁 onUserEarnedReward type=${reward.type} amount=${reward.amount}',
            name: 'ADS',
          );

          // ✅ 보상에서만 AI 실행
          await onRewarded();
        },
      );
    } catch (e) {
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
