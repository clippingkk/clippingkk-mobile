import 'package:ClippingKK/model/appConfig.dart';
import 'package:ClippingKK/pages/about.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ClippingKK/utils/reporter.dart';
import 'package:ClippingKK/utils/logger.dart';
import 'package:ClippingKK/pages/setting.dart';
import './index.dart';
import './pages/auth.dart';
import 'package:fluwx/fluwx.dart' as fluwx;
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_analytics/observer.dart';

FirebaseAnalytics analytics = FirebaseAnalytics();

class _OnInit {
  static final _OnInit _handler = new _OnInit._internal();

  factory _OnInit() => _handler;

  _OnInit._internal();

  Future<void> execute() {
    if (!AppConfig.isDev) {
      this.initSentry();
    }
    this.initWechat();
    return this.preLoadUserInfo();
  }

  Future<void> preLoadUserInfo() async {
    final result = await Future.wait([
      FlutterSecureStorage().read(key: 'jwt'),
      FlutterSecureStorage().read(key: 'uid')
    ]);

    final jwt = result[0];
    final uid = result[1];
    AppConfig.jwtToken = jwt == null ? "" : jwt;

    AppConfig.uid = uid != null ? int.parse(uid) : -1;
  }

  void initSentry() {
    Reporter();
  }

  void initWechat() {
    fluwx.register(appId: "wxb602f4d89c1112c3");
  }
}


void main() async {
  await _OnInit().execute();
  KKLogger().getLogger().fine("app start");
  runApp(new MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ClippingKK',
      showPerformanceOverlay: false,
      theme: ThemeData(
//        primarySwatch: Colors.black45,
//        primaryColor: Colors.red,
        primaryColor: const Color.fromRGBO(33, 150, 243, 1),
      ),
      navigatorObservers: [
        FirebaseAnalyticsObserver(analytics: analytics),
      ],
      initialRoute: '/',
      routes: {
        '/': (context) => IndexPage(),
        '/auth': (context) => AuthPage(),
        '/setting': (context) => SettingPage(),
        '/about': (context) => AboutPage()
      },
    );
  }
}

