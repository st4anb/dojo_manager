import 'package:cloud_firestore/cloud_firestore.dart';

class EventoModel {
  final String id;
  final String titulo;
  final String descricao;
  final DateTime dataEvento;
  final String imagemUrl;
  final String local;
  final bool ativo;

  EventoModel({
    required this.id,
    required this.titulo,
    required this.descricao,
    required this.dataEvento,
    required this.imagemUrl,
    required this.local,
    required this.ativo,
  });

  factory EventoModel.fromMap(String id, Map<String, dynamic>? data) {
    if (data == null) return _empty(id);

    return EventoModel(
      id: id,
      titulo: data['titulo']?.toString() ?? 'Novo Evento',
      descricao: data['descricao']?.toString() ?? '',
      dataEvento: (data['dataEvento'] as Timestamp?)?.toDate() ?? 
                  (data['data_evento'] as Timestamp?)?.toDate() ?? 
                  DateTime.now(),
      imagemUrl: data['imagemUrl']?.toString() ?? data['flyer_url']?.toString() ?? '',
      local: data['local']?.toString() ?? 'A definir',
      ativo: data['ativo'] is bool ? data['ativo'] : true,
    );
  }

  static EventoModel _empty(String id) => EventoModel(
    id: id,
    titulo: 'Sem título',
    descricao: '',
    dataEvento: DateTime.now(),
    imagemUrl: '',
    local: '',
    ativo: false,
  );

  Map<String, dynamic> toMap() {
    return {
      'titulo': titulo,
      'descricao': descricao,
      'dataEvento': Timestamp.fromDate(dataEvento),
      'imagemUrl': imagemUrl,
      'local': local,
      'ativo': ativo,
    };
  }
}
