import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class EspecialistaDetallePage extends StatefulWidget {
  const EspecialistaDetallePage({Key? key}) : super(key: key);

  @override
  _EspecialistaDetallePageState createState() =>
      _EspecialistaDetallePageState();
}

class _EspecialistaDetallePageState extends State<EspecialistaDetallePage> {
  List<dynamic> especialistas = [];
  bool isLoading = true;
  Map<String, dynamic>? user;

  // 🔹 Mapa de íconos personalizados
  final Map<String, IconData> fieldIcons = {
    "nombre_completo": Icons.badge,
    "telefono": Icons.phone,
    "correo": Icons.email,
    "categories_selected": Icons.work_outline,
    "anio_experiencia": Icons.timeline,
    "metodos_pago": Icons.payment,
    "cartera": Icons.account_balance_wallet,
    "ciudad": Icons.location_city,
    "nacionalidad": Icons.flag,
    "cedula": Icons.credit_card,
    "aprobado": Icons.verified,
    "fecha_registro": Icons.calendar_today,
    "fecha_actualizacion": Icons.update,
    "estado": Icons.info,
    "latitud": Icons.location_on,
    "longitud": Icons.location_on,
  };

  Future<void> _getInfoEspecialista() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userData = prefs.getString('user');

    print("📦 Datos guardados en SharedPreferences: $userData");

    if (userData != null) {
      final userMap = json.decode(userData);
      print("👤 UserMap decodificado: $userMap");

      setState(() {
        user = userMap;
      });
    } else {
      print("⚠️ No se encontró información del usuario en SharedPreferences");
      return;
    }

    try {
      print("➡️ Enviando request con user_id: ${user!['id']}");

      final res = await http.post(
        Uri.parse(
            'https://manohogar.online/api/app_api.php?action=getInfoEspecialista'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'user_id': user!['id'].toString()}),
      );

      print("📡 Status Code: ${res.statusCode}");
      print("📥 Response Body: ${res.body}");

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        print("✅ JSON decodificado: $data");

        if (data['status'] == 'ok') {
          setState(() {
            especialistas = [data['datos']];
            isLoading = false;
          });
          print("🎯 Especialistas cargados: ${especialistas.length}");
        } else {
          setState(() {
            isLoading = false;
          });
        }
      } else {
        throw Exception("Error en la petición: ${res.statusCode}");
      }
    } catch (e, stacktrace) {
      print("❌ Excepción: $e");
      print("📌 StackTrace: $stacktrace");
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _getInfoEspecialista();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Perfil del Especialista"),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.deepOrange,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : especialistas.isEmpty
          ? const Center(child: Text("No se encontraron especialistas"))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: especialistas.length,
        itemBuilder: (context, index) {
          final esp = especialistas[index];

          return Card(
            margin: const EdgeInsets.only(bottom: 20),
            elevation: 5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 📌 Foto principal
                  if (esp["foto"] != null &&
                      esp["foto"].toString().isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        esp["foto"],
                        height: 220,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (context, error, stackTrace) =>
                        const Icon(Icons.broken_image,
                            size: 100),
                      ),
                    ),

                  const SizedBox(height: 20),

                  // 📌 Datos en lista
                  Column(
                    children: esp.entries.map<Widget>((entry) {
                      final key = entry.key;
                      final value = entry.value;

                      // Saltamos imágenes que ya mostramos arriba
                      if (key == "foto" ||
                          key == "antecedentes" ||
                          key == "cedula_frontal" ||
                          key == "cedula_trasera") {
                        return const SizedBox.shrink();
                      }

                      return Container(
                        margin: const EdgeInsets.symmetric(
                            vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: Icon(
                            fieldIcons[key] ??
                                Icons.label_outline, // 🔹 ícono dinámico
                            color: Colors.deepOrange,
                          ),
                          title: Text(
                            key.replaceAll("_", " "),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
                          ),
                          subtitle: Text(
                            value?.toString() ?? "N/A",
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // 📌 Galería de imágenes (antecedentes / cédulas)
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      if (esp["antecedentes"] != null)
                        _buildImageTile(
                            "Antecedentes", esp["antecedentes"]),
                      if (esp["cedula_frontal"] != null)
                        _buildImageTile(
                            "Cédula frontal", esp["cedula_frontal"]),
                      if (esp["cedula_trasera"] != null)
                        _buildImageTile(
                            "Cédula trasera", esp["cedula_trasera"]),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // 🔹 Widget helper para mostrar imágenes con título
  Widget _buildImageTile(String title, String url) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            url,
            height: 140,
            width: 140,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.broken_image, size: 60),
          ),
        ),
      ],
    );
  }
}
