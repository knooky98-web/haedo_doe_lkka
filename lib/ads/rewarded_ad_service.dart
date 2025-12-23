import 'package:google_mobile_ads/google_mobile_ads.dart';

class RewardedAdService {
  RewardedAd? _ad;
  bool get isLoaded => _ad != null;

  // ✅ Android 테스트 리워드 광고 유닛
  static const String testUnitId = 'ca-app-pub-3940256099942544/5224354917';

  void load({String adUnitId = testUnitId}) {
    RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _ad!.setImmersiveMode(true);
        },
        onAdFailedToLoad: (_) {
          _ad = null;
        },
      ),
    );
  }

  /// ✅ onUserEarnedReward 에서만 onRewarded 실행
  Future<void> show({
    required Future<void> Function() onRewarded,
    void Function()? onClosed,
    void Function()? onFailed,
  }) async {
    final ad = _ad;
    if (ad == null) {
      onFailed?.call();
      return;
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _ad = null;
        onClosed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _ad = null;
        onFailed?.call();
      },
    );

    await ad.show(
      onUserEarnedReward: (_, __) async {
        await onRewarded(); // ✅ 여기에서만 AI 호출
      },
    );
  }

  void dispose() {
    _ad?.dispose();
    _ad = null;
  }
}
