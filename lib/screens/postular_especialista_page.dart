import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

class PostulacionEspecialistaScreen extends StatefulWidget {
  const PostulacionEspecialistaScreen({Key? key}) : super(key: key);

  @override
  State<PostulacionEspecialistaScreen> createState() =>
      _PostulacionEspecialistaScreenState();
}

class _PostulacionEspecialistaScreenState
    extends State<PostulacionEspecialistaScreen> {
  final _formKey = GlobalKey<FormState>();
  List categories = [];
  List<int> selectedCategoryIds = []; // ✅ varias categorías
  Map<String, dynamic> user = {};

  // Campos del formulario
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController aniosController = TextEditingController();
  final idController = TextEditingController();
  final ciudadController = TextEditingController();
  final nacionalidadController = TextEditingController();

  String? selectedDepartamento;
  String? selectedCiudad;
  String? selectedNacionalidad;

  final List<String> nacionalidades = [
    "Argentina",
    "Bolivia",
    "Brasil",
    "Chile",
    "Colombia",
    "Costa Rica",
    "Cuba",
    "Ecuador",
    "El Salvador",
    "Guatemala",
    "Honduras",
    "México",
    "Nicaragua",
    "Panamá",
    "Paraguay",
    "Perú",
    "Puerto Rico",
    "República Dominicana",
    "Uruguay",
    "Venezuela",
  ];

  final Map<String, List<String>> colombia = {
    "Amazonas": ["Leticia", "Puerto Nariño"],
    "Antioquia": ["Medellín", "Bello", "Envigado", "Itagüí"],
    "Atlántico": ["Barranquilla", "Soledad", "Malambo"],
    "Bolívar": ["Cartagena", "Magangué", "Turbaco"],
    "Boyacá": ["Tunja", "Duitama", "Sogamoso"],
    "Caldas": ["Manizales", "Villamaría", "Chinchiná"],
    "Cauca": ["Popayán", "Santander de Quilichao"],
    "Cesar": ["Valledupar", "Aguachica"],
    "Córdoba": ["Montería", "Lorica"],
    "Cundinamarca": ["Bogotá", "Soacha", "Chía"],
    "Norte de Santander": ["Cúcuta", "Villa del Rosario", "Los Patios"],
    "Santander": ["Bucaramanga", "Floridablanca", "Girón"],
    "Tolima": ["Ibagué", "Espinal"],
    "Valle del Cauca": ["Cali", "Palmira", "Buenaventura"],
    "Meta": ["Villavicencio", "Acacías"],
    "Nariño": ["Pasto", "Ipiales"],
    "Risaralda": ["Pereira", "Dosquebradas"],
    "Quindío": ["Armenia", "Calarcá"],
    "Magdalena": ["Santa Marta", "Ciénaga"],
  };

  int subcategoryLimit = 0; // ✅ límite global (categorías + subcategorías)
  List<dynamic> subcategoryList = [];
  List<int> selectedSubcategoryIds = [];

  File? cedulaFront;
  File? cedulaBack;
  File? antecedentes;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadCategories();
    _loadLimit();
  }

  Future<void> _loadCategories() async {
    final response = await http.post(
      Uri.parse('https://manohogar.online/api/app_api.php?action=get_categories'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'ok') {
        setState(() {
          categories = data['categories'];
        });
      }
    }
  }

  Future<void> _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userData = prefs.getString('user');
    if (userData != null) {
      final userMap = json.decode(userData);

      setState(() {
        user = userMap;
        nameController.text = userMap['nombre'] ?? '';
        phoneController.text = userMap['telefono'] ?? '';
        emailController.text = userMap['email'] ?? '';
      });
    }
  }

  Future<void> _loadSubcategories(int categoryId) async {
    final url = Uri.parse(
        'https://manohogar.online/api/app_api.php?action=get_subcategories');

    final data = {
      'category_id': categoryId,
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(data),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);

        if (jsonResponse['status'] == 'ok') {
          final List subcategories = jsonResponse['subcategories'];

          setState(() {
            subcategoryList.addAll(subcategories);
          });
        }
      }
    } catch (e) {
      print('❗ Error: $e');
    }
  }

  Future<void> _loadLimit() async {
    final response = await http.post(
      Uri.parse(
          'https://manohogar.online/api/app_api.php?action=get_limit_config'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final limitStr = data['limit']?.toString();

      if (limitStr != null && limitStr.isNotEmpty && limitStr != 'null') {
        setState(() {
          subcategoryLimit = int.parse(limitStr);
        });
      } else {
        setState(() {
          subcategoryLimit = 0;
        });
      }
    }
  }

  Future<void> _pickFile(Function(File) onSelected) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);

    if (result != null && result.files.single.path != null) {
      onSelected(File(result.files.single.path!));
    }
  }

  void _submit() async {
    if (_formKey.currentState!.validate() &&
        cedulaFront != null &&
        cedulaBack != null &&
        antecedentes != null &&
        (selectedCategoryIds.isNotEmpty || selectedSubcategoryIds.isNotEmpty)) {
      try {
        final uri = Uri.parse(
            'https://manohogar.online/api/app_api.php?action=registrar_especialista');
        final request = http.MultipartRequest('POST', uri);

        // Datos simples
        request.fields['user_id'] = user['id'];
        request.fields['nombre'] = nameController.text;
        request.fields['telefono'] = phoneController.text;
        request.fields['email'] = emailController.text;
        request.fields['numero_identificacion'] = idController.text;
        request.fields['ciudad'] = ciudadController.text;
        request.fields['nacionalidad'] = nacionalidadController.text;
        request.fields['anios_experiencia'] = aniosController.text;

        // ✅ Enviar listas como JSON
        request.fields['categorias'] = json.encode(selectedCategoryIds);
      //  request.fields['subcategorias'] = json.encode(selectedSubcategoryIds);

        // Archivos adjuntos
        request.files.add(await http.MultipartFile.fromPath(
            'cedula_frontal', cedulaFront!.path));
        request.files.add(await http.MultipartFile.fromPath(
            'cedula_trasera', cedulaBack!.path));
        request.files.add(await http.MultipartFile.fromPath(
            'antecedentes', antecedentes!.path));

        final response = await request.send();

        if (response.statusCode == 200) {
          final respStr = await response.stream.bytesToString();
          final jsonResp = json.decode(respStr);

          if (jsonResp['status'] == 'ok') {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Postulación enviada con éxito")),
            );
            Navigator.pop(context);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(jsonResp['message'] ?? 'Error desconocido')),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al enviar: ${response.statusCode}')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Ocurrió un error al enviar la postulación.")),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Completa todos los campos requeridos")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Postularse como Especialista'),
        backgroundColor: Colors.orange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildTextField(nameController, 'Nombre'),
              _buildTextField(phoneController, 'Teléfono',
                  keyboard: TextInputType.phone,
                  formatter: [FilteringTextInputFormatter.digitsOnly]),
              _buildTextField(emailController, 'Correo',
                  keyboard: TextInputType.emailAddress),
              _buildTextField(idController, 'Número de identificación'),

              // Departamento
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: DropdownButtonFormField<String>(
                  value: selectedDepartamento,
                  decoration: InputDecoration(
                    labelText: 'Departamento',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  items: colombia.keys.map((String dep) {
                    return DropdownMenuItem<String>(
                      value: dep,
                      child: Text(dep),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedDepartamento = value;
                      selectedCiudad = null;
                    });
                  },
                  validator: (value) =>
                  value == null ? 'Selecciona un departamento' : null,
                ),
              ),

              if (selectedDepartamento != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: DropdownButtonFormField<String>(
                    value: selectedCiudad,
                    decoration: InputDecoration(
                      labelText: 'Ciudad',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    items: colombia[selectedDepartamento]!
                        .map((String ciudad) {
                      return DropdownMenuItem<String>(
                        value: ciudad,
                        child: Text(ciudad),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedCiudad = value;
                        ciudadController.text = value!;
                      });
                    },
                    validator: (value) =>
                    value == null ? 'Selecciona una ciudad' : null,
                  ),
                ),

              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: DropdownButtonFormField<String>(
                  value: selectedNacionalidad,
                  decoration: InputDecoration(
                    labelText: 'Nacionalidad',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  items: nacionalidades.map((String pais) {
                    return DropdownMenuItem<String>(
                      value: pais,
                      child: Text(pais),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedNacionalidad = value;
                      nacionalidadController.text = value!;
                    });
                  },
                  validator: (value) =>
                  value == null ? 'Selecciona una nacionalidad' : null,
                ),
              ),

              _buildTextField(aniosController, 'Años de experiencia',
                  keyboard: TextInputType.number,
                  formatter: [FilteringTextInputFormatter.digitsOnly]),

              const SizedBox(height: 20),

              // ✅ Múltiples categorías
              Text("Selecciona categorías:",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              Column(
                children: categories.map<Widget>((cat) {
                  final catId = int.parse(cat['id']);
                  return CheckboxListTile(
                    title: Text(cat['nombre']),
                    value: selectedCategoryIds.contains(catId),
                    onChanged: (bool? checked) {
                      setState(() {
                        if (checked == true) {
                          if (selectedCategoryIds.length +
                              selectedSubcategoryIds.length <
                              subcategoryLimit) {
                            selectedCategoryIds.add(catId);
                            _loadSubcategories(catId);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      "Solo puedes seleccionar hasta $subcategoryLimit categorías/subcategorías")),
                            );
                          }
                        } else {
                          selectedCategoryIds.remove(catId);
                          subcategoryList.removeWhere(
                                  (sub) => sub['category_id'] == catId);
                          selectedSubcategoryIds.removeWhere((id) =>
                              subcategoryList.any(
                                      (sub) => int.parse(sub['id']) == id));
                        }
                      });
                    },
                  );
                }).toList(),
              ),

              if (subcategoryList.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Selecciona subcategorías:',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                Column(
                  children: subcategoryList.map<Widget>((sub) {
                    final subId = int.parse(sub['id'].toString());
                    return CheckboxListTile(
                      title: Text(sub['nombre']),
                      value: selectedSubcategoryIds.contains(subId),
                      onChanged: (bool? checked) {
                        setState(() {
                          if (checked == true) {
                            if (selectedCategoryIds.length +
                                selectedSubcategoryIds.length <
                                subcategoryLimit) {
                              selectedSubcategoryIds.add(subId);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        "Solo puedes seleccionar hasta $subcategoryLimit categorías/subcategorías")),
                              );
                            }
                          } else {
                            selectedSubcategoryIds.remove(subId);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ],

              const SizedBox(height: 20),
              Text('Cargar cédula (delantera):',
                  style: GoogleFonts.poppins()),
              _buildUploadButton(cedulaFront,
                      () => _pickFile((f) => setState(() => cedulaFront = f))),

              const SizedBox(height: 10),
              Text('Cargar cédula (trasera):', style: GoogleFonts.poppins()),
              _buildUploadButton(cedulaBack,
                      () => _pickFile((f) => setState(() => cedulaBack = f))),

              const SizedBox(height: 10),
              Text('Antecedentes judiciales (< 1 mes):',
                  style: GoogleFonts.poppins()),
              _buildUploadButton(antecedentes,
                      () => _pickFile((f) => setState(() => antecedentes = f))),

              const SizedBox(height: 30),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: GoogleFonts.poppins(fontSize: 16),
                ),
                onPressed: _submit,
                child: const Text('Enviar postulación'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {TextInputType keyboard = TextInputType.text,
        List<TextInputFormatter>? formatter}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        inputFormatters: formatter,
        validator: (value) =>
        value == null || value.isEmpty ? 'Campo obligatorio' : null,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Widget _buildUploadButton(File? file, VoidCallback onPick) {
    return Row(
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.upload),
          label: const Text("Seleccionar archivo"),
          onPressed: onPick,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            file != null
                ? file.path.split('/').last
                : 'Ningún archivo seleccionado',
            overflow: TextOverflow.ellipsis,
          ),
        )
      ],
    );
  }
}
