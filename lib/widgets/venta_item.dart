import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:refrescos_app/models/venta.dart';

// En venta_item.dart, actualiza el widget para incluir la acción de descartar
class VentaItem extends StatelessWidget {
  final Venta venta;
  final VoidCallback onCambiarEstado;
  final VoidCallback onVerDetalles;
  final VoidCallback? onDescartar;

  const VentaItem({
    Key? key,
    required this.venta,
    required this.onCambiarEstado,
    required this.onVerDetalles,
    this.onDescartar,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: venta.estado == 'descartado' ? Colors.grey[200] : null,
      child: ListTile(
        leading: Icon(
          venta.estado == 'entregado' ? Icons.check_circle : 
          venta.estado == 'pendiente' ? Icons.pending_actions :
          Icons.archive,
          color: venta.estado == 'entregado' ? Colors.green : 
                venta.estado == 'pendiente' ? Colors.orange :
                Colors.grey,
        ),
        title: Text(venta.clienteNombre ?? 'Cliente no especificado'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total: \$${venta.total.toStringAsFixed(2)}'),
            Text('Fecha: ${DateFormat('dd/MM/yy HH:mm').format(venta.fecha)}'),
            Text('Estado: ${venta.estado}'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onDescartar != null)
              IconButton(
                icon: Icon(Icons.archive, color: Colors.orange),
                onPressed: onDescartar,
                tooltip: 'Descartar ticket',
              ),
            IconButton(
              icon: Icon(Icons.remove_red_eye, color: Colors.blue),
              onPressed: onVerDetalles,
              tooltip: 'Ver detalles',
            ),
            IconButton(
              icon: Icon(
                venta.estado == 'entregado' ? Icons.undo : Icons.check,
                color: venta.estado == 'entregado' ? Colors.orange : Colors.green,
              ),
              onPressed: onCambiarEstado,
              tooltip: venta.estado == 'entregado' ? 'Marcar como pendiente' : 'Marcar como entregado',
            ),
          ],
        ),
      ),
    );
  }
}