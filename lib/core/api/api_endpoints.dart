class ApiEndpoints {
  // ── Service bases ──────────────────────────────────────────────────────────
  // PRODUCT_SERVICE_BASE can be overridden at build/run time, e.g. to test
  // against a LAN IP from a phone on the same Wi-Fi:
  //   flutter run -d chrome --web-hostname=0.0.0.0 --web-port=8000 \
  //     --dart-define=PRODUCT_SERVICE_BASE=http://<your-lan-ip>:8081
  // Shared host for all three services — override once via --dart-define
  // to point every client at a LAN IP (e.g. testing from a phone) instead
  // of localhost, which does not resolve to the dev machine from an
  // Android emulator or a physical device.
  static const String _apiHost = String.fromEnvironment(
    'API_HOST',
    defaultValue: '192.168.1.114',
  );

  static const String productServiceBase = String.fromEnvironment(
    'PRODUCT_SERVICE_BASE',
    defaultValue: 'http://$_apiHost:8081',
  );
  static const String orderServiceBase = String.fromEnvironment(
    'ORDER_SERVICE_BASE',
    defaultValue: 'http://$_apiHost:8082',
  );
  static const String deliveryServiceBase = String.fromEnvironment(
    'DELIVERY_SERVICE_BASE',
    defaultValue: 'http://$_apiHost:8083',
  );

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
  // Presigned direct-to-Cloudinary upload — POST {productId}/media/signature to
  // get a short-lived signed payload, upload straight to Cloudinary with it,
  // then POST the result here to attach it to the product.
  static String sellerProductMediaSignature(String productId) =>
      '$sellerProductBase/$productId/media/signature';
  static const String sellerProductMediaConfirm    = '/api/v1/seller/product/media/confirm';
  static const String sellerProductMediaRemove     = '/api/v1/seller/product/media/remove';
  // GET — {complete, missing: [...]} — gates the Images step's Continue action.
  static String sellerProductMediaStatus(String productId) =>
      '$sellerProductBase/$productId/media/status';
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
  static const String sellerProductDashboardSummary = '/api/v1/seller/product/dashboard-summary';
  // GET ?weeks=2 — weekly {week, products, views, comments} rows
  static const String sellerProductActivity       = '/api/v1/seller/product/activity';
  // GET ?days=7 — [{source, count}]
  static const String sellerProductTrafficSources = '/api/v1/seller/product/traffic-sources';
  // GET ?days=7 — [{productId, productName, viewerCount}]
  static const String sellerProductViewers        = '/api/v1/seller/product/viewers';
  // GET ?page=0&size=50&query= — not-yet-live products with a future scheduledAt
  static const String sellerProductScheduled       = '/api/v1/seller/product/scheduled-products';
  // POST ${sellerProductBase}/{productId}/schedule  body: { scheduledAt } — also used to reschedule
  // POST ${sellerProductBase}/{productId}/publish-now

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
  static String sellerReviewReply(String reviewId) => '/api/v1/seller/product/reviews/$reviewId/reply';
  static String sellerReviewReact(String reviewId) => '/api/v1/seller/product/reviews/$reviewId/react';
  static String sellerReviewDelete(String reviewId) => '/api/v1/seller/product/reviews/$reviewId';

  // ── Customer Analytics (ProductClientService) ─────────────────────────────
  static const String sellerTopCities     = '/api/v1/seller/product/top-cities';
  static const String sellerMonthlyViews  = '/api/v1/seller/product/monthly-views';
  static const String sellerReturns       = '/api/v1/seller/product/returns';
  static const String sellerReturnSummary = '/api/v1/seller/product/returns/summary';
  static const String sellerCustomersNotify = '/api/v1/seller/product/customers/notify';
  static const String sellerTopProducts = '/api/v1/seller/stats/top-products';
  static const String sellerEarnings    = '/api/v1/seller/earnings';
  static const String sellerEarningsHistory = '/api/v1/seller/earnings/history';
  static const String sellerCustomerStats = '/api/v1/seller/stats/customers';

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

  // ── Order Receipts  (OrderPaymentNotificationService · 8082) ──────────────
  // GET ${sellerReceiptDownload}/{bookingId}/download — PDF bytes of the seller's
  // own invoice for that order. 404 if not yet generated, 403 if not their order.
  static const String sellerReceiptDownload = '/api/v1/seller/receipt';

  // ── Seller-authored Invoices (POS)  (OrderPaymentNotificationService · 8082) ──
  // POST create draft · PUT /{id} update draft · GET list (?status=&query=&page=&size=)
  // GET /{id} detail · GET /{id}/download PDF bytes
  // POST /{id}/finalize · POST /{id}/cancel · PUT /{id}/status  body:{status}
  // POST /{id}/send  body:{channel: WHATSAPP|EMAIL, destination?}
  static const String invoices          = '/api/v1/seller/invoices';
  static const String invoiceCustomers  = '/api/v1/seller/invoices/customers';

  // ── In-App Notifications  (OrderPaymentNotificationService · 8082) ─────────
  // GET  ?page=0&size=20&onlyUnread=false
  static const String notifications       = '/api/v1/users/notifications';
  // PATCH /{id}/read   PATCH /read-all
  static const String notificationReadAll = '/api/v1/users/notifications/read-all';
  static const String notificationUnreadCount = '/api/v1/users/notifications/unread-count';
  static const String notificationPreferences = '/api/v1/users/notification-preferences';
  // PATCH /{category}

  // ── Device Tokens  (OrderPaymentNotificationService · 8082) ──────────────
  // POST  body: { token, platform }
  static const String deviceTokens = '/api/v1/users/devices';

  // ── Generic config  (ProductClientService · 8081) ────────────────────────
  // GET /api/v1/config/{key}  →  data is the raw JSON value stored for that key
  static const String config = '/api/v1/config';

  // ── Seller Product Variant Discount  (ProductClientService · 8081) ────────
  // PATCH sets/updates the discount, DELETE removes it — both return the
  // updated variant (with a null `discount` after DELETE).
  static String sellerProductVariantDiscount(String productId, String variantId) =>
      '$sellerProductBase/$productId/variants/$variantId/discount';
}
