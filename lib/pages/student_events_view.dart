import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/app_theme.dart';
import '../core/constants/firebase_collections.dart';
import '../models/evento_model.dart'; // [IMPORT NOVO]

class StudentEventsView extends StatelessWidget {
  const StudentEventsView({super.key});

  Future<void> _openLink(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openWhatsApp(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final url = "https://wa.me/$cleanPhone?text=Olá! Gostaria de mais informações sobre o evento.";
    await _openLink(url);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(FirebaseCollections.eventos)
          .where('ativo', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.accentGold));
        }
        
        final docs = snapshot.data?.docs ?? [];
        
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.calendarOff, size: 80, color: AppTheme.textGrey),
                const SizedBox(height: 24),
                const Text('Dojo em Silêncio...', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Não há eventos programados no momento.', style: TextStyle(color: AppTheme.textGrey, fontSize: 14)),
              ],
            ),
          );
        }

        final now = DateTime.now();
        
        // Mapeia docs usando o Model para garantir consistência
        final events = docs.map((doc) => EventoModel.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList();
        
        // Filtra eventos de hoje
        final todayEvents = events.where((e) {
          final date = e.dataEvento;
          return date.year == now.year && date.month == now.month && date.day == now.day;
        }).toList();

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (todayEvents.isNotEmpty) ...[
              const Text('🔔 LEMBRETE DE HOJE', 
                style: TextStyle(color: AppTheme.accentGold, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              const SizedBox(height: 12),
              ...todayEvents.map((event) => _buildTodayReminderCard(event)),
              const SizedBox(height: 32),
              const Divider(color: Colors.white10),
              const SizedBox(height: 24),
            ],
            
            const Text('PRÓXIMOS EVENTOS', 
              style: TextStyle(color: AppTheme.textGrey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 16),
            
            ...events.map((event) => _buildEventCard(context, event)),
          ],
        );
      },
    );
  }

  Widget _buildTodayReminderCard(EventoModel event) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.accentGold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentGold.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppTheme.accentGold.withValues(alpha: 0.2), shape: BoxShape.circle),
            child: const Icon(LucideIcons.bell, color: AppTheme.accentGold, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.titulo, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const Text('Hoje, em horário de destaque', style: TextStyle(color: AppTheme.accentGold, fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(BuildContext context, EventoModel event) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: AppTheme.cardDarkGrey,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.glassBorder),
        boxShadow: AppTheme.premiumShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── FLYER DO EVENTO (Protegido contra distorção) ───
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 450, // Altura máxima para não "quebrar" o layout no Web
              minWidth: double.infinity,
            ),
            child: Container(
              color: Colors.black, // Fundo de contraste para flyers com proporções variadas
              child: Image.network(
                event.imagemUrl,
                fit: BoxFit.contain, // Crucial: Mostra o flyer inteiro com leitura preservada
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 200, 
                  color: AppTheme.backgroundBlack, 
                  child: const Icon(LucideIcons.imageOff, color: AppTheme.textGrey)
                ),
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.titulo, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text(
                  event.descricao,
                  style: const TextStyle(color: AppTheme.textGrey, fontSize: 14, height: 1.6),
                ),
                const SizedBox(height: 24),
                
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Venda de ingressos via Pix em breve!'), backgroundColor: AppTheme.accentGold),
                          );
                        },
                        icon: const Icon(LucideIcons.ticket),
                        label: const Text('GARANTIR INGRESSO'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentGold,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openWhatsApp('5511999999999'), // Fallback phone
                        icon: const Icon(LucideIcons.messageCircle),
                        label: const Text('DÚVIDAS'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
