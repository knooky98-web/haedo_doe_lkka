import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'core.dart';
import 'app/haedo_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await MobileAds.instance.initialize();




  // ✅ 앱 실행/복귀 후 1분 뒤 전면광고(라이프사이클 포함) 시작
  // - 내부에서 interstitial/rewardedInterstitial 로드도 같이 함
  appLaunchInterstitial.start();

  runApp(const HaedoApp());
}
