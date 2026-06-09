import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:taller_movil/core/theme/app_colors.dart';
import 'package:taller_movil/services/auth_service.dart';
import 'package:taller_movil/services/emergencia_service.dart';
import 'package:taller_movil/services/pago_service.dart';
import 'package:taller_movil/services/api_helper.dart';

class VerCotizacionPage extends StatefulWidget {
  const VerCotizacionPage({super.key});

  @override
  State<VerCotizacionPage> createState() => _VerCotizacionPageState();
}

class _VerCotizacionPageState extends State<VerCotizacionPage> {
  final _emergenciaSvc = EmergenciaService();
  final _pagoSvc = PagoService();
  final _authSvc = AuthService();

  List<Map<String, dynamic>> _cotizaciones = [];
  bool _loading = true;
  String _error = '';
  String _userRole = 'cliente';
  int? _expandedId;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    try {
      final user = await _authSvc.getUser();
      if (mounted) {
        setState(() {
          _userRole = user?['role'] as String? ?? 'cliente';
        });
      }
      await _cargarCotizaciones();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error de inicialización: ${e.toString()}';
          _loading = false;
        });
      }
    }
  }

  Future<void> _cargarCotizaciones() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      List<Map<String, dynamic>> list = [];
      if (_userRole == 'taller') {
        list = await _pagoSvc.listarCotizacionesTaller();
      } else {
        list = await _emergenciaSvc.listarMisCotizaciones();
      }
      if (mounted) {
        setState(() {
          _cotizaciones = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        if (e is TokenExpiradoException) {
          Navigator.pushReplacementNamed(context, '/login');
          return;
        }
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _cambiarEstado(int id, String nuevoEstado) async {
    setState(() => _loading = true);
    try {
      await _pagoSvc.actualizarEstadoCotizacion(cotizacionId: id, estado: nuevoEstado);
      _mostrarMensaje('Cotización ${nuevoEstado == 'aceptada' ? 'aceptada' : 'rechazada'} con éxito', isError: false);
      await _cargarCotizaciones();
    } catch (e) {
      setState(() => _loading = false);
      _mostrarMensaje(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _pagarCotizacion(int id, String metodo) async {
    setState(() => _loading = true);
    try {
      await _pagoSvc.realizarPago(cotizacionId: id, metodo: metodo);
      _mostrarMensaje('¡Pago registrado con éxito!', isError: false);
      await _cargarCotizaciones();
    } catch (e) {
      setState(() => _loading = false);
      _mostrarMensaje(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _mostrarMensaje(String msg, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.danger : AppColors.success,
      ),
    );
  }

  void _mostrarSelectorPago(int id) {
    showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Método de Pago', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Selecciona el método con el que deseas pagar la cotización:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'efectivo'),
            child: const Text('Efectivo', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'qr'),
            child: const Text('Código QR', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'tarjeta'),
            child: const Text('Tarjeta', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    ).then((metodo) {
      if (metodo == 'efectivo') {
        _pagarCotizacion(id, 'efectivo');
      } else if (metodo == 'qr') {
        _mostrarQrDialog(id);
      } else if (metodo == 'tarjeta') {
        _mostrarTarjetaDialog(id);
      }
    });
  }

  void _mostrarQrDialog(int id) {
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Escanea el Código QR', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Realiza el pago escaneando este código con la app de tu banco:'),
            const SizedBox(height: 16),
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Image.network(
                'https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=PagoTaller_Cotizacion_$id',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(child: Icon(Icons.qr_code, size: 100, color: Colors.grey));
                },
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Una vez transferido, confirma el pago.',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Confirmar Pago', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ).then((confirmado) {
      if (confirmado == true) {
        _pagarCotizacion(id, 'qr');
      }
    });
  }

  void _mostrarTarjetaDialog(int id) {
    final formKey = GlobalKey<FormState>();

    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Pago con Tarjeta', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Ingresa los datos de tu tarjeta de crédito o débito:'),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Número de Tarjeta',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.credit_card),
                ),
                keyboardType: TextInputType.number,
                validator: (val) => (val == null || val.length < 16) ? 'Número inválido' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'MM/AA',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.datetime,
                      validator: (val) => (val == null || val.isEmpty) ? 'Inválido' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'CVV',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      validator: (val) => (val == null || val.length < 3) ? 'Inválido' : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.pop(ctx, true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Pagar Ahora', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ).then((confirmado) {
      if (confirmado == true) {
        _pagarCotizacion(id, 'tarjeta');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Cotizaciones', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarCotizaciones,
          ),
        ],
      ),
      body: _loading && _cotizaciones.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error.isNotEmpty
              ? _buildErrorView()
              : _cotizaciones.isEmpty
                  ? _buildEmptyView()
                  : RefreshIndicator(
                      onRefresh: _cargarCotizaciones,
                      color: AppColors.primary,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _cotizaciones.length,
                        itemBuilder: (context, idx) {
                          final c = _cotizaciones[idx];
                          final id = c['id'] as int;
                          final bool isExpanded = _expandedId == id;
                          return _buildCotizacionCard(c, isExpanded);
                        },
                      ),
                    ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
            const SizedBox(height: 16),
            Text(
              _error,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.text, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _cargarCotizaciones,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.grey.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          const Text(
            'No tienes cotizaciones registradas',
            style: TextStyle(fontSize: 15, color: AppColors.grey, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildCotizacionCard(Map<String, dynamic> c, bool isExpanded) {
    final id = c['id'] as int;
    final int incidenteId = c['incidente_id'] as int;
    final double monto = (c['monto_estimado'] as num).toDouble();
    final String estado = c['estado'] as String? ?? 'pendiente';
    final String fechaRaw = c['created_at'] as String? ?? '';
    final String fecha = _formatDate(fechaRaw);

    // Parsear items desde JSON detalle
    List<dynamic> items = [];
    if (c['detalle'] != null) {
      try {
        items = jsonDecode(c['detalle'] as String) as List<dynamic>;
      } catch (_) {}
    }

    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              setState(() {
                _expandedId = isExpanded ? null : id;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.receipt_long, color: AppColors.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cotización #$id',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.text),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Incidente #$incidenteId · $fecha',
                          style: const TextStyle(color: AppColors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Bs. ${monto.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.text),
                      ),
                      const SizedBox(height: 6),
                      _buildStatusChip(estado),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Detalle de Servicios',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.text),
                  ),
                  const SizedBox(height: 10),
                  if (items.isEmpty)
                    const Text('No hay detalles registrados.', style: TextStyle(fontSize: 12, color: AppColors.grey))
                  else
                    ...items.map((it) {
                      final desc = it['descripcion'] ?? '';
                      final cant = it['cantidad'] ?? 1;
                      final precio = (it['precio_unitario'] as num?)?.toDouble() ?? 0.0;
                      final subtotal = cant * precio;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '$desc (x$cant)',
                                style: const TextStyle(fontSize: 13, color: AppColors.text),
                              ),
                            ),
                            Text(
                              'Bs. ${subtotal.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text),
                            ),
                          ],
                        ),
                      );
                    }),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Estimado',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.text),
                      ),
                      Text(
                        'Bs. ${monto.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
                      ),
                    ],
                  ),
                  
                  // Botones de acción sólo visibles para clientes
                  if (_userRole == 'cliente') ...[
                    const SizedBox(height: 20),
                    if (estado == 'pendiente') ...[
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _cambiarEstado(id, 'rechazada'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.danger,
                                side: const BorderSide(color: AppColors.danger),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('Rechazar', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _cambiarEstado(id, 'aceptada'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.success,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 0,
                              ),
                              child: const Text('Aceptar', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ] else if (estado == 'aceptada') ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _mostrarSelectorPago(id),
                          icon: const Icon(Icons.payment),
                          label: const Text('Pagar Cotización', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ] else if (estado == 'pagada') ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.check_circle_outline, color: AppColors.success, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Esta cotización ya fue pagada',
                              style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ] else if (estado == 'rechazada') ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.cancel_outlined, color: AppColors.danger, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Has rechazado esta cotización',
                              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ]
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusChip(String estado) {
    Color bg;
    Color text;
    String textLabel = estado.toUpperCase();

    switch (estado.toLowerCase()) {
      case 'pendiente':
        bg = Colors.orange.shade50;
        text = Colors.orange.shade900;
        break;
      case 'aceptada':
        bg = Colors.green.shade50;
        text = Colors.green.shade900;
        break;
      case 'rechazada':
        bg = Colors.red.shade50;
        text = Colors.red.shade900;
        break;
      case 'pagada':
        bg = Colors.blue.shade50;
        text = Colors.blue.shade900;
        textLabel = 'PAGADA';
        break;
      default:
        bg = AppColors.border;
        text = AppColors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        textLabel,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: text),
      ),
    );
  }

  String _formatDate(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoString;
    }
  }
}
