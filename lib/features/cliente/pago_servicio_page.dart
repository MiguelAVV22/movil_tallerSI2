import 'package:flutter/material.dart';
import 'package:taller_movil/core/theme/app_colors.dart';
import 'package:taller_movil/services/api_helper.dart';
import 'package:taller_movil/services/api_helper.dart' show TokenExpiradoException;
import 'package:taller_movil/services/pago_service.dart';

class PagoServicioPage extends StatefulWidget {
  const PagoServicioPage({super.key, required this.incidenteId});
  final int incidenteId;

  @override
  State<PagoServicioPage> createState() => _PagoServicioPageState();
}

class _PagoServicioPageState extends State<PagoServicioPage> {
  final _pago = PagoService();
  Map<String, dynamic>? _data;
  String _metodo = 'qr';
  bool _loading = true;
  bool _paying = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final d = await _pago.resumenPago(incidenteId: widget.incidenteId);
      if (!mounted) return;
      setState(() => _data = d);
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _ejecutarPago(int cotizacionId) async {
    setState(() => _paying = true);
    try {
      await _pago.realizarPago(cotizacionId: cotizacionId, metodo: _metodo);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Pago exitoso'),
          content: const Text('El pago se registró correctamente.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Aceptar')),
          ],
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      if (e is TokenExpiradoException) {
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  void _pagar() {
    final c = _data?['cotizacion'] as Map<String, dynamic>?;
    if (c == null) return;
    final id = c['id'] as int?;
    if (id == null) return;

    if (_metodo == 'qr') {
      _mostrarQrDialog(id);
    } else if (_metodo == 'tarjeta') {
      _mostrarTarjetaDialog(id);
    } else {
      _ejecutarPago(id);
    }
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
                errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.qr_code, size: 100, color: Colors.grey)),
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
              backgroundColor: const Color(0xFF00135b),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Confirmar Pago', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ).then((confirmado) {
      if (confirmado == true) _ejecutarPago(id);
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
              if (formKey.currentState?.validate() == true) Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00135b),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Pagar Ahora', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ).then((confirmado) {
      if (confirmado == true) _ejecutarPago(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: const Color(0xFF00135b),
        foregroundColor: Colors.white,
        title: const Text('Pago del servicio', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00135b)))
          : _err != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_err!)))
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    final c = _data!['cotizacion'] as Map<String, dynamic>;
    final monto = (c['monto_estimado'] as num).toDouble();
    final desc = _data!['descripcion_incidente'] as String? ?? '—';
    final taller = _data!['taller_nombre'] as String? ?? 'Taller';
    final ya = _data!['ya_pagada'] as bool? ?? false;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _cardResumen(
                taller: taller,
                desc: desc,
                monto: monto,
              ),
              const SizedBox(height: 20),
              const Text('Método de pago', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF00135b))),
              const SizedBox(height: 8),
              _opt(
                'qr',
                'Código QR',
                'Pago rápido con SINPE Móvil',
                Icons.qr_code_2,
                const Color(0xFF5d8ce2),
              ),
              const SizedBox(height: 8),
              _opt(
                'tarjeta',
                'Tarjeta de crédito/débito',
                'Visa, Mastercard, American Express',
                Icons.credit_card,
                const Color(0xFF9CA3AF),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0FE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock, color: Color(0xFFB45309), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pago seguro: tu información está protegida con encriptación de nivel bancario.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF00135b)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: ya || _paying ? null : () => _pagar(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  disabledBackgroundColor: const Color(0xFF9CA3AF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _paying
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(ya ? 'Ya pagado' : 'Pagar ahora', style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 16)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _cardResumen({required String taller, required String desc, required double monto}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Resumen del servicio', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF00135b))),
          const SizedBox(height: 10),
          Row(
            children: [
              const CircleAvatar(backgroundColor: Color(0xFFE5E7EB), child: Icon(Icons.store, color: Color(0xFF6B7280))),
              const SizedBox(width: 10),
              Expanded(child: Text(taller, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF00135b)))),
            ],
          ),
          const SizedBox(height: 8),
          Text(desc, style: const TextStyle(color: Color(0xFF00135b))),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total a pagar', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF00135b))),
              Text(
                '₡${monto.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF00135b)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _opt(String id, String t, String s, IconData icon, Color ic) {
    final sel = _metodo == id;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _metodo = id),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: sel ? const Color(0xFF5d8ce2) : const Color(0xFFE5E7EB), width: sel ? 2 : 1),
          ),
          child: Row(
            children: [
              Icon(icon, color: ic, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF00135b))),
                    Text(s, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                  ],
                ),
              ),
              if (sel) const Icon(Icons.check_circle, color: Color(0xFF5d8ce2)),
            ],
          ),
        ),
      ),
    );
  }
}
