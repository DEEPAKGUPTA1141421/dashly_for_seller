class ApiEndpoints {
  // ── Service bases ──────────────────────────────────────────────────────────
  // PRODUCT_SERVICE_BASE can be overridden at build/run time, e.g. to test
  // against a LAN IP from a phone on the same Wi-Fi:
  //   flutter run -d chrome --web-hostname=0.0.0.0 --web-port=8000 \
  //     --dart-define=PRODUCT_SERVICE_BASE=http://<your-lan-ip>:8081
  static const String productServiceBase = String.fromEnvironment(
    'PRODUCT_SERVICE_BASE',
    defaultValue: 'http://localhost:8081',
  );
  static const String orderServiceBase    = 'https://orderpaymentnotificationservice.onrender.com';
  static const String deliveryServiceBase = 'https://deliveryinventoryservice.onrender.com';

  // ── Auth  (ProductClientService · 8081) ───────────────────────────────────
  static const String login     = '/api/v1/auth/login';
  static const String verifyOtp = '/api/v1/auth/verify';
  static const String refresh   = '/api/v1/auth/refresh';
  static const String logout    = '/api/v1/auth/logout';

  // ── Seller Products  (ProductClientService · 8081) ────────────────────────
  static const String sellerProducts               = '/api/v1/seller/product/my-products';
  static const String sellerProductsEs             = '/api/v1/seller/product/my-products-es';
  static const String sellerProductBase            = '/api/v1/seller/product'; // DELETE /{productId}  PATCH /{productId}/toggle-active
  static const String sellerProductCreate          = '/api/v1/seller/product/create';
  static const String sellerProductUploadImages    = '/api/v1/seller/product/upload-images';
  static const String sellerProductAddVariants     = '/api/v1/seller/product/add-variants';
  // attach-brand uses query params: ?productId=X&brandId=Y  (null body)
  static const String sellerProductAttachBrand     = '/api/v1/seller/product/attach-brand';
  static const String sellerProductAddTag          = '/api/v1/seller/product/add-tag';
  static const String sellerProductLoadAttribute   = '/api/v1/seller/product/load-attribute';
  static const String sellerProductCreateAttribute = '/api/v1/seller/product/create-product-attribute';
  static const String sellerProductMakeLive        = '/api/v1/seller/product/make-product-live';
  static const String sellerProductDraft           = '/api/v1/seller/product/draft-product';
  static const String sellerProductDraftFull       = '/api/v1/seller/product/draft-product/full';
  static const String sellerProductDiscardDraft    = '/api/v1/seller/product/discard-draft-product';
  static const String sellerProductCatalogSearch   = '/api/v1/seller/product/catalog/search';
  // GET /api/v1/seller/product/catalog/detail/{standardProductId}
  static const String sellerProductCatalogDetail   = '/api/v1/seller/product/catalog/detail';
  static const String sellerProductFromCatalog     = '/api/v1/seller/product/listing/from-catalog';
  static const String sellerProductUpdateAddress   = '/api/v1/seller/product/update-address';

  // ── Categories & Brands  (ProductClientService · 8081) ───────────────────
  // Category tree (hierarchical) — full global tree, used in the add-product flow
  static const String categoryTree       = '/api/v1/product/category';
  // Distinct categories the seller actually has LIVE products in — used for the
  // seller's product-list filter (not the full global tree)
  static const String sellerCategories   = '/api/v1/seller/product/my-categories';
  // Level-0 categories only (used in Settings → business category picker)
  static const String levelZeroCategories = '/api/v1/product/categorylevelwise';
  // GET /api/v1/seller/product/getall-category-attribute/{categoryId}
  // Append /{categoryId} when calling — returns {data: {attributeIds: [...]}}
  static const String categoryAttributes = '/api/v1/seller/product/getall-category-attribute';
  static const String brands             = '/api/v1/brand';
  // GET /api/v1/brands/category/{categoryId}
  static const String brandsByCategory   = '/api/v1/brands/category';
  // GET /api/v1/brands/search?query=X
  static const String brandsSearch       = '/api/v1/brands/search';

  // ── KYC / Aadhaar  (ProductClientService · 8081) ─────────────────────────
  static const String aadharSendOtp      = '/api/v1/seller/product/kyc/aadhar/send-otp';
  static const String aadharVerifyOtp    = '/api/v1/seller/product/kyc/aadhar/verify-otp';
  static const String aadharUploadDoc    = '/api/v1/seller/product/kyc/aadhar/upload-document';
  static const String aadharStatus       = '/api/v1/seller/product/kyc/aadhar/status';
  // GET — overall Aadhaar+PAN+GST document review status
  static const String kycDocuments       = '/api/v1/seller/product/kyc/documents';
  // POST (multipart) — each document type is submitted independently
  static const String kycDocumentsAadhaar = '/api/v1/seller/product/kyc/documents/aadhaar';
  static const String kycDocumentsPan     = '/api/v1/seller/product/kyc/documents/pan';
  static const String kycDocumentsGst     = '/api/v1/seller/product/kyc/documents/gst';

  // ── Seller Settings  (ProductClientService · 8081) ───────────────────────
  static const String settingsAll           = '/api/v1/seller/settings/all';
  static const String settingsPersonal      = '/api/v1/seller/settings/personal';
  static const String settingsEmailRequest  = '/api/v1/seller/settings/personal/email/request';
  static const String settingsEmailVerify   = '/api/v1/seller/settings/personal/email/verify';
  static const String settingsBusiness      = '/api/v1/seller/settings/business';
  static const String settingsBank          = '/api/v1/seller/settings/bank';
  static const String settingsNotifications = '/api/v1/seller/settings/notifications';
  static const String settingsPreferences   = '/api/v1/seller/settings/preferences';
  static const String settingsPassword      = '/api/v1/seller/settings/security/password';
  static const String settingsSessions      = '/api/v1/seller/settings/security/sessions';

  // ── Seller Orders & Stats  (OrderPaymentNotificationService · 8082) ────────
  static const String sellerOrders             = '/api/v1/seller/orders';
  static const String sellerOrderStatusCounts  = '/api/v1/seller/orders/status-counts';
  static const String sellerStats              = '/api/v1/seller/stats';
  static const String sellerProductLowStock    = '/api/v1/seller/product/low-stock';
  static const String sellerReviews            = '/api/v1/seller/product/reviews';
  static const String sellerReviewSummary      = '/api/v1/seller/product/reviews/summary';
  static const String sellerTopProducts = '/api/v1/seller/stats/top-products';
  static const String sellerEarnings    = '/api/v1/seller/earnings';

  // ── Wallet / Earnings  (OrderPaymentNotificationService · 8082) ──────────
  static const String wallet             = '/api/v1/users/wallet';
  static const String walletTransactions = '/api/v1/users/wallet/transactions';

  // ── Bookings / Orders  (OrderPaymentNotificationService · 8082) ───────────
  static const String bookings        = '/api/v1/booking';
  static const String bookingCheckout = '/api/v1/booking/checkout';
  // PUT /api/v1/booking/{bookingId}/status  body: { status }
  static const String bookingStatus   = '/api/v1/booking';

  // ── Payments  (OrderPaymentNotificationService · 8082) ────────────────────
  static const String payments        = '/api/v1/payment';
  static const String validatePayment = '/api/v1/payment/validate-payment';

  // ── In-App Notifications  (OrderPaymentNotificationService · 8082) ─────────
  // GET  ?page=0&size=20&onlyUnread=false
  static const String notifications       = '/api/v1/users/notifications';
  // PATCH /{id}/read   PATCH /read-all
  static const String notificationReadAll = '/api/v1/users/notifications/read-all';

  // ── Device Tokens  (OrderPaymentNotificationService · 8082) ──────────────
  // POST  body: { token, platform }
  static const String deviceTokens = '/api/v1/users/devices';

  // ── Generic config  (ProductClientService · 8081) ────────────────────────
  // GET /api/v1/config/{key}  →  data is the raw JSON value stored for that key
  static const String config = '/api/v1/config';
}
