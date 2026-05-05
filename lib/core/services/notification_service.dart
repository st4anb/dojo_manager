import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:flutter/material.dart';

class NotificationService {
  static NotificationService? _instance;
  NotificationService._internal();

  static NotificationService get instance {
    _instance ??= NotificationService._internal();
    return _instance!;
  }

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  
  // Flags de controle para evitar loops infinitos e economizar bateria
  bool _isInitialized = false;
  bool _isTokenSynced = false;
  bool _isTrainingScheduled = false;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      tz.initializeTimeZones();
      const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
      const InitializationSettings settings = InitializationSettings(android: androidSettings, iOS: iosSettings);
      
      await _notificationsPlugin.initialize(settings);
      
      // Inicializa o FCM (Firebase Cloud Messaging)
      await _initFCM();
      
      _isInitialized = true;
      print("NotificationService: Inicializado com sucesso.");
    } catch (e) {
      print("Erro ao inicializar notificações: $e");
    }
  }

  Future<void> _initFCM() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _showForegroundNotify(message);
      });
    } catch (e) {
      print("Erro ao inicializar FCM: $e");
    }
  }

  void _showForegroundNotify(RemoteMessage message) {
    try {
      final notification = message.notification;
      if (notification != null) {
        _notificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'high_importance_channel',
              'Importantes',
              importance: Importance.max,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
            iOS: DarwinNotificationDetails(),
          ),
        );
      }
    } catch (e) {
      print("Erro ao mostrar notificação: $e");
    }
  }

  /// Sincroniza o token FCM com o Firestore (Apenas uma vez por sessão)
  Future<void> getAndSaveToken(String uid) async {
    if (_isTokenSynced) return; // Evita loop infinito se chamado no build

    try {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('ALUNOS').doc(uid).update({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
        _isTokenSynced = true;
        print("Token FCM sincronizado com sucesso.");
      }
    } catch (e) {
      print("Erro ao sincronizar token: $e");
    }
  }

  /// Agenda notificações de treino (Apenas uma vez por sessão)
  Future<void> agendarNotificacoesTreino(dynamic modalidades) async {
    if (_isTrainingScheduled) return; // Evita loop infinito se chamado no build
    if (modalidades == null || (modalidades is List && modalidades.isEmpty)) return;

    try {
      print("Agendando notificações para as modalidades: $modalidades");
      await _notificationsPlugin.cancelAll();

      List<String> listaModalidades = [];
      if (modalidades is List) {
        listaModalidades = modalidades.map((e) => e.toString()).toList();
      } else if (modalidades is String) {
        listaModalidades = [modalidades];
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('MODALIDADES') // Seguindo o padrão de caixa alta do usuário
          .where('nome', whereIn: listaModalidades)
          .get();

      int notificationId = 100;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final String nomeMod = data['nome'] ?? 'Treino';
        final List schedules = data['horarios'] ?? [];

        for (var s in schedules) {
          final int dia = s['dia'] ?? 1;
          final String inicioStr = s['inicio'] ?? "00:00";
          final parts = inicioStr.split(':');
          if (parts.length != 2) continue;
          
          final int hora = int.parse(parts[0]);
          final int min = int.parse(parts[1]);

          await _notificationsPlugin.zonedSchedule(
            notificationId++,
            'Hora de Treinar! 🥋',
            'Sua aula de $nomeMod começou. Bom treino!',
            _nextInstance(dia, hora, min),
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'treinos_channel',
                'Treinos',
                importance: Importance.max,
                priority: Priority.high,
              ),
              iOS: DarwinNotificationDetails(),
            ),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          );
        }
      }
      
      _isTrainingScheduled = true;
      print("Notificações de treino agendadas com sucesso.");
    } catch (e) {
      print("Erro ao agendar treinos: $e");
    }
  }

  tz.TZDateTime _nextInstance(int weekday, int hour, int minute) {
    tz.TZDateTime scheduledDate = _nextInstanceOfTime(hour, minute);
    while (scheduledDate.weekday != weekday) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  Future<void> schedulePaymentReminder(DateTime dataVencimento) async {
    try {
      final scheduledDate = DateTime.now().add(const Duration(days: 27));
      if (scheduledDate.isBefore(DateTime.now())) return;

      await _notificationsPlugin.zonedSchedule(
        0,
        'Vencimento Próximo',
        'Sua mensalidade vence em 3 dias.',
        tz.TZDateTime.from(scheduledDate, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'pagamentos_channel', 
            'Pagamentos', 
            importance: Importance.max, 
            priority: Priority.high
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      print("Erro ao agendar lembrete: $e");
    }
  }
}