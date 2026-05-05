import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'dart:typed_data';

class DossiePdfGenerator {
  static Future<void> generateAndDownload(Map<String, dynamic> studentData, String studentId, {List<Map<String, dynamic>>? paymentHistory}) async {
    final pdf = pw.Document();
    
    final personal = studentData['dados_pessoais'] as Map<String, dynamic>? ?? {};
    final financeiro = studentData['financeiro'] as Map<String, dynamic>? ?? {};
    final String nome = personal['nome'] ?? studentData['nome'] ?? '---';
    final String faixa = personal['faixa'] ?? 'BRANCA';
    final String matricula = personal['data_matricula'] ?? '---';
    final String modalidade = (studentData['modalidade'] is List) 
        ? (studentData['modalidade'] as List).join(', ') 
        : (studentData['modalidade']?.toString() ?? '---');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          // CABEÇALHO
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('DOJO MANAGER', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.amber)),
                  pw.Text('DOSSIÊ 360º DO ALUNO', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Emissão: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text('ID: $studentId', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Divider(thickness: 2, color: PdfColors.amber),
          pw.SizedBox(height: 20),

          // SESSÃO 1: DADOS PESSOAIS
          pw.Text('1. INFORMAÇÕES DO ATLETA', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.Row(
            children: [
              pw.Expanded(child: _buildInfoItem('Nome', nome)),
              pw.Expanded(child: _buildInfoItem('CPF', personal['cpf'] ?? '---')),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              pw.Expanded(child: _buildInfoItem('E-mail', personal['email'] ?? studentData['email'] ?? '---')),
              pw.Expanded(child: _buildInfoItem('Telefone', personal['telefone'] ?? '---')),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              pw.Expanded(child: _buildInfoItem('Peso', '${personal['peso'] ?? '---'} KG')),
              pw.Expanded(child: _buildInfoItem('Altura', '${personal['altura'] ?? '---'} CM')),
              pw.Expanded(child: _buildInfoItem('Idade', '${personal['idade'] ?? '---'} ANOS')),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              pw.Expanded(child: _buildInfoItem('Matrícula', matricula)),
              pw.Expanded(child: _buildInfoItem('Faixa Atual', faixa.toUpperCase())),
            ],
          ),
          pw.SizedBox(height: 8),
          _buildInfoItem('Modalidades Ativas', modalidade),
          pw.SizedBox(height: 8),
          _buildInfoItem('Endereço', 
            '${studentData['endereco']?['logradouro'] ?? ''}, ${studentData['endereco']?['numero'] ?? ''} - ${studentData['endereco']?['bairro'] ?? ''} | ${studentData['endereco']?['cidade'] ?? ''}'),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              pw.Expanded(child: _buildInfoItem('Contato Emergência', personal['contatoEmergenciaNome'] ?? studentData['saude_emergencia']?['contatoEmergenciaNome'] ?? '---')),
              pw.Expanded(child: _buildInfoItem('Tel. Emergência', personal['contatoEmergenciaTel'] ?? studentData['saude_emergencia']?['contatoEmergenciaTel'] ?? '---')),
            ],
          ),
          
          pw.SizedBox(height: 30),

          // SESSÃO 2: PERFORMANCE & GAMIFICAÇÃO
          pw.Text('2. PERFORMANCE & GAMIFICAÇÃO', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.Row(
            children: [
              pw.Expanded(child: _buildInfoItem('Treinos (Físico)', '${studentData['frequenciaTotal'] ?? 0}')),
              pw.Expanded(child: _buildInfoItem('KI (Teórico)', '${studentData['ki_total'] ?? 0} PTS')),
            ],
          ),

          pw.SizedBox(height: 30),

          // SESSÃO 3: HISTÓRICO FINANCEIRO
          pw.Text('3. EXTRATO FINANCEIRO DETALHADO', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.Table.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.amber),
            cellHeight: 25,
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.center,
              2: pw.Alignment.center,
              3: pw.Alignment.center,
            },
            data: <List<String>>[
              ['Referência', 'Status', 'Valor', 'Data Pagamento'],
              if (paymentHistory != null && paymentHistory.isNotEmpty)
                ...paymentHistory.map((p) => [
                  p['referencia'] ?? '---',
                  (p['status'] ?? '---').toUpperCase(),
                  'R\$ ' + (p['valor'] ?? '---').toString(),
                  p['dataPagamento'] != null ? DateFormat('dd/MM/yyyy').format(p['dataPagamento']) : '---',
                ])
              else
                [
                  DateFormat('MMMM / yyyy', 'pt_BR').format(DateTime.now()).toUpperCase(),
                  (financeiro['status'] ?? 'PENDENTE').toString().toUpperCase(),
                  'R\$ ' + (studentData['valor_mensalidade'] ?? '---').toString(),
                  financeiro['data_pagamento'] != null 
                      ? DateFormat('dd/MM/yyyy').format((financeiro['data_pagamento'] as dynamic).toDate())
                      : '---',
                ],
            ],
          ),

          pw.Spacer(),

          // RODAPÉ
          pw.Divider(thickness: 0.5, color: PdfColors.grey300),
          pw.SizedBox(height: 5),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Documento oficial Dojo Manager V16 - Force Sync', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
              pw.Text('Emitido em: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Dossie_360_${nome.replaceAll(' ', '_')}.pdf',
    );
  }

  static pw.Widget _buildInfoItem(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label.toUpperCase(), style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
        pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }
}
