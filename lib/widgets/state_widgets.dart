import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> showErrorDialog(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.error_outline, color: Colors.red, size: 42),
      title: Text(title),
      content: Text(message, textAlign: TextAlign.center),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

class LoadingState extends StatelessWidget {
  final String? message;
  const LoadingState({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[const SizedBox(height: 16), Text(message!)],
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String message;
  final VoidCallback? onRefresh;
  const EmptyState({super.key, required this.message, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
            if (onRefresh != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text("Refresh"),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const ErrorState({super.key, required this.error, required this.onRetry});

  bool get _isNetworkError {
    final lower = error.toLowerCase();
    return lower.contains('socketexception') ||
        lower.contains('clientexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('network') ||
        lower.contains('connection');
  }

  @override
  Widget build(BuildContext context) {
    final isNet = _isNetworkError;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isNet ? Icons.wifi_off_rounded : Icons.error_outline,
              size: 64,
              color: isNet ? Colors.orange : Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              isNet ? "No Internet Connection" : "An Error Occurred",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isNet
                  ? "Please check your network connection and try again. Offline cached data is being displayed where available."
                  : error,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE91E63),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              icon: const Icon(Icons.refresh),
              label: const Text("RETRY CONNECTION"),
            ),
          ],
        ),
      ),
    );
  }
}

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.amber.shade800,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Text(
            "OFFLINE MODE — Showing locally cached data",
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class SmartBackButton extends StatelessWidget {
  final String? fallbackRoute;
  const SmartBackButton({super.key, this.fallbackRoute});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () async {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          final navigator = Navigator.of(context);
          final user = Supabase.instance.client.auth.currentUser;
          if (fallbackRoute != null) {
            navigator.pushReplacementNamed(fallbackRoute!);
            return;
          }
          if (user == null) {
            navigator.pushReplacementNamed('/');
            return;
          }
          String targetRoute = '/menu';
          try {
            final profile = await Supabase.instance.client
                .from('profiles')
                .select('role')
                .eq('id', user.id)
                .maybeSingle();
            final role = profile?['role']?.toString().toUpperCase() ?? 'GUEST';
            if (role == 'OWNER' || role == 'ADMIN') {
              targetRoute = '/staff/dashboard';
            } else if (role == 'CASHIER') {
              targetRoute = '/staff/pos';
            } else if (role == 'KITCHEN') {
              targetRoute = '/staff/kitchen';
            } else if (role == 'RIDER') {
              targetRoute = '/rider/dashboard';
            } else {
              targetRoute = '/menu';
            }
          } catch (_) {
            targetRoute = '/menu';
          }
          if (!navigator.context.mounted) return;
          navigator.pushReplacementNamed(targetRoute);
        }
      },
    );
  }
}
