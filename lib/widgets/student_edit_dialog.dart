import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import '../core/services/image_upload_service.dart';

import '../core/theme/app_theme.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/constants/firebase_collections.dart';

Future<String?> _uploadProfileImage(String uid, {required ImageSource source}) async {
  if (source == ImageSource.camera) {
    var status = await Permission.camera.request();
    if (status.isPermanentlyDenied) {
      openAppSettings();
      return null;
    }
    if (!status.isGranted) return null;
  }

  final picker = ImagePicker();
  final XFile? image = await picker.pickImage(source: source);
  
  if (image == null) return null;

  return await ImageUploadService.uploadImage(image);
}

void showEditStudentDialog(BuildContext context, DocumentSnapshot doc) {
  final data = doc.data() as Map<String, dynamic>;
  final carreira = data['carreira'] as Map<String, dynamic>? ?? {};
  final endereco = data['endereco'] as Map<String, dynamic>? ?? {};
  final emergencia = data['contato_emergencia'] is Map 
      ? data['contato_emergencia'] as Map<String, dynamic> 
      : {'nome': data['contato_emergencia'] ?? '', 'telefone': '', 'parentesco': ''};
  
  final String nomeInicial = (data['dados_pessoais']?['nome'] as String?) ?? 
                             (data['nome'] as String?) ?? 
                             (data['aluno_nome'] as String?) ?? 
                             (data['display_name'] as String?) ?? 
                             (data['displayName'] as String?) ?? 
                             '';
  final nomeCtrl = TextEditingController(text: nomeInicial);
  final pesoCtrl = TextEditingController(text: data['peso']?.toString() ?? data['dados_pessoais']?['peso']?.toString() ?? '');
  final alturaCtrl = TextEditingController(text: data['altura']?.toString() ?? data['dados_pessoais']?['altura']?.toString() ?? '');
  final idadeCtrl = TextEditingController(text: data['idade']?.toString() ?? data['dados_pessoais']?['idade']?.toString() ?? '');
  
  // MODALIDADES E FAIXAS (Novo Modelo)
  final dynamic rawModalidade = data['modalidade'] ?? data['dados_pessoais']?['modalidade'];
  List<String> modalidadesSelecionadas = [];
  if (rawModalidade is List) {
    modalidadesSelecionadas = List<String>.from(rawModalidade);
  } else if (rawModalidade is String && rawModalidade.isNotEmpty) {
    modalidadesSelecionadas = [rawModalidade];
  }
  if (modalidadesSelecionadas.isEmpty) modalidadesSelecionadas = ['Geral'];

  String selectedModForBelt = modalidadesSelecionadas.first;
  final Map<String, String> faixasPorMod = Map<String, String>.from(data['faixas_por_modalidade'] ?? data['dados_pessoais']?['faixas_por_modalidade'] ?? {});
  
  // Inicialização da Faixa com fallback
  final faixaCtrl = TextEditingController(text: faixasPorMod[selectedModForBelt] ?? data['faixa'] ?? 'BRANCA');
  
  // Endereço
  final cepCtrl = TextEditingController(text: endereco['cep']?.toString() ?? '');
  final logradouroCtrl = TextEditingController(text: endereco['logradouro']?.toString() ?? '');
  final numeroCtrl = TextEditingController(text: endereco['numero']?.toString() ?? '');
  final bairroCtrl = TextEditingController(text: endereco['bairro']?.toString() ?? '');
  final cidadeCtrl = TextEditingController(text: endereco['cidade']?.toString() ?? '');
  final estadoCtrl = TextEditingController(text: endereco['estado']?.toString() ?? '');
  final complementoCtrl = TextEditingController(text: endereco['complemento']?.toString() ?? '');

  // Emergência
  final emergenciaNomeCtrl = TextEditingController(text: emergencia['nome']?.toString() ?? '');
  final emergenciaTelCtrl = TextEditingController(text: emergencia['telefone']?.toString() ?? '');
  final emergenciaParCtrl = TextEditingController(text: emergencia['parentesco']?.toString() ?? '');

  final vitoriasCtrl = TextEditingController(text: carreira['vitorias']?.toString() ?? '0');
  final derrotasCtrl = TextEditingController(text: carreira['derrotas']?.toString() ?? '0');
  final trofeusCtrl = TextEditingController(text: carreira['trofeus']?.toString() ?? '0');
  final medalhasCtrl = TextEditingController(text: carreira['medalhas']?.toString() ?? '0');
  final cinturoesCtrl = TextEditingController(text: carreira['cinturoes']?.toString() ?? '0');
  final campsCtrl = TextEditingController(text: carreira['campeonatos_disputados']?.toString() ?? '0');
  
  List<String> certificados = List<String>.from(carreira['certificados'] ?? []);
  final certCtrl = TextEditingController();
  
  // PRECIFICAÇÃO (Novo Modelo)
  final financeiro = data['financeiro'] as Map<String, dynamic>? ?? {};
  final precoCtrl = TextEditingController(text: (financeiro['mensalidade_personalizada'] ?? '').toString());
  
  // Documentação (CPF/RG) - Suporte a legado ou novo formato
  final String docFull = data['cpf_rg'] ?? '${data['cpf'] ?? ''} / ${data['rg'] ?? ''}';
  final docCtrl = TextEditingController(text: docFull);
  

  bool isUploading = false;
  final formKey = GlobalKey<FormState>();

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        backgroundColor: AppTheme.cardDarkGrey,
        title: Row(
          children: [
            const Icon(LucideIcons.shieldCheck, color: AppTheme.accentGold),
            const SizedBox(width: 12),
            const Expanded(child: Text('Gestão de Carreira', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
          ],
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Avatar
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: AppTheme.backgroundBlack,
                        backgroundImage: data['foto_url'] != null ? NetworkImage(data['foto_url']) : null,
                        child: data['foto_url'] == null ? const Icon(LucideIcons.user, size: 50, color: AppTheme.textGrey) : null,
                      ),
                      Positioned(
                        bottom: 0, right: 0,
                        child: CircleAvatar(
                          backgroundColor: AppTheme.accentGold,
                          radius: 18,
                          child: isUploading 
                            ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                            : IconButton(
                                icon: const Icon(LucideIcons.camera, size: 18, color: Colors.black),
                                onPressed: () async {
                                  showModalBottomSheet(
                                    context: context,
                                    backgroundColor: AppTheme.cardDarkGrey,
                                    builder: (ctx) => Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ListTile(
                                          leading: const Icon(LucideIcons.camera, color: AppTheme.accentGold),
                                          title: const Text('Tirar Selfie', style: TextStyle(color: Colors.white)),
                                          onTap: () async {
                                            Navigator.pop(ctx);
                                            setDialogState(() => isUploading = true);
                                            final url = await _uploadProfileImage(doc.id, source: ImageSource.camera);
                                            if (url != null) {
                                              await doc.reference.update({'foto_url': url});
                                              if (context.mounted) {
                                                Navigator.pop(context);
                                                showEditStudentDialog(context, doc);
                                              }
                                            }
                                            setDialogState(() => isUploading = false);
                                          },
                                        ),
                                        ListTile(
                                          leading: const Icon(LucideIcons.image, color: AppTheme.accentGold),
                                          title: const Text('Galeria', style: TextStyle(color: Colors.white)),
                                          onTap: () async {
                                            Navigator.pop(ctx);
                                            setDialogState(() => isUploading = true);
                                            final url = await _uploadProfileImage(doc.id, source: ImageSource.gallery);
                                            if (url != null) {
                                              await doc.reference.update({'foto_url': url});
                                              if (context.mounted) {
                                                Navigator.pop(context);
                                                showEditStudentDialog(context, doc);
                                              }
                                            }
                                            setDialogState(() => isUploading = false);
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionHeader('DADOS CADASTRAIS'),
                _buildTextField('Nome Completo 👤', nomeCtrl, icon: LucideIcons.user, isRequired: true),
                const SizedBox(height: 16),
                
                        const SizedBox(height: 16),
                        _buildSectionHeader('GRADUAÇÃO ESPECÍFICA'),
                        const SizedBox(height: 8),
                        const Text('Selecione a modalidade que deseja graduar:', style: TextStyle(color: AppTheme.textGrey, fontSize: 10)),
                        const SizedBox(height: 8),
                        
                        // SELETOR DE MODALIDADE PARA GRADUAÇÃO
                        DropdownButtonFormField<String>(
                          initialValue: selectedModForBelt,
                          dropdownColor: AppTheme.cardDarkGrey,
                          style: const TextStyle(color: AppTheme.accentGold, fontWeight: FontWeight.bold),
                          decoration: const InputDecoration(
                            labelText: 'Modalidade Alvo 🎯',
                            labelStyle: TextStyle(color: AppTheme.textGrey, fontSize: 11),
                            prefixIcon: Icon(LucideIcons.target, size: 16, color: AppTheme.accentGold),
                          ),
                          items: modalidadesSelecionadas.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                selectedModForBelt = val;
                                // Atualiza o controller com a faixa já salva para essa modalidade ou fallback
                                faixaCtrl.text = faixasPorMod[val] ?? data['faixa'] ?? 'BRANCA';
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance.collection('config').doc('modalidades').collection('esportes').doc(selectedModForBelt).snapshots(),
                          builder: (context, faixaSnap) {
                            final faixaData = faixaSnap.data?.data() as Map<String, dynamic>?;
                            final List<String> faixasDisponiveis = List<String>.from(faixaData?['faixas'] ?? ['BRANCA', 'CINZA', 'AMARELA', 'LARANJA', 'VERDE', 'AZUL', 'ROXA', 'MARROM', 'PRETA']);

                            return Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    key: ValueKey(selectedModForBelt), // Força rebuild ao trocar mod
                                    initialValue: faixasDisponiveis.contains(faixaCtrl.text.toUpperCase()) ? faixaCtrl.text.toUpperCase() : faixasDisponiveis.first,
                                    dropdownColor: AppTheme.cardDarkGrey,
                                    style: const TextStyle(color: Colors.white, fontSize: 13),
                                    decoration: const InputDecoration(
                                      labelText: 'Alterar para Faixa 🏅',
                                      labelStyle: TextStyle(color: AppTheme.textGrey, fontSize: 11),
                                      prefixIcon: Icon(LucideIcons.medal, size: 16, color: AppTheme.accentGold),
                                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
                                    ),
                                    items: faixasDisponiveis.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setDialogState(() {
                                          faixaCtrl.text = val;
                                          faixasPorMod[selectedModForBelt] = val; // Atualiza no mapa local
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: _buildTextField('Peso (kg)', pesoCtrl, icon: LucideIcons.gauge, isNumeric: true)),
                              ],
                            );
                          }
                        ),
                Row(
                  children: [
                    Expanded(child: _buildTextField('Altura (m)', alturaCtrl, icon: LucideIcons.ruler, isNumeric: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTextField('Idade', idadeCtrl, isNumeric: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTextField('Preço Fixo (R\$)', precoCtrl, icon: LucideIcons.dollarSign, color: Colors.green, isNumeric: true)),
                  ],
                ),
                if (precoCtrl.text.isEmpty)
                   Padding(
                     padding: EdgeInsets.only(top: 4, bottom: 12),
                     child: Text('Deixe vazio para usar o cálculo automático (Qtd Lutas * Base Global)', style: TextStyle(color: AppTheme.textGrey, fontSize: 9)),
                   ),
                
                const SizedBox(height: 12),
                _buildSectionHeader('CONTATO DE EMERGÊNCIA'),
                _buildTextField('Falar com (Nome)', emergenciaNomeCtrl, icon: LucideIcons.userPlus, color: Colors.orangeAccent),
                Row(
                  children: [
                    Expanded(child: _buildTextField('Telefone', emergenciaTelCtrl, icon: LucideIcons.phoneOutgoing)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTextField('Parentesco', emergenciaParCtrl, icon: LucideIcons.heart)),
                  ],
                ),

                const SizedBox(height: 12),
                _buildSectionHeader('LOCALIZAÇÃO'),
                _buildTextField('CEP', cepCtrl, icon: LucideIcons.mapPin, isNumeric: true),
                Row(
                  children: [
                    Expanded(flex: 3, child: _buildTextField('Logradouro', logradouroCtrl, icon: LucideIcons.home)),
                    const SizedBox(width: 12),
                    Expanded(flex: 1, child: _buildTextField('Nº', numeroCtrl, isNumeric: true)),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: _buildTextField('Bairro', bairroCtrl)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTextField('Cidade', cidadeCtrl)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTextField('UF', estadoCtrl)),
                  ],
                ),
                _buildTextField('Complemento', complementoCtrl),
                
                const SizedBox(height: 12),
                _buildSectionHeader('DOCUMENTAÇÃO'),
                _buildTextField('CPF / RG', docCtrl, icon: LucideIcons.creditCard),

                const SizedBox(height: 24),
                _buildSectionHeader('CONQUISTAS (CARREIRA)'),
                Row(
                  children: [
                    Expanded(child: _buildTextField('Vitórias', vitoriasCtrl, icon: LucideIcons.trophy, color: Colors.green, isNumeric: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTextField('Derrotas', derrotasCtrl, icon: LucideIcons.frown, color: Colors.redAccent, isNumeric: true)),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: _buildTextField('Troféus', trofeusCtrl, icon: LucideIcons.award, color: AppTheme.accentGold, isNumeric: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTextField('Medalhas', medalhasCtrl, icon: LucideIcons.medal, color: Colors.blueAccent, isNumeric: true)),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: _buildTextField('Cinturões', cinturoesCtrl, icon: LucideIcons.crown, color: AppTheme.accentGold, isNumeric: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTextField('Campeonatos', campsCtrl, icon: LucideIcons.swords, isNumeric: true)),
                  ],
                ),

                const SizedBox(height: 24),
                _buildSectionHeader('CARREIRA & CERTIFICADOS'),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: certCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: const InputDecoration(hintText: 'Nome do destaque...', hintStyle: TextStyle(color: AppTheme.textGrey)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(LucideIcons.plusCircle, color: Colors.green),
                      onPressed: () {
                        if (certCtrl.text.isNotEmpty) {
                          setDialogState(() => certificados.add(certCtrl.text.trim()));
                          certCtrl.clear();
                        }
                      },
                    )
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: certificados.map((c) => Chip(
                    label: Text(c, style: const TextStyle(fontSize: 10, color: Colors.white)),
                    onDeleted: () => setDialogState(() => certificados.remove(c)),
                    backgroundColor: AppTheme.backgroundBlack,
                    deleteIconColor: Colors.red,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  )).toList(),
                )
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCELAR', style: TextStyle(color: AppTheme.textGrey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentGold, foregroundColor: Colors.black),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              
              final Map<String, dynamic> careerMap = {
                'vitorias': int.tryParse(vitoriasCtrl.text) ?? 0,
                'derrotas': int.tryParse(derrotasCtrl.text) ?? 0,
                'trofeus': int.tryParse(trofeusCtrl.text) ?? 0,
                'medalhas': int.tryParse(medalhasCtrl.text) ?? 0,
                'cinturoes': int.tryParse(cinturoesCtrl.text) ?? 0,
                'campeonatos_disputados': int.tryParse(campsCtrl.text) ?? 0,
                'certificados': certificados,
              };

              final Map<String, dynamic> enderecoMap = {
                'cep': cepCtrl.text.trim(),
                'logradouro': logradouroCtrl.text.trim(),
                'numero': numeroCtrl.text.trim(),
                'bairro': bairroCtrl.text.trim(),
                'cidade': cidadeCtrl.text.trim(),
                'estado': estadoCtrl.text.trim(),
                'complemento': complementoCtrl.text.trim(),
              };

              final Map<String, dynamic> emergenciaMap = {
                'nome': emergenciaNomeCtrl.text.trim(),
                'telefone': emergenciaTelCtrl.text.trim(),
                'parentesco': emergenciaParCtrl.text.trim(),
              };

              // V15-FIX: PARTIAL UPDATE com DOT NOTATION
              // NÃO sobrescreve o mapa inteiro dados_pessoais!
              // Isso PRESERVA email, telefone, nascimento e todos os dados do cadastro original.
              final Map<String, dynamic> updatePayload = {
                // Atualizações PONTUAIS dentro de dados_pessoais (dot notation)
                'dados_pessoais.nome': nomeCtrl.text.trim(),
                'dados_pessoais.peso': double.tryParse(pesoCtrl.text),
                'dados_pessoais.altura': double.tryParse(alturaCtrl.text),
                'dados_pessoais.idade': int.tryParse(idadeCtrl.text),
                'dados_pessoais.cpf_rg': docCtrl.text.trim(),
                'dados_pessoais.modalidade': modalidadesSelecionadas,
                'dados_pessoais.faixas_por_modalidade': faixasPorMod,
                'dados_pessoais.faixa': faixaCtrl.text.trim().toUpperCase(),
                
                // Campos na raiz (backup para queries legadas)
                'nome': nomeCtrl.text.trim(),
                'modalidade': modalidadesSelecionadas,
                'faixa': faixaCtrl.text.trim().toUpperCase(),
                
                // Endereço e Emergência (mapas separados, seguros para sobrescrever)
                'endereco': enderecoMap,
                'contato_emergencia': emergenciaMap,
                
                // Carreira e Financeiro
                'carreira': careerMap,
                'financeiro.mensalidade_personalizada': precoCtrl.text.isEmpty ? null : double.tryParse(precoCtrl.text.replaceAll(',', '.')),
              };

              await doc.reference.update(updatePayload);

              // 2. Sincronizar com Módulo Financeiro (Matrículas)
              try {
                await FirebaseFirestore.instance.collection(FirebaseCollections.matriculas).doc(doc.id).set({
                  'valor_plano': double.tryParse(precoCtrl.text.replaceAll(',', '.')) ?? 75.0,
                  'nome': nomeCtrl.text.trim(),
                }, SetOptions(merge: true));
              } catch (e) {
                debugPrint('Erro não-crítico ao sincronizar matrícula: $e');
              }

              if (context.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perfil do Aluno e Financeiro atualizados!')));
              }
            },
            child: const Text('SALVAR ALTERAÇÕES'),
          ),
        ],
      ),
    ),
  );
}

Widget _buildSectionHeader(String title) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(color: AppTheme.accentGold, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.2)),
      const Divider(color: Colors.white10),
      const SizedBox(height: 8),
    ],
  );
}

Widget _buildTextField(String label, TextEditingController ctrl, {IconData? icon, Color? color, bool isNumeric = false, TextInputFormatter? formatter, bool isRequired = false}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12.0),
    child: TextFormField(
      controller: ctrl,
      keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
      inputFormatters: formatter != null ? [formatter] : null,
      validator: isRequired ? (val) => (val == null || val.isEmpty) ? 'Obrigatório' : null : null,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.textGrey, fontSize: 11),
        prefixIcon: icon != null ? Icon(icon, size: 16, color: color ?? AppTheme.textGrey) : null,
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.accentGold)),
      ),
    ),
  );
}
