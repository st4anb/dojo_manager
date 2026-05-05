import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class FirebaseStorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Faz o upload de um PDF para o caminho especificado e retorna a URL de download.
  static Future<String?> uploadPdf(Uint8List bytes, String path) async {
    try {
      final ref = _storage.ref().child(path);
      final metadata = SettableMetadata(contentType: 'application/pdf');
      
      final uploadTask = ref.putData(bytes, metadata);
      final snapshot = await uploadTask;
      
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Erro ao fazer upload para Firebase Storage: $e');
      return null;
    }
  }

  /// Faz o upload de um arquivo genérico a partir de bytes.
  static Future<String?> uploadFile(Uint8List bytes, String path, String contentType) async {
    try {
      final ref = _storage.ref().child(path);
      final metadata = SettableMetadata(contentType: contentType);
      
      final uploadTask = ref.putData(bytes, metadata);
      final snapshot = await uploadTask;
      
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Erro no upload de ficheiro: $e');
      return null;
    }
  }
}
