import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';
import '../core/constants/firebase_collections.dart';
import 'modality_management_page.dart';
import '../widgets/glass_container.dart';
// PremiumClickable is included in glass_container.dart

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _whatsappController = TextEditingController();
  final _mensalidadeController = TextEditingController();
  final _latController = TextEditingController(); 
  final _lngController = TextEditingController();
  final _tempLatController = TextEditingController();
  final _tempLngController = TextEditingController();
  final _raioController = TextEditingController();
  final _minAulasController = TextEditingController();
  bool _usarLocalTemporario = false;

  final _whatsappMask = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: { "#": RegExp(r'[0-9]') },
    type: MaskAutoCompletionType.lazy,
  );

  Map<String, Map<String, int>> _aulasPorAluno = {}; 
  Map<String, Map<String, int>> _kiPorAluno = {}; // [NOVO] { uid: { mod: meta_ki } }
  Map<String, Map<String, String>> _patchesPorAluno = {}; // [NOVO] { uid: { mod: patch_url } }
  final Map<String, String> _nomesPorAluno = {}; 
  
  final _currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _whatsappController.dispose();
    _mensalidadeController.dispose();
    _latController.dispose(); 
    _lngController.dispose(); 
    _tempLatController.dispose();
    _tempLngController.dispose();
    _raioController.dispose(); 
    _minAulasController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('config').doc('geral').get();
      if (doc.exists) {
        final data = doc.data()!;
        final number = data['whatsapp_sensei'] ?? '';
        setState(() {
          String displayNumber = number.toString();
          if (displayNumber.startsWith('55')) {
            displayNumber = displayNumber.substring(2);
          }
          _whatsappController.text = _whatsappMask.maskText(displayNumber);
          _mensalidadeController.text = _currencyFormat.format(data['mensalidade_valor'] ?? 1.0);
          _latController.text = (data['dojo_lat'] ?? -23.4040862).toString(); 
          _lngController.text = (data['dojo_lng'] ?? -46.5391125).toString(); 
          _tempLatController.text = (data['temp_lat'] ?? '').toString();
          _tempLngController.text = (data['temp_lng'] ?? '').toString();
          _usarLocalTemporario = data['usar_local_temporario'] ?? false;
          _raioController.text = (data['checkin_raio'] ?? 150.0).toString();
          _minAulasController.text = (data['minimo_aulas_exame'] ?? 40).toString();
          
          final rawExcecoes = data['aulas_por_aluno'] as Map<String, dynamic>? ?? {};
          _aulasPorAluno = rawExcecoes.map((uid, value) {
            if (value is Map) return MapEntry(uid, Map<String, int>.from(value));
            return MapEntry(uid, {'Geral': (value as num).toInt()});
          });

          final rawKi = data['ki_por_aluno'] as Map<String, dynamic>? ?? {};
          _kiPorAluno = rawKi.map((uid, value) {
            if (value is Map) return MapEntry(uid, Map<String, int>.from(value));
            return MapEntry(uid, {'Geral': (value as num).toInt()});
          });

          final rawPatches = data['patches_por_aluno'] as Map<String, dynamic>? ?? {};
          _patchesPorAluno = rawPatches.map((uid, value) {
            if (value is Map) return MapEntry(uid, Map<String, String>.from(value));
            return MapEntry(uid, {'Geral': value.toString()});
          });

          _isLoading = false;
        });
        if (_aulasPorAluno.isNotEmpty || _kiPorAluno.isNotEmpty) _loadExceptionNames();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveConfig() async {
    // Sanitização robusta: extrai apenas os números do WhatsApp
    final cleanNumber = _whatsappController.text.replaceAll(RegExp(r'\D'), '');
    
    // Sanitização de Moeda
    String valorText = _mensalidadeController.text
        .replaceAll('R\$', '')
        .replaceAll('.', '')
        .replaceAll(',', '.')
        .trim();
    final cleanValor = double.tryParse(valorText) ?? 1.0;

    // Sanitização de GPS
    final cleanLat = double.tryParse(_latController.text.replaceAll(',', '.')) ?? -23.4040862; 
    final cleanLng = double.tryParse(_lngController.text.replaceAll(',', '.')) ?? -46.5391125; 
    final cleanTempLat = double.tryParse(_tempLatController.text.replaceAll(',', '.')) ?? 0.0;
    final cleanTempLng = double.tryParse(_tempLngController.text.replaceAll(',', '.')) ?? 0.0;
    final cleanRaio = double.tryParse(_raioController.text.replaceAll(',', '.')) ?? 150.0;
    final cleanMinAulas = int.tryParse(_minAulasController.text) ?? 40;

    if (cleanNumber.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('O número de WhatsApp deve ter pelo menos 10 dígitos (DDD + Número).'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final finalNumber = cleanNumber.startsWith('55') ? cleanNumber : (cleanNumber.isNotEmpty ? '55$cleanNumber' : '');

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('config').doc('geral').set({
        'whatsapp_sensei': finalNumber,
        'mensalidade_valor': cleanValor,
        'dojo_lat': cleanLat, 
        'dojo_lng': cleanLng, 
        'usar_local_temporario': _usarLocalTemporario,
        'temp_lat': cleanTempLat,
        'temp_lng': cleanTempLng,
        'checkin_raio': cleanRaio,
        'minimo_aulas_exame': cleanMinAulas,
        'aulas_por_aluno': _aulasPorAluno,
        'ki_por_aluno': _kiPorAluno,
        'patches_por_aluno': _patchesPorAluno,
        'ultima_atualizacao': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configurações salvas com sucesso!'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      setState(() => _isSaving = true);
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _tempLatController.text = position.latitude.toString();
        _tempLngController.text = position.longitude.toString();
        _usarLocalTemporario = true;
      });
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundBlack,
      appBar: AppBar(
        title: const Text('CENTRAL DE CONFIGURAÇÕES', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accentGold))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSectionCard('CONTATO SENSEI', LucideIcons.phone, [
                    TextField(
                      controller: _whatsappController,
                      keyboardType: TextInputType.phone, // Mapeia para type="tel", aceita parênteses e hifens
                      inputFormatters: [_whatsappMask],
                      style: const TextStyle(color: Colors.white),
                      decoration: _buildInputDecoration('WhatsApp do Sensei', LucideIcons.messageSquare),
                    ),
                  ]),
                  const SizedBox(height: 24),
                  _buildSectionCard('FINANCEIRO GLOBAL', LucideIcons.banknote, [
                    TextField(
                      controller: _mensalidadeController,
                      keyboardType: TextInputType.text, // Evita erro "Insira um número válido" no browser
                      style: const TextStyle(color: AppTheme.accentGold, fontSize: 24, fontWeight: FontWeight.w900),
                      decoration: _buildInputDecoration('Valor Base Mensalidade', LucideIcons.coins),
                      onChanged: (value) {
                        if (value.isEmpty) return;
                        String cleanValue = value.replaceAll(RegExp(r'[^0-9]'), '');
                        double doubleValue = double.parse(cleanValue) / 100;
                        _mensalidadeController.value = TextEditingValue(
                          text: _currencyFormat.format(doubleValue),
                          selection: TextSelection.collapsed(offset: _currencyFormat.format(doubleValue).length),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    const Text('Este valor será a base para faturamentos automáticos.', style: TextStyle(color: AppTheme.textGrey, fontSize: 10)),
                  ]),
                  const SizedBox(height: 24),
                  _buildSectionCard('GEOFENCING (GPS)', LucideIcons.mapPin, [
                    Row(
                      children: [
                        Expanded(child: TextField(controller: _latController, decoration: _buildInputDecoration('Lat', LucideIcons.compass))),
                        const SizedBox(width: 12),
                        Expanded(child: TextField(controller: _lngController, decoration: _buildInputDecoration('Lng', LucideIcons.map))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('MODO VIAGEM / EVENTO', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Ativa localização temporária.', style: TextStyle(color: AppTheme.textGrey, fontSize: 10)),
                      value: _usarLocalTemporario,
                      activeColor: AppTheme.accentGold,
                      onChanged: (v) => setState(() => _usarLocalTemporario = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (_usarLocalTemporario) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: _tempLatController, decoration: _buildInputDecoration('Lat Temp', LucideIcons.navigation))),
                          const SizedBox(width: 12),
                          Expanded(child: TextField(controller: _tempLngController, decoration: _buildInputDecoration('Lng Temp', LucideIcons.navigation))),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _getCurrentLocation,
                      icon: const Icon(LucideIcons.locateFixed, size: 16),
                      label: const Text('CAPTURAR GPS AGORA'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white10, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 45)),
                    ),
                  ]),
                  const SizedBox(height: 24),
                  _buildSectionCard('GRADUAÇÃO', LucideIcons.award, [
                    TextField(
                      controller: _minAulasController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
                      decoration: _buildInputDecoration('Mínimo Aulas p/ Exame', LucideIcons.graduationCap),
                    ),
                    const SizedBox(height: 24),
                    _buildSubSectionTitle('EXCEÇÕES POR ALUNO'),
                    const SizedBox(height: 12),
                    if (_aulasPorAluno.isEmpty)
                      _buildEmptyState('Nenhuma exceção configurada.')
                    else
                      ..._aulasPorAluno.entries.map((entry) {
                        final uid = entry.key;
                        final metasFisicas = entry.value;
                        final metasKi = _kiPorAluno[uid] ?? {};
                        final patches = _patchesPorAluno[uid] ?? {};
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _nomesPorAluno[uid]?.toUpperCase() ?? "CARREGANDO...", 
                                      style: const TextStyle(color: AppTheme.accentGold, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)
                                    ),
                                    const Icon(LucideIcons.user, size: 12, color: AppTheme.accentGold),
                                  ],
                                ),
                              ),
                              const Divider(color: Colors.white10, indent: 16, endIndent: 16),
                              ...metasFisicas.entries.map((m) {
                                final mod = m.key;
                                return ListTile(
                                  dense: true,
                                  visualDensity: VisualDensity.compact,
                                  title: Text(mod, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                                  subtitle: Text(
                                    'Check-ins: ${m.value} | KI: ${metasKi[mod] ?? "Padrão"} | Patch: ${patches[mod] != null ? "Sim" : "Não"}', 
                                    style: const TextStyle(color: AppTheme.textGrey, fontSize: 11)
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(LucideIcons.trash2, color: Colors.redAccent, size: 16),
                                    onPressed: () => setState(() {
                                      _aulasPorAluno[uid]!.remove(mod);
                                      _kiPorAluno[uid]?.remove(mod);
                                      _patchesPorAluno[uid]?.remove(mod);
                                      if (_aulasPorAluno[uid]!.isEmpty) {
                                        _aulasPorAluno.remove(uid);
                                        _kiPorAluno.remove(uid);
                                        _patchesPorAluno.remove(uid);
                                      }
                                    }),
                                  ),
                                  onTap: () {
                                    final data = _aulasPorAluno[uid]!;
                                    _showSetGoalDialog(uid, _nomesPorAluno[uid] ?? '...', data.keys.toList());
                                  },
                                );
                              }),
                            ],
                          ),
                        );
                      }),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _showStudentSearchBottomSheet,
                      icon: const Icon(LucideIcons.userPlus, size: 16),
                      label: const Text('ADICIONAR EXCEÇÃO'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white10, foregroundColor: AppTheme.accentGold),
                    ),
                  ]),
                  const SizedBox(height: 32),
                  PremiumClickable(
                    onTap: _isSaving ? null : _saveConfig,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [AppTheme.accentGold, Color(0xFFB8860B)]),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: _isSaving 
                          ? const CircularProgressIndicator(color: Colors.black) 
                          : const Text('SALVAR TODAS AS ALTERAÇÕES', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionCard(String title, IconData icon, List<Widget> children) {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.accentGold, size: 18),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.5)),
            ],
          ),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppTheme.textGrey, fontSize: 12),
      prefixIcon: Icon(icon, color: AppTheme.textGrey, size: 18),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.accentGold, width: 1)),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
      child: Center(child: Text(msg, style: const TextStyle(color: AppTheme.textGrey, fontSize: 12))),
    );
  }

  Widget _buildSubSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2),
    );
  }

  Future<void> _loadExceptionNames() async {
    for (String uid in _aulasPorAluno.keys) {
      if (!_nomesPorAluno.containsKey(uid)) {
        final doc = await FirebaseFirestore.instance.collection(FirebaseCollections.alunos).doc(uid).get();
        if (doc.exists) {
          final data = doc.data();
          final personal = data?['dados_pessoais'] as Map<String, dynamic>?;
          setState(() => _nomesPorAluno[uid] = personal?['nome'] ?? '...');
        }
      }
    }
  }

  void _showStudentSearchBottomSheet() {
    final searchController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardDarkGrey,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(24),
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
            children: [
              const Text('CONFIGURAR EXCEÇÃO INDIVIDUAL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: _buildInputDecoration('Buscar aluno pelo nome...', LucideIcons.search),
                onChanged: (val) => setModalState(() {}),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection(FirebaseCollections.alunos).snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppTheme.accentGold));
                    final query = searchController.text.toLowerCase();
                    final filtered = snapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final personal = data['dados_pessoais'] as Map<String, dynamic>?;
                      final name = (personal?['nome'] ?? data['nome'] ?? '').toString().toLowerCase();
                      return name.contains(query);
                    }).toList();
                    return ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final alu = filtered[index];
                        final data = alu.data() as Map<String, dynamic>;
                        final name = (data['dados_pessoais']?['nome'] ?? data['nome'] ?? '...');
                        return ListTile(
                          title: Text(name, style: const TextStyle(color: Colors.white)),
                          subtitle: Text(data['role']?.toString().toUpperCase() ?? 'ALUNO', style: const TextStyle(color: AppTheme.textGrey, fontSize: 10)),
                          onTap: () {
                            Navigator.pop(ctx);
                            final personal = data['dados_pessoais'] as Map<String, dynamic>?;
                            final modRaw = personal?['modalidade'] ?? data['modalidade'];
                            List<String> userMods = [];
                            if (modRaw is String) userMods = [modRaw];
                            else if (modRaw is List) userMods = List<String>.from(modRaw);
                            
                            // Remove empty strings and ensure Geral is an option
                            userMods = userMods.where((m) => m.trim().isNotEmpty).toList();
                            if (!userMods.contains('Geral')) userMods.add('Geral');
                            
                            _showSetGoalDialog(alu.id, name, userMods);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSetGoalDialog(String uid, String name, List<String> userMods) {
    final Map<String, TextEditingController> checkinCtrls = {};
    final Map<String, TextEditingController> kiCtrls = {};
    final Map<String, TextEditingController> patchCtrls = {};

    for (var mod in userMods) {
      checkinCtrls[mod] = TextEditingController(text: (_aulasPorAluno[uid]?[mod] ?? 40).toString());
      kiCtrls[mod] = TextEditingController(text: (_kiPorAluno[uid]?[mod] ?? 100).toString());
      patchCtrls[mod] = TextEditingController(text: (_patchesPorAluno[uid]?[mod] ?? '').toString());
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDarkGrey,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('METAS CUSTOMIZADAS', style: TextStyle(color: AppTheme.accentGold, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            Text(name.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...userMods.map((mod) => Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(mod.toUpperCase(), style: const TextStyle(color: AppTheme.accentGold, fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 16),
                      TextField(
                        controller: checkinCtrls[mod],
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: _buildInputDecoration('Meta Check-ins (Físico)', LucideIcons.calendarCheck),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: kiCtrls[mod],
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: _buildInputDecoration('Meta KI (Teórico)', LucideIcons.zap),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: patchCtrls[mod],
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: _buildInputDecoration('URL do Patch Digital (Opcional)', LucideIcons.award),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCELAR', style: TextStyle(color: AppTheme.textGrey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentGold, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () {
              setState(() {
                _aulasPorAluno[uid] ??= {};
                _kiPorAluno[uid] ??= {};
                _patchesPorAluno[uid] ??= {};
                
                for (var mod in userMods) {
                  _aulasPorAluno[uid]![mod] = int.tryParse(checkinCtrls[mod]!.text) ?? 40;
                  _kiPorAluno[uid]![mod] = int.tryParse(kiCtrls[mod]!.text) ?? 100;
                  _patchesPorAluno[uid]![mod] = patchCtrls[mod]!.text.trim();
                }
              });
              Navigator.pop(ctx);
            },
            child: const Text('CONFIRMAR METAS', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
