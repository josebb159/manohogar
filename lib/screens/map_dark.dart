import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController _mapController;
  LatLng? _servicioPosition;
  LatLng? _domiciliarioPosition;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  String distancia = "";
  String duracion = "";
  bool _isLoading = true;
  String _errorMessage = "";
  late BitmapDescriptor origenIcon;
  late BitmapDescriptor destinoIcon;
  Timer? _ubicacionTimer;
  @override
  void initState() {
    super.initState();
    print("🚀 initState llamado");
    _inicializar();
  }



  Future<void> _inicializar() async {
    await _loadIcons();       // 👈 carga íconos personalizados
    await _loadAndTrack();    // 👈 continúa con el flujo
  }
  Future<void> _loadIcons() async {
    origenIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/origen.png',
    );
    destinoIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/destino.png',
    );
    print("✅ Íconos personalizados cargados");
  }
  @override
  void dispose() {
    _ubicacionTimer?.cancel();
    super.dispose();
  }


  Future<void> _loadAndTrack() async {
    print("📥 Iniciando _loadAndTrack");

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userData = prefs.getString('user');
    print("📦 userData desde SharedPreferences: $userData");

    if (userData == null) {
      print("❌ No se encontró información del usuario");
      setState(() {
        _errorMessage = "No se encontró información del usuario";
        _isLoading = false;
      });
      return;
    }

    final Map<String, dynamic> userMap = json.decode(userData);
    final int userId = int.parse(userMap['id'].toString());
    print("✅ ID de usuario obtenido: $userId");

    await _obtenerUbicacionesDesdeAPI(userId);

    if (_servicioPosition != null && _domiciliarioPosition != null) {
      print("📍 Ubicaciones válidas, creando marcadores y obteniendo ruta");
      _crearMarkers();
      _getRouteInfo();
    } else {
      print("⚠️ Las ubicaciones están incompletas");
    }

    setState(() {
      _isLoading = false;
    });

    _ubicacionTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      print("🔄 Timer ejecutando nueva consulta de ubicación...");
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userData = prefs.getString('user');
      if (userData != null) {
        final userMap = json.decode(userData);
        final int userId = int.parse(userMap['id'].toString());
        await _obtenerUbicacionesDesdeAPI(userId);
        if (_servicioPosition != null && _domiciliarioPosition != null) {
          _crearMarkers();
          _getRouteInfo();
        }
      }
    });
  }

  Future<void> _obtenerUbicacionesDesdeAPI(int userId) async {
    print("🌐 Llamando API para obtener ubicaciones con userId: $userId");

    try {
      final response = await http.post(
        Uri.parse('https://manohogar.online/api/app_api.php?action=get_ubication_domicialiario_from_deviery'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'user_id': userId}),
      );

      print("🔁 Código de respuesta: ${response.statusCode}");
      print("📄 Cuerpo de respuesta: ${response.body}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'ok') {
          final ubicacion = data['ubication'];

          print("✅ Datos de ubicación recibidos: $ubicacion");

          _servicioPosition = LatLng(
            double.parse(ubicacion['servicio']['latitud'].toString()),
            double.parse(ubicacion['servicio']['longitud'].toString()),
          );
          print("📌 Servicio: $_servicioPosition");

          _domiciliarioPosition = LatLng(
            double.parse(ubicacion['domiciliario']['latitud'].toString()),
            double.parse(ubicacion['domiciliario']['longitud'].toString()),
          );
          print("🏍️ Domiciliario: $_domiciliarioPosition");

        } else {
          print("❗ Error en la API: ${data['message']}");
          _errorMessage = data['message'] ?? 'Error al obtener ubicación';
        }
      } else {
        print("❌ Error de conexión: ${response.statusCode}");
        _errorMessage = "Error de conexión: ${response.statusCode}";
      }
    } catch (e) {
      print("❌ Excepción capturada: $e");
      _errorMessage = "Excepción: $e";
    }
  }
  void _crearMarkers() {
    _markers = {
      Marker(
        markerId: const MarkerId('domiciliario'),
        position: _domiciliarioPosition!,
        icon: origenIcon, // 👈 Ícono personalizado
        infoWindow: const InfoWindow(title: 'Domiciliario'),
      ),
      Marker(
        markerId: const MarkerId('servicio'),
        position: _servicioPosition!,
        icon: destinoIcon, // 👈 Ícono personalizado
        infoWindow: const InfoWindow(title: 'Cliente'),
      ),
    };
  }

  Future<void> _getRouteInfo() async {
    print("🧭 Solicitando ruta...");

    const apiKey = 'AIzaSyBz3zJ1d-TOXPhpp5t1ZNaKhWai5aVdVpc';
    final url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${_domiciliarioPosition!.latitude},${_domiciliarioPosition!.longitude}&destination=${_servicioPosition!.latitude},${_servicioPosition!.longitude}&key=$apiKey';

    print("📤 URL solicitada: $url");

    try {
      final response = await http.get(Uri.parse(url));
      print("🔁 Código de respuesta: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print("📄 Respuesta de ruta: $data");

        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final polyline = route['overview_polyline']['points'];
          final polylinePoints = PolylinePoints().decodePolyline(polyline);

          final polylineCoords = polylinePoints
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList();

          setState(() {
            _polylines = {
              Polyline(
                polylineId: const PolylineId("ruta"),
                points: polylineCoords,
                color: Colors.blue,
                width: 5,
              )
            };

            distancia = route['legs'][0]['distance']['text'] ?? "N/A";
            duracion = route['legs'][0]['duration']['text'] ?? "N/A";
          });

          print("📏 Distancia: $distancia | 🕒 Duración: $duracion");
        } else {
          print("⚠️ No se encontraron rutas en la respuesta.");
        }
      }
    } catch (e) {
      print("❌ Error obteniendo la ruta: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seguimiento')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
          ? Center(child: Text(_errorMessage))
          : Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _domiciliarioPosition ?? const LatLng(7.9, -72.52),
                zoom: 14,
              ),
              markers: _markers,
              polylines: _polylines,
              onMapCreated: (controller) {
                _mapController = controller;
              },
            ),
          ),
          if (distancia.isNotEmpty && duracion.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                "Distancia: $distancia | Tiempo: $duracion",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }
}
