import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'core.dart';
import 'app/haedo_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await MobileAds.instance.initialize();

  // ✅ 테스트 디바이스 설정(네 로그에 찍힌 값)
  await MobileAds.instance.updateRequestConfiguration(
    RequestConfiguration(
      testDeviceIds: ['11427C643901094A9B2BA28CFC09D37A'],
    ),
  );

  // ✅ 앱 시작 시 미리 로드
  rewardedAds.load();

  runApp(const HaedoApp());
}
