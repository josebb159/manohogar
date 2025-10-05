import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class MisDescuentosScreen extends StatefulWidget {
  const MisDescuentosScreen({Key? key}) : super(key: key);

  @override
  State<MisDescuentosScreen> createState() => _MisDescuentosScreenState();
}

class _MisDescuentosScreenState extends State<MisDescuentosScreen> {
  Map<String, dynamic>? user;
  List<dynamic> descuentos = [];
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userData = prefs.getString('user');

    if (userData != null) {
      final userMap = json.decode(userData);
      setState(() {
        user = userMap;
      });
      obtenerDescuentos();
    } else {
      setState(() => cargando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se encontró información del usuario')),
      );
    }
  }

  Future<void> obtenerDescuentos() async {
    if (user == null) return;

    final uri = Uri.parse("https://manohogar.online/api/app_api.php?action=get_descuentos_servicio");

    // En este ejemplo, se podrían listar todos los descuentos del especialista
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'id_especialista': user!['id'].toString()}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print("Respuesta descuentos: $data");

      if (data['status'] == 'ok') {
        setState(() {
          descuentos = List.from(data['descuentos']);
          cargando = false;
        });
      } else {
        setState(() => cargando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Sin descuentos registrados')),
        );
      }
    } else {
      setState(() => cargando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error de conexión')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Transacciones"),
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : descuentos.isEmpty
          ? const Center(child: Text("No tienes descuentos aplicados"))
          : ListView.builder(
        itemCount: descuentos.length,
        itemBuilder: (context, index) {
          final descuento = descuentos[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 3,
            child: ListTile(
              leading: const Icon(Icons.percent, color: Colors.blue, size: 36),
              title: Text("Servicio ID: ${descuento['id_servicio']}"),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Monto servicio: \$${descuento['monto_servicio']}"),
                  Text("Descuento al monedero: -\$${descuento['monto_descuento']}"),
                  Text(
                    "Fecha: ${descuento['fecha_aplicacion']}",
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
