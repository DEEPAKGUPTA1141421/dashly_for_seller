class ApiEndpoints {
  // ── Service bases ──────────────────────────────────────────────────────────
  static const String productServiceBase = 'http://localhost:8081';
  static const String orderServiceBase   = 'http://localhost:8082';

  // ── Auth  (ProductClientService · 8081) ───────────────────────────────────
  static const String login     = '/api/v1/auth/login';
  static const String verifyOtp = '/api/v1/auth/verify';
  static const String refresh   = '/api/v1/auth/refresh';
  static const String logout    = '/api/v1/auth/logout';

  // ── Seller Products  (ProductClientService · 8081) ────────────────────────
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
  static const String sellerProductDiscardDraft    = '/api/v1/seller/product/discard-draft-product';
  static const String sellerProductCatalogSearch   = '/api/v1/seller/product/catalog/search';
  static const String sellerProductFromCatalog     = '/api/v1/seller/product/listing/from-catalog';
  static const String sellerProductUpdateAddress   = '/api/v1/seller/product/update-address';

  // ── Categories & Brands  (ProductClientService · 8081) ───────────────────
  // Category tree (hierarchical)
  static const String categoryTree       = '/api/v1/product/category';
  static const String sellerCategories   = '/api/v1/product/category';
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

  // ── Seller Settings  (ProductClientService · 8081) ───────────────────────
  static const String settingsAll           = '/api/v1/seller/settings/all';
  static const String settingsPersonal      = '/api/v1/seller/settings/personal';
  static const String settingsBusiness      = '/api/v1/seller/settings/business';
  static const String settingsBank          = '/api/v1/seller/settings/bank';
  static const String settingsNotifications = '/api/v1/seller/settings/notifications';
  static const String settingsPreferences   = '/api/v1/seller/settings/preferences';
  static const String settingsPassword      = '/api/v1/seller/settings/security/password';
  static const String settingsSessions      = '/api/v1/seller/settings/security/sessions';

  // ── Bookings / Orders  (OrderPaymentNotificationService · 8082) ───────────
  static const String bookings        = '/api/v1/booking';
  static const String bookingCheckout = '/api/v1/booking/checkout';
  // PUT /api/v1/booking/{bookingId}/status  body: { status }
  static const String bookingStatus   = '/api/v1/booking';

  // ── Payments  (OrderPaymentNotificationService · 8082) ────────────────────
  static const String payments        = '/api/v1/payment';
  static const String validatePayment = '/api/v1/payment/validate-payment';
}
