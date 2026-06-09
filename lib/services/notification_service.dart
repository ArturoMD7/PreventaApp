import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  RealtimeChannel? _channel;
  String? _userId;

  Future<void> init() async {
    if (kIsWeb) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _localNotifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    const androidChannel = AndroidNotificationChannel(
      'pedidos',
      'Pedidos',
      description: 'Notificaciones de nuevos pedidos y cambios de estado',
      importance: Importance.high,
    );
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(androidChannel);

    _startRealtimeSubscription();
  }

  void _startRealtimeSubscription() {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    _userId = user.id;

    _channel?.unsubscribe();

    _channel = _supabase
        .channel('ventas-provider-$_userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'ventas',
          filter: PostgresChangeFilter(
            column: 'user_id',
            type: PostgresChangeFilterType.eq,
            value: _userId,
          ),
          callback: _handleInsert,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'ventas',
          filter: PostgresChangeFilter(
            column: 'user_id',
            type: PostgresChangeFilterType.eq,
            value: _userId,
          ),
          callback: _handleUpdate,
        )
        .subscribe();
  }

  Future<void> _handleInsert(PostgresChangePayload payload) async {
    final newRecord = payload.newRecord;
    final String? clienteId = newRecord['cliente_id'];
    final double total =
        (newRecord['total'] as num?)?.toDouble() ?? 0.0;

    String clienteNombre = 'Desconocido';
    if (clienteId != null) {
      try {
        final res = await _supabase
            .from('clientes')
            .select('nombre')
            .eq('id', clienteId)
            .maybeSingle();
        if (res != null) {
          clienteNombre = res['nombre'] ?? 'Desconocido';
        }
      } catch (_) {}
    }

    _showNotification(
      title: 'Nuevo Pedido',
      body: '$clienteNombre - Total: \$${total.toStringAsFixed(2)}',
    );
  }

  Future<void> _handleUpdate(PostgresChangePayload payload) async {
    final oldRecord = payload.oldRecord;
    final newRecord = payload.newRecord;

    final String oldEstado = oldRecord['estado'] ?? '';
    final String newEstado = newRecord['estado'] ?? '';

    if (newEstado == 'cancelado' && oldEstado != 'cancelado') {
      final String? clienteId = newRecord['cliente_id'];

      String clienteNombre = 'Desconocido';
      if (clienteId != null) {
        try {
          final res = await _supabase
              .from('clientes')
              .select('nombre')
              .eq('id', clienteId)
              .maybeSingle();
          if (res != null) {
            clienteNombre = res['nombre'] ?? 'Desconocido';
          }
        } catch (_) {}
      }

      _showNotification(
        title: 'Pedido Cancelado',
        body: '$clienteNombre ha cancelado su pedido',
      );
    }
  }

  void _showNotification({
    required String title,
    required String body,
  }) {
    final notificationId =
        DateTime.now().millisecondsSinceEpoch.remainder(100000);
    _localNotifications.show(
      notificationId,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'pedidos',
          'Pedidos',
          channelDescription: 'Notificaciones de pedidos',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  void refreshSubscription() {
    _startRealtimeSubscription();
  }

  void dispose() {
    _channel?.unsubscribe();
  }
}
