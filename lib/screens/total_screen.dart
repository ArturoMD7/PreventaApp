import 'dart:io';
import 'package:flutter/material.dart';
import 'package:refrescos_app/services/data_service.dart';
import 'package:refrescos_app/services/sync_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

class TotalScreen extends StatefulWidget {
  @override
  _TotalScreenState createState() => _TotalScreenState();
}

class _TotalScreenState extends State<TotalScreen> {
  final Map<String, int> _resumenProductos = {};
  bool _isLoading = false;
  final DataService _dbService = DataService();

  @override
  void initState() {
    super.initState();
    _cargarResumen();
  }

  Future<void> _sincronizarYCargar() async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              SizedBox(width: 12),
              Text('Sincronizando con servidor...'),
            ],
          ),
          duration: Duration(seconds: 3),
        ),
      );
    }
    await SyncService().syncAll();
    await _cargarResumen();
  }

  Future<void> _cargarResumen() async {
    setState(() => _isLoading = true);
    try {
      final ventas = await _dbService.getVentas();
      final ventasPendientes = ventas.where((v) => v.estado == 'pendiente').toList();
      
      final resumen = <String, int>{};

      for (var venta in ventasPendientes) {
        final detalles = await _dbService.getDetallesVenta(venta.id!);
        for (var detalle in detalles) {
          final nombre = detalle.productoNombre ?? 'Desconocido';
          resumen[nombre] = (resumen[nombre] ?? 0) + detalle.cantidad;
        }
      }

      // Ordenar por cantidad descendente
      final sortedResumen = Map.fromEntries(
        resumen.entries.toList()..sort((e1, e2) => e2.value.compareTo(e1.value))
      );

      setState(() {
        _resumenProductos.clear();
        _resumenProductos.addAll(sortedResumen);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generarYCompartirPDF() async {
    setState(() => _isLoading = true);

    try {
      final negocio = await _dbService.getNegocio();
      
      final pdf = pw.Document();
      final fecha = DateTime.now();
      final fechaFormateada =
          '${fecha.day}/${fecha.month}/${fecha.year} ${fecha.hour}:${fecha.minute.toString().padLeft(2, '0')}';

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(
                    negocio?.nombreNegocio ?? 'MI NEGOCIO',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Center(
                  child: pw.Text(
                    'Resumen de Productos Pendientes',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Center(
                  child: pw.Text(
                    'Fecha: $fechaFormateada',
                    style: pw.TextStyle(fontSize: 12),
                  ),
                ),
                pw.SizedBox(height: 15),
                pw.Table.fromTextArray(
                  context: context,
                  border: null,
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFFE3F2FD),
                  ),
                  cellAlignment: pw.Alignment.centerLeft,
                  headerAlignment: pw.Alignment.centerLeft,
                  data: [
                    ['Producto', 'Cantidad'],
                    ..._resumenProductos.entries
                        .map((entry) => [entry.key, '${entry.value} unidades'])
                        .toList(),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Total: ${_resumenProductos.values.fold(0, (sum, item) => sum + item)} unidades',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );

      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}/resumen_pendientes_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File(path);
      await file.writeAsBytes(await pdf.save());

      if (!mounted) return;
      _mostrarOpcionesPDF(path);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al generar PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _mostrarOpcionesPDF(String path) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('PDF Generado'),
        content: const Text('¿Qué deseas hacer con el archivo?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _abrirArchivo(path);
            },
            child: const Text('Abrir'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _mostrarRutaArchivo(path);
            },
            child: const Text('Ver ubicación'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _compartirArchivo(path);
            },
            child: const Text('Compartir'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  void _abrirArchivo(String path) async {
    final file = File(path);
    final bytes = await file.readAsBytes();
    await Printing.layoutPdf(onLayout: (_) => bytes);
  }

  void _compartirArchivo(String path) {
    Share.shareXFiles([XFile(path)],
        text: 'Resumen de productos pendientes');
  }

  void _mostrarRutaArchivo(String path) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ubicación del PDF'),
        content: SelectableText('Archivo guardado en:\n$path'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Total Productos Pendientes'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _sincronizarYCargar,
            tooltip: 'Sincronizar y actualizar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _sincronizarYCargar,
              child: _resumenProductos.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2,
                              size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          const Text(
                            'No hay productos pendientes',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          color: Colors.blue[50],
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total:',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                '${_resumenProductos.values.fold(0, (sum, item) => sum + item)} unidades',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView(
                            children: _resumenProductos.entries.map((entry) {
                              return Card(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                child: ListTile(
                                  title: Text(entry.key,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w500)),
                                  trailing: Text(
                                    '${entry.value} unidades',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[700],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
            ),
      floatingActionButton: _resumenProductos.isNotEmpty
          ? FloatingActionButton(
              onPressed: _generarYCompartirPDF,
              backgroundColor: Colors.blue[700],
              tooltip: 'Generar PDF',
              child: const Icon(Icons.picture_as_pdf),
            )
          : null,
    );
  }
}
