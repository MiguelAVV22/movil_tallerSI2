import 'package:flutter/material.dart';
import 'package:taller_movil/core/theme/app_colors.dart';
import 'package:taller_movil/services/vehiculo_service.dart';
import 'package:taller_movil/services/api_helper.dart';
import 'package:taller_movil/features/acceso_registro/registrar_vehiculo/registrar_vehiculo_page.dart';

class GestionarVehiculosPage extends StatefulWidget {
  const GestionarVehiculosPage({super.key});

  @override
  State<GestionarVehiculosPage> createState() => _GestionarVehiculosPageState();
}

class _GestionarVehiculosPageState extends State<GestionarVehiculosPage> {
  final _service = VehiculoService();
  late Future<List<Map<String, dynamic>>> _futureVehiculos;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() { _futureVehiculos = _service.listarVehiculos(); });
  }

  Future<void> _delete(int id, String placa) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar vehículo'),
        content: Text('¿Eliminar el vehículo con placa "$placa"?'),
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
      await _service.eliminarVehiculo(id);
      _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehículo eliminado'), backgroundColor: AppColors.success),
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

  Future<void> _editar(Map<String, dynamic> v) async {
    final id = v['id'] as int;
    final placaCtrl = TextEditingController(text: v['placa'] as String);
    final marcaCtrl = TextEditingController(text: v['marca'] as String);
    final modeloCtrl = TextEditingController(text: v['modelo'] as String);
    final anioCtrl = TextEditingController(text: '${v['anio']}');
    final colorCtrl = TextEditingController(text: v['color'] as String);
    final formKey = GlobalKey<FormState>();

    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Editar vehículo'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: placaCtrl,
                    decoration: const InputDecoration(labelText: 'Placa'),
                    textCapitalization: TextCapitalization.characters,
                  ),
                  TextFormField(controller: marcaCtrl, decoration: const InputDecoration(labelText: 'Marca')),
                  TextFormField(controller: modeloCtrl, decoration: const InputDecoration(labelText: 'Modelo')),
                  TextFormField(
                    controller: anioCtrl,
                    decoration: const InputDecoration(labelText: 'Año'),
                    keyboardType: TextInputType.number,
                    validator: (s) {
                      final n = int.tryParse(s?.trim() ?? '');
                      if (n == null || n < 1900 || n > 2100) return 'Año inválido';
                      return null;
                    },
                  ),
                  TextFormField(controller: colorCtrl, decoration: const InputDecoration(labelText: 'Color')),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            TextButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) Navigator.pop(ctx, true);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      );
      if (ok != true) return;

      await _service.actualizarVehiculo(
        id: id,
        placa: placaCtrl.text.trim().toUpperCase(),
        marca: marcaCtrl.text.trim(),
        modelo: modeloCtrl.text.trim(),
        anio: int.parse(anioCtrl.text.trim()),
        color: colorCtrl.text.trim(),
      );
      _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehículo actualizado'), backgroundColor: AppColors.success),
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
    } finally {
      placaCtrl.dispose();
      marcaCtrl.dispose();
      modeloCtrl.dispose();
      anioCtrl.dispose();
      colorCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Mis Vehículos', style: TextStyle(fontWeight: FontWeight.w700)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Agregar vehículo',
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const RegistrarVehiculoPage()));
              _reload();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const RegistrarVehiculoPage()));
          _reload();
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Agregar', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _futureVehiculos,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
                  const SizedBox(height: 12),
                  Text(snapshot.error.toString().replaceFirst('Exception: ', ''),
                    style: const TextStyle(color: AppColors.danger), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _reload, child: const Text('Reintentar')),
                ],
              ),
            );
          }
          final vehiculos = snapshot.data ?? [];
          if (vehiculos.isEmpty) {
            return _EmptyState(onAdd: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const RegistrarVehiculoPage()));
              _reload();
            });
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: vehiculos.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _VehiculoCard(
              vehiculo: vehiculos[i],
              onEdit: () => _editar(vehiculos[i]),
              onDelete: () => _delete(vehiculos[i]['id'] as int, vehiculos[i]['placa'] as String),
            ),
          );
        },
      ),
    );
  }
}

class _VehiculoCard extends StatelessWidget {
  const _VehiculoCard({required this.vehiculo, required this.onEdit, required this.onDelete});
  final Map<String, dynamic> vehiculo;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.directions_car, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${vehiculo['marca']} ${vehiculo['modelo']}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text),
                ),
                const SizedBox(height: 4),
                Row(children: [
                  _Tag(label: vehiculo['placa'] as String, color: AppColors.primary),
                  const SizedBox(width: 8),
                  _Tag(label: '${vehiculo['anio']}', color: const Color(0xFF6B7280)),
                  const SizedBox(width: 8),
                  _Tag(label: vehiculo['color'] as String, color: const Color(0xFF6B7280)),
                ]),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
            onPressed: onEdit,
            tooltip: 'Editar',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
            onPressed: onDelete,
            tooltip: 'Eliminar',
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.directions_car_outlined, size: 64, color: Color(0xFFD1D5DB)),
        const SizedBox(height: 16),
        const Text('Sin vehículos registrados',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
        const SizedBox(height: 8),
        const Text('Registra tu primer vehículo para comenzar',
          style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF))),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: const Text('Registrar vehículo'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    ),
  );
}
