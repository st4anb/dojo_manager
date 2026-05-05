import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class FinanceSummary {
  final double totalRecebido;
  final double totalPendente;
  final double totalPrevisto;
  final int alunosPagos;
  final int alunosAtrasados;
  final Map<String, int> corporateCounts; // {'wellhub': 5, 'totalpass': 3}
  final List<Map<String, dynamic>> alunosDetalhados;

  FinanceSummary({
    required this.totalRecebido,
    required this.totalPendente,
    required this.totalPrevisto,
    required this.alunosPagos,
    required this.alunosAtrasados,
    required this.corporateCounts,
    required this.alunosDetalhados,
  });

  double get adimplenciaRate => (alunosPagos + alunosAtrasados) > 0 
    ? (alunosPagos / (alunosPagos + alunosAtrasados)) * 100 
    : 0;
}

class FinanceService {
  static FinanceSummary calculateSummaryFromDocs(List<QueryDocumentSnapshot> docs) {
      final now = DateTime.now();
      final hoje = DateTime(now.year, now.month, now.day);
      
      double totalRecebido = 0;
      double totalPendente = 0;
      double totalPrevisto = 0;
      int alunosPagosCount = 0;
      int alunosAtrasadosCount = 0;
      Map<String, int> corpCounts = {'wellhub': 0, 'totalpass': 0};
      List<Map<String, dynamic>> detalhados = [];

      for (var doc in docs) {
        try {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          final financeiro = data['financeiro'] as Map<String, dynamic>? ?? {};
          final personal = data['dados_pessoais'] as Map<String, dynamic>? ?? {};
          
          final String planoCorp = data['plano_corporativo']?.toString() ?? 'nenhum';
          final bool isCorp = planoCorp != 'nenhum';
          final bool isAtivo = data['status']?.toString() != 'inativo';

          // REGRAS DE NEGÓCIO: Só entra no financeiro se for ATIVO
          if (isAtivo) {
            // Incrementa contagem corporativa
            if (isCorp && corpCounts.containsKey(planoCorp)) {
              corpCounts[planoCorp] = (corpCounts[planoCorp] ?? 0) + 1;
            }

            // EXTRAÇÃO DE DADOS FINANCEIROS
            final statusMP = financeiro['statusPagamento']?.toString() ?? financeiro['status']?.toString() ?? 'pendente';
            final status = statusMP.toLowerCase();
            debugPrint('Status Pagamento: $status');
            
            final vencTs = financeiro['data_vencimento'] as Timestamp? ?? data['proximo_vencimento'] as Timestamp?;
            final DateTime? vencDate = vencTs?.toDate();
            final bool isVencido = vencDate != null && vencDate.isBefore(hoje) && status != 'approved' && status != 'pago';

            // Conversão segura de valores (aceita num, String ou null)
            double parseDouble(dynamic value, double fallback) {
              if (value == null) return fallback;
              if (value is num) return value.toDouble();
              return double.tryParse(value.toString()) ?? fallback;
            }

            final double valorPlano = parseDouble(financeiro['mensalidade_personalizada'], 75.0);
            
            final double valorPago = parseDouble(financeiro['valor_ultimo_pagamento'], 0.0);

            if (!isCorp) {
              totalPrevisto += valorPlano;

              if (status == 'pago' || status == 'approved') {
                totalRecebido += valorPago > 0 ? valorPago : valorPlano;
                alunosPagosCount++;
              } else {
                totalPendente += valorPlano;
                alunosAtrasadosCount++;
              }
            }

            detalhados.add({
              'id': doc.id,
              'nome': personal['nome']?.toString() ?? data['nome']?.toString() ?? 'Inominado',
              'valor': valorPlano,
              'status': isCorp ? 'CORPORATIVO' : (isVencido ? 'VENCIDO' : (status == 'pago' || status == 'approved' ? 'PAGO' : 'PENDENTE')),
              'vencimento': vencTs,
              'telefone': personal['telefone']?.toString() ?? data['telefone']?.toString(),
              'plano_corporativo': planoCorp,
            });
          }
        } catch (e) {
          // Se um documento falhar, ignoramos ele para não quebrar o dashboard inteiro
          debugPrint('Erro ao processar aluno ${doc.id} no FinanceService: $e');
        }
      }

      return FinanceSummary(
        totalRecebido: totalRecebido,
        totalPendente: totalPendente,
        totalPrevisto: totalPrevisto,
        alunosPagos: alunosPagosCount,
        alunosAtrasados: alunosAtrasadosCount,
        corporateCounts: corpCounts,
        alunosDetalhados: detalhados,
      );
  }
}
