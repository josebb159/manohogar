import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'RecargaScreen.dart';

class EspecialistaDetallePage extends StatefulWidget {
  const EspecialistaDetallePage({Key? key}) : super(key: key);

  @override
  _EspecialistaDetallePageState createState() =>
      _EspecialistaDetallePageState();
}

class _EspecialistaDetallePageState extends State<EspecialistaDetallePage> {
  Map<String, dynamic>? especialista;
  bool isLoading = true;
  Map<String, dynamic>? user;

  Future<void> _getInfoEspecialista() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userData = prefs.getString('user');

    if (userData == null) {
      print("⚠️ No se encontró información del usuario en SharedPreferences");
      return;
    }

    user = json.decode(userData);

    try {
      final res = await http.post(
        Uri.parse(
            'https://manohogar.online/api/app_api.php?action=getInfoEspecialista'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'user_id': user!['id'].toString()}),
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['status'] == 'ok') {
          setState(() {
            especialista = data['datos'];
            isLoading = false;
          });
        } else {
          setState(() => isLoading = false);
        }
      } else {
        throw Exception("Error en la petición: ${res.statusCode}");
      }
    } catch (e) {
      print("❌ Excepción: $e");
      setState(() => isLoading = false);
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
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.deepOrange),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Perfil del especialista",
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : especialista == null
          ? const Center(child: Text("No se encontró información"))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 👋 Nombre
            Text(
              "!Hola, ${especialista!['nombre_completo'] ?? 'Usuario'}!",
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const SizedBox(height: 16),

            // 💰 Saldo cartera
            Container(
              width: MediaQuery.of(context).size.width, // 🔹 Usa todo el ancho disponible
              margin: const EdgeInsets.symmetric(horizontal: 4), // 🔹 Pequeño margen a los lados
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      const Icon(Icons.account_balance_wallet,
                          color: Colors.orange, size: 40),
                      const SizedBox(height: 8),
                      const Text(
                        "Saldo cartera",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "COL ${especialista!['monedero'] ?? '0'}",
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RecargaScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepOrange,
                          padding:
                          const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "Recargar",
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
,

            const SizedBox(height: 20),

            // 📊 Estadísticas simuladas
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatCard(especialista!['ingreso']?.toString() ?? "0 COP", "Ingresos",
                    Colors.green.shade100, Colors.green),
                _buildStatCard(especialista!['total_servicios']?.toString() ?? "0", "Trabajos",
                    Colors.blue.shade100, Colors.blue),
                _buildStatCard(
                  especialista!['calificacion']?.toString() ?? "0",
                  "Calificación",
                  Colors.amber.shade100,
                  Colors.amber[800]!,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 🧩 Categorías
            _buildInfoSection(
              title: "Mis Categorías",
              content:
              (especialista!['categories_selected'] ?? '')
                  .toString()
                  .split(',')
                  .join('   '),
            ),

            // 💳 Métodos de pago
            _buildInfoSection(
              title: "Métodos de pago recibido",
              content:
              (especialista!['metodos_pago'] ?? '')
                  .toString()
                  .split(',')
                  .join('   '),
            ),

            // 🌍 Nacionalidad y ciudad
            _buildInfoSection(
              title: "Nacionalidad - Ciudad",
              content:
              "${especialista!['nacionalidad'] ?? ''}   ${especialista!['ciudad'] ?? ''}",
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String value, String label, Color bgColor, Color textColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                  color: textColor, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    color: Colors.black54, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection({required String title, required String content}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE0B2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            content,
            style: const TextStyle(
                color: Colors.deepOrange,
                fontSize: 15,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
