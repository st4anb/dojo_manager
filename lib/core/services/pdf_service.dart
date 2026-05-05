import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'finance_service.dart';

class PdfService {
  static Future<void> generateFinancialReport(FinanceSummary summary) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(now);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // CADEÇALHO
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('C.T. PANDORA', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.amber800)),
                    pw.Text('Dojo Manager - Relatório Financeiro', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                  ],
                ),
                pw.Text(dateStr, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
              ],
            ),
            pw.Divider(thickness: 2, color: PdfColors.amber800),
            pw.SizedBox(height: 20),

            // DASHBOARD SUMMARY
            pw.Text('RESUMO DO PERÍODO', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                _buildSummaryRow('Receita Total Prevista', 'R\$ ${summary.totalPrevisto.toStringAsFixed(2)}'),
                _buildSummaryRow('Receita Confirmada (Paga)', 'R\$ ${summary.totalRecebido.toStringAsFixed(2)}', valueColor: PdfColors.green),
                _buildSummaryRow('Receita Pendente/Atrasada', 'R\$ ${summary.totalPendente.toStringAsFixed(2)}', valueColor: PdfColors.red),
                _buildSummaryRow('Taxa de Adimplência', '${summary.adimplenciaRate.toStringAsFixed(1)}%'),
              ],
            ),
            pw.SizedBox(height: 32),

            // DETALHAMENTO DE ALUNOS
            pw.Text('LISTA DETALHADA DE ALUNOS', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey100),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1.5),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.5),
              },
              children: [
                // CABEÇALHO TABELA
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _buildCell('NOME', isHeader: true),
                    _buildCell('VALOR', isHeader: true),
                    _buildCell('VENCIMENTO', isHeader: true),
                    _buildCell('STATUS', isHeader: true),
                  ],
                ),
                // LINHAS DE ALUNOS
                ...summary.alunosDetalhados.map((aluno) {
                  final status = aluno['status'] ?? '---';
                  final isVencido = status == 'VENCIDO';
                  final venc = aluno['vencimento'] != null 
                    ? DateFormat('dd/MM/yy').format(aluno['vencimento'].toDate()) 
                    : '---';

                  return pw.TableRow(
                    children: [
                      _buildCell(aluno['nome']?.toString().toUpperCase() ?? 'ALUNO', isVencido: isVencido),
                      _buildCell('R\$ ${aluno['valor'].toStringAsFixed(2)}', isVencido: isVencido),
                      _buildCell(venc, isVencido: isVencido),
                      _buildCell(status, isVencido: isVencido, highlightStatus: true),
                    ],
                  );
                }),
              ],
            ),
            
            pw.SizedBox(height: 48),
            pw.Center(
              child: pw.Text('Este documento é para uso interno e administrativo. OSS!', style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, color: PdfColors.grey)),
            ),
          ];
        },
      ),
    );

    // ABRE PRÉVIA DE IMPRESSÃO
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Relatorio_Financeiro_${now.millisecondsSinceEpoch}.pdf',
    );
  }

  static pw.TableRow _buildSummaryRow(String label, String value, {PdfColor? valueColor}) {
    return pw.TableRow(
      children: [
        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(label)),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8), 
          child: pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: valueColor ?? PdfColors.black)),
        ),
      ],
    );
  }

  static pw.Widget _buildCell(String text, {bool isHeader = false, bool isVencido = false, bool highlightStatus = false}) {
    PdfColor color = PdfColors.black;
    pw.FontWeight weight = isHeader ? pw.FontWeight.bold : pw.FontWeight.normal;
    
    if (isVencido) {
      color = PdfColors.red;
      weight = pw.FontWeight.bold;
    } else if (highlightStatus && text == 'PAGO') {
      color = PdfColors.green;
      weight = pw.FontWeight.bold;
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 9 : 8,
          fontWeight: weight,
          color: color,
        ),
      ),
    );
  }
}
