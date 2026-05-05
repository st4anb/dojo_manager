class TatameVirtualModel {
  final String id;
  final String titulo;
  final String descricao;
  final String imagemUrl;
  final String youtubeUrl;
  final String categoria;
  final bool ativo;
  final String modalityId; // [NOVO] Vinculação com modalidade
  final int kiValue; // [NOVO] Pontuação teórica concedida
  final List<String> galeria; // [NOVO] Suporte a múltiplas fotos

  TatameVirtualModel({
    required this.id,
    required this.titulo,
    required this.descricao,
    required this.imagemUrl,
    required this.youtubeUrl,
    required this.categoria,
    required this.ativo,
    this.modalityId = 'Geral',
    this.kiValue = 10,
    this.galeria = const [], // Default vazio
  });

  factory TatameVirtualModel.fromMap(String id, Map<String, dynamic>? data) {
    if (data == null) return _empty(id);

    return TatameVirtualModel(
      id: id,
      titulo: data['titulo']?.toString() ?? 'Aula / Treino',
      descricao: data['descricao']?.toString() ?? 'Confira o conteúdo técnico abaixo.',
      imagemUrl: data['imagemUrl']?.toString() ?? data['url_imagem']?.toString() ?? '',
      youtubeUrl: data['youtubeUrl']?.toString() ?? '',
      categoria: data['categoria']?.toString() ?? 'Geral',
      modalityId: data['modalityId']?.toString() ?? data['modalidade_id']?.toString() ?? 'Geral',
      kiValue: (data['kiValue'] ?? data['ki_value'] ?? 10) as int,
      ativo: data['ativo'] is bool ? data['ativo'] : true,
      galeria: List<String>.from(data['galeria'] ?? []),
    );
  }

  static TatameVirtualModel _empty(String id) => TatameVirtualModel(
    id: id,
    titulo: 'Vazio',
    descricao: '',
    imagemUrl: '',
    youtubeUrl: '',
    categoria: 'Geral',
    modalityId: 'Geral',
    kiValue: 0,
    ativo: false,
    galeria: [],
  );

  Map<String, dynamic> toMap() {
    return {
      'titulo': titulo,
      'descricao': descricao,
      'imagemUrl': imagemUrl,
      'youtubeUrl': youtubeUrl,
      'categoria': categoria,
      'modalityId': modalityId,
      'kiValue': kiValue,
      'ativo': ativo,
      'galeria': galeria,
    };
  }
}
