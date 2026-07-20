import 'package:flutter/material.dart';
import 'package:taller_movil/core/theme/app_colors.dart';
import 'package:taller_movil/services/sos_service.dart';
import 'package:taller_movil/services/api_helper.dart';

class GestionarContactosSosPage extends StatefulWidget {
  const GestionarContactosSosPage({super.key});

  @override
  State<GestionarContactosSosPage> createState() => _GestionarContactosSosPageState();
}

class _GestionarContactosSosPageState extends State<GestionarContactosSosPage> {
  final _service = SosService();
  late Future<List<Map<String, dynamic>>> _futureContactos;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _futureContactos = _service.listarContactos();
    });
  }

  Future<void> _eliminar(int id, String nombre) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar contacto'),
        content: Text('¿Eliminar a $nombre de tus contactos de emergencia?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _service.eliminarContacto(id);
      _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contacto eliminado'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (e is TokenExpiradoException) {
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppColors.danger),
      );
    }
  }

  Future<void> _agregarContacto() async {
    final nombreCtrl = TextEditingController();
    final telefonoCtrl = TextEditingController();
    final relacionCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo Contacto SOS'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre *', hintText: 'Ej. Mamá'),
                  validator: (s) => s?.trim().isEmpty == true ? 'Campo obligatorio' : null,
                ),
                TextFormField(
                  controller: telefonoCtrl,
                  decoration: const InputDecoration(labelText: 'Teléfono *', hintText: 'Ej. 73690995'),
                  keyboardType: TextInputType.phone,
                  validator: (s) => s?.trim().isEmpty == true ? 'Campo obligatorio' : null,
                ),
                TextFormField(
                  controller: relacionCtrl,
                  decoration: const InputDecoration(labelText: 'Relación / Parentesco', hintText: 'Ej. mamá, hermano, amigo'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await _service.registrarContacto(
        nombre: nombreCtrl.text.trim(),
        telefono: telefonoCtrl.text.trim(),
        relacion: relacionCtrl.text.trim().isEmpty ? 'contacto' : relacionCtrl.text.trim(),
      );
      _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contacto agregado'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (e is TokenExpiradoException) {
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Contactos de Emergencia SOS', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.primary),
            onPressed: _agregarContacto,
          )
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _futureContactos,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (snapshot.hasError) {
            final err = snapshot.error;
            if (err is TokenExpiradoException) {
              Future.microtask(() => Navigator.pushReplacementNamed(context, '/login'));
              return const SizedBox();
            }
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
                    const SizedBox(height: 12),
                    Text(
                      err.toString().replaceFirst('Exception: ', ''),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF4B5563)),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _reload, child: const Text('Reintentar')),
                  ],
                ),
              ),
            );
          }

          final list = snapshot.data ?? [];
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.contact_phone_outlined, size: 64, color: Color(0xFFD1D5DB)),
                    const SizedBox(height: 16),
                    const Text(
                      'No tienes contactos SOS',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Agrega familiares o amigos para poder alertarles vía WhatsApp o SMS en caso de una emergencia.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _agregarContacto,
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar Contacto'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            itemCount: list.length,
            itemBuilder: (ctx, index) {
              final c = list[index];
              final String nombre = c['nombre'] ?? '';
              final String telefono = c['telefono'] ?? '';
              final String relacion = c['relacion'] ?? 'contacto';

              return Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 0.5,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.contact_phone, color: AppColors.danger),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  nombre,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.text),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    relacion,
                                    style: const TextStyle(fontSize: 10, color: Color(0xFF4B5563), fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              telefono,
                              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                        onPressed: () => _eliminar(c['id'] as int, nombre),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
