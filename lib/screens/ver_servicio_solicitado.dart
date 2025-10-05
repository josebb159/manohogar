import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'chat_screen.dart';
import 'oferta_cliente.dart';

class VerServicioSolicitado extends StatefulWidget {
  final String idServicio;

  const VerServicioSolicitado({super.key, required this.idServicio});

  @override
  State<VerServicioSolicitado> createState() => _VerServicioSolicitadoState();
}
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

class _VerServicioSolicitadoState extends State<VerServicioSolicitado> with WidgetsBindingObserver {
  Map<String, dynamic>? servicio;
  bool cargando = true;
  Map<String, dynamic> user = {};
  final Map<String, String> metodosPago = {
    '1': 'Efectivo',
    '2': 'Nequi',
    '3': 'Daviplata',
  };
  double monedero = 0.0;
  bool bloqueadoPorFondos = false;
  final Map<String, String> opcionesTiempo = {
    '1': 'Urgente (1-2 días)',
    '2': 'Dentro de 2 semanas',
    '3': 'Más de 2 semanas',
    '4': 'No estoy seguro (aún planeando presupuesto)',
  };



  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // 👈 quitar observer
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // ⚡ Aquí se llama cuando la app vuelve a primer plano
      obtenerServicio();

    }
  }

  @override
  void didPopNext() {
    // ⚡ Se llama cuando vuelves a esta pantalla
    obtenerServicio();
    _loadUserData();
  }

  bool aceptado = false; // esta cambia a true cuando el usuario presiona aceptar
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // 👈 registrar observer
    obtenerServicio();
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



  bool botonesDeshabilitados = false; // para habilitar/deshabilitar botones
  Future<void> obtenerOfertas() async {
    setState(() => cargando = true);

    try {
      final res = await http.post(
        Uri.parse(
            'https://manohogar.online/api/app_api.php?action=verificar_oferta_aceptada'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'id_servicio': widget.idServicio}),
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);

        if (data['status'] == 'ok') {
          setState(() {
            botonesDeshabilitados = data['tiene_oferta'] == true;
            cargando = false;
          });
        } else {
          mostrarError(data['message'] ?? 'Error desconocido');
        }
      } else {
        mostrarError('Error en la respuesta del servidor: ${res.statusCode}');
      }
    } catch (e) {
      mostrarError('Error al obtener ofertas: $e');
    }
  }


  Future<void> finalizar(BuildContext context, int idServicio) async {
    double calificacion = 0;
    final TextEditingController comentarioController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Finalizar servicio'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Califica el servicio:'),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < calificacion ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                        ),
                        onPressed: () {
                          setState(() {
                            calificacion = (index + 1).toDouble();
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: comentarioController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Escribe un comentario...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (calificacion == 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Por favor selecciona una calificación.')),
                  );
                  return;
                }

                // Llamar API
                final uri = Uri.parse(
                    'https://manohogar.online/api/app_api.php?action=finalizar_servicio_cliente');
                final response = await http.post(
                  uri,
                  body: json.encode({
                    'id_servicio': idServicio,
                    'calificacion': calificacion,
                    'comentario': comentarioController.text,
                  }),
                );

                if (response.statusCode == 200) {
                  obtenerServicio();
                  final data = json.decode(response.body);
                  if (data['status'] == 'ok') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Servicio finalizado correctamente')),
                    );
                    Navigator.pop(context);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(data['message'] ?? 'Error al finalizar servicio')),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Error de conexión con el servidor')),
                  );
                }
              },
              child: const Text('Enviar'),
            ),
          ],
        );
      },
    );
  }
  Future<void> enviarAccion(String accion) async {
    if(accion == "aceptar_servicio"){
      aceptado = true;
    }
    var id =  user['id'].toString();
    print('id de usuario $id');
    final uri = Uri.parse('https://manohogar.online/api/app_api.php?action=$accion');
    final response = await http.post(
      uri,
      body:
      json.encode({'id_usuario': id,'id_servicio': widget.idServicio}),

    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('Respuesta de $accion: $data');

      if (data['status'] == 'ok') {
        obtenerServicio();
        // Mensaje según acción
        String mensaje = accion == "aceptar_servicio"
            ? "Servicio aceptado correctamente"
            : "Servicio cancelado correctamente";



        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensaje)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Ocurrió un error')),
        );
      }
    } else {
      print('Error al enviar acción $accion');
    }
  }


  Future<void> obtenerServicio() async {
    setState(() => cargando = true);

    try {
      final res = await http.post(
        Uri.parse('https://manohogar.online/api/app_api.php?action=ver_solicitud_de_servicio'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'id_servicio': widget.idServicio}),
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['status'] == 'ok') {
          setState(() {
            servicio = data['servicio'];
            cargando = false;
          });
        } else {
          mostrarError(data['message'] ?? 'Error desconocido');
        }
      } else {
        mostrarError('Error en la respuesta del servidor: ${res.statusCode}');
      }
    } catch (e) {
      mostrarError('Error al obtener servicio: $e');
    }
  }

  void mostrarError(String mensaje) {
    setState(() => cargando = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (servicio == null) {
      return const Scaffold(
        body: Center(child: Text('No se pudo cargar el servicio.')),
      );
    }

    final String? foto = servicio!['foto'];
    final String urlImagen = 'https://manohogar.online/assets/upload/servicios/$foto';

    final String metodoPago = metodosPago[servicio!['metodo_pago'].toString()] ?? 'Desconocido';
    final String solicitadoPara = opcionesTiempo[servicio!['solicitado_para'].toString()] ?? 'No especificado';

    final double? lat = double.tryParse(servicio!['latitud']?.toString() ?? '');
    final double? lng = double.tryParse(servicio!['longitud']?.toString() ?? '');

    final String categoria = servicio!['categoria'] ?? 'Sin categoría';

    final String nombre_usuario = servicio!['nombre_usuario'] ?? 'Sin usuario';
    final String id_especialista = servicio!['id_especialista'] ?? '0';
    final String estado_servicio = servicio!['estado_servicio'] ?? '0';
    final String calificacion = servicio!['calificacion'] ?? '0';
    final String calificacion_sis = servicio!['calificacion'] ?? '0';
     final String comentario_cliente = servicio!['comentario_cliente'] ?? '0';
    print('Especista $id_especialista');

    return Scaffold(
      appBar: AppBar(title: const Text('Servicio Solicitado')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (foto != null && foto.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  urlImagen,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              ),


            const SizedBox(height: 16),

            /// CARD PRINCIPAL DE DETALLES
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    /// DETALLE DEL SERVICIO
                    Text(
                      servicio!['detalle'] ?? 'Sin detalle',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Divider(),

                    /// CATEGORÍA
                    Row(
                      children: [
                        const Icon(Icons.category, size: 20),
                        const SizedBox(width: 5),
                        Text('Categoría: $categoria'),
                      ],
                    ),
                    const SizedBox(height: 12),

                    /// DIRECCIÓN
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on, size: 20),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(servicio!['direccion'] ?? 'Dirección no disponible'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    /// TIEMPO SOLICITADO
                    Row(
                      children: [
                        const Icon(Icons.timer, size: 20),
                        const SizedBox(width: 5),
                        Text('Solicitado para: $solicitadoPara'),
                      ],
                    ),
                    const SizedBox(height: 12),

                    /// MÉTODO DE PAGO
                    Row(
                      children: [
                        const Icon(Icons.payment, size: 20),
                        const SizedBox(width: 5),
                        Text('Método de pago: $metodoPago'),
                      ],
                    ),
                    const SizedBox(height: 12),

                    /// SOLICITADO POR
                    Row(
                      children: [
                        const Icon(Icons.person, size: 20),
                        const SizedBox(width: 5),
                        Text('Solicitado por: $nombre_usuario'),
                      ],
                    ),


                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),


            // -----------------------------------------------------------------
// LÓGICA CONDICIONAL PARA SERVICIO FINALIZADO (estado_servicio == '3')
// -----------------------------------------------------------------

            // -----------------------------------------------------------------
// LÓGICA CONDICIONAL PARA SERVICIO FINALIZADO (estado_servicio == '3')
// -----------------------------------------------------------------

            if (estado_servicio == '3')
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  // CARD DE ESTADO FINALIZADO, COMENTARIO Y CALIFICACIÓN
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    color: Colors.green.shade50, // Color para indicar finalización exitosa
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Mostrar que ha sido finalizado
                          Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green, size: 24),
                              const SizedBox(width: 8),
                              const Text(
                                '¡Servicio Finalizado con Éxito!',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                              ),
                            ],
                          ),
                          const Divider(height: 24),

                          // 2. Comentario Final
                          const Text(
                            'Comentario del Cliente:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            comentario_cliente.isNotEmpty ? comentario_cliente : 'Sin comentario.',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 12),

                          // 3. Calificación Final
                          Row(
                            children: [
                              const Text(
                                'Calificación:',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(width: 8),
                              // Muestra la calificación con estrellas
                              Row(
                                children: List.generate(5, (index) {
                                  final double rating = double.tryParse(calificacion) ?? 0.0;
                                  return Icon(
                                    index < rating.round()
                                        ? Icons.star
                                        : Icons.star_border,
                                    color: Colors.amber,
                                    size: 20,
                                  );
                                }),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '($calificacion / 5)',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
// -----------------------------------------------------------------
// FIN LÓGICA CONDICIONAL PARA ESTADO '3'
// -----------------------------------------------------------------

// -----------------------------------------------------------------
// INICIO LÓGICA CONDICIONAL PARA SERVICIO CANCELADO (estado_servicio == '4')
// -----------------------------------------------------------------
            else if (estado_servicio == '4')
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    color: Colors.red.shade50, // Color para indicar cancelación
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Mostrar que ha sido cancelado
                          Row(
                            children: [
                              const Icon(Icons.cancel, color: Colors.red, size: 24),
                              const SizedBox(width: 8),
                              const Text(
                                'Servicio Cancelado',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
                              ),
                            ],
                          ),
                          const Divider(height: 24),

                          // 2. Comentario (si aplica en caso de cancelación)
                          const Text(
                            'Comentario de la Transacción:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            comentario_cliente.isNotEmpty ? comentario_cliente : 'Sin comentario asociado a la cancelación.',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 12),

                          // 3. Calificación (si aplica en caso de cancelación)
                          Row(
                            children: [
                              const Text(
                                'Calificación:',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red),
                              ),
                              const SizedBox(width: 8),
                              // Muestra la calificación con estrellas
                              Row(
                                children: List.generate(5, (index) {
                                  final double rating = double.tryParse(calificacion) ?? 0.0;
                                  return Icon(
                                    index < rating.round()
                                        ? Icons.star
                                        : Icons.star_border,
                                    color: Colors.red.shade400, // Estrellas en tono rojo
                                    size: 20,
                                  );
                                }),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '($calificacion / 5)',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
// -----------------------------------------------------------------
// FIN LÓGICA CONDICIONAL PARA ESTADO '4'
// -----------------------------------------------------------------
            /// MAPA
            if (lat != null && lng != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ubicación del servicio:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 200,
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: LatLng(lat, lng),
                          zoom: 15,
                        ),
                        markers: {
                          Marker(
                            markerId: const MarkerId('servicio'),
                            position: LatLng(lat, lng),
                          ),
                        },
                      ),
                    ),
                  ),
                ],
              ),


            const SizedBox(height: 30),
            estado_servicio == '0'
                ? Center(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.local_offer),
                label: const Text('Ofertar'),
                onPressed: botonesDeshabilitados
                    ? null
                    : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CronologiaOfertaClientePage(
                        idServicio: int.parse(widget.idServicio),
                        idUsuario: int.parse(user['id']),
                        idDomiciliario: int.parse(id_especialista),
                        remitente: "cliente",
                      ),
                    ),
                  );
                },
              ),
            )
                : const SizedBox.shrink(),


            const SizedBox(height: 30),

            /// BOTONES
            ///
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [

                estado_servicio == '1'
                    ? ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  icon: const Icon(Icons.cancel),
                  label: const Text('Cancelar'),
                  onPressed: () {
                    enviarAccion('cancelar_servicio');
                  },
                ) : const SizedBox.shrink(), // No muestra nada
                id_especialista == '99'
                    ? ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  icon: const Icon(Icons.check),
                  label: const Text('Aceptar'),
                  onPressed: () {
                    enviarAccion('aceptar_servicio');
                  },
                )
                    : const SizedBox.shrink(), // No muestra nada

                estado_servicio == '99'
                    ? ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  icon: const Icon(Icons.check),
                  label: const Text('En camino'),
                  onPressed: () {
                    enviarAccion('servicio_a_la_ubicacion');
                  },
                )
                    : const SizedBox.shrink(), // No muestra nada

                estado_servicio == '99'
                    ? ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  icon: const Icon(Icons.check),
                  label: const Text('En proceso'),
                  onPressed: () {
                    enviarAccion('realizado_servicio');
                  },
                )
                    : const SizedBox.shrink(), // No muestra nada
                estado_servicio == '3' && calificacion_sis == "0"
                    ? ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  icon: const Icon(Icons.check),
                  label: const Text('Calificar'),
                  onPressed: () {
                    int idServicio = int.parse(widget.idServicio.toString());
                    finalizar(context, idServicio);
                  },
                )
                    : const SizedBox.shrink(),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: (id_especialista != '0' || aceptado)
          ? FloatingActionButton(
        backgroundColor: Colors.blue,
        child: const Icon(Icons.chat),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(

              builder: (_) => ChatScreen(idServicio: int.parse(widget.idServicio)),
            ),
          );
        },
      )
          : null,
    );
  }
}