import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_theme.dart';

class PermissionService {
  /// Check and request permission based on image source (Camera vs Gallery)
  static Future<bool> requestImagePickerPermission({
    required ImageSource source,
    required BuildContext context,
  }) async {
    if (kIsWeb) return true; // Web uses standard HTML file picker

    if (source == ImageSource.camera) {
      return await requestCameraPermission(context);
    } else {
      return await requestMediaPermission(context);
    }
  }

  /// Request Camera Permission
  static Future<bool> requestCameraPermission(BuildContext context) async {
    if (kIsWeb) return true;

    final status = await Permission.camera.status;
    if (status.isGranted) return true;

    final result = await Permission.camera.request();
    if (result.isGranted) return true;

    if (result.isPermanentlyDenied && context.mounted) {
      _showPermissionDialog(
        context,
        title: 'ক্যামেরা পারমিশন প্রয়োজন',
        message: 'বইয়ের কভার বা স্ক্রিনশট সরাসরি ক্যামেরা দিয়ে তোলার জন্য ক্যামেরা ব্যবহারের অনুমতি দিন।',
      );
    }
    return false;
  }

  /// Request Gallery / Media Storage Permission
  static Future<bool> requestMediaPermission(BuildContext context) async {
    if (kIsWeb) return true;

    // On modern Android (13+ / API 33+), photos permission is used
    PermissionStatus status;
    if (Platform.isAndroid) {
      status = await Permission.photos.status;
      if (!status.isGranted) {
        status = await Permission.photos.request();
      }
      // Fallback for older Android (storage)
      if (!status.isGranted) {
        status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
        }
      }
    } else {
      status = await Permission.photos.request();
    }

    if (status.isGranted || status.isLimited) return true;

    if (status.isPermanentlyDenied && context.mounted) {
      _showPermissionDialog(
        context,
        title: 'গ্যালারি ও মিডিয়া পারমিশন প্রয়োজন',
        message: 'ডিভাইস থেকে বইয়ের ছবি বা স্ক্রিনশট আপলোড করার জন্য ফটো ও মিডিয়া ব্যবহারের অনুমতি দিন।',
      );
    }
    return false;
  }

  /// Request Notification Permission (Android 13+)
  static Future<bool> requestNotificationPermission(
    BuildContext context, {
    bool showExplanation = false,
  }) async {
    if (kIsWeb) return true;

    final status = await Permission.notification.status;
    if (status.isGranted) return true;

    if (showExplanation && context.mounted) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surfaceDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.notifications_active_rounded, color: AppTheme.primary),
              SizedBox(width: 10),
              Text('নোটিফিকেশন পারমিশন', style: TextStyle(color: Colors.white, fontSize: 17)),
            ],
          ),
          content: const Text(
            'নতুন অর্ডার, কাস্টমার রিভিউ এবং জরুরি অ্যালার্ট তাৎক্ষণিকভাবে পাওয়ার জন্য নোটিফিকেশন অনুমোদন দেওয়া প্রয়োজন।',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('পরে করব', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
              child: const Text('অনুমোদন দিন', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      if (proceed != true) return false;
    }

    final result = await Permission.notification.request();
    if (result.isGranted) return true;

    if (result.isPermanentlyDenied && context.mounted) {
      _showPermissionDialog(
        context,
        title: 'নোটিফিকেশন পারমিশন বন্ধ আছে',
        message: 'নতুন অর্ডারের অ্যালার্ট পেতে অ্যাপ সেটিংসে গিয়ে নোটিফিকেশন চালু করুন।',
      );
    }
    return false;
  }

  /// Check if Battery Optimization is disabled
  static Future<bool> isBatteryOptimizationDisabled() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    return await Permission.ignoreBatteryOptimizations.isGranted;
  }

  /// Prompt and request to disable battery optimization
  static Future<bool> requestDisableBatteryOptimization(
    BuildContext context, {
    bool showPrompt = true,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return true;

    final isIgnored = await Permission.ignoreBatteryOptimizations.isGranted;
    if (isIgnored) return true;

    if (showPrompt && context.mounted) {
      final shouldRequest = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surfaceDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.battery_charging_full_rounded, color: AppTheme.accentAmber),
              SizedBox(width: 10),
              Text('ব্যাটারি অপ্টিমাইজেশন বন্ধ', style: TextStyle(color: Colors.white, fontSize: 17)),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'অ্যান্ড্রয়েডের ব্যাকগ্রাউন্ড কিলার বন্ধ করুন:',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              SizedBox(height: 8),
              Text(
                'ডিভাইসের ডিফল্ট ব্যাটারি সেভার ব্যাকগ্রাউন্ডে অ্যাপ বন্ধ করে দেয়। নতুন অর্ডারের লাইভ অ্যালার্ট এবং কুরিয়ার ডেটা সিঙ্ক অবিচ্ছিন্ন রাখতে অ্যাপটির ব্যাটারি অপ্টিমাইজেশন "Unrestricted / বন্ধ" রাখুন।',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('বাতিল', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
              child: const Text('অপ্টিমাইজেশন বন্ধ করুন', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (shouldRequest != true) return false;
    }

    final result = await Permission.ignoreBatteryOptimizations.request();
    return result.isGranted;
  }

  /// Helper dialog for permanently denied permissions
  static void _showPermissionDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.settings_suggest_rounded, color: AppTheme.accentRose),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Text(
          '$message\n\nঅ্যাপ সেটিংস থেকে পারমিশনটি সক্রিয় করুন।',
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('বাতিল', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            child: const Text('সেটিংস খুলুন', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  static const String keyHasPromptedInitialPermissions = 'has_prompted_initial_permissions';

  /// Check if all required core permissions (Notification, Battery Optimization, Camera or Media) are granted
  static Future<bool> areAllRequiredPermissionsGranted() async {
    if (kIsWeb) return true;

    try {
      final notif = await Permission.notification.isGranted;
      final batt = await isBatteryOptimizationDisabled();
      final cam = await Permission.camera.isGranted;
      final media = await Permission.photos.isGranted || await Permission.storage.isGranted;

      return notif && batt && (cam || media);
    } catch (_) {
      return false;
    }
  }

  /// Check if the startup permission prompt has already been shown after install
  static Future<bool> hasPromptedInitialPermissions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(keyHasPromptedInitialPermissions) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Mark the startup permission prompt as completed so it never shows again automatically
  static Future<void> markInitialPermissionsPrompted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyHasPromptedInitialPermissions, true);
    } catch (_) {}
  }
}
