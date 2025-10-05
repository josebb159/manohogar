import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'ver_servicio_solicitado.dart';

class MisServiciosScreen extends StatefulWidget {
  const MisServiciosScreen({Key? key}) : super(key: key);

  @override
  State<MisServiciosScreen> createState() => _MisServiciosScreenState();
}

class _MisServiciosScreenState extends State<MisServiciosScreen> {
  Map<String, dynamic>? user;
  List<dynamic> servicios = [];
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  String _getEstadoServicio(dynamic estado) {
    switch (estado.toString()) {
      case "0":
        return "Pendiente";
      case "1":
        return "Aceptado";
      case "5":
        return "En camino";
      case "2":
        return "En proceso";
      case "3":
        return "Finalizado";
      case "4":
        return "Cancelado";
      default:
        return "Desconocido";
    }
  }


  Future<void> _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userData = prefs.getString('user');
    if (userData != null) {
      final userMap = json.decode(userData);
      setState(() {
        user = userMap;
      });
      obtenerServicios();
    } else {
      setState(() => cargando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se encontró información del usuario')),
      );
    }
  }

  Future<void> obtenerServicios() async {
    if (user == null) return;

    final uri = Uri.parse("https://manohogar.online/api/app_api.php?action=mis_servicios");

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'id_usuario': user!['id'].toString()}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print("Respuesta mis_servicios: $data");

      if (data['status'] == 'ok') {
        setState(() {
          servicios = List.from(data['servicios']); // 👈 ahora plural
          cargando = false;
        });
      } else {
        setState(() => cargando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Sin servicios')),
        );
      }
    } else {
      setState(() => cargando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error de conexión')),
      );
    }
  }

  Widget _buildCalificacion(dynamic calificacion) {
    int stars = 0;

    if (calificacion is int) {
      stars = calificacion;
    } else if (calificacion is String) {
      stars = int.tryParse(calificacion) ?? 0;
    }

    return Row(
      children: List.generate(
        5,
            (index) => Icon(
          index < stars ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: 18,
        ),
      ),
    );
  }


  Widget _buildDetalle(String detalle) {
    const maxLength = 60;
    if (detalle.length <= maxLength) {
      return Text(detalle);
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("${detalle.substring(0, maxLength)}..."),
          GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("Detalle completo"),
                  content: Text(detalle),
                  actions: [
                    TextButton(
                      child: const Text("Cerrar"),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              );
            },
            child: const Text(
              "Ver más",
              style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mis Servicios"),
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : servicios.isEmpty
          ? const Center(child: Text("No tienes servicios"))
          : ListView.builder(
        itemCount: servicios.length,
        itemBuilder: (context, index) {
          final servicio = servicios[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 3,
            child: ListTile(
              leading: servicio['foto'] != null && servicio['foto'] != ""
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  servicio['foto'],
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                  const Icon(Icons.image_not_supported),
                ),
              )
                  : const Icon(Icons.home_repair_service, size: 40, color: Colors.blue),
              title: Text(servicio['categoria'] ?? 'Servicio sin título'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetalle(servicio['detalle'] ?? ''),
                  const SizedBox(height: 4),
                  _buildCalificacion(servicio['calificacion']),
                  Text(
                      "Estado: ${_getEstadoServicio(servicio['estado_servicio'])}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      )),

                ],
              ),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VerServicioSolicitado(
                      idServicio: servicio['id_servicios'].toString(),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
