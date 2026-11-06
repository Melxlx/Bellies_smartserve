import 'package:bellies_smartserve/core/app_routes.dart';
import 'package:bellies_smartserve/core/app_theme.dart';
import 'package:bellies_smartserve/models/customer_checkout_draft.dart';
import 'package:bellies_smartserve/models/order_model.dart';
import 'package:bellies_smartserve/models/product_model.dart';
import 'package:bellies_smartserve/screens/customer/customer_checkout_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CustomerDetails _details({
  String address = 'Mabini Street, Manila, Philippines',
  String name = 'Maria Santos',
  bool confirmed = true,
}) => CustomerDetails(
  name: name,
  contact: '09171234567',
  address: address,
  landmark: 'Opposite the barangay hall',
  notes: '',
  houseUnit: 'Unit 4, 12',
  latitude: 14.5764,
  longitude: 120.9821,
  locationConfirmed: confirmed,
  deliveryInstructions: 'Please ring the doorbell.',
);

List<OrderItem> _cart() => [
  OrderItem(
    product: ProductModel(
      id: 'meal-id',
      sku: 'MEAL-01',
      name: 'Chicken Meal',
      sellingPrice: 150,
      estimatedCost: 80,
      categoryId: 'category-id',
      status: ProductStatus.available,
      createdAt: DateTime(2026, 9, 15),
    ),
    quantity: 2,
  ),
];

