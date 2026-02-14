import 'dart:io';
import 'package:flutter/material.dart';
import 'package:refrescos_app/database/database_helper.dart';
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

  @override
  void initState() {
    super.initState();
    _cargarResumen();
  }

  Future<void> _cargarResumen() async {
    final dbHelper = DatabaseHelper();
    final query = '''
      SELECT p.nombre, SUM(dv.cantidad) as total
      FROM detalles_venta dv
      JOIN productos p ON dv.producto_id = p.id
      JOIN ventas v ON dv.venta_id = v.id
      WHERE v.estado = 'pendiente'
      GROUP BY p.id
      ORDER BY total DESC
    ''';

    final results = await dbHelper.database.then((db) => db.rawQuery(query));
    final resumen = <String, int>{};

    for (var row in results) {
      resumen[row['nombre'] as String] = row['total'] as int;
    }

    setState(() {
      _resumenProductos.clear();
      _resumenProductos.addAll(resumen);
    });
  }

  Future<void> _generarYCompartirPDF() async {
    setState(() => _isLoading = true);

    try {
      // Crear el PDF
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
                    'DEPOSITO EL JAROCHO',
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
                  headerDecoration: pw.BoxDecoration(
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

      // Guardar PDF
      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}/resumen_pendientes_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File(path);
      await file.writeAsBytes(await pdf.save());

      // Mostrar opciones
      _mostrarOpcionesPDF(path);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al generar PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _mostrarOpcionesPDF(String path) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('PDF Generado'),
        content: Text('¿Qué deseas hacer con el archivo?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _abrirArchivo(path);
            },
            child: Text('Abrir'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _mostrarRutaArchivo(path);
            },
            child: Text('Ver ubicación'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _compartirArchivo(path);
            },
            child: Text('Compartir'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
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
        title: Text('Ubicación del PDF'),
        content: SelectableText('Archivo guardado en:\n$path'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Total Productos Pendientes'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _cargarResumen,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargarResumen,
              child: _resumenProductos.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2,
                              size: 64, color: Colors.grey[300]),
                          SizedBox(height: 16),
                          Text(
                            'No hay productos pendientes',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        Container(
                          padding: EdgeInsets.all(16),
                          color: Colors.blue[50],
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
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
                                margin: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                child: ListTile(
                                  title: Text(entry.key,
                                      style: TextStyle(
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
              child: Icon(Icons.picture_as_pdf),
              backgroundColor: Colors.blue[700],
              tooltip: 'Generar PDF',
            )
          : null,
    );
  }
}
