import 'package:flutter/material.dart';
import '../../models/order_model.dart';
import '../../repositories/order_repository.dart';
import '../../widgets/state_widgets.dart';

class KitchenQueueScreen extends StatefulWidget {
  const KitchenQueueScreen({super.key});

  @override
  State<KitchenQueueScreen> createState() => _KitchenQueueScreenState();
}

class _KitchenQueueScreenState extends State<KitchenQueueScreen> {
  final _orderRepo = OrderRepository();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Current Kitchen Queue")),
      body: StreamBuilder<List<OrderModel>>(
        stream: _orderRepo.getKitchenOrdersStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return ErrorState(error: snapshot.error.toString(), onRetry: () => setState(() {}));
          if (!snapshot.hasData) return const LoadingState();

          final activeOrders = snapshot.data!;

          if (activeOrders.isEmpty) {
            return const EmptyState(message: "Kitchen queue is empty.");
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: activeOrders.length,
            itemBuilder: (context, index) {
              final order = activeOrders[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor,
                    child: Text(order.queueNumber, style: const TextStyle(color: Colors.white)),
                  ),
                  title: Text("Order #${order.id}"),
                  subtitle: Text("${order.items.length} items - ${order.serviceType.name.toUpperCase()}"),
                  trailing: _statusChip(context, order.status),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _statusChip(BuildContext context, String status) {
    Color color;
    switch (status) {
      case 'New': color = Colors.blue; break;
      case 'Preparing': color = Colors.orange; break;
      case 'Ready': color = Colors.green; break;
      default: color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha((0.1 * 255).toInt()),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(status, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}
