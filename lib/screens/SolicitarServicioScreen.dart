import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';

class SolicitarServicioScreen extends StatefulWidget {
  const SolicitarServicioScreen({Key? key}) : super(key: key);

  @override
  State<SolicitarServicioScreen> createState() => _SolicitarServicioScreenState();
}

class _SolicitarServicioScreenState extends State<SolicitarServicioScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController detalleController = TextEditingController();
  final TextEditingController direccionController = TextEditingController();
  final TextEditingController ofertaController = TextEditingController();
  double? latitud;
  double? longitud;


  String? tiempoSeleccionado;
  String? metodoPago;
  File? imagen;
  Map<String, dynamic> user = {};
  final List<Map<String, String>> opcionesTiempo = [
    {'id': '1', 'label': 'Urgente (1-2 días)'},
    {'id': '2', 'label': 'Dentro de 2 semanas'},
    {'id': '3', 'label': 'Más de 2 semanas'},
    {'id': '4', 'label': 'No estoy seguro (aún planeando presupuesto)'},
  ];


  late Map categoria;
  late Map subcategoria;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _obtenerUbicacion(); // sin await
  }


  Future<void> _obtenerUbicacion() async {
    bool servicioHabilitado;
    LocationPermission permiso;

    servicioHabilitado = await Geolocator.isLocationServiceEnabled();
    if (!servicioHabilitado) {
      return Future.error('Los servicios de ubicación están deshabilitados.');
    }

    permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
      if (permiso == LocationPermission.denied) {
        return Future.error('Permiso de ubicación denegado.');
      }
    }

    if (permiso == LocationPermission.deniedForever) {
      return Future.error('Los permisos de ubicación están permanentemente denegados.');
    }

    Position posicion = await Geolocator.getCurrentPosition();
    latitud = posicion.latitude;
    longitud = posicion.longitude;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>;
    categoria = args['categoria'];
    subcategoria = args['subcategoria'];
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


  final List<Map<String, String>> metodosPago = [
    {'id': '1', 'label': 'Efectivo'},
    {'id': '2', 'label': 'Nequi'},
    {'id': '3', 'label': 'Daviplata'},
  ];

  Future<void> _seleccionarImagen() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        imagen = File(pickedFile.path);
      });
    }
  }

  Future<void> enviarSolicitud() async {
    print('🚀 Iniciando envío de solicitud');

    final uri = Uri.parse('https://manohogar.online/api/app_api.php?action=solicitar_servicio');
    final request = http.MultipartRequest('POST', uri);

    // 🧑 Usuario
    final userId = user['id'];
    print('👤 ID Usuario: $userId');

    // 📦 Campos
    final categoriaId = categoria['id'].toString();
    final subcategoriaId = subcategoria['id'].toString();
    final detalle = detalleController.text;
    final direccion = direccionController.text;
    final tiempo = tiempoSeleccionado ?? '';
    final oferta = ofertaController.text;
    final metodo = metodoPago ?? '';
    final lat = latitud?.toString() ?? '';
    final lon = longitud?.toString() ?? '';

    print('📂 Categoría ID: $categoriaId');
    print('📂 Subcategoría ID: $subcategoriaId');
    print('✅ Detalle: $detalle');
    print('📍 Dirección: $direccion');
    print('📅 Tiempo: $tiempo');
    print('💰 Oferta: $oferta');
    print('💳 Método de pago: $metodo');
    print('🗺 Latitud: $lat');
    print('🗺 Longitud: $lon');

    request.fields['user_id'] = userId.toString();
    request.fields['categoria_id'] = categoriaId;
    request.fields['subcategoria_id'] = subcategoriaId;
    request.fields['detalle'] = detalle;
    request.fields['direccion'] = direccion;
    request.fields['tiempo'] = tiempo;
    request.fields['oferta'] = oferta;
    request.fields['metodo_pago'] = metodo;
    request.fields['latitud'] = lat;
    request.fields['longitud'] = lon;

    // 📷 Imagen
    if (imagen != null) {
      print('📷 Imagen: ${imagen!.path}');
      try {
        final file = await http.MultipartFile.fromPath('foto', imagen!.path);
        request.files.add(file);
        print('📎 Imagen agregada correctamente');
      } catch (e) {
        print('⚠️ Error al agregar imagen: $e');
      }
    } else {
      print('📷 Sin imagen');
    }

    try {
      print('⏳ Enviando solicitud al servidor...');
      final response = await request.send();

      print('✅ Solicitud enviada, esperando respuesta...');
      final responseData = await http.Response.fromStream(response);

      print('📦 Código de estado HTTP: ${response.statusCode}');
      print('📦 Cuerpo de respuesta: ${responseData.body}');

      if (responseData.body.isNotEmpty) {
        final result = json.decode(responseData.body);
        print('✅ JSON decodificado: $result');

        if (result['status'] == 'ok') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✅ Solicitud enviada correctamente')),
            );
            Navigator.pop(context);
          }
        } else {
          throw Exception(result['message'] ?? 'Error desconocido en la respuesta');
        }
      } else {
        throw Exception('❗ Respuesta vacía del servidor');
      }
    } catch (e) {
      print('❌ Error al enviar solicitud: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e')),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final categoria = args['categoria'];
    final subcategoria = args['subcategoria'];

    return Scaffold(
      appBar: AppBar(
        title: Text('Solicitar Servicio', style: GoogleFonts.poppins()),
        backgroundColor: Colors.orange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Text('Categoría: ${categoria['nombre']}', style: GoogleFonts.poppins(fontSize: 16)),
              Text('Subcategoría: ${subcategoria['nombre']}', style: GoogleFonts.poppins(fontSize: 16)),
              const SizedBox(height: 16),

              TextFormField(
                controller: detalleController,
                decoration: const InputDecoration(
                  labelText: 'Detalle del servicio solicitado',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) => value == null || value.isEmpty ? 'Ingrese el detalle' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: direccionController,
                decoration: const InputDecoration(
                  labelText: 'Dirección',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Ingrese la dirección' : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: '¿Para cuándo necesita el servicio?',
                  border: OutlineInputBorder(),
                ),
                value: tiempoSeleccionado,
                items: opcionesTiempo.map((opcion) {
                  return DropdownMenuItem<String>(
                    value: opcion['id'],
                    child: Text(opcion['label']!),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    tiempoSeleccionado = value;
                  });
                },
                validator: (value) => value == null ? 'Seleccione una opción' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: ofertaController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Oferta ',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Ingrese una oferta' : null,
              ),
              const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Método de pago',
                border: OutlineInputBorder(),
              ),
              value: metodoPago,
              items: metodosPago.map((metodo) {
                return DropdownMenuItem<String>(
                  value: metodo['id'],
                  child: Text(metodo['label']!),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  metodoPago = value;
                });
              },
              validator: (value) => value == null ? 'Seleccione un método de pago' : null,
            ),

              const SizedBox(height: 16),

              OutlinedButton.icon(
                onPressed: _seleccionarImagen,
                icon: const Icon(Icons.photo),
                label: const Text('Seleccionar Foto'),
              ),
              if (imagen != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Image.file(imagen!, height: 150),
                ),

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    // Aquí enviarías los datos a tu API
                    print('✅ Detalle: ${detalleController.text}');
                    print('📍 Dirección: ${direccionController.text}');
                    print('📅 Tiempo: $tiempoSeleccionado');
                    print('💰 Oferta: ${ofertaController.text}');
                    print('💳 Método de pago: $metodoPago');
                    print('📷 Imagen: ${imagen?.path}');
                    // Podrías hacer aquí la solicitud HTTP
                    enviarSolicitud(); // <- Este método sí manda a la API
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: Text('Enviar Solicitud', style: GoogleFonts.poppins()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
