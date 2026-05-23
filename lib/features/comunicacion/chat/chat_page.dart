import 'dart:async';
import 'package:flutter/material.dart';
import 'package:taller_movil/core/theme/app_colors.dart';
import 'package:taller_movil/services/auth_service.dart';
import 'package:taller_movil/services/comunicacion_service.dart';
import 'package:taller_movil/services/taller_service.dart';

class ChatArgs {
  final int asignacionId;
  final String nombreContacto;
  const ChatArgs({required this.asignacionId, required this.nombreContacto});
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _svc      = ComunicacionService();
  final _tallerSvc = TallerService();
  final _auth     = AuthService();
  final _inputCtrl  = TextEditingController();
  final _scrollCtrl = ScrollController();

  // null = mostrando lista de asignaciones; !null = en chat
  ChatArgs? _args;
  String? _role;
  int? _myUserId;

  // Lista de asignaciones (pantalla de selección)
  List<AsignacionModel> _asignaciones = [];
  bool _cargandoLista = false;
  String? _errorLista;

  // Mensajes del chat
  List<MensajeModel> _mensajes = [];
  bool _cargando = true;
  bool _enviando = false;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Si nos llegan args desde otra pantalla, ir directo al chat
    if (_args == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is ChatArgs) {
        _args = args;
        _initChat();
      }
    }
  }

  Future<void> _loadUser() async {
    final user = await _auth.getUser();
    if (mounted) {
      setState(() {
        _myUserId = user?['id'] as int?;
        _role     = user?['role'] as String?;
      });
      // Si no hay args inyectados, cargar lista de asignaciones
      if (_args == null) { _cargarLista(); }
    }
  }

  Future<void> _cargarLista() async {
    if (_role == null) return;
    setState(() { _cargandoLista = true; _errorLista = null; });
    try {
      final List<AsignacionModel> lista;
      if (_role == 'cliente') {
        lista = await _tallerSvc.listarMisAsignacionesCliente();
      } else {
        lista = await _tallerSvc.listarAsignacionesActivas();
      }
      if (mounted) setState(() { _asignaciones = lista; _cargandoLista = false; });
    } catch (e) {
      if (mounted) setState(() {
        _errorLista = 'No se pudieron cargar las conversaciones.';
        _cargandoLista = false;
      });
    }
  }

  void _seleccionarAsignacion(AsignacionModel asig) {
    setState(() {
      _args = ChatArgs(
        asignacionId: asig.id,
        nombreContacto: _role == 'cliente'
            ? 'Servicio #${asig.id}'
            : 'Incidente #${asig.incidenteId}',
      );
      _cargando = true;
      _mensajes = [];
      _error = null;
    });
    _initChat();
  }

  Future<void> _initChat() async {
    if (_args == null) return;
    await _cargarMensajes();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _pollMensajes());
  }

  Future<void> _cargarMensajes() async {
    if (_args == null) return;
    try {
      final msgs = await _svc.listarMensajes(_args!.asignacionId);
      if (mounted) {
        setState(() { _mensajes = msgs; _cargando = false; _error = null; });
        _scrollAlFinal();
      }
    } catch (e) {
      if (mounted) setState(() { _cargando = false; _error = e.toString(); });
    }
  }

  Future<void> _pollMensajes() async {
    if (_args == null || !mounted) return;
    try {
      final msgs = await _svc.listarMensajes(_args!.asignacionId);
      if (mounted && msgs.length != _mensajes.length) {
        setState(() => _mensajes = msgs);
        _scrollAlFinal();
      }
    } catch (_) {}
  }

  Future<void> _enviar() async {
    final texto = _inputCtrl.text.trim();
    if (texto.isEmpty || _args == null || _enviando) return;
    setState(() => _enviando = true);
    try {
      final msg = await _svc.enviarMensaje(
        asignacionId: _args!.asignacionId,
        contenido: texto,
      );
      if (mounted) {
        setState(() { _mensajes = [..._mensajes, msg]; _enviando = false; });
        _inputCtrl.clear();
        _scrollAlFinal();
      }
    } catch (_) {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _volverALista() {
    _timer?.cancel();
    setState(() {
      _args = null;
      _mensajes = [];
      _cargando = true;
      _error = null;
    });
    _cargarLista();
  }

  void _scrollAlFinal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  bool _esMio(MensajeModel m) => m.usuarioId == _myUserId;

  String _formatTime(String iso) {
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: _args == null ? _buildLista() : _buildChat(),
    );
  }

  AppBar _buildAppBar() {
    if (_args != null) {
      return AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFF3F4F6), height: 1),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _volverALista,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_args!.nombreContacto,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.text)),
            Text('Asignación #${_args!.asignacionId}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
          ],
        ),
      );
    }
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.text,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: const Color(0xFFF3F4F6), height: 1),
      ),
      title: const Text('Conversaciones',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.text)),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: AppColors.primary),
          onPressed: _cargarLista,
        ),
      ],
    );
  }

  // ── Pantalla de selección de asignación ──────────────────
  Widget _buildLista() {
    if (_cargandoLista) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_errorLista != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.danger, size: 48),
              const SizedBox(height: 12),
              Text(_errorLista!, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.grey)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _cargarLista,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    if (_asignaciones.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.chat_bubble_outline, color: AppColors.primary, size: 32),
              ),
              const SizedBox(height: 16),
              const Text('Sin servicios activos',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
              const SizedBox(height: 6),
              const Text(
                'El chat estará disponible cuando tengas un servicio activo asignado.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.grey),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _asignaciones.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final asig = _asignaciones[i];
        return Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          child: ListTile(
            leading: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.build_outlined, color: AppColors.primary, size: 20),
            ),
            title: Text('Servicio #${asig.id}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.text)),
            subtitle: Text('Incidente #${asig.incidenteId}',
              style: const TextStyle(fontSize: 12, color: AppColors.grey)),
            trailing: _estadoBadge(asig.estado),
            onTap: () => _seleccionarAsignacion(asig),
          ),
        );
      },
    );
  }

  Widget _estadoBadge(String estado) {
    final color = switch (estado) {
      'en_camino'     => const Color(0xFF2563EB),
      'en_sitio'      => const Color(0xFF7C3AED),
      'en_reparacion' => const Color(0xFFD97706),
      'aceptado'      => const Color(0xFF16A34A),
      _               => AppColors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(estado.replaceAll('_', ' '),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }

  // ── Pantalla de chat ──────────────────────────────────────
  Widget _buildChat() {
    return Column(
      children: [
        if (_error != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFFFEF2F2),
            child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
          ),
        Expanded(
          child: _cargando
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _mensajes.isEmpty
                  ? const Center(
                      child: Text('Sin mensajes aún. ¡Escribe el primero!',
                        style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
                    )
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: _mensajes.length,
                      itemBuilder: (_, i) => _buildBubble(_mensajes[i]),
                    ),
        ),
        _buildInputBar(),
      ],
    );
  }

  Widget _buildBubble(MensajeModel m) {
    final mio = _esMio(m);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: mio ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mio) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.primary,
              child: Text(
                m.remitente.isNotEmpty ? m.remitente[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 6),
          ],
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.68),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: mio ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(mio ? 14 : 4),
                  bottomRight: Radius.circular(mio ? 4 : 14),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!mio) ...[
                    Text('${m.remitente} · ${_rolLabel(m.rol)}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                    const SizedBox(height: 2),
                  ],
                  Text(m.contenido,
                    style: TextStyle(
                      fontSize: 14,
                      color: mio ? Colors.white : AppColors.text,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(_formatTime(m.createdAt),
                    style: TextStyle(
                      fontSize: 10,
                      color: mio ? Colors.white.withValues(alpha: 0.65) : const Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (mio) const SizedBox(width: 6),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _inputCtrl,
              maxLines: null,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 14, color: AppColors.text),
              decoration: InputDecoration(
                hintText: 'Escribe un mensaje…',
                hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
              ),
              onSubmitted: (_) => _enviar(),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 44, height: 44,
            child: ElevatedButton(
              onPressed: _enviando ? null : _enviar,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _enviando
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  String _rolLabel(String rol) {
    const map = {'taller': 'Taller', 'tecnico': 'Técnico', 'cliente': 'Cliente', 'admin': 'Admin'};
    return map[rol] ?? rol;
  }
}
