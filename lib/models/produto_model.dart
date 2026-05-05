
class ProdutoModel {
  final String id;
  final String nome;
  final String descricao;
  final int preco; // Armazenado em centavos (ex: 5000 = R$ 50,00)
  final String imagemUrl;
  final int estoque;
  final bool ativo;
  final String categoria;

  ProdutoModel({
    required this.id,
    required this.nome,
    required this.descricao,
    required this.preco,
    required this.imagemUrl,
    required this.estoque,
    required this.ativo,
    this.categoria = 'Geral',
  });

  factory ProdutoModel.fromMap(String id, Map<String, dynamic>? data) {
    if (data == null) return _empty(id);
    
    // Tratamento de segurança para PREÇO (Centavos)
    int precoFinal = 0;
    if (data['preco'] != null) {
      if (data['preco'] is num) {
        precoFinal = (data['preco'] as num).toInt();
      } else if (data['preco'] is String) {
        final double? parsed = double.tryParse(data['preco'].toString());
        precoFinal = (parsed != null) ? (parsed * 100).toInt() : 0;
      }
    }

    return ProdutoModel(
      id: id,
      nome: data['nome']?.toString() ?? data['titulo']?.toString() ?? 'Produto sem nome',
      descricao: data['descricao']?.toString() ?? 'Descrição não informada.',
      preco: precoFinal,
      imagemUrl: data['imagemUrl']?.toString() ?? data['url_imagem']?.toString() ?? '',
      estoque: data['estoque'] is num ? (data['estoque'] as num).toInt() : 0,
      ativo: data['ativo'] is bool ? data['ativo'] : false, // Step 2: Default to false if null
      categoria: data['categoria']?.toString() ?? 'Geral',
    );
  }

  static ProdutoModel _empty(String id) => ProdutoModel(
    id: id,
    nome: 'Produto não encontrado',
    descricao: '',
    preco: 0,
    imagemUrl: '',
    estoque: 0,
    ativo: false,
  );

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'descricao': descricao,
      'preco': preco,
      'imagemUrl': imagemUrl,
      'estoque': estoque,
      'ativo': ativo,
      'categoria': categoria,
    };
  }
}
