
class ModalidadeModel {
  final String id;
  final String nome;
  final String? professor;
  final bool ativo;
  final List<Map<String, dynamic>> gradeHorarios;
  final String? backgroundUrl;

  ModalidadeModel({
    required this.id,
    required this.nome,
    this.professor,
    this.ativo = true,
    required this.gradeHorarios,
    this.backgroundUrl,
  });

  factory ModalidadeModel.fromMap(String id, Map<String, dynamic> map) {
    return ModalidadeModel(
      id: id,
      nome: map['nome'] ?? 'Sem Nome',
      professor: map['professor'],
      ativo: map['ativo'] ?? true,
      backgroundUrl: map['background_url'],
      gradeHorarios: List<Map<String, dynamic>>.from(
        (map['gradeHorarios'] ?? map['horarios'] ?? []).map((h) => Map<String, dynamic>.from(h)),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'professor': professor,
      'ativo': ativo,
      'gradeHorarios': gradeHorarios,
      'background_url': backgroundUrl,
    };
  }
}
