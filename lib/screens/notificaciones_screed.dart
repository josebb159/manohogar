import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({Key? key}) : super(key: key);

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  Map<String, dynamic>? user;
  List<dynamic> notificaciones = [];
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  /// 🔹 Cargar el usuario desde la sesión
  Future<void> _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userData = prefs.getString('user');
    if (userData != null) {
      final userMap = json.decode(userData);
      setState(() {
        user = userMap;
      });
      obtenerNotificaciones();
    } else {
      setState(() => cargando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se encontró información del usuario')),
      );
    }
  }

  /// 🔹 Obtener notificaciones del usuario
  Future<void> obtenerNotificaciones() async {
    if (user == null) return;

    final uri = Uri.parse(
        "https://manohogar.online/api/app_api.php?action=ver_notificaciones");

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'id_usuario': user!['id'].toString()}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'ok') {
          setState(() {
            notificaciones = List.from(data['notificaciones']);
            cargando = false;
          });

          // 🔹 Marcar todas como vistas al abrir
          marcarNotificacionesVistas();
        } else {
          setState(() => cargando = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? 'Sin notificaciones')),
          );
        }
      } else {
        setState(() => cargando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error de conexión con el servidor')),
        );
      }
    } catch (e) {
      setState(() => cargando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  /// 🔹 Marcar todas las notificaciones como vistas
  Future<void> marcarNotificacionesVistas() async {
    if (user == null) return;

    final uri = Uri.parse(
        "https://manohogar.online/api/app_api.php?action=marcar_notificacion_vista");

    try {
      await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'id_usuario': user!['id'].toString()}),
      );
    } catch (e) {
      print("⚠️ Error al marcar notificaciones vistas: $e");
    }
  }

  /// 🔹 Construir cada tarjeta de notificación
  Widget _buildNotificacionCard(dynamic noti) {
    final descripcion = noti['descripcion'] ?? 'Sin descripción';
    final fecha = noti['fecha'] ?? '';
    final vista = noti['visto'].toString() == '1';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: vista ? Colors.white : Colors.orange.shade50,
      elevation: 3,
      child: ListTile(
        leading: Icon(
          vista ? Icons.notifications_none : Icons.notifications_active,
          color: vista ? Colors.grey : Colors.orange,
          size: 32,
        ),
        title: Text(
          descripcion,
          style: TextStyle(
            fontWeight: vista ? FontWeight.normal : FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        subtitle: Text(
          fecha,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ),
    );
  }

  /// 🔹 Vista principal
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Notificaciones"),
        backgroundColor: Colors.orange,
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : notificaciones.isEmpty
          ? const Center(child: Text("No tienes notificaciones"))
          : RefreshIndicator(
        onRefresh: obtenerNotificaciones,
        child: ListView.builder(
          itemCount: notificaciones.length,
          itemBuilder: (context, index) {
            final noti = notificaciones[index];
            return _buildNotificacionCard(noti);
          },
        ),
      ),
    );
  }
}
