import '../models/category_model.dart';
import '../models/product_model.dart';

/// Local Storage Service for Offline-First Caching & Fast POS Loading
class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  List<ProductModel>? _cachedProducts;
  List<CategoryModel>? _cachedCategories;
  final Map<String, bool> _cachedStockAvailability = {};
  DateTime? _lastSyncTime;

  /// Cache products in local memory & storage
  void cacheProducts(List<ProductModel> products) {
    _cachedProducts = List.from(products);
    _lastSyncTime = DateTime.now();
  }

  /// Get cached products if available
  List<ProductModel>? getCachedProducts() {
    return _cachedProducts;
  }

  /// Cache categories in local memory & storage
  void cacheCategories(List<CategoryModel> categories) {
    _cachedCategories = List.from(categories);
  }

  /// Get cached categories if available
  List<CategoryModel>? getCachedCategories() {
    return _cachedCategories;
  }

  /// Batch update stock availability map
  void updateStockCache(Map<String, bool> stockMap) {
    _cachedStockAvailability.addAll(stockMap);
  }

  /// Set stock availability for a single product
  void setProductStock(String productId, bool isAvailable) {
    _cachedStockAvailability[productId] = isAvailable;
  }

  /// Get cached stock availability for a product
  bool? isProductAvailable(String productId) {
    return _cachedStockAvailability[productId];
  }

  /// Get all cached stock availability
  Map<String, bool> getCachedStockMap() {
    return Map.from(_cachedStockAvailability);
  }

  /// Clear all cache
  void clearCache() {
    _cachedProducts = null;
    _cachedCategories = null;
    _cachedStockAvailability.clear();
    _lastSyncTime = null;
  }

  /// Check if cache is fresh (less than 5 minutes old)
  bool isCacheFresh({Duration maxAge = const Duration(minutes: 5)}) {
    if (_lastSyncTime == null || _cachedProducts == null) return false;
    return DateTime.now().difference(_lastSyncTime!) < maxAge;
  }
}
