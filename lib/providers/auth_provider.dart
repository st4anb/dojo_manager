import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/firebase_collections.dart';
import '../core/services/notification_service.dart';

class CareerStats {
  final int vitorias;
  final int derrotas;
  final int trofeus;
  final int medalhas;
  final int cinturoes;
  final int campeonatosDisputados;
  final List<String> certificados;

  CareerStats({
    this.vitorias = 0,
    this.derrotas = 0,
    this.trofeus = 0,
    this.medalhas = 0,
    this.cinturoes = 0,
    this.campeonatosDisputados = 0,
    this.certificados = const [],
  });

  factory CareerStats.fromMap(Map<String, dynamic> map) {
    return CareerStats(
      vitorias: _safeInt(map['vitorias']),
      derrotas: _safeInt(map['derrotas']),
      trofeus: _safeInt(map['trofeus']),
      medalhas: _safeInt(map['medalhas']),
      cinturoes: _safeInt(map['cinturoes']),
      campeonatosDisputados: _safeInt(map['campeonatos_disputados']),
      certificados: List<String>.from(map['certificados'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'vitorias': vitorias,
      'derrotas': derrotas,
      'trofeus': trofeus,
      'medalhas': medalhas,
      'cinturoes': cinturoes,
      'campeonatos_disputados': campeonatosDisputados,
      'certificados': certificados,
    };
  }
}

class UserProgressStats {
  final int totalGeral;
  final int treinosMes;
  final Map<String, int> porModalidade;

  UserProgressStats({
    this.totalGeral = 0,
    this.treinosMes = 0,
    this.porModalidade = const {},
  });

  factory UserProgressStats.fromMap(Map<String, dynamic> map) {
    return UserProgressStats(
      totalGeral: _safeInt(map['total_geral']),
      treinosMes: _safeInt(map['treinos_mes']),
      porModalidade: (map['por_modalidade'] as Map?)?.map((k, v) => MapEntry(k.toString(), _safeInt(v))) ?? {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'total_geral': totalGeral,
      'treinos_mes': treinosMes,
      'por_modalidade': porModalidade,
    };
  }
}

enum FinancialState { pago, pendente, vencido, regularGerenciado, adesaoPendente }

class UserProfileData {
  final String role;
  final bool isAnamneseCompleted;
  final String faixa;
  final List<String> modalidade;
  final bool aptoExameFaixa;
  final String uid;
  final String? nome;
  final String? fotoUrl;
  final double? peso;
  final double? altura;
  final int? idade;
  final String? nascimento;
  final String? termoResponsabilidadeUrl;
  final int frequenciaTotal;
  final CareerStats carreira;
  final String statusPagamento;
  final DateTime? ultimaConfirmacao;
  final DateTime? proximoVencimento;
  final DateTime? vencimentoIsencao;
  final String? idUltimoPagamento;
  final String? cpfRg;
  final String? cpf; // [NOVO]
  final String? rg;  // [NOVO]
  final String? statusAptidao;
  final String? urlAtestado;
  final bool temAtestado;
  final bool isTermsAccepted;
  final Map<String, String> faixasPorModalidade; // { 'Jiu-jitsu': 'Azul' }
  final Map<String, String> grausPorModalidade; // [NOVO] { 'Jiu-jitsu': '2º Grau' }
  final String planoCorporativo; // 'nenhum', 'wellhub', 'totalpass'
  final bool temAdesao;
  final UserProgressStats progresso;
  /// 'pendente' | 'ativo' | 'bloqueado' — controla o acesso do aluno ao app
  final String statusAcesso;
  final Map<String, int> kiPorModalidade; // [NOVO] { 'Jiu-jitsu': 150 }
  final Map<String, String> patchesPorModalidade; // [NOVO] { 'Jiu-jitsu': 'url_patch' }
  final double? valorMensalidadeCustomizado; // [NOVO] Override de mensalidade
  final String? contatoEmergenciaNome; // [NOVO]
  final String? contatoEmergenciaTel; // [NOVO]
  final String? urlAssinaturaImgbb; // [NOVO] Link imgBB
  final String? assinaturaBase64; // [NOVO] Backup local

  UserProfileData({
    required this.role, 
    required this.isAnamneseCompleted,
    required this.faixa,
    required this.modalidade,
    required this.aptoExameFaixa,
    required this.uid,
    this.nome,
    this.fotoUrl,
    this.peso,
    this.altura,
    this.idade,
    this.nascimento,
    this.termoResponsabilidadeUrl,
    this.statusPagamento = 'pendente',
    this.ultimaConfirmacao,
    this.proximoVencimento,
    this.vencimentoIsencao,
    this.idUltimoPagamento,
    this.cpfRg,
    this.statusAptidao,
    this.urlAtestado,
    this.temAtestado = false,
    this.isTermsAccepted = false,
    this.planoCorporativo = 'nenhum',
    this.temAdesao = false,
    this.frequenciaTotal = 0,
    this.faixasPorModalidade = const {},
    this.grausPorModalidade = const {},
    this.statusAcesso = 'ativo',
    this.kiPorModalidade = const {},
    this.patchesPorModalidade = const {},
    this.valorMensalidadeCustomizado,
    this.contatoEmergenciaNome,
    this.contatoEmergenciaTel,
    this.urlAssinaturaImgbb,
    this.assinaturaBase64,
    this.cpf,
    this.rg,
    UserProgressStats? progresso,
    CareerStats? carreira,
  }) : carreira = carreira ?? CareerStats(),
       progresso = progresso ?? UserProgressStats();

  factory UserProfileData.fromFirestore(DocumentSnapshot doc) {
    return UserProfileData.fromMap(doc.id, doc.data() as Map<String, dynamic>? ?? {});
  }

  factory UserProfileData.fromMap(String uid, Map<String, dynamic> data) {
    try {
      final personal = data['dados_pessoais'] as Map<String, dynamic>?;
      final financeiro = data['financeiro'] as Map<String, dynamic>?;
      
      String? cpf = personal?['cpf'] as String? ?? data['cpf'] as String?;
      String? rg = personal?['rg'] as String? ?? data['rg'] as String?;
      final String? cpfRgRaw = personal?['cpf_rg'] as String? ?? data['cpf_rg'] as String?;
      
      if ((cpf == null || rg == null) && cpfRgRaw != null && cpfRgRaw.contains('/')) {
        final parts = cpfRgRaw.split('/');
        cpf ??= parts[0].trim();
        rg ??= parts[1].trim();
      }
      
      final statusMP = financeiro?['statusPagamento']?.toString().toLowerCase() ?? 
                       financeiro?['status']?.toString().toLowerCase() ?? 'pendente';
      
      final dataUltimoRaw = financeiro?['data_ultimo_pagamento'] ?? financeiro?['dataPagamento'];
      final DateTime? dataPagamento = _parseDate(dataUltimoRaw) ?? (data['ultima_confirmacao'] as Timestamp?)?.toDate();
      
      final proxVencRaw = financeiro?['proximo_vencimento'] ?? financeiro?['proximoVencimento'];
      DateTime? proximoVencimento = _parseDate(proxVencRaw);
      
      if (proximoVencimento == null && dataPagamento != null) {
        proximoVencimento = dataPagamento.add(const Duration(days: 30));
      }

      return UserProfileData(
        role: data['role'] as String? ?? 'aluno',
        isAnamneseCompleted: data['is_anamnese_completed'] as bool? ?? false,
        faixa: personal?['faixa'] as String? ?? data['faixa'] as String? ?? 'BRANCA',
        modalidade: _parseModalidades(personal?['modalidade'] ?? data['modalidade']),
        aptoExameFaixa: personal?['apto_exame_faixa'] as bool? ?? data['apto_exame_faixa'] as bool? ?? false,
        uid: uid,
        nome: personal?['nome'] as String? ?? data['nome'] as String?,
        fotoUrl: personal?['foto_url'] as String? ?? data['foto_url'] as String?,
        peso: _safeDouble(personal?['peso'] ?? data['peso']),
        altura: _safeDouble(personal?['altura'] ?? data['altura']),
        idade: _calculateAge(personal?['nascimento'] ?? data['nascimento']),
        nascimento: personal?['nascimento'] as String? ?? data['nascimento'] as String?,
        termoResponsabilidadeUrl: data['termo_responsabilidade_url'] as String?,
        frequenciaTotal: _safeInt(data['frequencia_total']),
        statusPagamento: statusMP,
        ultimaConfirmacao: dataPagamento,
        proximoVencimento: proximoVencimento,
        vencimentoIsencao: (data['vencimentoIsencao'] as Timestamp?)?.toDate() ?? (financeiro?['vencimentoIsencao'] as Timestamp?)?.toDate(),
        idUltimoPagamento: data['id_ultimo_pagamento'] as String? ?? financeiro?['idUltimoPagamento'] as String?,
        cpfRg: cpfRgRaw,
        cpf: cpf,
        rg: rg,
        statusAptidao: personal?['status_aptidao'] as String?,
        urlAtestado: personal?['url_atestado'] as String?,
        temAtestado: personal?['tem_atestado'] as bool? ?? false,
        isTermsAccepted: data['termos_matricula']?['termoAssinado'] as bool? ?? false,
        faixasPorModalidade: (personal?['faixas_por_modalidade'] as Map?)?.map((k, v) => MapEntry(k.toString(), v.toString())) ?? {},
        grausPorModalidade: (personal?['graus_por_modalidade'] as Map?)?.map((k, v) => MapEntry(k.toString(), v.toString())) ?? {},
        planoCorporativo: data['plano_corporativo'] as String? ?? 'nenhum',
        statusAcesso: data['status_acesso'] as String? ?? 'ativo',
        carreira: data['carreira'] != null 
            ? CareerStats.fromMap(data['carreira'] as Map<String, dynamic>)
            : null,
        progresso: data['progresso'] != null 
            ? UserProgressStats.fromMap(data['progresso'] as Map<String, dynamic>)
            : null,
        kiPorModalidade: (data['ki_por_modalidade'] as Map?)?.map((k, v) => MapEntry(k.toString(), _safeInt(v))) ?? {},
        patchesPorModalidade: (data['patches_por_modalidade'] as Map?)?.map((k, v) => MapEntry(k.toString(), v.toString())) ?? {},
        valorMensalidadeCustomizado: _safeDouble(financeiro?['valor_customizado']),
        contatoEmergenciaNome: personal?['contatoEmergenciaNome'] ?? data['saude_emergencia']?['contatoEmergenciaNome'],
        contatoEmergenciaTel: personal?['contatoEmergenciaTel'] ?? data['saude_emergencia']?['contatoEmergenciaTel'],
        urlAssinaturaImgbb: data['url_assinatura_imgbb'] ?? data['termos_matricula']?['urlAssinaturaImgbb'],
        assinaturaBase64: data['termos_matricula']?['assinaturaBase64'],
      );
    } catch (e) {
      // FALLBACK SEGURO PARA EVITAR GREY BOX
      return UserProfileData(
        role: 'aluno',
        isAnamneseCompleted: false,
        faixa: 'BRANCA',
        modalidade: ['GERAL'],
        aptoExameFaixa: false,
        uid: uid,
        nome: 'ERRO AO CARREGAR PERFIL',
      );
    }
  }

  static int _calculateAge(String? birthDate) {
    if (birthDate == null || birthDate.isEmpty) return 0;
    try {
      DateTime? birth;
      if (birthDate.contains('/')) {
        final parts = birthDate.split('/');
        birth = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      } else {
        birth = DateTime.tryParse(birthDate);
      }
      
      if (birth == null) return 0;
      
      final now = DateTime.now();
      int age = now.year - birth.year;
      if (now.month < birth.month || (now.month == birth.month && now.day < birth.day)) {
        age--;
      }
      return age;
    } catch (_) {
      return 0;
    }
  }

  String getFaixaFor(String mod) {
    if (faixasPorModalidade.containsKey(mod)) {
      return faixasPorModalidade[mod]!;
    }
    return faixa;
  }

  int resolverMetaExame(Map<String, dynamic> config, {String? targetMod}) {
    final aulasPorAluno = Map<String, dynamic>.from(config['aulas_por_aluno'] ?? {});
    if (aulasPorAluno.containsKey(uid)) {
      final alunoRule = aulasPorAluno[uid];
      if (alunoRule is Map) {
        List<String> modsToTry = targetMod != null ? [targetMod] : modalidade;
        for (var mod in modsToTry) {
          if (alunoRule.containsKey(mod)) return _safeInt(alunoRule[mod]);
        }
        if (alunoRule.containsKey('Geral')) return _safeInt(alunoRule['Geral']);
      } else if (alunoRule is num) {
        return alunoRule.toInt();
      }
    }

    final metasGraduacao = Map<String, dynamic>.from(config['metas_graduacao'] ?? {});
    final aulasPorModalidade = Map<String, dynamic>.from(config['aulas_por_modalidade'] ?? {});
    
    List<String> mods = targetMod != null ? [targetMod] : modalidade;
    int metaMaisAlta = 0;

    for (var mod in mods) {
      int metaMod = 0;
      final currentFaixa = getFaixaFor(mod);
      
      if (metasGraduacao.containsKey(mod)) {
        final faixasMod = Map<String, dynamic>.from(metasGraduacao[mod] ?? {});
        metaMod = _safeInt(faixasMod[currentFaixa] ?? faixasMod['Geral']);
      }
      
      if (metaMod == 0 && aulasPorModalidade.containsKey(mod)) {
        metaMod = _safeInt(aulasPorModalidade[mod]);
      }

      if (metaMod > metaMaisAlta) metaMaisAlta = metaMod;
    }
    
    if (metaMaisAlta > 0) return metaMaisAlta;

    // 3. Fallback Global
    return _safeInt(config['minimo_aulas_exame'] ?? 40);
  }

  /// Resolve a meta de KI (Pontos Teóricos) de forma hierárquica
  int resolverMetaKi(Map<String, dynamic> config, {String? targetMod}) {
    // 1. Exceção por ALUNO (Prioridade Máxima)
    final kiPorAluno = Map<String, dynamic>.from(config['ki_por_aluno'] ?? {});
    if (kiPorAluno.containsKey(uid)) {
      final alunoRule = kiPorAluno[uid];
      if (alunoRule is Map) {
        List<String> modsToTry = targetMod != null ? [targetMod] : modalidade;
        for (var mod in modsToTry) {
          if (alunoRule.containsKey(mod)) return (alunoRule[mod] as num).toInt();
        }
        if (alunoRule.containsKey('Geral')) return (alunoRule['Geral'] as num).toInt();
      }
    }
    // 2. Fallback Global
    return _safeInt(config['meta_ki_padrao'] ?? 100);
  }

  FinancialState get financialStatus {
    // 1. REGRA WELLHUB / TOTALPASS (Solicitado: Retorne status 'Regular/Gerenciado')
    if (planoCorporativo != 'nenhum' && planoCorporativo != 'particular') {
      return FinancialState.regularGerenciado;
    }

    // 2. REGRA TAXA DE ADESÃO (Particular)
    if (!temAdesao) {
      return FinancialState.adesaoPendente;
    }

    // 3. REGRA MENSALIDADE
    if (statusPagamento.toLowerCase() == 'pago' || ultimaConfirmacao != null || statusPagamento.toLowerCase() == 'approved') {
      final now = DateTime.now();
      if (ultimaConfirmacao != null) {
        final diff = now.difference(ultimaConfirmacao!).inDays;
        if (diff > 30) {
          return FinancialState.vencido; // "Mensalidade Atrasada" (> 30 dias)
        }
      }
      return FinancialState.pago;
    }

    if (proximoVencimento == null) return FinancialState.pendente;
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final vencimento = DateTime(proximoVencimento!.year, proximoVencimento!.month, proximoVencimento!.day);
    
    if (today.isAfter(vencimento)) {
      return FinancialState.vencido;
    }
    return FinancialState.pendente;
  }
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is String) {
    if (value.isEmpty) return null;
    try {
      // 1. Tentar formato dd/MM/yyyy
      final slashParts = value.split('/');
      if (slashParts.length == 3) {
        return DateTime(int.parse(slashParts[2]), int.parse(slashParts[1]), int.parse(slashParts[0]));
      }

      // 2. Parser para formato longo: "13 de abril de 2026 às 02:37:18 UTC-3"
      final regex = RegExp(r"(\d{1,2}) de (\w+) de (\d{4})");
      final match = regex.firstMatch(value.toLowerCase());
      
      if (match != null) {
        final day = int.parse(match.group(1)!);
        final monthStr = match.group(2)!;
        final year = int.parse(match.group(3)!);
        
        const monthsPt = {
          'janeiro': 1, 'fevereiro': 2, 'março': 3, 'abril': 4,
          'maio': 5, 'junho': 6, 'julho': 7, 'agosto': 8,
          'setembro': 9, 'outubro': 10, 'novembro': 11, 'dezembro': 12
        };
        
        final month = monthsPt[monthStr] ?? 1;
        return DateTime(year, month, day);
      }
    } catch (_) {}
  }
  return null;
}

List<String> _parseModalidades(dynamic value) {
  if (value == null) return ['Geral'];
  if (value is String) return [value];
  if (value is List) return List<String>.from(value);
  return ['Geral'];
}

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final userProfileProvider = StreamProvider<UserProfileData?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);

