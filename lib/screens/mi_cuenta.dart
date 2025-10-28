import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class MiCuentaScreen extends StatefulWidget {
  const MiCuentaScreen({Key? key}) : super(key: key);

  @override
  _MiCuentaScreenState createState() => _MiCuentaScreenState();
}

class _MiCuentaScreenState extends State<MiCuentaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _apellidoController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _direccionController = TextEditingController();

  Map<String, dynamic>? user;
  File? _imagenSeleccionada;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userData = prefs.getString('user');
    if (userData != null) {
      setState(() {
        user = json.decode(userData);
        _nombreController.text = user?['nombre'] ?? '';
        _apellidoController.text = user?['apellido'] ?? '';
        _telefonoController.text = user?['telefono'] ?? '';
        _direccionController.text = user?['direccion'] ?? '';
      });
    }
  }

  Future<void> _seleccionarImagen() async {
    final XFile? imagen = await _picker.pickImage(source: ImageSource.gallery);
    if (imagen != null) {
      setState(() {
        _imagenSeleccionada = File(imagen.path);
      });
      await _subirImagen(File(imagen.path));
    }
  }

  Future<void> _subirImagen(File imagen) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://manohogar.online/api/app_api.php?action=upload_user_photo'),
      );

      request.fields['id'] = user?['id'].toString() ?? '';
      request.files.add(await http.MultipartFile.fromPath('foto', imagen.path));

      var response = await request.send();

      if (response.statusCode == 200) {
        final resBody = await response.stream.bytesToString();
        final data = json.decode(resBody);

        if (data['status'] == 'ok') {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          user?['foto'] = data['foto'];
          prefs.setString('user', json.encode(user));

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Foto actualizada correctamente')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${data['message']}')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir la foto. Código: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al subir la imagen: $e')),
      );
    }
  }

  void _mostrarDialogoCambioPassword(BuildContext context) {
    final TextEditingController nuevaPassController = TextEditingController();
    final TextEditingController confirmarPassController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cambiar contraseña'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nuevaPassController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Nueva contraseña'),
              ),
              TextField(
                controller: confirmarPassController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirmar contraseña'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final nuevaPass = nuevaPassController.text.trim();
                final confirmarPass = confirmarPassController.text.trim();

                if (nuevaPass.isEmpty || confirmarPass.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Por favor llena ambos campos')),
                  );
                  return;
                }

                if (nuevaPass != confirmarPass) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Las contraseñas no coinciden')),
                  );
                  return;
                }

                final data = {'id': user?['id'].toString(), 'password': nuevaPass};

                try {
                  final response = await http.post(
                    Uri.parse('https://manohogar.online/api/app_api.php?action=update_password_config'),
                    headers: {'Content-Type': 'application/json'},
                    body: json.encode(data),
                  );

                  final responseData = json.decode(response.body);

                  if (response.statusCode == 200 && responseData['status'] == 'ok') {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Contraseña actualizada exitosamente')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${responseData['message'] ?? 'No se pudo cambiar la contraseña'}')),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al conectar con el servidor: $e')),
                  );
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  void _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      final updatedData = {
        "id": user?['id'].toString(),
        "nombre": _nombreController.text,
        "apellido": _apellidoController.text,
        "telefono": _telefonoController.text,
        "direccion": _direccionController.text,
      };

      try {
        final response = await http.post(
          Uri.parse('https://manohogar.online/api/app_api.php?action=edit_user'),
          headers: {"Content-Type": "application/json"},
          body: json.encode(updatedData),
        );

        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);
          if (responseData['status'] == 'ok') {
            SharedPreferences prefs = await SharedPreferences.getInstance();
            user?['nombre'] = _nombreController.text;
            user?['apellido'] = _apellidoController.text;
            user?['telefono'] = _telefonoController.text;
            user?['direccion'] = _direccionController.text;
            prefs.setString('user', json.encode(user));

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Datos actualizados correctamente')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: ${responseData['message']}')),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al conectar con el servidor')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ocurrió un error: $e')),
        );
      }
    }
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Colors.grey.shade100,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String urlFoto = user?['foto'] != null && user!['foto'] != ''
        ? 'https://manohogar.online/assets/upload/usuario/${user!['foto']}'
        : 'https://manohogar.online/assets/upload/usuario/default.jpg';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Cuenta'),
        centerTitle: true,
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundImage: _imagenSeleccionada != null
                          ? FileImage(_imagenSeleccionada!)
                          : NetworkImage(urlFoto) as ImageProvider,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: InkWell(
                        onTap: _seleccionarImagen,
                        child: const CircleAvatar(
                          backgroundColor: Colors.blue,
                          radius: 22,
                          child: Icon(Icons.camera_alt, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              TextFormField(
                initialValue: user?['email'] ?? '',
                decoration: _inputDecoration('Correo'),
                enabled: false,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _nombreController,
                decoration: _inputDecoration('Nombre'),
                validator: (v) => v == null || v.isEmpty ? 'Ingrese su nombre' : null,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _apellidoController,
                decoration: _inputDecoration('Apellido'),
                validator: (v) => v == null || v.isEmpty ? 'Ingrese su apellido' : null,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _telefonoController,
                keyboardType: TextInputType.number,
                maxLength: 10,
                decoration: _inputDecoration('Teléfono').copyWith(counterText: ''),
                onChanged: (value) {
                  if (!RegExp(r'^[0-9]*$').hasMatch(value)) {
                    _telefonoController.text = value.replaceAll(RegExp(r'[^0-9]'), '');
                    _telefonoController.selection = TextSelection.fromPosition(
                      TextPosition(offset: _telefonoController.text.length),
                    );
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingrese un número de teléfono';
                  }
                  if (value.length != 10) {
                    return 'Debe tener 10 dígitos';
                  }
                  if (!value.startsWith('3')) {
                    return 'Debe iniciar con 3 (celular colombiano)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _direccionController,
                decoration: _inputDecoration('Dirección'),
              ),
              const SizedBox(height: 25),
              TextButton(
                onPressed: () => _mostrarDialogoCambioPassword(context),
                child: const Text(
                  'Cambiar contraseña',
                  style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () {
                  if (_formKey.currentState!.validate()) _saveChanges();
                },
                icon: const Icon(Icons.save),
                label: const Text('Guardar cambios'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
