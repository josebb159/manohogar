import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PasswordRecoveryScreen extends StatefulWidget {
  const PasswordRecoveryScreen({Key? key}) : super(key: key);

  @override
  State<PasswordRecoveryScreen> createState() => _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState extends State<PasswordRecoveryScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool isSending = false;
  String? feedbackMessage;

  Future<void> _sendRecoveryEmail() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ingresa tu correo.')),
      );
      return;
    }

    setState(() {
      isSending = true;
      feedbackMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse('https://manohogar.online/api/app_api.php?action=forgot_password'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['status'] == 'ok') {
          setState(() {
            feedbackMessage = responseData['message'] ?? 'Revisa tu correo electrónico.';
          });
        } else {
          setState(() {
            feedbackMessage = responseData['message'] ?? 'No se pudo enviar el correo.';
          });
        }
      } else {
        setState(() {
          feedbackMessage = 'Error del servidor. Intenta más tarde.';
        });
      }
    } catch (e) {
      setState(() {
        feedbackMessage = 'Error de red: $e';
      });
    } finally {
      setState(() {
        isSending = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar contraseña')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Ingresa tu correo electrónico y te enviaremos un enlace para recuperar tu contraseña.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Correo electrónico',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isSending ? null : _sendRecoveryEmail,
                child: isSending
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Enviar enlace de recuperación'),
              ),
            ),
            const SizedBox(height: 20),
            if (feedbackMessage != null)
              Text(
                feedbackMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.green),
              ),
          ],
        ),
      ),
    );
  }
}
