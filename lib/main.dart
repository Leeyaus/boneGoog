import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isIOS) {
    WebViewPlatform.instance = WebKitWebViewPlatform();
  }
  runApp(const YaosuLeeApp());
}

class YaosuLeeApp extends StatelessWidget {
  const YaosuLeeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '李藥師線上整復教學',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2A86FF)),
        useMaterial3: true,
      ),
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const String kLoginUrl   = 'https://yaosulee.com/login-2/';
  static const String kCoursesUrl = 'https://yaosulee.com/lpcourses/';
  static const String kShopUrl    = 'https://yaosulee.com/shop/';

  late final WebViewController _controller;
  bool _isLoading = true;
  String _currentTitle = '會員登入';

  // === 新增：頁面清潔模式 ===
  Future<void> _applyCleanUI() async {
    const js = r"""
      (function() {
        const hide = (sel) => document.querySelectorAll(sel).forEach(el => {
          el.style.display = 'none';
        });

        // 常見 WordPress 主題結構
        hide('#wpadminbar, header, .site-header, .elementor-location-header, .elementor-sticky--effects, .ast-header-break-point, .ast-mobile-header-wrap, .o-header, .oceanwp-mobile-menu-icon');
        hide('footer, .site-footer, .elementor-location-footer');

        // 移除麵包屑與公告列
        hide('.breadcrumbs, .breadcrumb, .page-header, .top-bar, .site-breadcrumbs, .notice, .announcement');

        // 清除頂部空白
        document.documentElement.style.setProperty('--wp-admin--admin-bar--height','0px');
        document.body.style.marginTop = '0';
        document.body.style.paddingTop = '0';

        // 調整主要容器
        const relax = (sel) => document.querySelectorAll(sel).forEach(el => {
          el.style.marginTop = '0';
          el.style.paddingTop = '0';
        });
        relax('#content, .site-content, .entry-content, .elementor-location-single, .container, .content-area');

        // 監聽 DOM 變化確保持隱藏
        if (!window.__yl_clean_observer__) {
          try {
            window.__yl_clean_observer__ = new MutationObserver(() => {
              hide('#wpadminbar, header, .site-header, .elementor-location-header, .elementor-sticky--effects, .ast-header-break-point, .ast-mobile-header-wrap, .o-header, .oceanwp-mobile-menu-icon');
              hide('footer, .site-footer, .elementor-location-footer');
            });
            window.__yl_clean_observer__.observe(document.body, { childList: true, subtree: true });
          } catch(e) {}
        }
      })();
    """;

    try {
      await _controller.runJavaScriptReturningResult(js);
    } catch (_) {}
  }

  // === 加上防快取 ===
  Uri _freshUri(String base) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final uri = Uri.parse(base);
    final qp = Map<String, String>.from(uri.queryParameters);
    qp['ts'] = '$now';
    return uri.replace(queryParameters: qp);
  }

  Future<void> _goTo(String url, {String? title}) async {
    setState(() {
      _isLoading = true;
      if (title != null) _currentTitle = title;
    });
    await _controller.loadRequest(_freshUri(url));
  }

  Future<void> _handleWebError(WebResourceError error) async {
    try {
      final cur = await _controller.currentUrl();
      if (cur != null) {
        final u = Uri.parse(cur);
        final qp = Map<String, String>.from(u.queryParameters);
        qp['ts'] = '${DateTime.now().millisecondsSinceEpoch}';
        await _controller.loadRequest(u.replace(queryParameters: qp));
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();

    final params = Platform.isAndroid
        ? const PlatformWebViewControllerCreationParams()
        : const PlatformWebViewControllerCreationParams();

    final controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) async {
            setState(() => _isLoading = false);
            await _applyCleanUI(); // ← 自動清除頁首與頁尾
          },
          onWebResourceError: _handleWebError,
          onNavigationRequest: (req) => NavigationDecision.navigate,
        ),
      );

    if (controller.platform is AndroidWebViewController) {
      final androidCtrl = controller.platform as AndroidWebViewController;
      androidCtrl.setMediaPlaybackRequiresUserGesture(false);
    }

    _controller = controller;
    _goTo(kLoginUrl, title: '會員登入');
  }

  Future<bool> _onWillPop() async => false;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_currentTitle),
          centerTitle: false,
          actions: [
            TextButton.icon(
              onPressed: () => _goTo(kCoursesUrl, title: '線上課程'),
              icon: const Icon(Icons.school_outlined),
              label: const Text('前往線上課程'),
            ),
            TextButton.icon(
              onPressed: () => _goTo(kShopUrl, title: '商城'),
              icon: const Icon(Icons.shopping_cart_outlined),
              label: const Text('商城'),
            ),
            IconButton(
              tooltip: '回會員登入',
              onPressed: () => _goTo(kLoginUrl, title: '會員登入'),
              icon: const Icon(Icons.home_outlined),
            ),
          ],
          bottom: _isLoading
              ? const PreferredSize(
                  preferredSize: Size.fromHeight(2),
                  child: LinearProgressIndicator(minHeight: 2),
                )
              : null,
        ),
        body: WebViewWidget(controller: _controller),
      ),
    );
  }
}
