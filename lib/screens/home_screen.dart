  import 'dart:io';
  import 'package:flutter/material.dart';
  import 'package:google_fonts/google_fonts.dart';
  import 'package:google_maps_flutter/google_maps_flutter.dart';
  import 'package:geolocator/geolocator.dart';
  import 'package:http/http.dart' as http;
  import 'package:image_picker/image_picker.dart';
  import 'dart:convert';
  import 'package:shared_preferences/shared_preferences.dart';
  import 'package:firebase_core/firebase_core.dart';
  import 'package:firebase_messaging/firebase_messaging.dart';
  import 'ver_servicio_solicitado.dart';

  class HomeScreen extends StatefulWidget {
    const HomeScreen({Key? key}) : super(key: key);
  
    @override
    State<HomeScreen> createState() => HomeScreenState();
  }
  
  class HomeScreenState extends State<HomeScreen> {
    Map<String, dynamic> user = {};
    List categories = [];
    Map<String, List> subcategories = {};
    String? selectedCategoryId;
    bool isEspecialista = false;
    double? latitud;
    bool isLoading = false;
    double? longitud;
    final _formKey = GlobalKey<FormState>();
    BitmapDescriptor? customMarker;

    final TextEditingController detalleController = TextEditingController();
    final TextEditingController direccionController = TextEditingController();
    final TextEditingController ofertaController = TextEditingController();
    final TextEditingController lugarController = TextEditingController();
    final TextEditingController selectedTiempo = TextEditingController();
    String? tiempoSeleccionado;
    String? metodoPago;
    File? imagen;
    Set<Marker> _markers = {};
  
    final List<Map<String, String>> metodosPago = [
      {'id': '1', 'label': 'Efectivo'},
      {'id': '2', 'label': 'Nequi'},
      {'id': '3', 'label': 'Daviplata'},
    ];
  
    final List<Map<String, String>> opcionesTiempo = [
      {'id': '1', 'label': 'Urgente (1-2 días)'},
      {'id': '2', 'label': 'Dentro de 2 semanas'},
      {'id': '3', 'label': 'Más de 2 semanas'},
      {'id': '4', 'label': 'No estoy seguro (aún planeando presupuesto)'},
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

    Map? categoria;
    Map? subcategoria;

    @override
    void initState() {
      super.initState();
      _loadUserData();
      _fetchCategories();
      _obtenerUbicacion();
      _getUbicationEspecialista();
      _saveFcmToken();
    }


    Future<void> _saveFcmToken() async {
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      print("📡 _saveFcmToken:");
      // Obtener token de FCM
      String? token = await messaging.getToken();
      try {
        final res = await http.post(
          Uri.parse(
              'https://manohogar.online/api/app_api.php?action=save_fcm'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'user_id': user['id'],
            'token': token,
          }),
        );

        print("📡 Status code: ${res.statusCode}");
        print("📡 Body: ${res.body}");

        if (res.statusCode == 200) {
          final data = json.decode(res.body);

          print("✅ Data decodificada: $data");

          if (data['status'] == 'ok') {
            print("🎉 Token guardado correctamente en el servidor");
          } else {
            print("⚠️ El servidor respondió con error: ${data['status']}");
          }
        } else {
          print("❌ Error HTTP: ${res.statusCode}");
        }
      } catch (e, stack) {
        print("❌ Error guardando token FCM: $e");
        print(stack);
      }
    }


    String getCategoryImage(String? imageName) {
      if (imageName == null || imageName.isEmpty) {
        return "https://manohogar.online/assets/upload/categories/no_found.png";
      }
      return "https://manohogar.online/assets/upload/categories/$imageName";
    }
  
    String getSubcategoryImage(String? imageName) {
      if (imageName == null || imageName.isEmpty) {
        return "https://manohogar.online/assets/upload/subcategories/no_found.png";
      }
      return "https://manohogar.online/assets/upload/subcategories/$imageName";
    }

    Future<void> _createCustomMarker() async {
      final BitmapDescriptor bitmap = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(48, 48)), // tamaño
        'assets/marque_user.png',
      );
      setState(() {
        customMarker = bitmap;
      });
    }


    Future<void> _obtenerUbicacion() async {
      try {
        bool servicioHabilitado = await Geolocator.isLocationServiceEnabled();
        if (!servicioHabilitado) return;

        LocationPermission permiso = await Geolocator.checkPermission();
        if (permiso == LocationPermission.denied) {
          permiso = await Geolocator.requestPermission();
        }
        if (permiso == LocationPermission.denied ||
            permiso == LocationPermission.deniedForever) {
          return;
        }

        Position posicion = await Geolocator.getCurrentPosition();

        // 🔹 Obtén el icono fuera de setState
        final userIcon = await BitmapDescriptor.fromAssetImage(
          const ImageConfiguration(size: Size(100, 100)),
          'assets/marque_user.png',
        );

        setState(() {
          latitud = posicion.latitude;
          longitud = posicion.longitude;

          _markers.add(Marker(
            markerId: const MarkerId("mi_ubicacion"),
            position: LatLng(latitud!, longitud!),
            icon: userIcon, // 👈 aquí usamos el icono personalizado
            infoWindow: const InfoWindow(title: "Mi ubicación"),
          ));
        });
      } catch (e) {
        print("❌ Error obteniendo ubicación: $e");
      }
    }



    Future<void> _loadUserData() async {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userData = prefs.getString('user');
      if (userData != null) {
        setState(() {
          user = json.decode(userData);
        });
        _checkIfEspecialista();
      }
    }
  
    Future<void> _checkIfEspecialista() async {
      if (user.isEmpty) return;
      try {
        final res = await http.post(
          Uri.parse(
              'https://manohogar.online/api/app_api.php?action=get_is_especialista'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'user_id': user['id']}),
        );
        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          if (data['status'] == 'ok' && data['especialista'] > 0) {
            setState(() {
              isEspecialista = true;
            });
          }
        }
      } catch (e) {
        print("🔥 Error verificando especialista: $e");
      }
    }
  
    Future<void> enviarSolicitud() async {


      if (selectedCategoryId == null || subcategoria == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ Selecciona una categoría y subcategoría')),
        );
        return;
      }
      setState(() {
        isLoading = true; // 🔹 Activa la pantalla de carga
      });
      final uri = Uri.parse(
          'https://manohogar.online/api/app_api.php?action=solicitar_servicio');
      final request = http.MultipartRequest('POST', uri);
  
      final userId = user['id'];
      final categoriaId = categoria!['id'].toString();
      final subcategoriaId = subcategoria!['id'].toString();
  
      request.fields['user_id'] = userId.toString();
      request.fields['categoria_id'] = categoriaId;
      request.fields['subcategoria_id'] = subcategoriaId;
      request.fields['detalle'] = detalleController.text;
      request.fields['direccion'] = direccionController.text;
      request.fields['tiempo'] = tiempoSeleccionado ?? '';
      request.fields['oferta'] = ofertaController.text;
      request.fields['metodo_pago'] = metodoPago ?? '';
      request.fields['latitud'] = latitud?.toString() ?? '';
      request.fields['longitud'] = longitud?.toString() ?? '';
      request.fields['lugar'] = lugarController.text ?? '';
      request.fields['tiempo_alquiler'] = selectedTiempo.text ?? '';
  
      if (imagen != null) {
        final file = await http.MultipartFile.fromPath('foto', imagen!.path);
        request.files.add(file);
      }
  
      try {
        final response = await request.send();
        final responseData = await http.Response.fromStream(response);
        final result = json.decode(responseData.body);

        if (result['status'] == 'ok') {
          final String idServicio = result['id_servicio'].toString();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Solicitud enviada'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );

            // 👇 Limpia el formulario y actualiza la vista
            setState(() {
              detalleController.clear();
              direccionController.clear();
              ofertaController.clear();
              tiempoSeleccionado = null;
              metodoPago = null;
              imagen = null;
              selectedCategoryId = null;
              categoria = null;
              subcategoria = null;
            });

            // 👇 Vuelve a traer datos frescos desde el backend
            _fetchCategories();
            Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VerServicioSolicitado(
                    idServicio: idServicio, // ← Aquí se pasa el valor real del backend
                  ),
                ),
            );
          }
        } else {
          throw Exception(result['message'] ?? 'Error en respuesta');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ Error: $e')),
          );
        }
      }finally {
        setState(() {
          isLoading = false; // 🔹 Desactiva la pantalla de carga
        });
      }
    }
  
    Future<void> _fetchCategories() async {
      print("⚠️ entro en categories");
      try {
        final res = await http.post(
          Uri.parse('https://manohogar.online/api/app_api.php?action=get_categories'),
          headers: {'Content-Type': 'application/json'},
        );
        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          if (data['status'] == 'ok') {
            setState(() {
              categories = data['categories'];
            });
            for (var cat in categories) {
              _fetchSubcategories(cat['id'].toString());
            }
          }
        }
      } catch (e) {
        print("❌ Error cargando categorías: $e");
      }
    }


    Future<void> _getUbicationEspecialista() async {
      try {
        final res = await http.post(
          Uri.parse(
              'https://manohogar.online/api/app_api.php?action=getUbicationEspecialista'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'user_id': user['id']}), // ⚠️ cuidado aquí
        );

        print("📡 Status code: ${res.statusCode}");
        print("📡 Body: ${res.body}");

        if (res.statusCode == 200) {
          final data = json.decode(res.body);

          print("✅ Data decodificada: $data");

          if (data['status'] == 'ok') {
            if (data['ubicaciones'] == null) {
              print("⚠️ No llegaron ubicaciones en la respuesta");
              return;
            }

            final List ubicaciones = data['ubicaciones'];

            // 🔹 Cargamos el icono antes de entrar a setState
            final workIcon = await BitmapDescriptor.fromAssetImage(
              const ImageConfiguration(size: Size(100, 100)),
              'assets/marque_work.png',
            );

            setState(() {
              for (var i = 0; i < ubicaciones.length; i++) {
                final ubi = ubicaciones[i];

                final double lat =
                    double.tryParse(ubi['latitud'].toString()) ?? 0.0;
                final double lng =
                    double.tryParse(ubi['longitud'].toString()) ?? 0.0;

                if (lat == 0.0 && lng == 0.0) {
                  print("⚠️ Ubicación inválida en índice $i: $ubi");
                  continue;
                }

                _markers.add(
                  Marker(
                    markerId: MarkerId("especialista_$i"),
                    position: LatLng(lat, lng),
                    icon: workIcon, // 👈 aquí usamos la imagen personalizada
                    infoWindow: InfoWindow(
                      title: "Especialista $i",
                    ),
                  ),
                );
              }
            });

            print("✅ ${_markers.length} marcadores agregados");
          } else {
            print("⚠️ Status recibido no es 'ok': ${data['status']}");
          }
        } else {
          print("❌ Error HTTP: ${res.statusCode}");
        }
      } catch (e, stack) {
        print("❌ Error cargando ubicaciones: $e");
        print(stack);
      }
    }




    Future<void> _fetchSubcategories(String categoryId) async {
      print("⚠️ Entró en _fetchSubcategories con categoryId: $categoryId");
  
      try {
        final url = Uri.parse(
            'https://manohogar.online/api/app_api.php?action=get_subcategories');
        print("🌍 URL de la petición: $url");
  
        final body = json.encode({'category_id': categoryId});
        print("📦 Body enviado: $body");
  
        final res = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: body,
        );
  
        print("📡 Status Code: ${res.statusCode}");
        print("📡 Respuesta RAW: ${res.body}");
  
        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          print("📊 Decoded JSON: $data");
  
          if (data['status'] == 'ok') {
            print("✅ Subcategorías recibidas para $categoryId -> ${data['subcategories']}");
            setState(() {
              subcategories[categoryId] = data['subcategories'];
            });
          } else {
            print("⚠️ La API no devolvió subcategorías válidas para $categoryId");
          }
        } else {
          print("⚠️ Error HTTP con status: ${res.statusCode}");
        }
      } catch (e) {
        print("❌ Excepción al cargar subcategorías: $e");
      }
    }
  
  
    void _logout() async {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('user');
      Navigator.of(context).pushReplacementNamed('/login');
    }
  
    @override
    Widget build(BuildContext context) {
      final selectedSubcats = subcategories[selectedCategoryId] ?? [];
  
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.orange,
          title: Text('Manohogar', style: GoogleFonts.poppins()),
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications, color: Colors.black),
              onPressed: () {
                Navigator.pushNamed(context, '/notificaciones');
              },
            ),
          ],
        ),
        drawer: Drawer(
          child: ListView(
            children: [
                UserAccountsDrawerHeader(
                accountName: Text(user['nombre'] ?? 'Usuario'),
                accountEmail: Text(user['correo'] ?? ''),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Colors.orange,
                  backgroundImage: (user['foto'] != null && user['foto'].toString().isNotEmpty)
                      ? NetworkImage('https://manohogar.online/assets/upload/usuario/${user['foto']}')
                      : const AssetImage('assets/no_user.png') as ImageProvider, // 👈 imagen por defecto
                ),
              ),
              ListTile(
                leading: const Icon(Icons.build),
                title: const Text("Mis servicios"),
                onTap: () {
                  Navigator.pushNamed(context, '/mis_servicios');
                },
              ),
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text("Mi perfil"),
                onTap: () {
                  Navigator.pushNamed(context, '/mi_cuenta');
                },
              ),
              if (isEspecialista)
              ListTile(
                leading: const Icon(Icons.account_balance_wallet),
                title: const Text("Recargar"),
                onTap: () {
                  Navigator.pushNamed(context, '/recarga');
                },
              ),
              if (isEspecialista)
                ListTile(
                  leading: const Icon(Icons.info),
                  title: const Text("Información especialista"),
                  onTap: () {
                    Navigator.pushNamed(context, '/especialista');
                  },
                ),
              if (isEspecialista)
                ListTile(
                  leading: const Icon(Icons.list_alt),
                  title: const Text("Servicios disponibles"),
                  onTap: () {
                    Navigator.pushNamed(context, '/mis_servicios_especialistas');
                  },
                ),
              if (isEspecialista)
                ListTile(
                  leading: const Icon(Icons.payment),
                  title: const Text("Transacciones"),
                  onTap: () {
                    Navigator.pushNamed(context, '/mis_descuentos');
                  },
                ),
              if (!isEspecialista)
                ListTile(
                  leading: const Icon(Icons.person_add),
                  title: const Text("Ser especialista"),
                  onTap: () {
                    Navigator.pushNamed(context, '/postular_especialista');
                  },
                ),

              ListTile(
                leading: const Icon(Icons.support_agent),
                title: const Text("Soporte chat"),
                onTap: () {
                  Navigator.pushNamed(context, '/chat_suport');
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text("Salir"),
                onTap: _logout,
              ),
            ],
          ),
        ),
        body:  isLoading
            ? const Center(child: CircularProgressIndicator())
            :SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Form( // 👈 ahora sí usamos el form
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (latitud != null && longitud != null)
                  SizedBox(
                  height: 200,
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(latitud ?? 0, longitud ?? 0),
                      zoom: 14,
                    ),
                    markers: _markers,
                  ),
                ),

  
                  SizedBox(
                    height: 140,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: categories.length,
                      shrinkWrap: true, // 👈 ajusta al contenido
                      physics: const ClampingScrollPhysics(), // 👈 evita conflicto de scroll
                      itemBuilder: (context, index) {
                        final cat = categories[index];
                        final isSelected =
                            cat['id'].toString() == selectedCategoryId;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedCategoryId = cat['id'].toString();
                              categoria = cat;
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isSelected ? Colors.orange : Colors.grey,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                            mainAxisSize: MainAxisSize.min, // 👈 evita que el column crezca de más
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.network(
                                getCategoryImage(cat['imagen']),
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                cat['nombre'] ?? '',
                                style: GoogleFonts.poppins(fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                          ),
                        );
                      },
                    ),
                  ),
  
                  if (selectedCategoryId != null && selectedSubcats.isNotEmpty)

                    GridView.builder(
                      shrinkWrap: true,

                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 1, // 👈 prueba con 1 o incluso 1.1
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: selectedSubcats.length,
                      itemBuilder: (context, index) {
                        final sub = selectedSubcats[index];
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              subcategoria = sub;
                              if (sub['valor_min'] != null && sub['valor_min'].toString().isNotEmpty) {
                                ofertaController.text = sub['valor_min'].toString();
                                print("✅ valor_min aplicado automáticamente -> ${sub['valor_min']}");
                              } else {
                                print("⚠️ Esta subcategoría no tiene valor_min definido");
                              }
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: subcategoria == sub ? Colors.orange : Colors.grey, // 👈 marcado
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    getSubcategoryImage(sub['imagen']),
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  sub['nombre'] ?? '',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: subcategoria == sub ? FontWeight.bold : FontWeight.normal, // 👈 resalta texto
                                    color: subcategoria == sub ? Colors.orange : Colors.black, // 👈 color marcado
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    )
                  else if (selectedCategoryId != null)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                          child: Text("⚠️ No hay subcategorías para esta categoría"),
                      ),
                    ),
  
                  const Divider(thickness: 1, height: 32),


                  if(selectedCategoryId != "10")
                  TextFormField(
                    controller: detalleController,
                    decoration: const InputDecoration(
                      labelText: 'Detalle del servicio solicitado',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    validator: (value) =>
                    value == null || value.isEmpty ? 'Ingrese el detalle' : null,
                  ),
                  const SizedBox(height: 16),


                  if(selectedCategoryId == "10")
                    TextFormField(
                      controller: lugarController,
                      decoration: const InputDecoration(
                        labelText: 'Lugar de recogida',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      validator: (value) =>
                      value == null || value.isEmpty ? 'Ingrese el lugar' : null,
                    ),
                  const SizedBox(height: 16),

                  if(selectedCategoryId == "13")
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Tiempo',
                      border: OutlineInputBorder(),
                    ),
                    value: selectedTiempo.text.isNotEmpty ? selectedTiempo.text : null,
                    items: const [
                      DropdownMenuItem(value: '4 horas', child: Text('4 horas')),
                      DropdownMenuItem(value: '6 horas', child: Text('6 horas')),
                      DropdownMenuItem(value: '12 horas', child: Text('12 horas')),
                      DropdownMenuItem(value: '24 horas', child: Text('24 horas')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        selectedTiempo.text = value; // Aquí guardas la selección
                      }
                    },
                    validator: (value) =>
                    value == null || value.isEmpty ? 'Seleccione el tiempo' : null,
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    isExpanded: true, // 🔥 Esto hace que el dropdown use todo el ancho disponible
                    decoration: const InputDecoration(
                      labelText: '¿Para cuándo necesita el servicio?',
                      border: OutlineInputBorder(),
                    ),
                    value: tiempoSeleccionado,
                    items: opcionesTiempo.map((opcion) {
                      return DropdownMenuItem<String>(
                        value: opcion['id'],
                        child: Text(
                          opcion['label']!,
                          overflow: TextOverflow.ellipsis, // 🔥 Evita desbordamiento de texto largo
                        ),
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
                      labelText: 'Oferta',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                    value == null || value.isEmpty ? 'Ingrese una oferta' : null,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: direccionController,
                    keyboardType: TextInputType.text,
                    decoration: const InputDecoration(
                      labelText: 'Dirección',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                    value == null || value.isEmpty ? 'Ingrese Dirección' : null,
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
                        enviarSolicitud();
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                    child: Text('Enviar Solicitud', style: GoogleFonts.poppins()),
                  ),
                  const SizedBox(height: 24),const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      );
    }
  }
