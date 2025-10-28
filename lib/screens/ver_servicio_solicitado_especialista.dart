import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'chat_screen2.dart';
import 'oferta.dart';

class VerServicioSolicitadoEspecialista extends StatefulWidget  {
  final String idServicio;

  const VerServicioSolicitadoEspecialista({super.key, required this.idServicio});

  @override
  State<VerServicioSolicitadoEspecialista> createState() =>
      _VerServicioSolicitadoEspecialistaState();
}
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();
class _VerServicioSolicitadoEspecialistaState
    extends State<VerServicioSolicitadoEspecialista> with WidgetsBindingObserver  {
  Map<String, dynamic>? servicio;
  bool cargando = true;
  Map<String, dynamic> user = {};
  bool aceptado = false;
  late String idspecialista = "";

  final Map<String, String> metodosPago = {
    '1': 'Efectivo',
    '2': 'Nequi',
    '3': 'Daviplata',
  };

  final List<String> motivosCancelacion = [
    "El cliente no respondió",
    "La dirección es incorrecta",
    "El trabajo no corresponde a mi especialidad",
    "No puedo en la fecha/hora solicitada",
    "El presupuesto no es adecuado",
    "Otro motivo",
  ];

  Map<String, dynamic>? ultimaOferta;  // aquí guardamos la última oferta (puede ser null)
  bool botonesDeshabilitados = false; // para habilitar/deshabilitar botones



  final Map<String, String> opcionesTiempo = {
    '1': 'Urgente (1-2 días)',
    '2': 'Dentro de 2 semanas',
    '3': 'Más de 2 semanas',
    '4': 'No estoy seguro (aún planeando presupuesto)',
  };

  final TextEditingController _ofertaController = TextEditingController();


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


  @override
  void initState() {
    super.initState();
    obtenerServicio();
    _loadUserData();
    obtenerOfertas();
    verificarMonedero();
    verificarLimiteServicios();
  }

  double monedero = 0.0;
  bool bloqueadoPorFondos = false;


  Future<void> verificarLimiteServicios() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userData = prefs.getString('user');

    if (userData == null) {
      print('No se encontró información del usuario.');
      return;
    }

    final userMap = json.decode(userData);
    final userId = userMap['id'].toString();

    setState(() {
      user = userMap;
    });

    try {
      final res = await http.post(
        Uri.parse('https://manohogar.online/api/app_api.php?action=verificar_servicios_activos'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'id_especialista': userId,
          'id_servicio': widget.idServicio, // ⚡ Pasamos también el ID del servicio
        }),
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        print('Respuesta API servicios activos: $data');

        if (data['status'] == 'ok') {
          bool superaMaximo = data['supera_maximo'] ?? false;

          if (superaMaximo) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              mostrarModalSuperaLimite();
            });
          }
        } else {
          print('Error del servidor: ${data['message']}');
        }
      } else {
        print('Error HTTP: ${res.statusCode}');
      }
    } catch (e) {
      print('Error al verificar servicios activos: $e');
    }
  }

  void mostrarModalSuperaLimite() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Límite de servicios alcanzado'),
          content: const Text(
            'Has superado el límite de servicios activos que puedes aceptar. No puedes continuar con nuevos servicios hasta finalizar algunos.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // cierra el modal
                Navigator.pop(context); // regresa de la pantalla
              },
              child: const Text('Volver'),
            ),
          ],
        );
      },
    );
  }



  Future<void> verificarMonedero() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userData = prefs.getString('user');

    if (userData == null) {
      print('No se encontró información del usuario.');
      return;
    }

    final userMap = json.decode(userData);
    final userId = userMap['id'].toString();

    setState(() {
      user = userMap;
    });

    try {
      final res = await http.post(
        Uri.parse('https://manohogar.online/api/app_api.php?action=get_monedero_usuario'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'id_usuario': userId,
          'id_servicio': widget.idServicio, // ⚡ Pasamos también el ID del servicio
        }),
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        print('Respuesta API monedero: $data');

        if (data['status'] == 'ok') {
          double saldo = double.tryParse(data['usuario']['monedero'].toString()) ?? 0.0;
          setState(() {
            monedero = saldo;
            bloqueadoPorFondos = saldo <= 0;
          });

          if (saldo <= 0) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              mostrarModalFondosInsuficientes();
            });
          }
        } else {
          print('Error del servidor: ${data['message']}');
        }
      } else {
        print('Error HTTP: ${res.statusCode}');
      }
    } catch (e) {
      print('Error al verificar monedero: $e');
    }
  }



  void mostrarModalFondosInsuficientes() {
    showDialog(
      context: context,
      barrierDismissible: false, // ❌ no se puede cerrar tocando fuera
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Fondos insuficientes'),
          content: const Text(
            'No tienes fondos suficientes en tu monedero para continuar.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // cierra el modal
                Navigator.pop(context); // regresa de la pantalla
              },
              child: const Text('Volver'),
            ),
          ],
        );
      },
    );
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
                    'https://manohogar.online/api/app_api.php?action=finalizar_servicio');
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
  void mostrarModalCancelar() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text("Cancelar servicio"),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: motivosCancelacion.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (ctx, index) {
              final motivo = motivosCancelacion[index];
              return ListTile(
                leading: const Icon(Icons.warning, color: Colors.red),
                title: Text(motivo),
                onTap: () {
                  Navigator.of(ctx).pop(); // cerrar modal de motivos

                  // Abrir aviso de confirmación
                  showDialog(
                    context: context,
                    builder: (ctx2) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      title: const Text("¿Estás seguro?"),
                      content: Text("¿Deseas cancelar el servicio por el motivo: \"$motivo\"?"),
                      actions: [
                        TextButton(
                          child: const Text("No"),
                          onPressed: () => Navigator.of(ctx2).pop(),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text("Sí, cancelar"),
                          onPressed: () {
                            Navigator.of(ctx2).pop();
                            // Aquí envías la acción real
                            // enviarAccion("cancelar_servicio", motivo);
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            child: const Text("Cerrar"),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
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

  Future<void> abrirGoogleMaps(double lat, double lng) async {
    final Uri url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      throw 'No se pudo abrir Google Maps';
    }
  }

  Future<void> enviarAccion(String accion) async {
    if (accion == "aceptar_servicio") {
      aceptado = true;
    }

    var id = user['id'].toString();
    final uri =
    Uri.parse('https://manohogar.online/api/app_api.php?action=$accion');
    final response = await http.post(
      uri,
      body: json.encode({'id_usuario': id, 'id_servicio': widget.idServicio}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      obtenerServicio();
      if (data['status'] == 'ok') {
        String mensaje;
        switch (accion) {
          case "aceptar_servicio":
            mensaje = "Servicio aceptado correctamente";
            break;
          case "servicio_a_la_ubicacion":
            mensaje = "En camino";
            break;
          case "realizado_servicio":
            mensaje = "Servicio en proceso";
            break;
          case "finalizar_servicio":
            mensaje = "Servicio finalizado correctamente";
            break;
          default:
            mensaje = "Servicio cancelado correctamente";
        }
        mostrarExito(mensaje);
      } else {
        mostrarError(data['message'] ?? 'Ocurrió un error');
      }
    } else {
      mostrarError("Error al enviar acción $accion");
    }
  }

  void mostrarExito(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

  Future<void> ofertarServicio(
      BuildContext ctx, String idUsuario, String idServicio) async {
    final valor = _ofertaController.text.trim();

    if (valor.isEmpty) {
      mostrarError("Debes ingresar un valor para ofertar");
      return;
    }

    try {
      final res = await http.post(
        Uri.parse('https://manohogar.online/api/app_api.php?action=registrar_oferta_especialista'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'id_usuario': idUsuario,
          'id_servicio': idServicio,
          'valor': valor,
        }),
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['status'] == 'ok') {
          Navigator.of(ctx).pop(); // cerrar modal correctamente
          mostrarExito("Oferta enviada correctamente");
        } else {
          mostrarError(data['message'] ?? 'Error al ofertar');
        }
      } else {
        mostrarError("Error en la respuesta del servidor: ${res.statusCode}");
      }
    } catch (e) {
      mostrarError("Error al ofertar: $e");
    }
  }

  void mostrarModalOfertar(
      BuildContext context, String idUsuario, String idServicio) {
    _ofertaController.clear();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text("Ofertar servicio"),
        content: TextField(
          controller: _ofertaController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: "Ingrese el valor de su oferta",
            prefixIcon: Icon(Icons.monetization_on),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
      Expanded(
      child: ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
      backgroundColor: Colors.red,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: const Icon(Icons.cancel),
      label: const Text('Cancelar'),
      onPressed: () => mostrarModalCancelar(),
    ),
    ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text("Enviar"),
            onPressed: () {
              ofertarServicio(ctx, idUsuario, idServicio);
            },
          ),
        ],
      ),
    );
  }

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
            //ultimaOferta = data['oferta']; // null si no hay oferta
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


  Future<void> obtenerServicio() async {
    setState(() => cargando = true);

    try {
      final res = await http.post(
        Uri.parse(
            'https://manohogar.online/api/app_api.php?action=ver_solicitud_de_servicio'),
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
    final String urlImagen =
        'https://manohogar.online/assets/upload/servicios/$foto';

    final String metodoPago =
        metodosPago[servicio!['metodo_pago'].toString()] ?? 'Desconocido';
    final String solicitadoPara =
        opcionesTiempo[servicio!['solicitado_para'].toString()] ??
            'No especificado';
    final String oferta = servicio!['oferta'].toString();
    final double? lat = double.tryParse(servicio!['latitud']?.toString() ?? '');
    final double? lng =
    double.tryParse(servicio!['longitud']?.toString() ?? '');

    final String categoria = servicio!['categoria'] ?? 'Sin categoría';
    final String nombre_usuario =
        servicio!['nombre_usuario'] ?? 'Sin usuario';
    final String id_especialista = servicio!['id_especialista'] ?? '0';
    final String estado_servicio = servicio!['estado_servicio'] ?? '0';

    final String comentario_especialista = servicio!['comentario_especialista'] ?? '';
    final String calificacion_especialista = servicio!['calificacion_especialista'] ?? '0';
    final String calificacion = servicio!['calificacion'] ?? '0';
    final String comentario_cliente = servicio!['comentario_cliente'] ?? '0';

      idspecialista = servicio!['id_especialista'] ?? '0';
    return Scaffold(
      appBar: AppBar(title: Text('Servicio Solicitado #' + widget.idServicio)),
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

            /// Card principal
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      servicio!['detalle'] ?? 'Sin detalle',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Divider(),
                    Row(
                      children: [
                        const Icon(Icons.category, size: 20),
                        const SizedBox(width: 5),
                        Text('Categoría: $categoria'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on, size: 20),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(servicio!['direccion'] ??
                              'Dirección no disponible'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.timer, size: 20),
                        const SizedBox(width: 5),
                        Text('Solicitado para: $solicitadoPara'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.monetization_on, size: 20),
                        const SizedBox(width: 5),
                        Text('Valor por: $oferta'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.payment, size: 20),
                        const SizedBox(width: 5),
                        Text('Método de pago: $metodoPago'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.person, size: 20),
                        const SizedBox(width: 5),
                        Text('Solicitado por: $nombre_usuario'),
                      ],
                    ),
                    if (ultimaOferta != null) ...[
                      const SizedBox(height: 20),
                      Card(
                        color: Colors.yellow.shade100,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const Icon(Icons.local_offer, color: Colors.orange, size: 28),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  "Nueva oferta: \$${ultimaOferta!['monto']}",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),


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
                    color: Colors.green.shade50, // Finalizado: Verde
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Título Principal
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
                          const Divider(height: 16),

                          // === RETROALIMENTACIÓN DEL CLIENTE ===
                          const Text(
                            'Feedback del Cliente:',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          const SizedBox(height: 8),
                          // Comentario del Cliente
                          Text(
                            comentario_cliente.isNotEmpty ? comentario_cliente : 'Cliente no dejó un comentario.',
                            style: const TextStyle(fontSize: 15, fontStyle: FontStyle.italic),
                          ),
                          const SizedBox(height: 4),
                          // Calificación del Cliente
                          Row(
                            children: [
                              const Text('Calificación: ', style: TextStyle(fontWeight: FontWeight.w600)),
                              Row(
                                children: List.generate(5, (index) {
                                  final double rating = double.tryParse(calificacion) ?? 0.0;
                                  return Icon(
                                    index < rating.round() ? Icons.star : Icons.star_border,
                                    color: Colors.amber,
                                    size: 18,
                                  );
                                }),
                              ),
                              const SizedBox(width: 4),
                              Text('($calificacion / 5)'),
                            ],
                          ),
                          const Divider(height: 24),

                          // === RETROALIMENTACIÓN DEL ESPECIALISTA ===
                          const Text(
                            'Feedback del Especialista:',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          const SizedBox(height: 8),
                          // Comentario del Especialista
                          Text(
                            comentario_especialista.isNotEmpty ? comentario_especialista : 'Especialista no dejó un comentario.',
                            style: const TextStyle(fontSize: 15, fontStyle: FontStyle.italic),
                          ),
                          const SizedBox(height: 4),
                          // Calificación del Especialista
                          Row(
                            children: [
                              const Text('Calificación: ', style: TextStyle(fontWeight: FontWeight.w600)),
                              Row(
                                children: List.generate(5, (index) {
                                  final double rating = double.tryParse(calificacion_especialista) ?? 0.0;
                                  return Icon(
                                    index < rating.round() ? Icons.star : Icons.star_border,
                                    color: Colors.blueAccent, // Color diferente para distinguir
                                    size: 18,
                                  );
                                }),
                              ),
                              const SizedBox(width: 4),
                              Text('($calificacion_especialista / 5)'),
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
                    color: Colors.red.shade50, // Cancelado: Rojo
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Título Principal
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
                          const Divider(height: 16),

                          // === RETROALIMENTACIÓN DEL CLIENTE ===
                          const Text(
                            'Feedback del Cliente:',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          const SizedBox(height: 8),
                          // Comentario del Cliente
                          Text(
                            comentario_cliente.isNotEmpty ? comentario_cliente : 'Cliente no dejó un comentario.',
                            style: const TextStyle(fontSize: 15, fontStyle: FontStyle.italic),
                          ),
                          const SizedBox(height: 4),
                          // Calificación del Cliente
                          Row(
                            children: [
                              const Text('Calificación: ', style: TextStyle(fontWeight: FontWeight.w600)),
                              Row(
                                children: List.generate(5, (index) {
                                  final double rating = double.tryParse(calificacion) ?? 0.0;
                                  return Icon(
                                    index < rating.round() ? Icons.star : Icons.star_border,
                                    color: Colors.amber,
                                    size: 18,
                                  );
                                }),
                              ),
                              const SizedBox(width: 4),
                              Text('($calificacion / 5)'),
                            ],
                          ),
                          const Divider(height: 24),

                          // === RETROALIMENTACIÓN DEL ESPECIALISTA ===
                          const Text(
                            'Feedback del Especialista:',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          const SizedBox(height: 8),
                          // Comentario del Especialista
                          Text(
                            comentario_especialista.isNotEmpty ? comentario_especialista : 'Especialista no dejó un comentario.',
                            style: const TextStyle(fontSize: 15, fontStyle: FontStyle.italic),
                          ),
                          const SizedBox(height: 4),
                          // Calificación del Especialista
                          Row(
                            children: [
                              const Text('Calificación: ', style: TextStyle(fontWeight: FontWeight.w600)),
                              Row(
                                children: List.generate(5, (index) {
                                  final double rating = double.tryParse(calificacion_especialista) ?? 0.0;
                                  return Icon(
                                    index < rating.round() ? Icons.star : Icons.star_border,
                                    color: Colors.blueAccent, // Color diferente para distinguir
                                    size: 18,
                                  );
                                }),
                              ),
                              const SizedBox(width: 4),
                              Text('($calificacion_especialista / 5)'),
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

            const SizedBox(height: 20),

            /// Mapa
            if (lat != null && lng != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ubicación del servicio:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
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

            /// Botones organizados y alineados
            Column(
              children: [
                const SizedBox(height: 12),

                // ======== ESTADO: SIN ASIGNAR (id_especialista == 0) ========
                if (id_especialista == '0') ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.check, color: Colors.white),
                      label: const Text('Aceptar',
                          style: TextStyle(fontSize: 16, color: Colors.white)),
                      onPressed: botonesDeshabilitados
                          ? null
                          : () => enviarAccion('aceptar_servicio'),
                    ),
                  ),
                ],

                // ======== ESTADO: 0 → OFERTAR ========
                if (estado_servicio == '0') ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.local_offer, color: Colors.white),
                      label: const Text('Ver oferta',
                          style: TextStyle(fontSize: 16, color: Colors.white)),
                      onPressed: botonesDeshabilitados
                          ? null
                          : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CronologiaOfertaPage(
                              idServicio: int.parse(widget.idServicio),
                              idUsuario: int.parse(user['id']),
                              idDomiciliario: int.parse(idspecialista),
                              remitente: "cliente",
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],

                // ======== ESTADO: 1 → EN CAMINO ========
                if (estado_servicio == '1') ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.directions_walk, color: Colors.white),
                      label: const Text('En camino',
                          style: TextStyle(fontSize: 16, color: Colors.white)),
                      onPressed: () => enviarAccion('servicio_a_la_ubicacion'),
                    ),
                  ),
                ],

                // ======== ESTADO: 5 → EN PROCESO ========
                if (estado_servicio == '5') ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.build, color: Colors.white),
                      label: const Text('En proceso',
                          style: TextStyle(fontSize: 16, color: Colors.white)),
                      onPressed: () => enviarAccion('realizado_servicio'),
                    ),
                  ),
                ],

                // ======== ESTADO: 2 → FINALIZAR SERVICIO ========
                if (estado_servicio == '2') ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.check_circle, color: Colors.white),
                      label: const Text('Finalizar servicio',
                          style: TextStyle(fontSize: 16, color: Colors.white)),
                      onPressed: () {
                        int idServicio = int.parse(widget.idServicio.toString());
                        finalizar(context, idServicio);
                      },
                    ),
                  ),
                ],
              ],
            )
,

            const SizedBox(height: 12),

            /// Ir a ubicación
            if (lat != null && lng != null  && (estado_servicio==1 ||estado_servicio==2 || estado_servicio==5 ))
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.map),
                  label: const Text('Ir a la ubicación'),
                  onPressed: () => abrirGoogleMaps(lat, lng),
                ),
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
