import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';
import '../constants/legal_texts.dart';
import 'package:intl/intl.dart';

class TermoPdfGenerator {
  /// Gera os bytes do PDF do Termo de Responsabilidade sob demanda.
  static Future<Uint8List> generatePdf(Map<String, dynamic> data) async {
    final pdf = pw.Document(compress: true);
    final bool isMenor = (data['idade'] ?? 0) < 18;
    final DateTime dataAssinatura = data['dataAssinatura'] != null 
        ? (data['dataAssinatura'] as dynamic).toDate() 
        : DateTime.now();
    
    final String formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(dataAssinatura);
    
    // Tratamento da Assinatura (Bytes Diretos ou Base64 do Firestore)
    Uint8List? signatureBytes;
    if (data['signatureBytes'] != null) {
      signatureBytes = data['signatureBytes'];
    } else if (data['termos_matricula'] != null && data['termos_matricula']['assinaturaBase64'] != null) {
      signatureBytes = base64Decode(data['termos_matricula']['assinaturaBase64']);
    }

    // Extração de CPF/RG (Suporte a legado e novo formato unificado)
    final String fullDoc = data['cpf_rg'] ?? '${data['cpf'] ?? '---'} / ${data['rg'] ?? '---'}';
    final List<String> docParts = fullDoc.split('/');
    final String displayCpf = docParts.isNotEmpty ? docParts[0].trim() : '---';
    final String displayRg = docParts.length > 1 ? docParts[1].trim() : '---';

    // PREPARAÇÃO DO TEXTO DINÂMICO
    String termText = isMenor ? LegalTexts.termoMenor : LegalTexts.termoMaior;
    if (isMenor) {
      termText = termText.replaceAll('[NOME DO RESPONSÁVEL LEGAL]', data['responsavel_nome'] ?? '---')
                         .replaceAll('[NÚMERO DO RG DO RESPONSÁVEL]', data['responsavel_rg'] ?? '---')
                         .replaceAll('[NÚMERO DO CPF DO RESPONSÁVEL]', data['responsavel_cpf'] ?? '---')
                         .replaceAll('[NOME DO ALUNO MENOR]', data['nome'] ?? '---')
                         .replaceAll('[RG DO MENOR]', displayRg)
                         .replaceAll('[CPF DO MENOR]', displayCpf);
    } else {
      termText = termText.replaceAll('[NOME COMPLETO DO ALUNO]', data['nome'] ?? '---')
                         .replaceAll('[NÚMERO DO RG]', displayRg)
                         .replaceAll('[NÚMERO DO CPF]', displayCpf);
    }

    // Página Única Unificada (ou múltiplas se transbordar, pw.Page lida com isso)
    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) => [
          // 1º) LGPD
          pw.Header(
            level: 0,
            child: pw.Text('POLÍTICA DE PRIVACIDADE E CONSENTIMENTO (LGPD)', 
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
          ),
          pw.SizedBox(height: 10),
          pw.Text(LegalTexts.lgpdTerm.trim(), textAlign: pw.TextAlign.justify, style: const pw.TextStyle(fontSize: 10)),
          
          pw.SizedBox(height: 20),
          pw.Divider(thickness: 0.5, color: PdfColors.grey300),
          pw.SizedBox(height: 20),

          // 2º) Título Responsabilidade
          pw.Header(
            level: 0,
            child: pw.Text('TERMO DE RESPONSABILIDADE E ASSUNÇÃO DE RISCOS', 
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
          ),
          pw.SizedBox(height: 10),

          // 3º) Texto da Responsabilidade (Injetando dados se necessário)
          pw.Text(
            termText,
            textAlign: pw.TextAlign.justify,
            style: const pw.TextStyle(fontSize: 10),
          ),
          
          pw.SizedBox(height: 10),
          
          // ASSINATURA VISUAL (PNG EXPORTADO DO CANVAS)
          if (signatureBytes != null) ...[
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Image(
                    pw.MemoryImage(signatureBytes),
                    height: 80,
                    fit: pw.BoxFit.contain,
                  ),
                  pw.Container(
                    width: 200,
                    child: pw.Divider(thickness: 1, color: PdfColors.black),
                  ),
                  pw.Text('Assinatura Eletrônica do Aluno', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
          ],

          pw.Header(
            level: 1,
            child: pw.Text('COMPROVANTE DE AUTENTICIDADE REGISTRADO', 
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.blue)),
          ),
          pw.SizedBox(height: 5),
          pw.Text('IP/ID do Registro: ${data['uid'] ?? 'N/A'}', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          pw.Text('Data/Hora do Aceite Digital: $formattedDate', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 15),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey200)),
            child: pw.Text('Documento gerado pelo sistema Dojo Manager. A validade jurídica é garantida pelo consentimento digital e registro auditável vinculado ao CPF do titular.',
              style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic),
            ),
          ),
        ],
      ),
    );

    return await pdf.save();
  }
}
