import 'package:flutter/material.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class ImpresoraScreen extends StatefulWidget {
  @override
  _ImpresoraScreenState createState() => _ImpresoraScreenState();
}

class _ImpresoraScreenState extends State<ImpresoraScreen> {
  BlueThermalPrinter printer = BlueThermalPrinter.instance;
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _selectedDevice;
  bool _isLoading = true;
  bool _isConnecting = false;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _loadSavedPrinter();
    _getDevices();
    _checkConnectionStatus();
  }

  Future<void> _checkConnectionStatus() async {
    try {
      final connected = await printer.isConnected;
      setState(() {
        _isConnected = connected ?? false;
      });
    } catch (e) {
      print("Error al verificar estado de conexión: $e");
      setState(() => _isConnected = false);
    }
  }

  Future<void> _getDevices() async {
    try {
      setState(() => _isLoading = true);
      final devices = await printer.getBondedDevices();
      setState(() {
        _devices = devices;
        _isLoading = false;
      });
    } catch (e) {
      print("Error al obtener dispositivos: $e");
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error al obtener dispositivos: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadSavedPrinter() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final address = prefs.getString("printer_address");
      if (address != null) {
        final devices = await printer.getBondedDevices();
        final device = devices.firstWhere(
          (d) => d.address == address,
          orElse: () => BluetoothDevice("No encontrado", ""),
        );
        if (device.name != "No encontrado") {
          setState(() => _selectedDevice = device);
          _checkConnectionStatus();
        }
      }
    } catch (e) {
      print("Error al cargar impresora guardada: $e");
    }
  }

  Future<void> _connect(BluetoothDevice device) async {
    try {
      setState(() => _isConnecting = true);
      await printer.connect(device);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("printer_address", device.address!);
      
      // Verificar conexión después de conectar
      final connected = await printer.isConnected;
      
      setState(() {
        _selectedDevice = device;
        _isConnecting = false;
        _isConnected = connected ?? false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Conectado a ${device.name}"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _isConnecting = false;
        _isConnected = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error al conectar: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _disconnect() async {
    try {
      if (_selectedDevice != null) {
        await printer.disconnect();
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove("printer_address");
        setState(() {
          _selectedDevice = null;
          _isConnected = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Desconectado de la impresora"),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error al desconectar: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _testPrint() async {
    if (_selectedDevice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Primero selecciona una impresora"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Verificar si está conectado antes de intentar imprimir
      final connected = await printer.isConnected;
      if (!(connected ?? false)) {
        await _connect(_selectedDevice!);
      }

      String fechaFormateada = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

      // Encabezado
      await printer.printCustom("DEPOSITO", 2, 1);
      await printer.printCustom("EL JAROCHO", 2, 1);
      await printer.printNewLine();
      await printer.printCustom("=== PRUEBA DE IMPRESORA ===", 1, 1);
      await printer.printCustom("Fecha: $fechaFormateada", 1, 0);
      await printer.printNewLine();
      
      // Contenido de prueba
      await printer.printCustom("Este es un ticket de prueba", 1, 0);
      await printer.printCustom("Impresora: ${_selectedDevice!.name}", 1, 0);
      await printer.printNewLine();
      
      // Línea de prueba
      await printer.printCustom("--------------------------------", 1, 0);
      await printer.printCustom("Producto prueba x1  \$10.00", 1, 0);
      await printer.printCustom("--------------------------------", 1, 0);
      
      // Total
      await printer.printNewLine();
      await printer.printCustom("TOTAL: \$10.00", 2, 2);
      await printer.printNewLine();
      await printer.printNewLine();
      await printer.printCustom("** Impresión exitosa **", 1, 1);
      await printer.printNewLine();
      await printer.printNewLine();
      await printer.printNewLine();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Prueba de impresión enviada"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error al imprimir prueba: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildDeviceList() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Buscando dispositivos..."),
          ],
        ),
      );
    }

    if (_devices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.print_disabled, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              "No hay dispositivos vinculados",
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              "Asegúrate de haber emparejado tu impresora Bluetooth",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _getDevices,
              icon: Icon(Icons.refresh),
              label: Text("Reintentar"),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _devices.length,
      itemBuilder: (context, index) {
        final device = _devices[index];
        final isSelected = _selectedDevice?.address == device.address;
        final isConnected = isSelected && _isConnected;

        return Card(
          margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          elevation: 2,
          child: ListTile(
            leading: Icon(
              Icons.print,
              color: isConnected ? Colors.green : Colors.grey,
            ),
            title: Text(
              device.name ?? "Dispositivo sin nombre",
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Text(device.address ?? "Sin dirección"),
            trailing: _isConnecting && isSelected
                ? CircularProgressIndicator(strokeWidth: 2)
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isConnected)
                        Icon(
                          Icons.check_circle,
                          color: Colors.green,
                        ),
                      if (isSelected && !isConnected)
                        IconButton(
                          icon: Icon(Icons.refresh),
                          onPressed: () => _connect(device),
                          tooltip: "Reconectar",
                        ),
                    ],
                  ),
            onTap: () => _connect(device),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Configurar impresora"),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _getDevices,
            tooltip: "Actualizar dispositivos",
          ),
        ],
      ),
      body: Column(
        children: [
          // Estado de conexión
          if (_selectedDevice != null)
            Container(
              padding: EdgeInsets.all(16),
              color: _isConnected 
                  ? Colors.green[50] 
                  : Colors.orange[50],
              child: Row(
                children: [
                  Icon(
                    _isConnected 
                        ? Icons.check_circle 
                        : Icons.warning,
                    color: _isConnected 
                        ? Colors.green 
                        : Colors.orange,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isConnected 
                              ? "Conectado a ${_selectedDevice!.name}" 
                              : "Desconectado de ${_selectedDevice!.name}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _isConnected 
                                ? Colors.green[800] 
                                : Colors.orange[800],
                          ),
                        ),
                        if (!_isConnected)
                          Text(
                            "Toca para reconectar",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_selectedDevice != null)
                    IconButton(
                      icon: Icon(Icons.cancel),
                      onPressed: _disconnect,
                      tooltip: "Desconectar",
                      color: Colors.red,
                    ),
                ],
              ),
            ),

          // Lista de dispositivos
          Expanded(child: _buildDeviceList()),

          // Botones de acción
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              children: [
                if (_selectedDevice != null)
                  ElevatedButton.icon(
                    icon: Icon(Icons.print),
                    label: Text("Probar Impresión"),
                    onPressed: _testPrint,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, 50),
                    ),
                  ),
                SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: Icon(Icons.help_outline),
                  label: Text("Ayuda"),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text("Ayuda de configuración"),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("1. Asegúrate de que tu impresora esté encendida"),
                            Text("2. Empareja la impresora desde ajustes Bluetooth"),
                            Text("3. Selecciona tu impresora de la lista"),
                            Text("4. Usa 'Probar Impresión' para verificar"),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text("Entendido"),
                          ),
                        ],
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: Size(double.infinity, 50),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}