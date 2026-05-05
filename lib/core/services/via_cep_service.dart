import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ViaCepService {
  /// Consulta um CEP na API ViaCEP
  /// Retorna um Map com as informações do endereço ou null em caso de erro.
  static Future<Map<String, dynamic>?> fetchAddress(String cep) async {
    // Remove caracteres não numéricos
    final cleanCep = cep.replaceAll(RegExp(r'[^0-9]'), '');
    
    if (cleanCep.length != 8) return null;

    final url = Uri.parse('https://viacep.com.br/ws/$cleanCep/json/');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // ViaCEP retorna erro: true se o CEP não for encontrado
        if (data['erro'] == true) {
          return null;
        }
        
        return data as Map<String, dynamic>;
      } else {
        debugPrint('Erro ViaCEP: Status ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Exception ViaCEP: $e');
      return null;
    }
  }
}
