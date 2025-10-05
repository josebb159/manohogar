import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Importa tus pantallas
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/mis_servicios_screen.dart';
import 'screens/mi_cuenta.dart';
import 'screens/postular_especialista_page.dart';
import 'screens/SolicitarServicioScreen.dart';
import 'screens/ver_servicio_solicitado.dart';
import 'screens/ver_servicio_solicitado_especialista.dart';
import 'screens/RecargaScreen.dart';
import 'screens/mis_servicios_screen_specialista.dart';
import 'screens/especialista_screed.dart';
import 'screens/mis_descuentos_screen.dart';
import 'screens/oferta.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/chat_suport_screen.dart';
import 'dart:convert';

// Clave para navegación global
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
// Clave global para acceder al estado de HomeScreen
final GlobalKey<HomeScreenState> homeScreenKey = GlobalKey<HomeScreenState>();

const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel',
  'Notificaciones Importantes',
  description: 'Este canal se usa para notificaciones críticas.',
  importance: Importance.high,
);

// Plugin de notificaciones locales
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

// Handler en segundo plano
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  print("📦 Mensaje en segundo plano: ${message.data}");

  final action = message.data['type'] ?? '';
  final idServicio = message.data['id_servicio'] ?? '';

  // 🔹 Título y cuerpo personalizados
  String title;
  String body;

  switch (action) {
    case 'update_rental':
      title = "Actualización de estado";
      body = idServicio.isNotEmpty
          ? "Tu servicio #$idServicio ha cambiado de estado."
          : "Tu servicio ha cambiado de estado.";
      break;

    case 'open_mis_servicios':
      title = "Servicios";
      body = "Accede a tus servicios activos.";
      break;

    case 'logout':
      title = "Sesión finalizada";
      body = "Se cerró tu sesión por seguridad.";
      break;

    default:
      title = "Manohogar";
      body = "Tienes una nueva notificación.";
  }

  // 🔹 Mostrar notificación local
  flutterLocalNotificationsPlugin.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    ),
    payload: "id_servicio=$idServicio&type=$action",
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Pedir permisos
  await FirebaseMessaging.instance.requestPermission();

  // Inicializar notificaciones locales
  const androidInitSettings = AndroidInitializationSettings('ic_notification');
  const initSettings = InitializationSettings(android: androidInitSettings);

  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse:
        (NotificationResponse notificationResponse) {
      final payload = notificationResponse.payload;
      if (payload != null) {
        final data = Uri.splitQueryString(payload);
        final id = data['id_servicio'];
        if (id != null) {
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => VerServicioSolicitadoEspecialista(idServicio: id),
            ),
          );
        }
      }
    },
  );


  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    print("📩 Notificación recibida: ${message.data}");
    final idServicio = message.data['id_servicio'];
    final action = message.data['type'];
    final userId = message.data['user_id'];
    String title = "Manohogar";
    String body = "Nueva notificación";

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userData = prefs.getString('user');
    Map<String, dynamic> user = {};
    if (userData != null) {
      user = json.decode(userData);
    }

    if (action != null) {
      switch (action) {

        case 'oferta':
          title = "Oferta";
          body = "Nueva oferta realizada.";

          break;
        case 'oferta_aceptada':
          title = "Oferta";
          body = "Oferta aceptada.";

          break;

        case 'update_rental':
          title = "Actualización de estado";
          body = "Tu servicio ha cambiado de estado.";
          // ⚡ Aviso dentro de la app
          final context = navigatorKey.currentContext;
          if (context != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("📢 Actualización de estado: Tu servicio ha cambiado."),
                duration: Duration(seconds: 4),
                backgroundColor: Colors.blueAccent,
              ),
            );
          }

          if (user['id'] != null && homeScreenKey.currentState != null) {
            print("📩 entro en update_rental notification");

            //homeScreenKey.currentState!.getRentalStatus(user['id'].toString());
          }
          break;

        case 'open_mis_servicios':
          title = "Nuevo servicio Disponible";
          body = "Tienes un nuevo servicio disponible.";
          showDialog(
            context: navigatorKey.currentContext!,
            builder: (_) => AlertDialog(
              title: Text(message.notification!.title ?? 'Nuevo servicio'),
              content: Text(message.notification!.body ?? ''),
              actions: [
                TextButton(
                  child: const Text('Ver'),
                  onPressed: () {
                    Navigator.of(navigatorKey.currentContext!).pop();
                    Navigator.push(
                      navigatorKey.currentContext!,
                      MaterialPageRoute(
                        builder: (_) =>
                            VerServicioSolicitadoEspecialista(idServicio: idServicio),
                      ),
                    );
                  },
                ),
                TextButton(
                  child: const Text('Cerrar'),
                  onPressed: () {
                    Navigator.of(navigatorKey.currentContext!).pop();
                  },
                ),
              ],
            ),
          );
          break;

        case 'logout':
          navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (r) => false);
          break;

        default:
          print("⚠️ Acción desconocida: $action");
      }
      // 🔹 Mostrar notificación local
      flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
        payload: "type=$action",
      );
    }
  });



  // Notificación al abrir app desde cerrada
  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    final id = initialMessage.data['id_servicio'];
    if (id != null) {
      Future.delayed(Duration.zero, () {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => VerServicioSolicitadoEspecialista(idServicio: id),
          ),
        );
      });
    }
  }

  // Notificación tocada cuando app en segundo plano
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    final id = message.data['id_servicio'];
    if (id != null) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => VerServicioSolicitadoEspecialista(idServicio: id),
        ),
      );
    }
  });

  // Notificaciones en segundo plano
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
       navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Manohogar',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Color(0xFF0090FF)),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => LoginScreen(),
        '/login': (context) => LoginScreen(),
        '/home': (context) => HomeScreen(),
        '/register': (context) => RegisterScreen(),
        '/mis_servicios': (context) => MisServiciosScreen(),
        '/mi_cuenta': (context) => MiCuentaScreen(),
        '/postular_especialista': (context) =>
            PostulacionEspecialistaScreen(),
        '/solicitar_servicio': (context) => const SolicitarServicioScreen(),
        '/recarga': (context) => const RecargaScreen(),
        '/especialista': (context) => const EspecialistaDetallePage(),
        '/mis_servicios_especialistas': (context) => const MisServiciosEspecialistaScreen(),
        '/mis_descuentos': (context) => const MisDescuentosScreen(),
        '/chat_suport': (context) => const ChatScreenSupport(),



        // Puedes agregar esta ruta si quieres usar pushNamed en vez de push:
        // '/ver_servicio': (context) => VerServicioSolicitado(idServicio: ''),
      },
    );
  }
}
