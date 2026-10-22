import 'dart:async';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:youtube_explode_dart/js_challenge.dart';

/// Solves YouTube's JavaScript "n"/"sig" challenges on the phone using a
/// hidden WebView (Chrome's V8 engine) and yt-dlp's EJS solver scripts.
/// Without this, YouTube refuses most streams ("unplayable").
class WebViewEJSSolver extends BaseEJSSolver {
  HeadlessInAppWebView? _hw;
  InAppWebViewController? _c;
  Future<void>? _ready;

  Future<void> _init() async {
    final loaded = Completer<InAppWebViewController>();
    _hw = HeadlessInAppWebView(
      initialData: InAppWebViewInitialData(
          data: '<!doctype html><html><head></head><body></body></html>'),
      initialSettings: InAppWebViewSettings(javaScriptEnabled: true),
      onLoadStop: (c, _) {
        if (!loaded.isCompleted) loaded.complete(c);
      },
    );
    await _hw!.run();
    _c = await loaded.future.timeout(const Duration(seconds: 20));
    final modules = await EJSBuilder.getJSModules();
    await _c!.evaluateJavascript(source: '$modules\n;null;');
  }

  @override
  Future<String> executeJavaScript(String jsCode) async {
    _ready ??= _init();
    try {
      await _ready;
    } catch (e) {
      _ready = null; // retry next time
      rethrow;
    }
    final r = await _c!.evaluateJavascript(source: jsCode);
    if (r is String) return r;
    throw Exception('JS solver returned: $r');
  }

  @override
  void dispose() {
    // Keep it re-usable: a new YoutubeExplode may get this solver again.
    try {
      _hw?.dispose();
    } catch (_) {}
    _hw = null;
    _c = null;
    _ready = null;
  }
}
