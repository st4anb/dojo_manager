import 'package:cloud_firestore/cloud_firestore.dart';

class AlunoDestaqueModel {
  final String id;
  final String nome;
  final String fotoUrl;
  final String trajetoria;
  final DateTime createdAt;

  AlunoDestaqueModel({
    required this.id,
    required this.nome,
    required this.fotoUrl,
    required this.trajetoria,
    required this.createdAt,
  });

  factory AlunoDestaqueModel.fromMap(String id, Map<String, dynamic> data) {
    // [CORREÇÃO BUG 1] Blindagem contra dados malformados
    DateTime? parsedDate;
    try {
      if (data['createdAt'] is Timestamp) {
        parsedDate = (data['createdAt'] as Timestamp).toDate();
      } else if (data['createdAt'] is String) {
        parsedDate = DateTime.tryParse(data['createdAt']);
      }
    } catch (_) {
      parsedDate = null;
    }

    return AlunoDestaqueModel(
      id: id,
      nome: data['nome']?.toString() ?? 'Aluno Destaque',
      fotoUrl: data['fotoUrl']?.toString() ?? '',
      trajetoria: data['trajetoria']?.toString() ?? '',
      createdAt: parsedDate ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'fotoUrl': fotoUrl,
      'trajetoria': trajetoria,
      'createdAt': createdAt,
    };
  }
}
