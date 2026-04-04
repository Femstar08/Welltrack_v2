import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Product IDs — must match Google Play Console & App Store Connect
class BillingProducts {
  static const String monthlyPro = 'welltrack_pro_monthly';
  static const String yearlyPro = 'welltrack_pro_yearly';

  static const Set<String> allIds = {monthlyPro, yearlyPro};
}

/// Purchase state exposed to the UI
enum BillingStatus {
  idle,
  loading,
  purchasing,
  purchased,
  restored,
  error,
}

/// Platform-agnostic billing state
class BillingState {
  const BillingState({
    this.status = BillingStatus.idle,
    this.isAvailable = false,
    this.products = const [],
    this.activeSubscription,
    this.errorMessage,
  });

  final BillingStatus status;
  final bool isAvailable;
  final List<ProductDetails> products;
  final PurchaseDetails? activeSubscription;
  final String? errorMessage;

  BillingState copyWith({
    BillingStatus? status,
    bool? isAvailable,
    List<ProductDetails>? products,
    PurchaseDetails? activeSubscription,
    String? errorMessage,
    bool clearSubscription = false,
    bool clearError = false,
  }) {
    return BillingState(
      status: status ?? this.status,
      isAvailable: isAvailable ?? this.isAvailable,
      products: products ?? this.products,
      activeSubscription: clearSubscription
          ? null
          : (activeSubscription ?? this.activeSubscription),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Billing service that wraps in_app_purchase for both Android and iOS.
///
/// Uses Google Play Billing on Android and StoreKit on iOS — no vendor lock-in.
/// Receipt validation is server-side via Supabase Edge Function.
class BillingService extends StateNotifier<BillingState> {
  BillingService(this._supabase) : super(const BillingState()) {
    _init();
  }

  final SupabaseClient _supabase;
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  Future<void> _init() async {
    final available = await _iap.isAvailable();
    if (!available) {
      state = state.copyWith(
        isAvailable: false,
        status: BillingStatus.error,
        errorMessage: 'In-app purchases not available on this device',
      );
      return;
    }

    state = state.copyWith(isAvailable: true);

    // Listen to purchase updates (works for both platforms)
    _purchaseSubscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (error) {
        state = state.copyWith(
          status: BillingStatus.error,
          errorMessage: 'Purchase stream error: $error',
        );
      },
    );

    await loadProducts();
  }

  /// Load available products from the store
  Future<void> loadProducts() async {
    state = state.copyWith(status: BillingStatus.loading, clearError: true);

    final response = await _iap.queryProductDetails(BillingProducts.allIds);

    if (response.error != null) {
      state = state.copyWith(
        status: BillingStatus.error,
        errorMessage: response.error!.message,
      );
      return;
    }

    if (response.notFoundIDs.isNotEmpty) {
      debugPrint(
        'BillingService: Products not found: ${response.notFoundIDs}',
      );
    }

    state = state.copyWith(
      status: BillingStatus.idle,
      products: response.productDetails,
    );
  }

  /// Initiate a subscription purchase
  Future<void> purchaseSubscription(ProductDetails product) async {
    state = state.copyWith(status: BillingStatus.purchasing, clearError: true);

    final purchaseParam = PurchaseParam(productDetails: product);

    try {
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      state = state.copyWith(
        status: BillingStatus.error,
        errorMessage: 'Failed to initiate purchase: $e',
      );
    }
  }

  /// Restore previous purchases (required by App Store guidelines)
  Future<void> restorePurchases() async {
    state = state.copyWith(status: BillingStatus.loading, clearError: true);

    try {
      await _iap.restorePurchases();
    } catch (e) {
      state = state.copyWith(
        status: BillingStatus.error,
        errorMessage: 'Failed to restore purchases: $e',
      );
    }
  }

  /// Handle purchase updates from the store
  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          state = state.copyWith(status: BillingStatus.purchasing);
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // Validate receipt server-side before granting access
          final valid = await _validateReceipt(purchase);
          if (valid) {
            state = state.copyWith(
              status: purchase.status == PurchaseStatus.purchased
                  ? BillingStatus.purchased
                  : BillingStatus.restored,
              activeSubscription: purchase,
            );
          } else {
            state = state.copyWith(
              status: BillingStatus.error,
              errorMessage: 'Receipt validation failed. Please contact support.',
            );
          }

          // Complete the purchase (required on both platforms)
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          break;

        case PurchaseStatus.error:
          state = state.copyWith(
            status: BillingStatus.error,
            errorMessage:
                purchase.error?.message ?? 'Purchase failed. Please try again.',
          );

          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          break;

        case PurchaseStatus.canceled:
          state = state.copyWith(status: BillingStatus.idle, clearError: true);
          break;
      }
    }
  }

  /// Validate receipt server-side via Supabase Edge Function.
  ///
  /// This is the ONLY place plan_tier gets updated — never on the client.
  /// The Edge Function verifies the receipt with Google/Apple servers,
  /// then updates wt_users.plan_tier and subscription_expires_at.
  Future<bool> _validateReceipt(PurchaseDetails purchase) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await _supabase.functions.invoke(
        'validate-receipt',
        body: {
          'user_id': userId,
          'product_id': purchase.productID,
          'purchase_token': purchase.verificationData.serverVerificationData,
          'platform': Platform.isAndroid ? 'android' : 'ios',
          'source': purchase.verificationData.source,
        },
      );

      if (response.status != 200) {
        debugPrint('Receipt validation failed: ${response.data}');
        return false;
      }

      final data = response.data as Map<String, dynamic>;
      return data['valid'] == true;
    } catch (e) {
      debugPrint('Receipt validation error: $e');
      return false;
    }
  }

  /// Get the monthly product (convenience getter for paywall)
  ProductDetails? get monthlyProduct {
    try {
      return state.products.firstWhere(
        (p) => p.id == BillingProducts.monthlyPro,
      );
    } catch (_) {
      return null;
    }
  }

  /// Get the yearly product (convenience getter for paywall)
  ProductDetails? get yearlyProduct {
    try {
      return state.products.firstWhere(
        (p) => p.id == BillingProducts.yearlyPro,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    super.dispose();
  }
}

/// Global billing service provider — lives for the app's lifetime
final billingServiceProvider =
    StateNotifierProvider<BillingService, BillingState>((ref) {
  final supabase = Supabase.instance.client;
  return BillingService(supabase);
});
