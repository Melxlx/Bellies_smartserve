import '../models/user_model.dart';
import '../models/product_model.dart';
import '../models/order_model.dart';
import '../models/ingredient_model.dart';
import '../models/inventory_movement_model.dart';
import '../models/attendance_model.dart';

class SampleData {
  static List<OrderModel> kitchenQueue = [];
  static List<OrderModel> completedOrders = [];
  static List<AttendanceModel> attendanceList = [];
  
  static List<UserModel> employees = [
    UserModel(
      id: 'EMP001',
      email: 'owner@bellies.com',
      fullName: 'Bellie Owner',
      position: 'Owner',
      role: UserRole.owner,
      accountStatus: AccountStatus.active,
    ),
    UserModel(
      id: 'EMP002',
      email: 'staff@bellies.com',
      fullName: 'Sample Cashier',
      position: 'Staff',
      role: UserRole.cashier,
      accountStatus: AccountStatus.active,
    ),
  ];

  static List<IngredientModel> inventory = [
    IngredientModel(id: 'I001', code: 'RICE-001', name: 'Rice Grains (Sinandomeng)', category: 'Grains', unit: IngredientUnit.kilogram, currentQuantity: 50, reorderLevel: 10, averageUnitCost: 52, lastUpdated: DateTime.now()),
    IngredientModel(id: 'I002', code: 'EGG-001', name: 'Eggs (Large)', category: 'Poultry', unit: IngredientUnit.piece, currentQuantity: 120, reorderLevel: 30, averageUnitCost: 7, lastUpdated: DateTime.now()),
    IngredientModel(id: 'I003', code: 'MEAT-001', name: 'Marinated Beef Tapa', category: 'Meat', unit: IngredientUnit.kilogram, currentQuantity: 15, reorderLevel: 5, averageUnitCost: 280, lastUpdated: DateTime.now()),
    IngredientModel(id: 'I004', code: 'MEAT-002', name: 'Sweet Pork Tocino', category: 'Meat', unit: IngredientUnit.kilogram, currentQuantity: 3, reorderLevel: 5, averageUnitCost: 240, lastUpdated: DateTime.now()),
    IngredientModel(id: 'I005', code: 'MEAT-003', name: 'Chicken Meat', category: 'Poultry', unit: IngredientUnit.kilogram, currentQuantity: 20, reorderLevel: 5, averageUnitCost: 180, lastUpdated: DateTime.now()),
    IngredientModel(id: 'I006', code: 'MEAT-004', name: 'Jumbo Hotdogs', category: 'Meat', unit: IngredientUnit.piece, currentQuantity: 0, reorderLevel: 15, averageUnitCost: 12, lastUpdated: DateTime.now()),
    IngredientModel(id: 'I007', code: 'NOOD-001', name: 'Korean Jin Ramen Packs', category: 'Noodles', unit: IngredientUnit.pack, currentQuantity: 40, reorderLevel: 10, averageUnitCost: 45, lastUpdated: DateTime.now()),
    IngredientModel(id: 'I008', code: 'NOOD-002', name: 'Buldak Carbonara Packs', category: 'Noodles', unit: IngredientUnit.pack, currentQuantity: 25, reorderLevel: 10, averageUnitCost: 55, lastUpdated: DateTime.now()),
    IngredientModel(id: 'I009', code: 'OIL-001', name: 'Cooking Oil', category: 'Oil & Fats', unit: IngredientUnit.liter, currentQuantity: 10, reorderLevel: 3, averageUnitCost: 90, lastUpdated: DateTime.now()),
    IngredientModel(id: 'I010', code: 'SPICE-001', name: 'Garlic & Seasonings', category: 'Seasoning', unit: IngredientUnit.kilogram, currentQuantity: 8, reorderLevel: 2, averageUnitCost: 120, lastUpdated: DateTime.now()),
  ];

  static List<InventoryMovementModel> inventoryHistory = [];

  static const List<String> categories = [
    'Lugaw',
    'Ulam Meals',
    'Pancit & Noodles',
    'Silog Meals',
    'Student Meals',
    'Korean Noodles',
    'Pares & Mami',
    'Merienda sa Hapon',
    'Drinks & Coffee',
    'Add-ons',
  ];

