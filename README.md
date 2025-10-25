# Eram Yadak Flutter Shop (WooCommerce)

## Run (Debug)
```bash
flutter run   --dart-define=BASE_URL=https://eramyadak.com   --dart-define=WC_CK=ck_ab285a4ad1263a7a7b59bb5c7fc994f0d28b079c   --dart-define=WC_CS=cs_184b1b7344439a958d3e6b2e57ec4e1f80787a1d
```

## Build APK
```bash
flutter build apk   --dart-define=BASE_URL=https://eramyadak.com   --dart-define=WC_CK=ck_ab285a4ad1263a7a7b59bb5c7fc994f0d28b079c   --dart-define=WC_CS=cs_184b1b7344439a958d3e6b2e57ec4e1f80787a1d
```

> Keys are for read-only catalog in the client. For orders, use a server-side proxy.