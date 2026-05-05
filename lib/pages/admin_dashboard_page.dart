import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import 'financial_list_view.dart';
import 'store_admin_view.dart';
import 'admin_access_management_view.dart';
import 'students_list_view.dart';
import 'attendance_dashboard_view.dart';
import '../delegates/manual_checkin_delegate.dart';
import 'schedule_view.dart';
import '../delegates/student_search_delegate.dart'; // [RESTAURADO]
import 'admin_events_view.dart';
import 'admin_tatame_view.dart'; // [NOVO]
import 'admin_destaques_view.dart'; // [IMPORT]
import 'settings_page.dart'; // [IMPORT]
import '../widgets/glass_container.dart';
import '../core/services/notification_service.dart';
import '../core/utils/pwa_utils.dart';


class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}
class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {

  // --- ADICIONE ESTAS LINHAS AQUI ---
  int _selectedIndex = 0;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  // ----------------------------------

  // O restante do seu código (initState, dispose, build...) continua abaixo
  @override
  void initState() {
    super.initState();
    // Inicializa o serviço de notificações
    NotificationService.instance.init();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildLogoutButton({bool isMobile = false}) {
    return PremiumClickable(
      onTap: () => FirebaseAuth.instance.signOut(),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 16,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFDC3545).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFDC3545).withValues(alpha: 0.3),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFDC3545).withValues(alpha: 0.1),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  LucideIcons.logOut,
                  color: Color(0xFFFF4D5E),
                  size: 18,
                ),
                if (!isMobile) ...[
                  const SizedBox(width: 8),
                  const Text(
                    'SAIR',
                    style: TextStyle(
                      color: Color(0xFFFF4D5E),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainArea() {
    switch (_selectedIndex) {
      case 0:
        return AttendanceDashboardView(onTabSelected: (index) => setState(() => _selectedIndex = index));
      case 1:
        return const FinancialListView();
      case 2:
        return const StoreAdminView();
      case 3:
        return const AdminAccessManagementView(); // Central de Acesso
      case 4:
        return StudentsListView(searchController: _searchController); // Lista técnica
      case 5:
        return const ScheduleView();
      case 6:
        return const AdminEventsView();
      case 7:
        return const AdminTatameView();
      case 8:
        return const AdminDestaquesView();
      default:
        return const Center(child: Text('Em breve...', style: TextStyle(color: Colors.white)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);

    // [CORREÇÃO BUG 2] Aguarda o carregamento do perfil e a disponibilidade dos dados para evitar o Flash de "Acesso Negado"
    if (profileAsync.isLoading || !profileAsync.hasValue) {
      return const Scaffold(
        backgroundColor: AppTheme.backgroundBlack,
        body: Center(child: CircularProgressIndicator(color: AppTheme.accentGold)),
      );
    }

    final profile = profileAsync.value;
    final isAdmin = profile?.role == 'admin';

    // Escuta o perfil para sincronizar o token do Sensei (Executa apenas uma vez devido à flag no serviço)
    ref.listen(userProfileProvider, (prev, next) {
      if (next.hasValue && next.value != null) {
        final p = next.value!;
        if (p.role == 'admin') {
          NotificationService.instance.getAndSaveToken(p.uid);
        }
      }
    });

    if (!isAdmin) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundBlack,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(LucideIcons.shieldAlert, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              const Text('ACESSO NEGADO', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Você não tem permissão para acessar esta área.', style: TextStyle(color: AppTheme.textGrey)),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: () => FirebaseAuth.instance.signOut(), child: const Text('VOLTAR')),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 800;

        if (isMobile) {
          return Scaffold(
            backgroundColor: AppTheme.backgroundBlack,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: _isSearching && _selectedIndex == 4
                  ? TextField(
                      controller: _searchController,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Buscar aluno...',
                        hintStyle: TextStyle(color: AppTheme.textGrey),
                        border: InputBorder.none,
                      ),
                      onChanged: (val) => setState(() {}),
                    )
                  : const Text('Sensei Admin', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
              actions: [
                if (_selectedIndex == 4)
                  IconButton(
                    icon: Icon(_isSearching ? LucideIcons.x : LucideIcons.search, color: AppTheme.accentGold),
                    onPressed: () {
                      setState(() {
                        _isSearching = !_isSearching;
                        if (!_isSearching) {
                          _searchController.clear();
                        }
                      });
                    },
                  )
                else
                    IconButton(
                      icon: const Icon(LucideIcons.search, color: AppTheme.accentGold),
                      onPressed: () => showSearch(context: context, delegate: StudentSearchDelegate()),
                    ),
                  IconButton(
                    icon: const Icon(LucideIcons.refreshCw, color: AppTheme.accentGold),
                    onPressed: () => PWAUtils.hardRefresh(),
                    tooltip: 'Hard Refresh PWA',
                  ),
                Padding(
                  padding: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
                  child: _buildLogoutButton(isMobile: true),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.settings, color: AppTheme.textGrey),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage())),
                ),
              ],
            ),
            floatingActionButton: _selectedIndex == 0 
              ? FloatingActionButton.extended(
                  onPressed: () => showSearch(context: context, delegate: ManualCheckinDelegate()),
                  backgroundColor: AppTheme.accentGold,
                  icon: const Icon(LucideIcons.unlock, color: Colors.black),
                  label: const Text('Liberação Manual', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                )
              : null,
            body: SafeArea(child: _buildMainArea()),
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
              ),
              child: BottomNavigationBar(
                backgroundColor: AppTheme.backgroundBlack,
                selectedItemColor: AppTheme.accentGold,
                unselectedItemColor: AppTheme.textGrey,
                currentIndex: _selectedIndex,
                type: BottomNavigationBarType.fixed,
                onTap: (index) {
                  setState(() {
                    _selectedIndex = index;
                    _isSearching = false;
                    _searchController.clear();
                  });
                },
                items: const [
                  BottomNavigationBarItem(icon: Icon(LucideIcons.barChart2), label: 'Dash'),
                  BottomNavigationBarItem(icon: Icon(LucideIcons.banknote), label: 'Grana'),
                  BottomNavigationBarItem(icon: Icon(LucideIcons.shoppingBag), label: 'Loja'),
                  BottomNavigationBarItem(icon: Icon(LucideIcons.shieldCheck), label: 'Acesso'),
                  BottomNavigationBarItem(icon: Icon(LucideIcons.users), label: 'Alunos'),
                  BottomNavigationBarItem(icon: Icon(LucideIcons.calendarDays), label: 'Grade'),
                  BottomNavigationBarItem(icon: Icon(LucideIcons.calendar), label: 'Eventos'),
                  BottomNavigationBarItem(icon: Icon(LucideIcons.messageSquare), label: 'Tatame'),
                  BottomNavigationBarItem(icon: Icon(LucideIcons.award), label: 'Destaques'),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppTheme.backgroundBlack,
          body: Row(
            children: [
              // Glass Sidebar
              Container(
                width: 100,
                decoration: BoxDecoration(
                  color: AppTheme.cardDarkGrey,
                  border: Border(
                    right: BorderSide(color: AppTheme.glassBorder),
                  ),
                ),
                child: NavigationRail(
                  backgroundColor: Colors.transparent,
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (int index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                  labelType: NavigationRailLabelType.all,
                  selectedIconTheme: const IconThemeData(color: Colors.black, size: 28),
                  unselectedIconTheme: const IconThemeData(color: AppTheme.textGrey, size: 24),
                  selectedLabelTextStyle: const TextStyle(color: AppTheme.accentGold, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.5),
                  unselectedLabelTextStyle: const TextStyle(color: AppTheme.textGrey, fontSize: 10),
                  useIndicator: true,
                  indicatorColor: AppTheme.accentGold,
                  indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  trailing: Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('V16', style: TextStyle(color: AppTheme.accentGold, fontSize: 10, fontWeight: FontWeight.w900)),
                            const Text('ONCE FORCE SYNC', style: TextStyle(color: Colors.white24, fontSize: 6, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),
                            IconButton(
                              icon: const Icon(LucideIcons.settings, color: AppTheme.textGrey, size: 20),
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage())),
                            ),
                            IconButton(
                              icon: const Icon(LucideIcons.refreshCw, color: AppTheme.accentGold, size: 20),
                              onPressed: () => PWAUtils.hardRefresh(),
                              tooltip: 'Hard Refresh PWA',
                            ),
                            const SizedBox(height: 12),
                            _buildLogoutButton(),
                          ],
                        ),
                      ),
                    ),
                  ),
                  destinations: const [
                    NavigationRailDestination(icon: Icon(LucideIcons.layoutDashboard), label: Text('DASHBOARD')),
                    NavigationRailDestination(icon: Icon(LucideIcons.banknote), label: Text('FINANCEIRO')),
                    NavigationRailDestination(icon: Icon(LucideIcons.shoppingBag), label: Text('LOJA')),
                    NavigationRailDestination(icon: Icon(LucideIcons.shieldCheck), label: Text('ACESSO')),
                    NavigationRailDestination(icon: Icon(LucideIcons.users), label: Text('ALUNOS')),
                    NavigationRailDestination(icon: Icon(LucideIcons.calendarDays), label: Text('GRADE')),
                    NavigationRailDestination(icon: Icon(LucideIcons.calendar), label: Text('EVENTOS')),
                    NavigationRailDestination(icon: Icon(LucideIcons.messageSquare), label: Text('TATAME')),
                    NavigationRailDestination(icon: Icon(LucideIcons.award), label: Text('DESTAQUES')),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    // Top Bar with "URL" and Profile
                    Container(
                      height: 70,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundBlack,
                        border: Border(bottom: BorderSide(color: AppTheme.glassBorder)),
                      ),
                      child: Row(
                        children: [
                          // Fake Browser URL Bar
                          Expanded(
                            child: Container(
                              height: 38,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(LucideIcons.lock, color: Colors.greenAccent, size: 14),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'dojo-manager-2bf1a.web.app/admin',
                                    style: TextStyle(color: AppTheme.textGrey, fontSize: 12, letterSpacing: 0.5),
                                  ),
                                  const Spacer(),
                                  Icon(LucideIcons.rotateCcw, color: Colors.white.withValues(alpha: 0.2), size: 14),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 32),
                          // Notifications & Profile
                          const Icon(LucideIcons.bell, color: AppTheme.textGrey, size: 20),
                          const SizedBox(width: 24),
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              gradient: AppTheme.premiumGoldGradient,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 2),
                            ),
                            child: const Center(child: Icon(LucideIcons.user, color: Colors.black, size: 18)),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1600),
                          child: _buildMainArea(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: _selectedIndex == 0 
            ? Container(
                margin: const EdgeInsets.only(right: 20, bottom: 20),
                child: ElevatedButton.icon(
                  onPressed: () => showSearch(context: context, delegate: ManualCheckinDelegate()),
                  icon: const Icon(LucideIcons.lock, size: 20),
                  label: const Text('LIBERAÇÃO MANUAL'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentGold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                    elevation: 20,
                    shadowColor: AppTheme.accentGold.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 14),
                  ),
                ),
              )
            : null,
        );
      },
    );
  }
}
