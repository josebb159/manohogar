import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MiCuentaScreen extends StatefulWidget {
  const MiCuentaScreen({Key? key}) : super(key: key);

  @override
  _MiCuentaScreenState createState() => _MiCuentaScreenState();
}

class _MiCuentaScreenState extends State<MiCuentaScreen> {
  final _formKey = GlobalKey<FormState>();
  TextEditingController _nombreController = TextEditingController();
  TextEditingController _apellidoController = TextEditingController();
  TextEditingController _telefonoController = TextEditingController();
  TextEditingController _direccionController = TextEditingController();

  Map<String, dynamic>? user;

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

                final data = {
                  'id': user?['id'].toString(),
                  'password': nuevaPass
                };

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
          Uri.parse('https://manohogar.online/api/app_api.php?action=edit_user'), // Cambia aquí por tu URL
          headers: {"Content-Type": "application/json"},
          body: json.encode(updatedData),
        );

        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);
          if (responseData['status'] == 'ok') {
            // Actualizar SharedPreferences
            SharedPreferences prefs = await SharedPreferences.getInstance();
            user?['nombre'] = _nombreController.text;
            user?['apellido'] = _apellidoController.text;
            user?['telefono'] = _telefonoController.text;
            user?['direccion'] = _direccionController.text;
            prefs.setString('user', json.encode(user));

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Datos actualizados correctamente')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: ${responseData['message']}')),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al conectar con el servidor')),
          );
        }
      } catch (e) {
        print(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ocurrió un error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Cuenta'),
      ),
      body: user == null
          ? Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                initialValue: user?['email'] ?? '',
                decoration: InputDecoration(labelText: 'Correo'),
                enabled: false,
              ),
              TextFormField(
                controller: _nombreController,
                decoration: InputDecoration(labelText: 'Nombre'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa tu nombre';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _apellidoController,
                decoration: InputDecoration(labelText: 'Apellido'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa tu apellido';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _telefonoController,
                decoration: InputDecoration(labelText: 'Teléfono'),
              ),
              TextFormField(
                controller: _direccionController,
                decoration: InputDecoration(labelText: 'Dirección'),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  _mostrarDialogoCambioPassword(context);
                },
                child: const Text(
                  'Cambiar contraseña',
                  style: TextStyle(color: Color(0xFF0090FF)),
                ),
              ),
              ElevatedButton(
                onPressed: _saveChanges,
                child: const Text('Guardar cambios'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
