import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:home_widget/home_widget.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/env.dart';
import 'providers/ai_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/transaction_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'services/ai_service.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'services/export_service.dart';
import 'services/import_service.dart';
import 'services/settings_service.dart';
import 'services/transaction_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 初始化桌面卡片插件（Android 留空字符串）
  await HomeWidget.setAppGroupId('');

  final db = await DatabaseService.instance.database;
  final prefs = await SharedPreferences.getInstance();

  final authService = AuthService(db);
  final transactionService = TransactionService(db);
  final settingsService = SettingsService(prefs);
  final exportService = ExportService(transactionService);
  final aiService = AiService();
  final importService = ImportService(aiService, transactionService);

  runApp(AnticountApp(
    authService: authService,
    transactionService: transactionService,
    settingsService: settingsService,
    exportService: exportService,
    importService: importService,
    aiService: aiService,
  ));
}

class AnticountApp extends StatelessWidget {
  const AnticountApp({
    super.key,
    required this.authService,
    required this.transactionService,
    required this.settingsService,
    required this.exportService,
    required this.importService,
    required this.aiService,
  });

  final AuthService authService;
  final TransactionService transactionService;
  final SettingsService settingsService;
  final ExportService exportService;
  final ImportService importService;
  final AiService aiService;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(authService)..bootstrap(),
        ),
        ChangeNotifierProvider(
          create: (_) => TransactionProvider(transactionService),
        ),
        ChangeNotifierProvider(
            create: (_) => SettingsProvider(settingsService),
          ),
          Provider(
            create: (_) => exportService,
          ),
          Provider(
            create: (_) => importService,
          ),
          ChangeNotifierProvider(
            create: (context) {
              final auth = context.read<AuthProvider>();
              final ai = AiProvider(aiService);
              // 登录用户变化时按用户加载/清空 AI 配置
              auth.addListener(() => ai.loadForUser(auth.user?.id));
              ai.loadForUser(auth.user?.id);
              return ai;
            },
          ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          final themeMode = switch (settings.themeMode) {
            'light' => ThemeMode.light,
            'dark' => ThemeMode.dark,
            _ => ThemeMode.system,
          };
          return MaterialApp(
            title: currentEnv.appName,
            debugShowCheckedModeBanner: false,
            // 中文本地化：让日期选择器等 Material 组件显示中文
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('zh', 'CN'),
              Locale('en', 'US'),
            ],
            locale: const Locale('zh', 'CN'),
            // 浅色主题：白色基调 + 蓝色主色调
            theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.light,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF1565C0),
                brightness: Brightness.light,
                surface: Colors.white, // 白色背景
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.white,
                foregroundColor: Color(0xFF1565C0),
                elevation: 0,
                centerTitle: false,
              ),
              scaffoldBackgroundColor: Colors.white,
              cardTheme: CardThemeData(
                color: Colors.white,
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            // 深色主题：保留蓝色主色调
            darkTheme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF1565C0),
                brightness: Brightness.dark,
              ),
            ),
            themeMode: themeMode,
            home: const _RootGate(),
          );
        },
      ),
    );
  }
}

/// 登录态守卫
///
/// 初始化时显示带 AntiCount logo 的开屏界面
class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.initialized) {
      // 开屏界面：白色背景 + 居中加载指示器 + 底部 AntiCount logo
      return Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            // 上方留白 + 居中加载指示器
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF6C5CE7),
                  strokeWidth: 3,
                ),
              ),
            ),
            // 底部 AntiCount logo
            Padding(
              padding: const EdgeInsets.only(bottom: 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 网站图标风格 logo（紫色圆角方形 + 白色 N + 青色斜线）
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: CustomPaint(
                      painter: _LogoNPainter(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // AntiCount 文字 logo
                  const Text(
                    'AntiCount',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w300,
                      color: Color(0xFF6C5CE7),
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // 副标题
                  Text(
                    '智能记账',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[400],
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return auth.isAuthenticated ? const HomeScreen() : const LoginScreen();
  }
}

/// 开屏 logo 画笔（网站图标风格）
///
/// 绘制 anticraft 网站图标：紫色圆角方形 + 白色 N + 青色对角斜线
class _LogoNPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final purplePaint = Paint()
      ..color = const Color(0xFF6C5CE7)
      ..style = PaintingStyle.fill;
    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final tealPaint = Paint()
      ..color = const Color(0xFF00CEC9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.07
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    // 紫色圆角方形背景
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h),
      Radius.circular(w * 0.1875), // rx=12/64≈0.1875
    );
    canvas.drawRRect(bgRect, purplePaint);

    // 白色 N 字母（按比例缩放原始 SVG 路径）
    // 原始 64x64: M20,44 V20 h8 l8,16 V20 h8 v24 h-8 l-8,-16 v16 h-8 z
    // 按比例转换为当前尺寸
    final nPath = Path()
      ..moveTo(w * 0.3125, h * 0.6875)   // M20,44
      ..lineTo(w * 0.3125, h * 0.3125)   // V20
      ..lineTo(w * 0.4375, h * 0.3125)   // h8
      ..lineTo(w * 0.5625, h * 0.5625)   // l8,16
      ..lineTo(w * 0.5625, h * 0.3125)   // V20
      ..lineTo(w * 0.6875, h * 0.3125)   // h8
      ..lineTo(w * 0.6875, h * 0.6875)   // v24
      ..lineTo(w * 0.5625, h * 0.6875)   // h-8
      ..lineTo(w * 0.4375, h * 0.4375)   // l-8,-16
      ..lineTo(w * 0.4375, h * 0.6875)   // v16
      ..lineTo(w * 0.3125, h * 0.6875)   // h-8
      ..close();
    canvas.drawPath(nPath, whitePaint);

    // 青色对角斜线（从左下到右上）
    // 原始 64x64: M14,48 L50,16
    canvas.drawLine(
      Offset(w * 0.21875, h * 0.75),  // (14,48)
      Offset(w * 0.78125, h * 0.25),  // (50,16)
      tealPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
