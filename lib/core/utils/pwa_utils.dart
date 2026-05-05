import 'dart:js' as js;
import 'package:flutter/foundation.dart';

class PWAUtils {
  /// Executa um "Hard Refresh" completo da PWA limpando caches do Service Worker
  /// e recarregando a página.
  static void hardRefresh() {
    if (kIsWeb) {
      try {
        js.context.callMethod('handleHardPWARefresh');
      } catch (e) {
        debugPrint('Erro ao chamar handleHardPWARefresh: $e');
        // Fallback caso a função não esteja definida no index.html
        js.context['location'].callMethod('reload');
      }
    }
  }
}