  // Gatilho para Notificações removido daqui para evitar loop infinito
  // A sincronização agora é feita via initState nas páginas principais

  return FirebaseFirestore.instance
      .collection(FirebaseCollections.alunos)
      .doc(user.uid)
      .snapshots()
      .asyncMap((doc) async {
    if (doc.exists && doc.data() != null) {
      final data = doc.data()!;
      final personal = data['dados_pessoais'] as Map<String, dynamic>?;
      final financeiro = data['financeiro'] as Map<String, dynamic>?;

      // PARSER FINANCEIRO RIGOROSO (Sincronizado com o Webhook)
      final statusMP = financeiro?['statusPagamento'] as String? ?? financeiro?['status'] as String? ?? 'pendente';
      
      final dataUltimoRaw = financeiro?['data_ultimo_pagamento'] ?? financeiro?['dataPagamento'];
      final DateTime? dataPagamento = _parseDate(dataUltimoRaw) ?? (data['ultima_confirmacao'] as Timestamp?)?.toDate();
      
      final proxVencRaw = financeiro?['proximo_vencimento'] ?? financeiro?['proximoVencimento'];
      DateTime? proximoVencimento = _parseDate(proxVencRaw);
      
      if (proximoVencimento == null && dataPagamento != null) {
        proximoVencimento = dataPagamento.add(const Duration(days: 30));
      }

      // Busca adesão via .get() para evitar Stream aninhado
      final adesaoSnap = await FirebaseFirestore.instance
          .collection(FirebaseCollections.alunos)
          .doc(user.uid)
          .collection('historicoPagamentos')
          .where('tipo', isEqualTo: 'adesao')
          .limit(1)
          .get();
      final temAdesao = adesaoSnap.docs.isNotEmpty;

      final profile = UserProfileData.fromMap(doc.id, data);
      
      // Adiciona o campo temAdesao que não está no fromMap básico
      // (Poderíamos mover isso para o fromMap se fôssemos passar o snap, mas fromMap usa Map)
      // Para manter simples, vamos apenas garantir que o profile retornado seja o correto.
      // Na verdade, o fromMap já retorna o profile. Se precisarmos de temAdesao, 
      // podemos precisar de um copyWith ou ajustar o fromMap.
      // Dado que temAdesao é específico do StreamProvider por enquanto:
      
      return UserProfileData(
        role: profile.role,
        isAnamneseCompleted: profile.isAnamneseCompleted,
        faixa: profile.faixa,
        modalidade: profile.modalidade,
        aptoExameFaixa: profile.aptoExameFaixa,
        uid: profile.uid,
        nome: profile.nome,
        fotoUrl: profile.fotoUrl,
        peso: profile.peso,
        altura: profile.altura,
        idade: profile.idade,
        nascimento: profile.nascimento,
        termoResponsabilidadeUrl: profile.termoResponsabilidadeUrl,
        frequenciaTotal: profile.frequenciaTotal,
        statusPagamento: profile.statusPagamento,
        ultimaConfirmacao: profile.ultimaConfirmacao,
        proximoVencimento: profile.proximoVencimento,
        vencimentoIsencao: profile.vencimentoIsencao,
        idUltimoPagamento: profile.idUltimoPagamento,
        cpfRg: profile.cpfRg,
        statusAptidao: profile.statusAptidao,
        urlAtestado: profile.urlAtestado,
        temAtestado: profile.temAtestado,
        isTermsAccepted: profile.isTermsAccepted,
        temAdesao: temAdesao,
        faixasPorModalidade: profile.faixasPorModalidade,
        planoCorporativo: profile.planoCorporativo,
        statusAcesso: profile.statusAcesso,
        carreira: profile.carreira,
        progresso: profile.progresso,
        kiPorModalidade: profile.kiPorModalidade,
        patchesPorModalidade: profile.patchesPorModalidade,
        valorMensalidadeCustomizado: profile.valorMensalidadeCustomizado,
        cpf: profile.cpf,
        rg: profile.rg,
        contatoEmergenciaNome: profile.contatoEmergenciaNome,
        contatoEmergenciaTel: profile.contatoEmergenciaTel,
        urlAssinaturaImgbb: profile.urlAssinaturaImgbb,
        assinaturaBase64: profile.assinaturaBase64,
      );

      // Sincronização de lembretes removida daqui para evitar loop infinito

      return profile;
    }
    return null;
  });
});

int _safeInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

double? _safeDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}