Future<void> _pumpCheckout(
  WidgetTester tester, {
  required CustomerCheckoutDraft draft,
  required Future<OrderModel> Function(OrderModel) placeOrder,
  Future<CustomerDetails?> Function(
    BuildContext,
    CustomerDetails?,
    ValueChanged<CustomerDetails>,
  )?
  selectDeliveryAddress,
  ValueChanged<OrderModel>? onReceipt,
}) async {
  tester.view.physicalSize = const Size(1000, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: CustomerCheckoutScreen(
        cart: _cart(),
        draft: draft,
        placeOrder: placeOrder,
        selectDeliveryAddress: selectDeliveryAddress,
      ),
      onGenerateRoute: (settings) {
        expect(settings.name, AppRoutes.receipt);
        final args = settings.arguments;
        final order = args is ReceiptArguments ? args.order : (args as OrderModel);
        onReceipt?.call(order);
        return MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Saved order receipt')),
        );
      },
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String text) async {
  final target = find.text(text);
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('payment cannot submit without a confirmed delivery address', (
    tester,
  ) async {
    var submissions = 0;
    final draft = CustomerCheckoutDraft()..gcashReference = '1234567890123';
    await _pumpCheckout(
      tester,
      draft: draft,
      placeOrder: (order) async {
        submissions++;
        return order;
      },
    );

    await _tap(tester, 'PLACE ORDER & PAY');

    expect(submissions, 0);
    expect(find.text('Choose Delivery Address'), findsOneWidget);
    expect(draft.hasConfirmedAddress, isFalse);
  });

  testWidgets('coordinates alone do not count as customer confirmation', (
    tester,
  ) async {
    var submissions = 0;
    final draft = CustomerCheckoutDraft()
      ..details = _details(confirmed: false)
      ..gcashReference = '1234567890123';
    await _pumpCheckout(
      tester,
      draft: draft,
      placeOrder: (order) async {
        submissions++;
        return order;
      },
    );

    await _tap(tester, 'PLACE ORDER & PAY');

    expect(submissions, 0);
    expect(draft.hasConfirmedAddress, isFalse);
  });

  testWidgets('a confirmed point still requires recipient details', (
    tester,
  ) async {
    var submissions = 0;
    final draft = CustomerCheckoutDraft()
      ..details = _details(name: ' ')
      ..gcashReference = '1234567890123';
    await _pumpCheckout(
      tester,
      draft: draft,
      placeOrder: (order) async {
        submissions++;
        return order;
      },
    );

    await _tap(tester, 'PLACE ORDER & PAY');

    expect(submissions, 0);
    expect(draft.hasConfirmedAddress, isFalse);
  });

  testWidgets('selection appears in summary and edit receives saved details', (
    tester,
  ) async {
    final draft = CustomerCheckoutDraft();
    final first = _details();
    final edited = _details(address: 'Rizal Avenue, Manila, Philippines');
    CustomerDetails? initialOnEdit;
    var selections = 0;
    await _pumpCheckout(
      tester,
      draft: draft,
      placeOrder: (order) async => order,
      selectDeliveryAddress: (_, initial, onDraftChanged) async {
        selections++;
        if (selections == 1) {
          expect(initial, isNull);
          onDraftChanged(first);
          return first;
        }
        initialOnEdit = initial;
        onDraftChanged(edited);
        return edited;
      },
    );

    await _tap(tester, 'Choose Delivery Address');
    expect(find.textContaining(first.address), findsOneWidget);
    expect(find.text('Confirmed Delivery Address'), findsOneWidget);
    expect(draft.hasConfirmedAddress, isTrue);

    await _tap(tester, 'Edit');

    expect(initialOnEdit?.address, first.address);
    expect(draft.details?.address, edited.address);
    expect(find.textContaining(edited.address), findsOneWidget);
    expect(find.textContaining(first.address), findsNothing);
    expect(draft.details?.houseUnit, first.houseUnit);
    expect(draft.details?.deliveryInstructions, first.deliveryInstructions);
  });

  testWidgets('leaving selector with edits requires confirming them again', (
    tester,
  ) async {
    var submissions = 0;
    final draft = CustomerCheckoutDraft()
      ..details = _details()
      ..gcashReference = '1234567890123';
    final unconfirmed = _details(
      address: 'New street, Manila, Philippines',
      confirmed: false,
    );
    await _pumpCheckout(
      tester,
      draft: draft,
      placeOrder: (order) async {
        submissions++;
        return order;
      },
      selectDeliveryAddress: (_, initial, onDraftChanged) async {
        onDraftChanged(unconfirmed);
        return null;
      },
    );

    await _tap(tester, 'Edit');
    await _tap(tester, 'PLACE ORDER & PAY');

    expect(draft.details?.address, unconfirmed.address);
    expect(draft.hasConfirmedAddress, isFalse);
    expect(submissions, 0);
  });

  testWidgets('online payment cannot proceed without agreeing to terms', (
    tester,
  ) async {
    var submissions = 0;
    final details = _details();
    final draft = CustomerCheckoutDraft()
      ..details = details
      ..gcashReference = '1234567890123';
    await _pumpCheckout(
      tester,
      draft: draft,
      placeOrder: (order) async {
        submissions++;
        return order;
      },
    );

    // Try placing order without agreeing to terms
    await _tap(tester, 'PLACE ORDER & PAY');

    expect(submissions, 0);
    expect(find.text('Checkout Incomplete'), findsOneWidget);
  });

  testWidgets('order saves address snapshot and separate GCash reference', (
    tester,
  ) async {
    final details = _details();
    final draft = CustomerCheckoutDraft()
      ..details = details
      ..gcashReference = '1234567890123';
    OrderModel? submitted;
    OrderModel? receipt;
    await _pumpCheckout(
      tester,
      draft: draft,
      placeOrder: (order) async {
        submitted = order;
        return order.copyWith(id: 'saved-order-id', queueNumber: '001');
      },
      onReceipt: (order) => receipt = order,
    );

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();

    await _tap(tester, 'PLACE ORDER & PAY');

    expect(submitted, isNotNull);
    expect(submitted!.serviceType, ServiceType.delivery);
    expect(submitted!.paymentMethod, PaymentMethod.gcash);
    expect(submitted!.referenceNumber, '1234567890123');
    expect(submitted!.customerDetails?.name, details.name);
    expect(submitted!.customerDetails?.contact, details.contact);
    expect(submitted!.customerDetails?.houseUnit, details.houseUnit);
    expect(submitted!.customerDetails?.address, details.address);
    expect(submitted!.customerDetails?.latitude, details.latitude);
    expect(submitted!.customerDetails?.longitude, details.longitude);
    expect(submitted!.customerDetails?.landmark, details.landmark);
    expect(
      submitted!.customerDetails?.deliveryInstructions,
      details.deliveryInstructions,
    );
    expect(submitted!.customerDetails?.notes, isNot(contains('GCash Ref')));
    expect(submitted!.subtotal, 300);
    expect(submitted!.deliveryFee, 50);
    expect(submitted!.totalAmount, 350);
    expect(receipt?.id, 'saved-order-id');
    expect(find.text('Saved order receipt'), findsOneWidget);

    draft.details = _details(address: 'An edited address');
    expect(submitted!.customerDetails?.address, details.address);
  });

  testWidgets('failed saving preserves delivery draft and permits retry', (
    tester,
  ) async {
    var submissions = 0;
    final details = _details();
    final draft = CustomerCheckoutDraft()
      ..details = details
      ..gcashReference = '1234567890123';
    await _pumpCheckout(
      tester,
      draft: draft,
      placeOrder: (order) async {
        submissions++;
        if (submissions == 1) throw StateError('Test connection failure');
        return order.copyWith(id: 'retry-order-id');
      },
    );

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();

    await _tap(tester, 'PLACE ORDER & PAY');

    expect(submissions, 1);
    expect(draft.details?.address, details.address);
    expect(draft.gcashReference, '1234567890123');
    expect(find.text('Saved order receipt'), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);

    await _tap(tester, 'PLACE ORDER & PAY');

    expect(submissions, 2);
    expect(find.text('Saved order receipt'), findsOneWidget);
  });

  testWidgets('address and payment survive returning to menu and checkout', (
    tester,
  ) async {
    final draft = CustomerCheckoutDraft();
    final details = _details();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CustomerCheckoutScreen(
                    cart: _cart(),
                    draft: draft,
                    placeOrder: (order) async => order,
                    selectDeliveryAddress: (_, initial, onDraftChanged) async =>
                        details,
                  ),
                ),
              ),
              child: const Text('Open checkout'),
            ),
          ),
        ),
      ),
    );

    await _tap(tester, 'Open checkout');
    await _tap(tester, 'Choose Delivery Address');
    final referenceField = find.widgetWithText(
      TextFormField,
      'GCash Reference Number',
    );
    await tester.ensureVisible(referenceField);
    await tester.enterText(referenceField, '1234567890123');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Open checkout'), findsOneWidget);

    await _tap(tester, 'Open checkout');

    expect(find.textContaining(details.address), findsOneWidget);
    expect(find.text('Confirmed Delivery Address'), findsOneWidget);
    expect(find.text('1234567890123'), findsOneWidget);
    expect(draft.hasConfirmedAddress, isTrue);
  });
}
