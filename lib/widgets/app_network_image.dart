import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../config/app_theme.dart';

class AppNetworkImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final IconData fallbackIcon;
  final String? fallbackText;
  final Color? backgroundColor;
  final bool showBorder;
  final Color? borderColor;
  final Widget? placeholder;
  final Widget? errorWidget;

  const AppNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.fallbackIcon = Icons.image_not_supported_outlined,
    this.fallbackText,
    this.backgroundColor,
    this.showBorder = false,
    this.borderColor,
    this.placeholder,
    this.errorWidget,
  });

  /// Normalizes and cleans any image URL:
  /// - Handles relative paths (/uploads/..., /images/...) by prepending baseUrl.
  /// - Converts Google Drive share links to direct streaming links.
  /// - Converts Dropbox links to direct download links.
  /// - Trims and removes unwanted spaces or control characters.
  static String? normalizeUrl(String? rawUrl, {String? baseUrl}) {
    if (rawUrl == null) return null;
    var url = rawUrl.trim();
    if (url.isEmpty) return null;

    // 1. Google Drive Sharing Link to direct stream
    // e.g. https://drive.google.com/file/d/1a2b3c4d5e/view?usp=sharing
    final gDriveMatch = RegExp(r'drive\.google\.com\/(?:file\/d\/|open\?id=)([a-zA-Z0-9_-]+)').firstMatch(url);
    if (gDriveMatch != null) {
      final fileId = gDriveMatch.group(1);
      return 'https://drive.google.com/uc?export=view&id=$fileId';
    }

    // 2. Dropbox share link (dl=0 -> raw=1)
    if (url.contains('dropbox.com') && url.contains('dl=0')) {
      return url.replaceAll('dl=0', 'raw=1');
    }

    // 3. If already absolute URL with http:// or https://
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }

    // 4. Resolve relative paths against active base URL
    final base = baseUrl ?? ApiConfig.baseUrl;
    final cleanBase = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final cleanPath = url.startsWith('/') ? url : '/$url';
    return '$cleanBase$cleanPath';
  }

  @override
  Widget build(BuildContext context) {
    final cleanUrl = normalizeUrl(imageUrl);
    final radius = borderRadius ?? BorderRadius.zero;

    Widget content;
    if (cleanUrl == null || cleanUrl.isEmpty) {
      content = _buildPlaceholder(context, isError: false);
    } else if (kIsWeb) {
      // Flutter Web: Image.network bypasses XHR CORS headers when rendered
      content = Image.network(
        cleanUrl,
        width: width,
        height: height,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildLoading(context);
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholder(context, isError: true);
        },
      );
    } else {
      // Mobile / Native: CachedNetworkImage with automatic disk caching
      content = CachedNetworkImage(
        imageUrl: cleanUrl,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => _buildLoading(context),
        errorWidget: (context, url, error) {
          // Graceful fallback to Image.network if cached_network_image failed on native
          return Image.network(
            cleanUrl,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (ctx, err, stack) => _buildPlaceholder(context, isError: true),
          );
        },
      );
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor ?? const Color(0xFF1E293B),
        borderRadius: radius,
        border: showBorder
            ? Border.all(color: borderColor ?? const Color(0xFF334155))
            : null,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: content,
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    if (placeholder != null) return placeholder!;
    return Center(
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppTheme.primary.withOpacity(0.8),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context, {required bool isError}) {
    if (isError && errorWidget != null) return errorWidget!;
    return Container(
      width: width,
      height: height,
      color: backgroundColor ?? const Color(0xFF161F30),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isError ? Icons.broken_image_rounded : fallbackIcon,
            color: isError ? AppTheme.accentRose.withOpacity(0.7) : const Color(0xFF64748B),
            size: (width != null && width! < 60) ? 20 : 28,
          ),
          if (fallbackText != null && (height == null || height! >= 70)) ...[
            const SizedBox(height: 4),
            Text(
              fallbackText!,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
