

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:signature/signature.dart';
import '../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../core/utils/app_formatters.dart';
import '../core/constants/firebase_collections.dart';
import '../core/constants/legal_texts.dart';
import '../core/services/via_cep_service.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:file_picker/file_picker.dart';
import '../core/services/image_upload_service.dart';
import '../core/services/firebase_storage_service.dart';
import '../core/utils/termo_pdf_generator.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emergencyFormKey = GlobalKey<FormState>(); // Nova chave para o Passo 2
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 6; // Expandido para jornada única de 6 passos

  // Controles Pessoais
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _confirmarEmailController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();
  final _cpfController = TextEditingController();
  final _rgController = TextEditingController();

  // Controles Biossociais
  final _dataNascimentoController = TextEditingController();
  final _pesoController = TextEditingController();
  final _alturaController = TextEditingController();
  final _contatoEmergenciaNomeController = TextEditingController();
  final _contatoEmergenciaTelController = TextEditingController();

  // Controles Geográficos
  final _cepController = TextEditingController();
  final _enderecoController = TextEditingController();
  final _numeroController = TextEditingController();
  final _bairroController = TextEditingController();
  final _cidadeController = TextEditingController();
  final _estadoController = TextEditingController();
  final _complementoController = TextEditingController();
  final _paisController = TextEditingController(text: 'Brasil');
  final _parentescoController = TextEditingController();

  // Saúde e Anamnese (Passo 5)
  final _lesoesController = TextEditingController();
  final _detalheLesaoController = TextEditingController();
  bool? _possuiLesao;
  String? _atestadoFileName;
  Uint8List? _atestadoFileBytes;
  bool get _showAtestado => _possuiLesao == true || _lesoesController.text.trim().isNotEmpty;

  // Convênio
  bool _usaConvenio = false;
  String _qualConvenio = 'Wellhub';

  // LGPD
  final ScrollController _scrollControllerLgpd = ScrollController();
  bool _lgpdAceito = false;
  bool _isLgpdScrolled = false;

  // Termo de Responsabilidade
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 4.5,
    penColor: Colors.blue, // Caneta azul conforme solicitado pelo Sensei
    exportBackgroundColor: Colors.white, // Fundo branco para o PDF
    exportPenColor: Colors.blue, // Exportar em azul para manter fidelidade
  );
  
  // Controles extras do Termo (Caso precise de dados do responsável)
  final _nomeResponsavelCtrl = TextEditingController();
  final _cpfResponsavelCtrl = TextEditingController();
  final _rgResponsavelCtrl = TextEditingController();

  // Máscaras Centralizadas
  final _telefoneMask = AppFormatters.phoneMask;
  final _dataNascMask = AppFormatters.dateMask;
  final _cpfMask = AppFormatters.cpfMask;
  final _rgMask = AppFormatters.rgMask;
  final _emergenciaTelMask = MaskTextInputFormatter(
    mask: '(##) #####-####', 
    filter: {"#": RegExp(r'[0-9]')}
  );
  final List<String> _modalidadesSelecionadas = []; // Solicitado pelo usuário (Etapa Final)
  double _mensalidadeGlobal = 1.0; // Valor global buscado de config/geral
  final List<String> _modalidadesOpcoes = [
    'MMA', 'Kickboxing', 'Jiu-jitsu', 'Boxing', 'Karate', 'Funcional', 'Self Defense', 'Muay Thai'
  ];

  bool _isGoogleUser = false;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    
    // Identificar se já existe usuário logado (Google)
    _currentUser = FirebaseAuth.instance.currentUser;
    if (_currentUser != null) {
      _isGoogleUser = true;
      _emailController.text = _currentUser!.email ?? '';
      _confirmarEmailController.text = _currentUser!.email ?? '';
      _nomeController.text = _currentUser!.displayName ?? '';
    }

    _scrollControllerLgpd.addListener(() {
      if (_scrollControllerLgpd.position.pixels >= _scrollControllerLgpd.position.maxScrollExtent - 50) {
        if (!_isLgpdScrolled) setState(() => _isLgpdScrolled = true);
      }
    });

    // Listener para Assinatura - Reactive UI
    _signatureController.addListener(() {
      setState(() {}); // Reconstrói para validar o botão de finalizar
    });

    // Listener para o CEP - Integração ViaCEP
    _cepController.addListener(() {
      final cep = _cepController.text.replaceAll(RegExp(r'[^0-9]'), '');
      if (cep.length == 8) {
        _buscarEndereco(cep);
      }
    });

    // Busca valor global da mensalidade para exibir na UI
    _fetchMensalidadeGlobal();
  }

  Future<void> _fetchMensalidadeGlobal() async {
    try {
      final configDoc = await FirebaseFirestore.instance.collection('config').doc('geral').get();
      if (configDoc.exists && mounted) {
        setState(() {
          _mensalidadeGlobal = (configDoc.data()?['mensalidade_valor'] ?? 1.0).toDouble();
        });
      }
    } catch (e) {
      debugPrint('Erro ao buscar mensalidade global: $e');
    }
  }

  Future<void> _pickAtestado() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _atestadoFileName = result.files.first.name;
        _atestadoFileBytes = result.files.first.bytes;
      });
    }
  }

  Future<void> _buscarEndereco(String cep) async {
    final address = await ViaCepService.fetchAddress(cep);
    if (address != null) {
      if (mounted) {
        setState(() {
          _enderecoController.text = address['logradouro'] ?? '';
          _bairroController.text = address['bairro'] ?? '';
          _cidadeController.text = address['localidade'] ?? '';
          _estadoController.text = address['uf'] ?? '';
        });
      }
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _confirmarEmailController.dispose();
    _telefoneController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    _cpfController.dispose();
    _rgController.dispose();
    _dataNascimentoController.dispose();
    _pesoController.dispose();
    _alturaController.dispose();
    _contatoEmergenciaNomeController.dispose();
    _contatoEmergenciaTelController.dispose();
    _cepController.dispose();
    _enderecoController.dispose();
    _numeroController.dispose();
    _bairroController.dispose();
    _cidadeController.dispose();
    _estadoController.dispose();
    _complementoController.dispose();
    _paisController.dispose();
    _parentescoController.dispose();
    _scrollControllerLgpd.dispose();
    _signatureController.dispose();
    _pageController.dispose();
    _nomeResponsavelCtrl.dispose();
    _cpfResponsavelCtrl.dispose();
    _rgResponsavelCtrl.dispose();
    _lesoesController.dispose();
    _detalheLesaoController.dispose();
    super.dispose();
  }


  bool _isRegistering = false;


  Future<void> _submit() async {
    if (_modalidadesSelecionadas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione ao menos uma modalidade.')));
      return;
    }
    if (_signatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, assine o termo.')));
      return;
    }
    if (!_lgpdAceito) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aceite a LGPD para continuar.')));
      return;
    }

    setState(() {
      _isRegistering = true;

    });

    try {
      User? user = _currentUser;
      
      // Se não for Google (Cadastro Manual), criar via E-mail e Senha
      if (!_isGoogleUser) {
        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _senhaController.text,
        ).timeout(const Duration(seconds: 15));
        user = cred.user;
      }

      if (user != null) {
        setState(() {});

        // 2. Uploads Opcionais (Atestado e Assinatura)
        String? urlAtestado;
        if (_atestadoFileBytes != null) {
          urlAtestado = await ImageUploadService.uploadImageFromBytes(_atestadoFileBytes!);
        }

        final signatureBytes = await _signatureController.toPngBytes();

        String? urlAssinatura;
        String? signatureBase64;
        bool assinaturaPendente = false; // [NOVO] Fallback
        
        if (signatureBytes != null) {
          try {
            // Timeout de 15s para evitar loop infinito solicitado pela OS
            urlAssinatura = await ImageUploadService.uploadImageFromBytes(signatureBytes)
                .timeout(const Duration(seconds: 15));
            signatureBase64 = base64Encode(signatureBytes);
          } catch (e) {
            debugPrint('Falha no processamento da assinatura: $e');
            assinaturaPendente = true; // [FALLBACK] Prossegue sem a imagem se falhar
          }
        }

        final agora = DateTime.now();
        final isApto = (_possuiLesao == false) && _lesoesController.text.trim().isEmpty;

        // 2.5 GERAR E UPLOAD DO TERMO LGPD PDF (NOVO)
        String? urlTermoPdf;
        if (signatureBytes != null) {
          try {
            final pdfData = {
              'uid': user.uid,
              'nome': _nomeController.text.trim(),
              'cpf_rg': '${_cpfController.text.trim()} / ${_rgController.text.trim()}',
              'nascimento': _dataNascimentoController.text.trim(),
              'idade': _calculateAgeForPdf(_dataNascimentoController.text.trim()),
              'signatureBytes': signatureBytes,
              'dataAssinatura': Timestamp.now(),
            };
            
            final pdfBytes = await TermoPdfGenerator.generatePdf(pdfData);
            final pdfPath = 'documentos/termos_assinados/${user.uid}_${agora.millisecondsSinceEpoch}.pdf';
            urlTermoPdf = await FirebaseStorageService.uploadPdf(pdfBytes, pdfPath).timeout(const Duration(seconds: 15), onTimeout: () => null);
          } catch (pdfErr) {
            debugPrint('Erro ao gerar/upload PDF LGPD: $pdfErr');
          }
        }

        // 3. GRAVAÇÃO CONSOLIDADA (Payload Único solicitado)
        final studentDoc = {
          'uid': user.uid,
          'role': 'aluno',
          'status': 'pendente',
          'status_acesso': 'pendente', // Unificado: Todo cadastro vai para pendente
          'created_at': FieldValue.serverTimestamp(),
          'is_anamnese_completed': true,
          'is_terms_accepted': true,
          'plano_corporativo': _usaConvenio ? _qualConvenio.toLowerCase() : 'nenhum',
          'termo_assinado_url': urlTermoPdf, // Campo solicitado pela OS
          
          'dados_pessoais': {
            'nome': _nomeController.text.trim(),
            'email': _emailController.text.trim(),
            'telefone': _telefoneController.text.trim(),
            'nascimento': _dataNascimentoController.text.trim(),
            'cpf': _cpfController.text.trim(), // Adicionado explícito para busca
            'rg': _rgController.text.trim(), // Adicionado explícito
            'cpf_rg': '${_cpfController.text.trim()} / ${_rgController.text.trim()}',
            'modalidade': _modalidadesSelecionadas,
            'faixa': 'BRANCA',
            'status_aptidao': isApto ? 'Apto' : 'Em avaliação',
            'url_atestado': urlAtestado,
            'url_assinatura': urlAssinatura,
            'url_assinatura_imgbb': urlAssinatura,
            'assinatura_pendente': assinaturaPendente, // [AUDITORIA]
            'peso': _pesoController.text.trim(),
            'altura': _alturaController.text.trim(),
          },

          'endereco': {
            'cep': _cepController.text.trim(),
            'logradouro': _enderecoController.text.trim(),
            'numero': _numeroController.text.trim(),
            'bairro': _bairroController.text.trim(),
            'cidade': _cidadeController.text.trim(),
            'uf': _estadoController.text.trim(),
            'complemento': _complementoController.text.trim(),
          },

          'saude_emergencia': {
            'usa_convenio': _usaConvenio,
            'nome_convenio': _usaConvenio ? _qualConvenio : 'Nenhum',
            'contatoEmergenciaNome': _contatoEmergenciaNomeController.text.trim(),
            'contatoEmergenciaTel': _contatoEmergenciaTelController.text.trim(),
            'parentesco': _parentescoController.text.trim(),
            'historico_lesoes': _lesoesController.text.trim(),
            'detalhe_lesao_atual': _detalheLesaoController.text.trim(),
          },

          'termos_matricula': {
            'termoAssinado': true,
            'aceiteLGPD': true,
            'assinaturaBase64': signatureBase64,
            'dataAceite': FieldValue.serverTimestamp(),
            'urlTermoPdf': urlTermoPdf,
          },

          'financeiro': {
            'statusPagamento': 'pendente',
            'data_vencimento': Timestamp.fromDate(agora.add(const Duration(days: 30))),
            'valor_plano': _mensalidadeGlobal * _modalidadesSelecionadas.length,
          },
        };

        await FirebaseFirestore.instance.collection(FirebaseCollections.alunos).doc(user.uid).set(studentDoc).timeout(const Duration(seconds: 15));
        
        // Sincronização Sutil com Matrículas
        await FirebaseFirestore.instance.collection(FirebaseCollections.matriculas).doc(user.uid).set({
          'nome': _nomeController.text.trim(),
          'status_pagamento': 'Pendente',
        }, SetOptions(merge: true)).timeout(const Duration(seconds: 10));

        if (mounted) {
          ref.invalidate(userProfileProvider);
          // Redireciona para tela de aguardo de aprovação
          context.go('/pending');
        }
      }
    } catch (e) {
      debugPrint('Erro Final de Cadastro: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('ERRO NO CADASTRO: $e. Verifique sua conexão.'),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 5),
        ));
      }
    } finally {
      if (mounted) {
        setState(() => _isRegistering = false);
      }
    }
  }

  int _calculateAgeForPdf(String birthDate) {
    try {
      final parts = birthDate.split('/');
      if (parts.length != 3) return 0;
      final birth = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      final today = DateTime.now();
      int age = today.year - birth.year;
      if (today.month < birth.month || (today.month == birth.month && today.day < birth.day)) age--;
      return age;
    } catch (_) {
      return 0;
    }
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppTheme.textGrey),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.0),
        borderSide: BorderSide.none,
      ),
      filled: true,
      fillColor: AppTheme.cardDarkGrey,
      floatingLabelStyle: const TextStyle(color: AppTheme.accentGold),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.0),
        borderSide: const BorderSide(color: AppTheme.accentGold, width: 2.0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundBlack,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundBlack,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('Passo ${_currentStep + 1} de $_totalSteps', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_currentStep + 1) / _totalSteps,
            backgroundColor: AppTheme.cardDarkGrey,
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accentGold),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildStep1(), // Pessoais
            _buildStep2(), // Emergência
            _buildStep3(), // Endereço
            _buildStep4(), // Convênio
            _buildStep5(), // Saúde e Anamnese (Novo)
            _buildStep6(), // Termos e LGPD (Novo)
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Dados Pessoais e Acesso', style: TextStyle(color: AppTheme.accentGold, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          TextFormField(
            controller: _nomeController, 
            decoration: _buildInputDecoration('Nome Completo do Aluno', LucideIcons.user), 
            validator: (val) => val!.isEmpty ? 'Obrigatório' : null
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _cpfController, 
                  inputFormatters: [_cpfMask], 
                  keyboardType: TextInputType.number,
                  decoration: _buildInputDecoration('CPF', LucideIcons.creditCard), 
                  validator: (val) => val!.length < 14 ? 'CPF Inválido' : null
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _rgController, 
                  inputFormatters: [_rgMask],
                  keyboardType: TextInputType.number,
                  decoration: _buildInputDecoration('RG', LucideIcons.contact), 
                  validator: (val) => (val == null || val.length < 12) ? 'RG Inválido' : null
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController, 
            keyboardType: TextInputType.emailAddress,
            decoration: _buildInputDecoration('E-mail de Acesso', LucideIcons.mail), 
            validator: (val) {
              if (val == null || val.isEmpty) return 'Obrigatório';
              if (!val.contains('@')) return 'E-mail inválido';
              return null;
            }
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmarEmailController, 
            keyboardType: TextInputType.emailAddress,
            decoration: _buildInputDecoration('Confirmar E-mail', LucideIcons.mailCheck), 
            validator: (val) {
              if (val != _emailController.text) return 'E-mails não conferem';
              if (val!.isEmpty) return 'Obrigatório';
              return null;
            }
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _telefoneController, 
                  inputFormatters: [_telefoneMask], 
                  keyboardType: TextInputType.phone,
                  decoration: _buildInputDecoration('Celular/WhatsApp', LucideIcons.phone),
                  validator: (val) => val!.isEmpty ? 'Obrigatório' : null,
                )
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _dataNascimentoController, 
                  inputFormatters: [_dataNascMask], 
                  keyboardType: TextInputType.number,
                  decoration: _buildInputDecoration('Data Nasc.', LucideIcons.calendar),
                  validator: (val) => val!.isEmpty ? 'Obrigatório' : null
                )
              ),
            ],
          ),
          
          if (!_isGoogleUser) ...[
            const SizedBox(height: 24),
            const Text('Senha de Acesso ao App', style: TextStyle(color: AppTheme.accentGold, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _senhaController, 
                    obscureText: true, 
                    decoration: _buildInputDecoration('Senha', LucideIcons.lock),
                    validator: (val) {
                      if (val!.isEmpty) return 'Obrigatório';
                      if (val.length < 6) return 'Mínimo 6 caracteres';
                      return null;
                    }
                  )
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _confirmarSenhaController, 
                    obscureText: true, 
                    decoration: _buildInputDecoration('Confirmar', LucideIcons.lock),
                    validator: (val) {
                      if (val != _senhaController.text) return 'Senhas não conferem';
                      if (val!.isEmpty) return 'Obrigatório';
                      return null;
                    }
                  )
                ),
              ],
            ),
          ],
          
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Modalidades Desejadas', style: TextStyle(color: AppTheme.accentGold, fontSize: 13, fontWeight: FontWeight.bold)),
              if (_modalidadesSelecionadas.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.withValues(alpha: 0.3))),
                  child: Text(
                    'Total: R\$ ${(_mensalidadeGlobal * _modalidadesSelecionadas.length).toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _modalidadesOpcoes.map((mod) {
              final isSelected = _modalidadesSelecionadas.contains(mod);
              return FilterChip(
                label: Text(mod, style: TextStyle(color: isSelected ? Colors.black : Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _modalidadesSelecionadas.add(mod);
                    } else {
                      _modalidadesSelecionadas.remove(mod);
                    }
                  });
                },
                selectedColor: AppTheme.accentGold,
                checkmarkColor: Colors.black,
                backgroundColor: AppTheme.cardDarkGrey,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: isSelected ? AppTheme.accentGold : Colors.white10),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _emergencyFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Contato de Emergência', style: TextStyle(color: AppTheme.accentGold, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Dados para contato imediato em caso de necessidade no tatame.', style: TextStyle(color: AppTheme.textGrey, fontSize: 13)),
            const SizedBox(height: 24),
            
            TextFormField(
              controller: _contatoEmergenciaNomeController,
              decoration: _buildInputDecoration('Nome do Responsável', LucideIcons.userPlus),
              validator: (val) => (val == null || val.isEmpty) ? 'Nome do responsável é obrigatório' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contatoEmergenciaTelController,
              inputFormatters: [_emergenciaTelMask],
              keyboardType: TextInputType.phone,
              decoration: _buildInputDecoration('Telefone (WhatsApp)', LucideIcons.phoneOutgoing),
              validator: (val) {
                if (val == null || val.isEmpty) return 'Telefone é obrigatório';
                if (val.length < 14) return 'Telefone incompleto';
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _parentescoController.text.isEmpty ? null : _parentescoController.text,
              dropdownColor: AppTheme.cardDarkGrey,
              style: const TextStyle(color: Colors.white),
              decoration: _buildInputDecoration('Selecione o parentesco', LucideIcons.heart),
              items: ['Pai', 'Mãe', 'Tio(a)', 'Primo(a)', 'Irmão(ã)', 'Amigo(a)', 'Avô(ó)'].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  _parentescoController.text = newValue ?? '';
                });
                FocusScope.of(context).unfocus(); // Oculta o teclado ao selecionar
              },
              validator: (val) => (val == null || val.isEmpty) ? 'Informe o parentesco' : null,
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Endereço Residencial', style: TextStyle(color: AppTheme.accentGold, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          
          // BLOCO ENDEREÇO
          const Text('Onde você mora?', style: TextStyle(color: AppTheme.textGrey, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextFormField(
            controller: _cepController,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            keyboardType: TextInputType.number,
            maxLength: 8,
            decoration: _buildInputDecoration('CEP (Busca automática)', LucideIcons.mapPin).copyWith(counterText: ''),
            validator: (val) => val!.length < 8 ? 'CEP Incompleto' : null,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2, // 2/3 do espaço
                child: TextFormField(
                  controller: _enderecoController,
                  decoration: _buildInputDecoration('Logradouro', LucideIcons.home),
                  validator: (val) => val!.isEmpty ? 'Obrigatório' : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1, // 1/3 do espaço
                child: TextFormField(
                  controller: _numeroController,
                  keyboardType: TextInputType.number,
                  decoration: _buildInputDecoration('Nº', LucideIcons.hash).copyWith(
                    prefixIcon: null,
                    prefixText: '# ',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
                  ),
                  validator: (val) => val!.isEmpty ? 'Obrigatório' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _bairroController,
            decoration: _buildInputDecoration('Bairro', LucideIcons.map),
            validator: (val) => val!.isEmpty ? 'Obrigatório' : null,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _cidadeController,
                  decoration: _buildInputDecoration('Cidade', LucideIcons.navigation),
                  validator: (val) => val!.isEmpty ? 'Obrigatório' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: TextFormField(
                  controller: _estadoController,
                  decoration: _buildInputDecoration('UF', LucideIcons.mapPin),
                  validator: (val) => val!.length != 2 ? 'UF Inválida' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _complementoController,
            decoration: _buildInputDecoration('Complemento (Opcional)', LucideIcons.plusCircle),
          ),
          
          const SizedBox(height: 24),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildStep4() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Benefício Corporativo', style: TextStyle(color: AppTheme.accentGold, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Você utiliza um desses benefícios corporativos para fazer check-in no C.T. PANDORA?', style: TextStyle(color: AppTheme.textGrey, fontSize: 13)),
          const SizedBox(height: 24),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppTheme.cardDarkGrey, borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Sim, utilizo Wellhub / TotalPass', style: TextStyle(color: Colors.white, fontSize: 14)),
                  activeThumbColor: AppTheme.accentGold,
                  contentPadding: EdgeInsets.zero,
                  value: _usaConvenio,
                  onChanged: (val) => setState(() => _usaConvenio = val),
                ),
                if (_usaConvenio) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _qualConvenio,
                    decoration: _buildInputDecoration('Selecione o Benefício', LucideIcons.building),
                    dropdownColor: AppTheme.cardDarkGrey,
                    style: const TextStyle(color: Colors.white),
                    items: ['Wellhub', 'TotalPass'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (val) => setState(() => _qualConvenio = val!),
                  ),
                ]
              ],
            ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildStep5() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Saúde e Anamnese', style: TextStyle(color: AppTheme.accentGold, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Informe fraturas recentes ou comorbidades para maior segurança.', style: TextStyle(color: AppTheme.textGrey, fontSize: 13)),
          const SizedBox(height: 24),
          const Text('Possui lesão ou limitação no momento?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            emptySelectionAllowed: true,
            segments: const [
              ButtonSegment(value: false, label: Text('Não'), icon: Icon(LucideIcons.thumbsUp)),
              ButtonSegment(value: true, label: Text('Sim'), icon: Icon(LucideIcons.alertTriangle)),
            ],
            selected: _possuiLesao != null ? {_possuiLesao!} : {},
            onSelectionChanged: (Set<bool> newSelection) {
              setState(() => _possuiLesao = newSelection.first);
            },
            style: SegmentedButton.styleFrom(
              backgroundColor: AppTheme.cardDarkGrey,
              selectedBackgroundColor: AppTheme.accentGold,
              selectedForegroundColor: Colors.black,
            ),
          ),
          if (_possuiLesao == true) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _detalheLesaoController,
              maxLines: 2,
              decoration: _buildInputDecoration('Detalhes da Lesão', LucideIcons.fileWarning),
            ),
          ],
          const SizedBox(height: 16),
          TextFormField(
            controller: _lesoesController,
            maxLines: 2,
            onChanged: (_) => setState(() {}),
            decoration: _buildInputDecoration('Outros Históricos (Opcional)', LucideIcons.stethoscope),
          ),
          if (_showAtestado) ...[
            const SizedBox(height: 24),
            const Text('Atestado Médico Obrigatório', style: TextStyle(color: AppTheme.accentGold, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickAtestado,
              icon: const Icon(LucideIcons.fileUp),
              label: Text(_atestadoFileName ?? 'SELECIONAR ATESTADO (PDF/JPG)', style: const TextStyle(color: Colors.white)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                side: const BorderSide(color: AppTheme.accentGold),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStep6() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Privacidade e Termos', style: TextStyle(color: AppTheme.accentGold, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Container(
            height: 200,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppTheme.cardDarkGrey, borderRadius: BorderRadius.circular(12)),
            child: Scrollbar(
              controller: _scrollControllerLgpd,
              child: SingleChildScrollView(
                controller: _scrollControllerLgpd,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1º) LGPD
                    const Text(
                      'POLÍTICA DE PRIVACIDADE E CONSENTIMENTO (LGPD)',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      LegalTexts.lgpdTerm,
                      style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    
                    // 2º) Título Responsabilidade
                    const Text(
                      'TERMO DE RESPONSABILIDADE E ASSUNÇÃO DE RISCOS',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    
                    // 3º) Cláusula I Saúde
                    const Text(
                      LegalTexts.responsabilidadeSaude,
                      style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
          CheckboxListTile(
            title: const Text('Li e aceito a política de dados (LGPD)', style: TextStyle(color: Colors.white, fontSize: 12)),
            value: _lgpdAceito,
            activeColor: AppTheme.accentGold,
            contentPadding: EdgeInsets.zero,
            onChanged: _isLgpdScrolled ? (val) => setState(() => _lgpdAceito = val!) : null,
          ),
          const SizedBox(height: 16),
          const Text('Assinatura Digital (Use o dedo):', style: TextStyle(color: AppTheme.accentGold, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          Container(
            height: 150,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Signature(controller: _signatureController, height: 150, backgroundColor: Colors.white),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _signatureController.clear(),
              icon: const Icon(LucideIcons.eraser, size: 14),
              label: const Text('LIMPAR', style: TextStyle(fontSize: 10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    final finalStepIndex = _totalSteps - 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const BoxDecoration(
        color: AppTheme.backgroundBlack, 
        border: Border(top: BorderSide(color: Colors.white10))
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                flex: 1,
                child: OutlinedButton(
                  onPressed: () {
                    _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                    setState(() => _currentStep--);
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('VOLTAR', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ),
            if (_currentStep > 0) const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: (_isRegistering || (_currentStep == finalStepIndex && (!_lgpdAceito || _signatureController.isEmpty))) 
                  ? null 
                  : () {
                  // LÓGICA DE VALIDAÇÃO E NAVEGAÇÃO POR PASSO
                  if (_currentStep == 0) {
                    if (!_formKey.currentState!.validate()) return;
                    if (_modalidadesSelecionadas.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione uma modalidade.')));
                      return;
                    }
                  }
                  
                  if (_currentStep == 1 && !_emergencyFormKey.currentState!.validate()) return;

                  if (_currentStep < finalStepIndex) {
                    _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                    setState(() => _currentStep++);
                  } else {
                    _submit();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentGold,
                  disabledBackgroundColor: AppTheme.cardDarkGrey, // Cor de desativado
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isRegistering 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : Text(_currentStep == finalStepIndex ? 'FINALIZAR CADASTRO' : 'PRÓXIMO', 
                        style: TextStyle(color: (_currentStep == finalStepIndex && (!_lgpdAceito || _signatureController.isEmpty)) ? Colors.white24 : Colors.black, fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
