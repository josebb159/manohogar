import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'ver_servicio_solicitado.dart';
// 🔹 Nueva vista a la que redirige cuando se acepta una oferta
class DetalleServicioPage extends StatelessWidget {
  final int idServicio;

  const DetalleServicioPage({super.key, required this.idServicio});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Servicio #$idServicio')),
      body: Center(
        child: Text(
          'Detalles del servicio $idServicio',
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}

class CronologiaOfertaPage extends StatefulWidget {
  final int idServicio;
  final int idUsuario; // cliente o solicitante
  final int idDomiciliario; // especialista
  final String remitente; // "especialista"

  const CronologiaOfertaPage({
    super.key,
    required this.idServicio,
    required this.idUsuario,
    required this.idDomiciliario,
    required this.remitente,
  });

  @override
  State<CronologiaOfertaPage> createState() => _CronologiaOfertaPageState();
}

class _CronologiaOfertaPageState extends State<CronologiaOfertaPage> {
  final TextEditingController _ofertaController = TextEditingController();
  List<Map<String, dynamic>> ofertas = [];
  bool enviando = false;
  Map<String, dynamic> user = {};
  Timer? _timer; // 🔹 Para el refresco automático

  @override
  void initState() {
    super.initState();
    getOfertas();
    _loadUserData();

    // 🔹 Actualizar cada 30 segundos
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      getOfertas();
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // 🔹 Detenemos el timer al salir
    super.dispose();
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

  final String apiUrl = "https://manohogar.online/api/app_api.php";

  Future<void> getOfertas() async {
    try {
      final response = await http.post(
        Uri.parse("$apiUrl?action=get_ofertas_servicio"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"id_servicio": widget.idServicio}),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData["status"] == "ok") {
          setState(() {
            ofertas = List<Map<String, dynamic>>.from(jsonData["ofertas"]);
          });
        }
      }
    } catch (e) {
      print("💥 Error al obtener ofertas: $e");
    }
  }

  Future<void> enviarOferta() async {
    if (_ofertaController.text.isEmpty) return;

    setState(() => enviando = true);

    try {
      final response = await http.post(
        Uri.parse("$apiUrl?action=registrar_oferta"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "id_servicio": widget.idServicio,
          "id_usuario": widget.idUsuario,
          "monto": _ofertaController.text,
          "especialista": user['id'],
          "remitente": "especialista",
        }),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData["status"] == "ok") {
          _ofertaController.clear();
          await getOfertas();
        } else {
          print("⚠️ Error registrar oferta: ${jsonData['message']}");
        }
      }
    } catch (e) {
      print("💥 Error al registrar oferta: $e");
    } finally {
      setState(() => enviando = false);
    }
  }

  Future<void> aceptarOferta(int idOferta) async {
    try {
      final response = await http.post(
        Uri.parse("$apiUrl?action=aceptar_oferta"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"id_oferta": idOferta}),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData["status"] == "ok") {
          // 🔹 Redirigir a la nueva vista y eliminar la actual
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    VerServicioSolicitado(idServicio: widget.idServicio.toString())
              ),
            );
          }
        } else {
          print("⚠️ Error aceptar oferta: ${jsonData['message']}");
        }
      }
    } catch (e) {
      print("💥 Error al aceptar oferta: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final yaOferto = ofertas.any((o) =>
    o["remitente"] == "especialista" &&
        (o["estado"] == "pendiente" || o["estado"] == "aceptada"));

    return Scaffold(
      appBar: AppBar(
        title: Text("Ofertas - Servicio ${widget.idServicio}"),
      ),
      body: Column(
        children: [
          Expanded(
            child: ofertas.isEmpty
                ? const Center(child: Text("No hay ofertas aún"))
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: ofertas.length,
              itemBuilder: (context, index) {
                final oferta = ofertas[index];
                final esEspecialista =
                    oferta["remitente"] == "especialista";
                final nombre = esEspecialista
                    ? oferta["nombre_especialista"] ?? "Especialista"
                    : oferta["nombre_cliente"] ?? "Cliente";

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(
                      "$nombre ofertó \$${oferta['monto']}",
                      style: TextStyle(
                        fontWeight: oferta["estado"] == "aceptada"
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: oferta["estado"] == "aceptada"
                            ? Colors.green
                            : Colors.black,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (oferta["estado"] == "aceptada")
                          const Text("✅ Oferta aceptada"),
                        Text("Remitente: ${oferta['remitente']}"),
                      ],
                    ),
                    trailing: oferta["estado"] == "pendiente" &&
                        !esEspecialista
                        ? ElevatedButton(
                      onPressed: () => aceptarOferta(
                          int.parse(oferta["id_oferta"].toString())),
                      child: const Text("Aceptar"),
                    )
                        : null,
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey[200],
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ofertaController,
                    enabled: !yaOferto,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: yaOferto
                          ? "Ya enviaste una oferta"
                          : "Escribe tu oferta en \$...",
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: yaOferto || enviando ? null : enviarOferta,
                  child: enviando
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text("Enviar"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
