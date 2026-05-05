import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class MercadoPagoService {
  static const String _vercelBase = 'https://backend-vercel-theta-rouge.vercel.app';
  static const Duration _timeout = Duration(seconds: 10);

  /// Gera a cobrança no Mercado Pago via backend Vercel.
  /// 
  /// O [valor] é enviado em REAIS (ex: 1.0 = R$ 1,00).
  /// O backend converte para centavos antes de chamar a API do Mercado Pago
  /// (ex: 1.0 → 100 centavos).
  /// 
  /// O valor é controlado pelo Admin via config/geral.mensalidade_valor.
  static Future<Map<String, String>> gerarEProcessarPagamento({
    required double valor,
    required String alunoId,
    required String email,
  }) async {
    // ─── Validação Client-Side ───
    if (valor < 1.0 || valor > 2000) {
      throw Exception('Valor inválido. Informe um valor entre R\$ 1,00 e R\$ 2.000,00.');
    }
    if (alunoId.trim().isEmpty) {
      throw Exception('ID do aluno não informado.');
    }

    final url = Uri.parse('$_vercelBase/api/pagamentos/gerar');

    try {
      debugPrint('🟢 Gerando cobrança Pix: R\$ ${valor.toStringAsFixed(2)} para $alunoId');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'valor': valor,
          'aluno_id': alunoId.trim(),
          'email': email,
        }),
      ).timeout(_timeout, onTimeout: () {
        throw Exception('Servidor não respondeu em ${_timeout.inSeconds}s. Tente novamente.');
      });

      debugPrint('📡 Resposta: ${response.statusCode}');
      if (response.statusCode != 200) {
        debugPrint('❌ Erro na requisição: ${response.body}');
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String? pixCopiaCola = data['pix_copia_e_cola'];
        final String? qrCodeBase64 = data['qr_code_base64'];

        if (pixCopiaCola != null && pixCopiaCola.isNotEmpty && qrCodeBase64 != null && qrCodeBase64.isNotEmpty) {
          debugPrint('✅ Pix Gerado com sucesso');
          return {
            'pix_copia_e_cola': pixCopiaCola,
            'qr_code_base64': qrCodeBase64,
          };
        } else {
          throw Exception('O gateway de pagamento não retornou os dados do Pix válidos.');
        }
      } else if (response.statusCode == 429) {
        throw Exception('Muitas tentativas. Aguarde um momento.');
      } else if (response.statusCode == 504) {
        throw Exception('O gateway de pagamento está lento. Tente novamente em alguns segundos.');
      } else {
        String errorMsg = 'Erro HTTP ${response.statusCode}';
        try {
          final errorData = jsonDecode(response.body);
          errorMsg = errorData['error'] ?? response.body;
        } catch (_) {
          // Se não conseguir parsear JSON (ex: HTML page de erro do Cloudflare)
          errorMsg = 'Erro HTTP ${response.statusCode}: ${response.body}';
        }
        
        // Trunca se a mensagem for muito longa (ex: página HTML inteira)
        if (errorMsg.length > 200) {
          errorMsg = '${errorMsg.substring(0, 197)}...';
        }

        throw Exception(errorMsg);
      }
    } on Exception {
      rethrow;
    } catch (e) {
      debugPrint('❌ Erro MercadoPago: $e');
      throw Exception('Falha de conexão. Verifique sua internet.');
    }
  }

  /// Verifica manualmente o status de um pagamento pendente.
  /// Retorna true se o pagamento for confirmado como PAGO.
  static Future<bool> verificarStatusPagamento({
    required String alunoId,
    required String orderNsu,
  }) async {
    final url = Uri.parse('$_vercelBase/api/pagamentos/verificar');

    try {
      debugPrint('🔍 Verificando status manual: $orderNsu para $alunoId');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'aluno_id': alunoId,
          'order_nsu': orderNsu,
        }),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final status = data['status']?.toString().toLowerCase();
        
        if (status == 'pago') {
          debugPrint('✅ Pagamento confirmado via verificação manual!');
          return true;
        }
        return false;
      } else {
        debugPrint('⚠️ Erro na verificação: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Erro ao verificar status: $e');
      return false;
    }
  }
}
