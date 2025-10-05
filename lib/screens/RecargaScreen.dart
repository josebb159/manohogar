import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class RecargaScreen extends StatefulWidget {
  const RecargaScreen({super.key});

  @override
  State<RecargaScreen> createState() => _RecargaScreenState();
}

class _RecargaScreenState extends State<RecargaScreen> {
  Map<String, dynamic>? user;
  final TextEditingController _montoController = TextEditingController();

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
    }
  }

  void _abrirNavegador() async {
    if (user == null) return;

    final monto = int.tryParse(_montoController.text.replaceAll(',', '')) ?? 0;
    if (monto < 10000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("El monto mínimo es 10.000 COP")),
      );
      return;
    }

    // URL apuntando a recarga.php en tu servidor
    final url = Uri.parse(
      "https://manohogar.online/api/recarga.php?"
          "user_id=${user!['id']}"
          "&monto=$monto",
    );

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No se pudo abrir el navegador")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Recargar con Epayco")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (user != null)
              Text("Usuario: ${user!['nombre']}", style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 10),
            TextField(
              controller: _montoController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Monto a recargar (COP)",
                hintText: "Ej: 10000",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _abrirNavegador,
              child: const Text("Recargar"),
            ),
          ],
        ),
      ),
    );
  }
}
