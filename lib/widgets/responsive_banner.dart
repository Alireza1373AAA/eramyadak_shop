import 'package:flutter/material.dart';

class ResponsiveBanner extends StatefulWidget {
  const ResponsiveBanner({
    super.key,
    required this.assetPath,
    this.borderRadius = 16,
    this.padding = const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
    this.fit = BoxFit.cover, // اگر نمی‌خوای تصویر برش بخوره بذار BoxFit.contain
    this.placeholderColor = const Color(0xFFF2F2F2),
  });

  final String assetPath;
  final double borderRadius;
  final EdgeInsets padding;
  final BoxFit fit;
  final Color placeholderColor;

  @override
  State<ResponsiveBanner> createState() => _ResponsiveBannerState();
}

class _ResponsiveBannerState extends State<ResponsiveBanner> {
  double? _aspect; // نسبت عرض به ارتفاع تصویر

  @override
  void initState() {
    super.initState();

    // ابعاد واقعی تصویر رو از خود فایل می‌گیریم تا بنر ریسپانسیو بشه
    final img = AssetImage(widget.assetPath);
    final stream = img.resolve(const ImageConfiguration());
    stream.addListener(
      ImageStreamListener(
        (info, _) {
          final width = info.image.width.toDouble();
          final height = info.image.height.toDouble();
          if (mounted && width > 0 && height > 0) {
            setState(() => _aspect = width / height);
          }
        },
        onError: (err, _) {
          // می‌تونی لاگ بگیری یا پیام بدی
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.padding,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: _aspect == null
            // تا وقتی ابعاد لود نشده، از نسبت پیش‌فرض 16/9 استفاده می‌کنیم
            ? AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(color: widget.placeholderColor),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  // ارتفاع تصویر = عرض / نسبت واقعی تصویر
                  final height = constraints.maxWidth / _aspect!;
                  return SizedBox(
                    height: height,
                    width: double.infinity,
                    child: Image.asset(
                      widget.assetPath,
                      fit: widget.fit,
                      errorBuilder: (_, __, ___) => Container(
                        color: widget.placeholderColor,
                        alignment: Alignment.center,
                        child: const Icon(Icons.image_not_supported),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
