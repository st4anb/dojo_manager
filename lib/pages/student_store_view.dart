import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../core/theme/app_theme.dart';
import '../core/constants/firebase_collections.dart';
import '../core/constants/app_constants.dart';

import '../models/produto_model.dart';

class StudentStoreView extends StatefulWidget {
  const StudentStoreView({super.key});

  @override
  State<StudentStoreView> createState() => _StudentStoreViewState();
}

class _StudentStoreViewState extends State<StudentStoreView> {
  String selectedFilter = 'Tudo';

  Future<void> iniciarCompraWhatsApp(ProdutoModel produto, String telefoneSensei) async {
    try {
      // 1. Limpeza do Telefone (remove qualquer caractere não-numérico)
      String telefoneLimpo = telefoneSensei.replaceAll(RegExp(r'\D'), '');
      if (!telefoneLimpo.startsWith('55')) {
        telefoneLimpo = '55$telefoneLimpo';
      }

      // 2. Construção da Mensagem
      final String mensagem = 'Oss Sensei! 🥋\n'
          'Tenho interesse no seguinte produto da loja:\n\n'
          '*Item:* ${produto.nome}\n'
          '*Detalhes:* ${produto.descricao}\n'
          '*Valor:* R\$ ${(produto.preco / 100).toStringAsFixed(2)}\n\n'
          '${produto.imagemUrl}\n\n'
          'Ainda tem disponível para mim?';

      // 3. Encode e URI
      final String mensagemCodificada = Uri.encodeComponent(mensagem);
      final Uri whatsappUri = Uri.parse('https://wa.me/$telefoneLimpo?text=$mensagemCodificada');

      // 4. Execução
      if (!await launchUrl(whatsappUri, mode: LaunchMode.externalApplication)) {
        throw Exception('Não foi possível abrir o link do WhatsApp.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Não foi possível abrir o WhatsApp. Verifique se o app está instalado.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _encomendarItem(BuildContext context, ProdutoModel produto) async {
    if (!context.mounted) return;

    // 1. BUSCA DINÂMICA DO WHATSAPP (Solicitado pelo usuário)
    String telefone = AppConstants.whatsappNumber; // Fallback
    try {
      final configDoc = await FirebaseFirestore.instance.collection('config').doc('geral').get();
      if (configDoc.exists && configDoc.data()?['whatsapp_sensei'] != null) {
        telefone = configDoc.data()!['whatsapp_sensei'];
      }
    } catch (e) {
      debugPrint('Erro ao buscar WhatsApp da loja: $e');
    }

    // 3. Execução do Redirecionamento
    await iniciarCompraWhatsApp(produto, telefone);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('config').doc('loja').snapshots(),
            builder: (context, snapshot) {
              final data = snapshot.data?.data() as Map<String, dynamic>?;
              final List<String> categorias = List<String>.from(data?['categorias'] ?? ['Equipamentos', 'Vestuário', 'Suplementos']);
              
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<String>(
                  segments: [
                    const ButtonSegment(value: 'Tudo', label: Text('Tudo'), icon: Icon(LucideIcons.layoutGrid)),
                    ...categorias.map((c) => ButtonSegment(
                      value: c, 
                      label: Text(c.length > 5 ? '${c.substring(0, 5)}.' : c), 
                      icon: Icon(_getIconForCategory(c))
                    )),
                  ],
                  selected: {selectedFilter},
                  onSelectionChanged: (newSelection) {
                    setState(() {
                      selectedFilter = newSelection.first;
                    });
                  },
                  style: SegmentedButton.styleFrom(
                    backgroundColor: AppTheme.backgroundBlack,
                    selectedBackgroundColor: AppTheme.accentGold,
                    selectedForegroundColor: Colors.black,
                    foregroundColor: AppTheme.textGrey,
                    side: const BorderSide(color: AppTheme.accentGold, width: 0.5),
                  ),
                ),
              );
            }
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection(FirebaseCollections.lojaProdutos).where('ativo', isEqualTo: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: SelectableText(
                      'Erro ao carregar vitrine: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                    ),
                  ),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppTheme.accentGold));

              var docs = snapshot.data?.docs ?? [];
              
              if (selectedFilter != 'Tudo') {
                docs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final categoria = data['categoria']?.toString() ?? 'Geral';
                  return categoria == selectedFilter;
                }).toList();
              }

              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(selectedFilter == 'Tudo' ? LucideIcons.shoppingBag : LucideIcons.search, size: 64, color: AppTheme.textGrey),
                      const SizedBox(height: 24),
                      Text(
                        selectedFilter == 'Tudo' ? 'Nenhum produto cadastrado' : 'Sem itens em $selectedFilter',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        selectedFilter == 'Tudo' 
                          ? 'O Sensei ainda não publicou produtos na vitrine.' 
                          : 'Tente selecionar outra categoria ou volte para "Tudo".',
                        style: const TextStyle(color: AppTheme.textGrey, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      if (selectedFilter != 'Tudo')
                        TextButton(
                          onPressed: () => setState(() => selectedFilter = 'Tudo'),
                          child: const Text('VER TODOS OS PRODUTOS', style: TextStyle(color: AppTheme.accentGold)),
                        ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final produto = ProdutoModel.fromMap(docs[index].id, docs[index].data() as Map<String, dynamic>);
                  final urlImagem = produto.imagemUrl;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: AppTheme.cardDarkGrey,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.glassBorder),
                        boxShadow: AppTheme.premiumShadow,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ─── IMAGEM LATERAL COM PROTEÇÃO ───
                            Container(
                              width: 140,
                              decoration: const BoxDecoration(
                                color: AppTheme.backgroundBlack, // Fundo suave para imagens com transparência ou falha
                              ),
                              child: urlImagem.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: urlImagem, 
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => const Center(
                                      child: CircularProgressIndicator(color: AppTheme.accentGold, strokeWidth: 1.5)
                                    ),
                                    errorWidget: (context, url, error) => const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.image_not_supported_outlined, color: AppTheme.textGrey, size: 28),
                                        SizedBox(height: 4),
                                        Text('Sem Imagem', style: TextStyle(color: AppTheme.textGrey, fontSize: 8)),
                                      ],
                                    ),
                                  )
                                : const Center(
                                    child: Icon(Icons.image_not_supported, size: 32, color: Colors.white10),
                                  ),
                            ),
                            // Conteúdo
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(4)),
                                      child: Text(produto.categoria, style: const TextStyle(color: AppTheme.accentGold, fontSize: 9, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      produto.nome,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'R\$ ${(produto.preco / 100).toStringAsFixed(2)}',
                                      style: const TextStyle(color: AppTheme.accentGold, fontWeight: FontWeight.bold, fontSize: 18),
                                    ),
                                    const Spacer(),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor: Colors.black,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            elevation: 0,
                                        ),
                                        onPressed: () => _encomendarItem(context, produto),
                                        icon: const Icon(LucideIcons.shoppingCart, size: 16),
                                        label: const Text('ENCOMENDAR AGORA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                );
            },
          ),
        ),
      ],
    );
  }

  IconData _getIconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'equipamentos': return LucideIcons.shield;
      case 'vestuário': return LucideIcons.shirt;
      case 'suplementos': return LucideIcons.fuel;
      case 'acessórios': return LucideIcons.watch;
      case 'kimonos': return LucideIcons.layers;
      default: return LucideIcons.package;
    }
  }
}
