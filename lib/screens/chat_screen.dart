import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ChatScreen extends StatefulWidget {
  final int idServicio; // servicio


  const ChatScreen({Key? key, required this.idServicio}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List chatMessages = [];
  TextEditingController _messageController = TextEditingController();
  Map<String, dynamic>? user;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _loadUser();
    getChatMessages();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  // Cargar usuario guardado en SharedPreferences
  Future<void> _loadUser() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userData = prefs.getString('user');
    if (userData != null) {
      setState(() {
        user = json.decode(userData);
      });
    }
  }

  // Iniciar polling cada 3 segundos
  void _startPolling() {
    _pollingTimer = Timer.periodic(Duration(seconds: 15), (timer) {
      getChatMessages();
    });
  }

  // Obtener mensajes desde API
  Future<void> getChatMessages() async {
    try {
      print("📡 Enviando request a la API con rentalId=${widget.idServicio}");

      final response = await http.post(
        Uri.parse('https://manohogar.online/api/app_api.php?action=get_chat_messages'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'id_alquiler': widget.idServicio}),
      );

      print("📩 Código de respuesta: ${response.statusCode}");
      print("📩 Body de respuesta: ${response.body}");

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        print("✅ JSON decodificado: $jsonData");

        if (jsonData['status'] == 'ok') {
          final mensajes = jsonData['mensajes'] ?? []; // 👈 usar la clave correcta

          print("✅ Mensajes recibidos: ${mensajes.length}");

          setState(() {
            chatMessages = mensajes;
          });
        } else {
          print("⚠️ Respuesta de API con error: ${jsonData['status']}");
        }
      } else {
        print("❌ Error en el servidor: ${response.reasonPhrase}");
      }
    } catch (e, stacktrace) {
      print("💥 Error cargando mensajes: $e");
      print("🧵 Stacktrace: $stacktrace");
    }
  }


  // Enviar mensaje
  Future<void> sendChatMessage(String mensaje) async {
    if (user == null || mensaje.trim().isEmpty) {
      print("⚠️ Usuario no definido o mensaje vacío.");
      return;
    }

    try {
      final payload = {
        'id_alquiler': widget.idServicio,
        'id_usuario': user!['id'],
        'id_domiciliario': widget.idServicio,
        'mensaje': mensaje,
        'tipo': 'usuario', // siempre usuario desde la app cliente
      };

      print("📡 Enviando mensaje con payload: $payload");

      final response = await http.post(
        Uri.parse('https://manohogar.online/api/app_api.php?action=send_chat_message'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      print("📩 Código de respuesta: ${response.statusCode}");
      print("📩 Body de respuesta: ${response.body}");

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        print("✅ JSON decodificado: $jsonData");

        if (jsonData['status'] == 'ok') {
          print("✅ Mensaje enviado correctamente.");
          _messageController.clear();
          getChatMessages(); // refrescar mensajes
        } else {
          print("⚠️ Error en respuesta API: ${jsonData['status']}");
        }
      } else {
        print("❌ Error en servidor: ${response.reasonPhrase}");
      }
    } catch (e, stacktrace) {
      print("💥 Error enviando mensaje: $e");
      print("🧵 Stacktrace: $stacktrace");
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Chat con el especialista"),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: false,
              itemCount: chatMessages.length,
              itemBuilder: (context, index) {
                final msg = chatMessages[index];
                final isUser = msg['remitente'] == 'usuario';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    padding: EdgeInsets.all(10),
                    margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blue[200] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      msg['mensaje'],
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                );
              },
            ),
          ),
          Divider(height: 1),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: "Escribe un mensaje...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.send, color: Colors.blue),
                  onPressed: () => sendChatMessage(_messageController.text),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