  static List<ProductModel> products = [
    // LUGAW
    ProductModel(id: 'P001', sku: 'L-PLN', name: 'Plain Lugaw', categoryId: 'Lugaw', sellingPrice: 30.0, estimatedCost: 12.0, status: ProductStatus.available, createdAt: DateTime.now(), imagePath: 'assets/images/Lugaw.png'),
    ProductModel(id: 'P002', sku: 'L-EGG', name: 'Lugaw with Egg', categoryId: 'Lugaw', sellingPrice: 40.0, estimatedCost: 18.0, status: ProductStatus.available, createdAt: DateTime.now(), imagePath: 'assets/images/Lugaw.png'),
    ProductModel(id: 'P003', sku: 'L-GOTO', name: 'Goto', categoryId: 'Lugaw', sellingPrice: 50.0, estimatedCost: 22.0, status: ProductStatus.available, createdAt: DateTime.now(), imagePath: 'assets/images/Lugaw.png'),
    ProductModel(id: 'P004', sku: 'L-OVR', name: 'Lugaw Overload', categoryId: 'Lugaw', sellingPrice: 85.0, estimatedCost: 40.0, status: ProductStatus.available, createdAt: DateTime.now(), imagePath: 'assets/images/Lugaw.png'),

    // ULAM MEALS
    ProductModel(id: 'P101', sku: 'U-ADOB', name: 'Adobo', categoryId: 'Ulam Meals', sellingPrice: 185.0, estimatedCost: 90.0, status: ProductStatus.available, createdAt: DateTime.now(), imagePath: 'assets/images/tapsilog.png'),
    ProductModel(id: 'P102', sku: 'U-BCW', name: 'Buttered Chicken Wings', categoryId: 'Ulam Meals', sellingPrice: 185.0, estimatedCost: 95.0, status: ProductStatus.available, createdAt: DateTime.now(), imagePath: 'assets/images/chicksilog.png'),
    ProductModel(id: 'P103', sku: 'U-IBW', name: 'Improved Buffalo Wings', categoryId: 'Ulam Meals', sellingPrice: 185.0, estimatedCost: 95.0, status: ProductStatus.available, createdAt: DateTime.now(), imagePath: 'assets/images/chicksilog.png'),
    ProductModel(id: 'P104', sku: 'U-TKC', name: 'Torta kon Carne', categoryId: 'Ulam Meals', sellingPrice: 95.0, estimatedCost: 45.0, status: ProductStatus.available, createdAt: DateTime.now(), imagePath: 'assets/images/tapsilog.png'),
    ProductModel(id: 'P105', sku: 'U-SSF', name: 'Sweet & Sour Fish Fillet', categoryId: 'Ulam Meals', sellingPrice: 200.0, estimatedCost: 100.0, status: ProductStatus.available, createdAt: DateTime.now(), imagePath: 'assets/images/tapsilog.png'),
    ProductModel(id: 'P106', sku: 'U-SSG', name: 'Sisig Barkada (2-3 pax)', categoryId: 'Ulam Meals', sellingPrice: 120.0, estimatedCost: 60.0, status: ProductStatus.available, createdAt: DateTime.now(), imagePath: 'assets/images/tapsilog.png'),

    // PANCIT & NOODLES
    ProductModel(id: 'P201', sku: 'PN-BIH', name: 'Pancit Bihon', categoryId: 'Pancit & Noodles', sellingPrice: 95.0, estimatedCost: 45.0, status: ProductStatus.available, createdAt: DateTime.now(), imagePath: 'assets/images/korean_noodles.png'),
    ProductModel(id: 'P202', sku: 'PN-CAN', name: 'Pancit Canton', categoryId: 'Pancit & Noodles', sellingPrice: 110.0, estimatedCost: 55.0, status: ProductStatus.available, createdAt: DateTime.now(), imagePath: 'assets/images/korean_noodles.png'),
    ProductModel(id: 'P203', sku: 'PN-MIK', name: 'Pancit Miki', categoryId: 'Pancit & Noodles', sellingPrice: 100.0, estimatedCost: 50.0, status: ProductStatus.available, createdAt: DateTime.now(), imagePath: 'assets/images/korean_noodles.png'),
    ProductModel(id: 'P204', sku: 'PN-BIL', name: 'Large Bihon Bilao', categoryId: 'Pancit & Noodles', sellingPrice: 800.0, estimatedCost: 400.0, status: ProductStatus.available, createdAt: DateTime.now(), imagePath: 'assets/images/korean_noodles.png'),

    // SILOG MEALS
    ProductModel(id: 'P301', sku: 'S-TAP', name: 'Tapsilog', categoryId: 'Silog Meals', sellingPrice: 90.0, estimatedCost: 45.0, status: ProductStatus.available, createdAt: DateTime.now(), imagePath: 'assets/images/tapsilog.png'),
    ProductModel(id: 'P302', sku: 'S-CHK', name: 'Chicksilog', categoryId: 'Silog Meals', sellingPrice: 85.0, estimatedCost: 42.0, status: ProductStatus.available, createdAt: DateTime.now(), imagePath: 'assets/images/chicksilog.png'),
    ProductModel(id: 'P303', sku: 'S-BNG', name: 'Bangsilog', categoryId: 'Silog Meals', sellingPrice: 90.0, estimatedCost: 45.0, status: ProductStatus.available, createdAt: DateTime.now(), imagePath: 'assets/images/tapsilog.png'),
    ProductModel(id: 'P304', sku: 'S-SPM', name: 'Spamsilog', categoryId: 'Silog Meals', sellingPrice: 70.0, estimatedCost: 35.0, status: ProductStatus.available, createdAt: DateTime.now(), imagePath: 'assets/images/tapsilog.png'),
    ProductModel(id: 'P305', sku: 'S-TOC', name: 'Tocilog', categoryId: 'Silog Meals', sellingPrice: 85.0, estimatedCost: 40.0, status: ProductStatus.available, createdAt: DateTime.now(), imagePath: 'assets/images/tocilog.png'),
    ProductModel(id: 'P306', sku: 'S-CRN', name: 'Corned Beef Silog', categoryId: 'Silog Meals', sellingPrice: 60.0, estimatedCost: 28.0, status: ProductStatus.available, createdAt: DateTime.now(), imagePath: 'assets/images/tapsilog.png'),
    ProductModel(id: 'P307', sku: 'S-HOT', name: 'Hotsilog', categoryId: 'Silog Meals', sellingPrice: 55.0, estimatedCost: 25.0, status: ProductStatus.available, createdAt: DateTime.now(), imagePath: 'assets/images/hotsilog.png'),
    ProductModel(id: 'P308', sku: 'S-SSG', name: 'Sisigsilog', categoryId: 'Silog Meals', sellingPrice: 90.0, estimatedCost: 45.0, status: ProductStatus.available, createdAt: DateTime.now(), imagePath: 'assets/images/tapsilog.png'),
    ProductModel(id: 'P309', sku: 'S-HUN', name: 'Hungarian Silog', categoryId: 'Silog Meals', sellingPrice: 85.0, estimatedCost: 42.0, status: ProductStatus.available, createdAt: DateTime.now(), imagePath: 'assets/images/tapsilog.png'),
    ProductModel(id: 'P310', sku: 'S-BOL', name: 'Bologna Silog (3 pcs)', categoryId: 'Silog Meals', sellingPrice: 85.0, estimatedCost: 40.0, status: ProductStatus.available, createdAt: DateTime.now(), imagePath: 'assets/images/tapsilog.png'),
    ProductModel(id: 'P311', sku: 'S-PRK', name: 'Porksilog', categoryId: 'Silog Meals', sellingPrice: 90.0, estimatedCost: 45.0, status: ProductStatus.available, createdAt: DateTime.now(), imagePath: 'assets/images/tapsilog.png'),

    // STUDENT MEALS
    ProductModel(id: 'P401', sku: 'ST-PAS', name: 'Pastilog', categoryId: 'Student Meals', sellingPrice: 65.0, estimatedCost: 30.0, status: ProductStatus.available, createdAt: DateTime.now(), imagePath: 'assets/images/tapsilog.png'),
    ProductModel(id: 'P402', sku: 'ST-SIO', name: 'Fried Siomai Silog (3)', categoryId: 'Student Meals', sellingPrice: 55.0, estimatedCost: 25.0, status: ProductStatus.available, createdAt: DateTime.now(), imagePath: 'assets/images/tapsilog.png'),

    // KOREAN NOODLES
    ProductModel(id: 'P501', sku: 'K-JIN-S', name: 'Jin Ramen (Spicy)', categoryId: 'Korean Noodles', sellingPrice: 80.0, estimatedCost: 40.0, status: ProductStatus.available, createdAt: DateTime.now(), imagePath: 'assets/images/korean_noodles.png'),
    ProductModel(id: 'P502', sku: 'K-BUL-C', name: 'Buldak Carbonara', categoryId: 'Korean Noodles', sellingPrice: 105.0, estimatedCost: 52.0, status: ProductStatus.available, createdAt: DateTime.now(), imagePath: 'assets/images/korean_noodles.png'),
    ProductModel(id: 'P503', sku: 'K-BUL-CH', name: 'Buldak Cheese', categoryId: 'Korean Noodles', sellingPrice: 105.0, estimatedCost: 52.0, status: ProductStatus.available, createdAt: DateTime.now(), imagePath: 'assets/images/korean_noodles.png'),
    ProductModel(id: 'P504', sku: 'K-JIN-M', name: 'Jin Ramen Mild', categoryId: 'Korean Noodles', sellingPrice: 80.0, estimatedCost: 40.0, status: ProductStatus.available, createdAt: DateTime.now(), imagePath: 'assets/images/korean_noodles.png'),
    ProductModel(id: 'P505', sku: 'K-BULG', name: 'Bulgogi', categoryId: 'Korean Noodles', sellingPrice: 105.0, estimatedCost: 52.0, status: ProductStatus.available, createdAt: DateTime.now(), imagePath: 'assets/images/korean_noodles.png'),
    ProductModel(id: 'P506', sku: 'K-SHIN', name: 'Shin Ramyun', categoryId: 'Korean Noodles', sellingPrice: 90.0, estimatedCost: 45.0, status: ProductStatus.available, createdAt: DateTime.now(), imagePath: 'assets/images/korean_noodles.png'),

    // PARES & MAMI
    ProductModel(id: 'P601', sku: 'PM-PAR', name: 'Pares', categoryId: 'Pares & Mami', sellingPrice: 50.0, estimatedCost: 25.0, status: ProductStatus.available, createdAt: DateTime.now(), imagePath: 'assets/images/tapsilog.png'),
    ProductModel(id: 'P602', sku: 'PM-PAR-R', name: 'Pares with Rice', categoryId: 'Pares & Mami', sellingPrice: 60.0, estimatedCost: 30.0, status: ProductStatus.available, createdAt: DateTime.now(), imagePath: 'assets/images/tapsilog.png'),
    ProductModel(id: 'P603', sku: 'PM-MAM', name: 'Mami', categoryId: 'Pares & Mami', sellingPrice: 45.0, estimatedCost: 20.0, status: ProductStatus.available, createdAt: DateTime.now(), imagePath: 'assets/images/korean_noodles.png'),
    ProductModel(id: 'P604', sku: 'PM-MAM-R', name: 'Mami with Rice', categoryId: 'Pares & Mami', sellingPrice: 55.0, estimatedCost: 25.0, status: ProductStatus.available, createdAt: DateTime.now(), imagePath: 'assets/images/korean_noodles.png'),

    // MERIENDA SA HAPON
    ProductModel(id: 'P701', sku: 'M-FR-SOL', name: 'Fries Solo', categoryId: 'Merienda sa Hapon', sellingPrice: 45.0, estimatedCost: 20.0, status: ProductStatus.available, createdAt: DateTime.now(), imagePath: 'assets/images/fries.png'),
    ProductModel(id: 'P702', sku: 'M-FR-SHR', name: 'Fries for Sharing', categoryId: 'Merienda sa Hapon', sellingPrice: 85.0, estimatedCost: 40.0, status: ProductStatus.available, createdAt: DateTime.now(), imagePath: 'assets/images/fries.png'),
    ProductModel(id: 'P703', sku: 'M-BAR', name: 'Barkada Meal', categoryId: 'Merienda sa Hapon', sellingPrice: 135.0, estimatedCost: 65.0, status: ProductStatus.available, createdAt: DateTime.now(), imagePath: 'assets/images/chicksilog.png'),
    ProductModel(id: 'P704', sku: 'M-CHK-FR', name: 'Chicken Tenders with Fries', categoryId: 'Merienda sa Hapon', sellingPrice: 95.0, estimatedCost: 45.0, status: ProductStatus.available, createdAt: DateTime.now(), imagePath: 'assets/images/chicksilog.png'),
    ProductModel(id: 'P705', sku: 'M-SHNG', name: 'Shanghai', categoryId: 'Merienda sa Hapon', sellingPrice: 15.0, estimatedCost: 7.0, status: ProductStatus.available, createdAt: DateTime.now(), imagePath: 'assets/images/tapsilog.png'),

    // DRINKS & COFFEE
    ProductModel(id: 'P801', sku: 'D-WAT', name: 'Bottled Water', categoryId: 'Drinks & Coffee', sellingPrice: 15.0, estimatedCost: 8.0, status: ProductStatus.available, createdAt: DateTime.now(), imagePath: 'assets/images/fries.png'),
    ProductModel(id: 'P802', sku: 'D-CUC', name: 'Cucumber Pitcher', categoryId: 'Drinks & Coffee', sellingPrice: 65.0, estimatedCost: 25.0, status: ProductStatus.available, createdAt: DateTime.now(), imagePath: 'assets/images/fries.png'),
    ProductModel(id: 'P803', sku: 'D-15C', name: '1.5 L Coke', categoryId: 'Drinks & Coffee', sellingPrice: 85.0, estimatedCost: 60.0, status: ProductStatus.available, createdAt: DateTime.now(), imagePath: 'assets/images/fries.png'),
    ProductModel(id: 'P804', sku: 'D-COK-M', name: 'Coke Mismo', categoryId: 'Drinks & Coffee', sellingPrice: 25.0, estimatedCost: 15.0, status: ProductStatus.available, createdAt: DateTime.now(), imagePath: 'assets/images/fries.png'),
    ProductModel(id: 'P805', sku: 'D-SPR', name: 'Sprite', categoryId: 'Drinks & Coffee', sellingPrice: 25.0, estimatedCost: 15.0, status: ProductStatus.available, createdAt: DateTime.now(), imagePath: 'assets/images/fries.png'),
    ProductModel(id: 'P806', sku: 'D-ROY', name: 'Royal', categoryId: 'Drinks & Coffee', sellingPrice: 25.0, estimatedCost: 15.0, status: ProductStatus.available, createdAt: DateTime.now(), imagePath: 'assets/images/fries.png'),
    ProductModel(id: 'P807', sku: 'D-LAT', name: 'Spanish Latte', categoryId: 'Drinks & Coffee', sellingPrice: 69.0, estimatedCost: 30.0, status: ProductStatus.available, createdAt: DateTime.now(), imagePath: 'assets/images/fries.png'),
    ProductModel(id: 'P808', sku: 'D-AME', name: 'Americano (pure beans)', categoryId: 'Drinks & Coffee', sellingPrice: 75.0, estimatedCost: 35.0, status: ProductStatus.available, createdAt: DateTime.now(), imagePath: 'assets/images/fries.png'),
    ProductModel(id: 'P809', sku: 'D-MAT', name: 'Matcha', categoryId: 'Drinks & Coffee', sellingPrice: 59.0, estimatedCost: 25.0, status: ProductStatus.available, createdAt: DateTime.now(), imagePath: 'assets/images/fries.png'),

    // ADD-ONS
    ProductModel(id: 'P901', sku: 'A-EGG', name: 'Boiled Egg', categoryId: 'Add-ons', sellingPrice: 10.0, estimatedCost: 5.0, status: ProductStatus.available, createdAt: DateTime.now(), imagePath: 'assets/images/Lugaw.png'),
    ProductModel(id: 'P902', sku: 'A-TKW', name: 'Tokwa', categoryId: 'Add-ons', sellingPrice: 15.0, estimatedCost: 7.0, status: ProductStatus.available, createdAt: DateTime.now(), imagePath: 'assets/images/Lugaw.png'),
    ProductModel(id: 'P903', sku: 'A-TOG', name: 'Lumpiang Toge', categoryId: 'Add-ons', sellingPrice: 20.0, estimatedCost: 10.0, status: ProductStatus.available, createdAt: DateTime.now(), imagePath: 'assets/images/Lugaw.png'),
    ProductModel(id: 'P904', sku: 'A-GYO', name: 'Gyoza', categoryId: 'Add-ons', sellingPrice: 10.0, estimatedCost: 5.0, status: ProductStatus.available, createdAt: DateTime.now(), imagePath: 'assets/images/korean_noodles.png'),
    ProductModel(id: 'P905', sku: 'A-CHS', name: 'Cheese', categoryId: 'Add-ons', sellingPrice: 15.0, estimatedCost: 7.0, status: ProductStatus.available, createdAt: DateTime.now(), imagePath: 'assets/images/korean_noodles.png'),
    ProductModel(id: 'P906', sku: 'A-CRB', name: 'Crabstick', categoryId: 'Add-ons', sellingPrice: 10.0, estimatedCost: 5.0, status: ProductStatus.available, createdAt: DateTime.now(), imagePath: 'assets/images/korean_noodles.png'),
    ProductModel(id: 'P907', sku: 'A-MIX', name: 'Mix Balls (3 pcs)', categoryId: 'Add-ons', sellingPrice: 20.0, estimatedCost: 10.0, status: ProductStatus.available, createdAt: DateTime.now(), imagePath: 'assets/images/korean_noodles.png'),
  ];

  static Map<String, double> salesOverview = {'Daily': 0, 'Weekly': 0, 'Monthly': 0};
  static List<Map<String, dynamic>> bestSellers = [];
  static Map<String, double> categorySales = {};
  static Map<String, double> paymentMethods = {};
  static Map<String, double> serviceTypes = {};
  static List<Map<String, dynamic>> peakHours = [];
}
