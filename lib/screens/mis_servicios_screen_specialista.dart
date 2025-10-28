import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'ver_servicio_solicitado_especialista.dart';

class MisServiciosEspecialistaScreen extends StatefulWidget {
  const MisServiciosEspecialistaScreen({Key? key}) : super(key: key);

  @override
  State<MisServiciosEspecialistaScreen> createState() => _MisServiciosEspecialistaScreenState();
}

class _MisServiciosEspecialistaScreenState extends State<MisServiciosEspecialistaScreen> {
  Map<String, dynamic>? user;
  List<dynamic> servicios = [];
  List<dynamic> serviciosFiltrados = [];
  bool cargando = true;

  String estadoSeleccionado = 'Todos';

  final Map<String, String> estados = {
    'Todos': 'Todos',
    '0': 'Pendiente',
    '1': 'Aceptado',
    '5': 'En camino',
    '2': 'En proceso',
    '3': 'Finalizado',
    '4': 'Cancelado',
  };

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

    final uri = Uri.parse("https://manohogar.online/api/app_api.php?action=mis_servicios_especialista");

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'id_usuario': user!['id'].toString()}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print("Respuesta mis_servicios_especialista: $data");

      if (data['status'] == 'ok') {
        setState(() {
          if (data['servicio'] is List) {
            servicios = data['servicio'];
          } else {
            servicios = [data['servicio']];
          }
          serviciosFiltrados = List.from(servicios);
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

  void _filtrarServicios(String estado) {
    setState(() {
      estadoSeleccionado = estado;
      if (estado == 'Todos') {
        serviciosFiltrados = List.from(servicios);
      } else {
        serviciosFiltrados = servicios
            .where((s) => s['estado_servicio'].toString() == estado)
            .toList();
      }
    });
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
          : Column(
        children: [
          Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: DropdownButtonFormField<String>(
              value: estadoSeleccionado,
              decoration: InputDecoration(
                labelText: "Filtrar por estado",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
              ),
              items: estados.entries
                  .map((e) => DropdownMenuItem<String>(
                value: e.key,
                child: Text(e.value),
              ))
                  .toList(),
              onChanged: (valor) {
                if (valor != null) _filtrarServicios(valor);
              },
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: serviciosFiltrados.length,
              itemBuilder: (context, index) {
                final servicio = serviciosFiltrados[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 3,
                  child: ListTile(
                    leading: servicio['foto'] != null &&
                        servicio['foto'] != ""
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
                        : const Icon(Icons.home_repair_service,
                        size: 40, color: Colors.blue),
                    title: Text(servicio['categoria'] ?? 'Servicio sin título'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetalle(servicio['detalle'] ?? ''),
                        const SizedBox(height: 4),
                        _buildCalificacion(servicio['calificacion_especialista']),
                        const SizedBox(height: 4),
                        Text(
                          "Estado: ${_getEstadoServicio(servicio['estado_servicio'])}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VerServicioSolicitadoEspecialista(
                            idServicio: servicio['id_servicios'].toString(),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
