import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'password_recovery.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Map<String, dynamic>? user;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userData = prefs.getString('user');

    if (userData != null) {
      user = json.decode(userData);
      // Redirigir directamente al Home
      Navigator.pushReplacementNamed(context, '/home');
    }
  }


  Future<void> _login() async {
    // Validación de campos vacíos
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      _showError('Por favor, ingresa tu correo y contraseña.');
      return;
    }

    setState(() => isLoading = true);

    // Crear los datos para enviar a la API
    final data = {
      'correo': emailController.text.trim(),
      'contrasena': passwordController.text.trim(),
    };

    try {
      // Realizar la solicitud a la API
      final response = await http.post(
        Uri.parse('https://manohogar.online/api/app_api.php?action=Login_no_uid'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(data),
      );

      // Procesar la respuesta de la API
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('Respuesta JSON: $responseData');
        // Verificar el estado de la respuesta
        if (responseData['status'] == 'ok') {
          // Si el login es exitoso, guardar la información del usuario
          final user = responseData['user'];
          final prefs = await SharedPreferences.getInstance();
          prefs.setString('user', json.encode(user)); // Guardar el usuario en SharedPreferences

          // Redirigir al usuario al home
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          // Si el login falla
          _showError('Correo o contraseña incorrectos.');
        }
      } else {
        _showError('Error al intentar iniciar sesión. Intenta de nuevo.');
      }
    } catch (e) {
      print('Error al hacer login: $e');
      _showError('Error de conexión. Intenta nuevamente más tarde.');
    } finally {
      setState(() => isLoading = false);
    }
  }


  Future<void> _loginWithGoogle() async {
    try {
      // Inicia sesión con Google
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return; // El usuario canceló el login

      // Obtén la autenticación de Google
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Crea las credenciales de Firebase
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Inicia sesión con Firebase usando las credenciales de Google
      final UserCredential authResult = await FirebaseAuth.instance.signInWithCredential(credential);

      final user = authResult.user;
      if (user == null) {
        _showError('No se pudo autenticar al usuario con Google.');
        return;
      }

      // Verificar si el usuario ya está registrado en tu API
      await _verifyUserInAPI(user.uid, user.email);
    } catch (e) {
      print('Error al ingresar con Google: $e');
      _showError('Error al ingresar con Google: ${e.toString()}');
    }
  }



  Future<void> _verifyUserInAPI(String uid, String? email) async {

    try {
      // La URL de tu API donde verificas si el usuario está registrado
      final data = {

        'correo': email
      };
      print('Respuesta JSON EMAIL: $email');
      // Enviar los datos del usuario (puedes usar uid o email)
      final response = await http.post(
        Uri.parse('https://manohogar.online/api/app_api.php?action=login_google'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(data),
      );


      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('Respuesta JSON: $responseData');
        // Verifica si el registro está completo (esto depende de la respuesta de tu API)
        if (responseData['status'] == 'ok') {
          // Si la respuesta es 'ok', obtenemos el usuario de la respuesta
          final user = responseData['user'];
          final prefs = await SharedPreferences.getInstance();
          prefs.setString('user', json.encode(user));
          // Guarda el 'user' en una variable de sesión usando SharedPreferences

          prefs.setString('user', json.encode(user)); // Guardar el usuario como JSON en SharedPreferences

          // Redirige al home
          Navigator.pushReplacementNamed(context, '/home');
        } else {
         // Si no está completo, redirige a la pantalla de registro
         Navigator.pushReplacementNamed(context, '/register', arguments: {
            'email': email,
            'googleLogin': true,
            'googleToken': uid,
          });


        }


      } else {
        _showError('Error al verificar el registro.');
      }
    } catch (e) {
      print('Error al verificar el registro: $e');
      _showError('Error al verificar el registro: ${e.toString()}');
    }
  }



  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // LOGO
                Image.asset(
                  'assets/logo.png',
                  height: 150,
                ),
                const SizedBox(height: 40),

                // EMAIL
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Correo electrónico',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),

                // PASSWORD
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),

                // BOTÓN LOGIN
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF0090FF),
                      foregroundColor: Colors.white, // <-- Letras blancas
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Iniciar Sesión', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 20),

                // DIVISOR
                Row(
                  children: [
                    Expanded(child: Divider()),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('O'),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 20),

                // BOTÓN GOOGLE
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _loginWithGoogle,
                    icon: Image.asset('assets/google_logo.png', height: 24),
                    label: const Text('Ingresar con Google', style: TextStyle(fontSize: 16)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Color(0xFF0090FF)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // BOTÓN REGISTRAR
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/register', arguments: {
                      'googleLogin': false,
                    });
                  },
                  child: const Text('¿No tienes cuenta? Regístrate aquí'),
                ),
                // OLVIDÉ MI CONTRASEÑA
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => PasswordRecoveryScreen()),
                    );
                  },
                  child: const Text('¿Olvidaste tu contraseña?'),
                ),
              ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
