import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:refrescos_app/models/negocio.dart';
import 'package:refrescos_app/services/data_service.dart';

class ConfiguracionScreen extends StatefulWidget {
  @override
  _ConfiguracionScreenState createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _headerController = TextEditingController();
  final _footerController = TextEditingController();
  
  final DataService _dbService = DataService();
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final negocio = await _dbService.getNegocio();
      if (negocio != null) {
        _nombreController.text = negocio.nombreNegocio;
        _headerController.text = negocio.ticketHeader ?? '';
        _footerController.text = negocio.ticketFooter ?? '';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _guardarConfiguracion() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final negocio = Negocio(
        id: userId,
        nombreNegocio: _nombreController.text,
        ticketHeader: _headerController.text,
        ticketFooter: _footerController.text,
      );

      await _dbService.updateNegocio(negocio);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuración guardada exitosamente'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _headerController.dispose();
    _footerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración del Negocio'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Código de Proveedor
                    Card(
                      margin: const EdgeInsets.only(bottom: 24),
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tu Código de Proveedor',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E3A8A),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Comparte este código con tus clientes para que puedan vincularse a tu catálogo desde la App Cliente.',
                              style: TextStyle(color: Colors.black87),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.blue.shade200),
                                    ),
                                    child: Text(
                                      Supabase.instance.client.auth.currentUser?.id ?? 'No disponible',
                                      style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  onPressed: () {
                                    final id = Supabase.instance.client.auth.currentUser?.id;
                                    if (id != null) {
                                      Clipboard.setData(ClipboardData(text: id));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Código copiado al portapapeles'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.copy, color: Color(0xFF1E3A8A)),
                                  tooltip: 'Copiar código',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Text(
                      'Personaliza tu App y Tickets',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Estos datos aparecerán en los tickets impresos por Bluetooth.',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    
                    TextFormField(
                      controller: _nombreController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del Negocio',
                        prefixIcon: Icon(Icons.store),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'El nombre es obligatorio';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _headerController,
                      decoration: const InputDecoration(
                        labelText: 'Encabezado del Ticket (Opcional)',
                        hintText: 'Ej. ¡Bienvenido a nuestro local!',
                        prefixIcon: Icon(Icons.title),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _footerController,
                      decoration: const InputDecoration(
                        labelText: 'Pie del Ticket (Opcional)',
                        hintText: 'Ej. ¡Gracias por su compra!',
                        prefixIcon: Icon(Icons.text_snippet),
                      ),
                      maxLines: 2,
                    ),
                    
                    const SizedBox(height: 32),
                    
                    _isSaving
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton.icon(
                            icon: const Icon(Icons.save),
                            label: const Text('Guardar Configuración'),
                            onPressed: _guardarConfiguracion,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E3A8A),
                            ),
                          ),
                  ],
                ),
              ),
            ),
    );
  }
}
