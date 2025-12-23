import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'app/haedo_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ AdMob 초기화
  await MobileAds.instance.initialize();

  runApp(const HaedoApp());
}
