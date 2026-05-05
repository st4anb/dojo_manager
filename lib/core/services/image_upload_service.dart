import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import '../constants/api_keys.dart';

class ImageUploadService {
  /// Realiza o upload de uma imagem para o ImgBB com compressão prévia.
  /// Ideal para reduzir custos e manter a arquitetura "Custo Zero".
  static Future<String?> uploadImage(XFile file) async {
    try {
      // 1. Obter bytes e comprimir
      final bytes = await file.readAsBytes();
      final compressedBytes = await _compressBytes(bytes);
      if (compressedBytes == null) return null;

      // 2. Preparação do Upload para ImgBB
      final uri = Uri.parse('https://api.imgbb.com/1/upload?key=${ApiKeys.imgBbKey}');
      final request = http.MultipartRequest('POST', uri);
      
      final multipartFile = http.MultipartFile.fromBytes(
        'image', 
        compressedBytes,
        filename: p.basename(file.path),
      );
      
      request.files.add(multipartFile);

      // 3. Execução
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // data['data']['url'] é o link direto otimizado pelo ImgBB
        return data['data']['url'];
      } else {
        debugPrint('Erro ImgBB Upload: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Exception ImgBB Upload: $e');
      return null;
    }
  }

  /// Realiza o upload de bytes de imagem (Uint8List) para o ImgBB com compressão.
  static Future<String?> uploadImageFromBytes(Uint8List bytes) async {
    try {
      // 1. Compressão
      final compressedBytes = await FlutterImageCompress.compressWithList(
        bytes,
        quality: 70,
        minWidth: 1080,
        minHeight: 1080,
      );

      // 2. Upload Multipart
      final uri = Uri.parse('https://api.imgbb.com/1/upload?key=${ApiKeys.imgBbKey}');
      final request = http.MultipartRequest('POST', uri);
      
      final multipartFile = http.MultipartFile.fromBytes(
        'image',
        compressedBytes,
        filename: 'upload_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      
      request.files.add(multipartFile);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data']['url'];
      }
      return null;
    } catch (e) {
      debugPrint('Exception ImgBB Upload Bytes: $e');
      return null;
    }
  }

  /// Comprime os bytes da imagem para < 1MB e máximo de 1080px de largura/altura.
  static Future<Uint8List?> _compressBytes(Uint8List bytes) async {
    try {
      final result = await FlutterImageCompress.compressWithList(
        bytes,
        quality: 70, // Equilíbrio entre peso e nitidez
        minWidth: 1080,
        minHeight: 1080,
      );
      return result;
    } catch (e) {
      if (kDebugMode) debugPrint('Erro na compressão: $e');
      return bytes; // Retorna original se houver erro
    }
  }
}
