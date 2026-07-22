import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final client = Supabase.instance.client;

  /// Test connectivity to Supabase
  static Future<bool> testConnectivity() async {
    if (kIsWeb) return true;
    try {
      // Test 1: Basic internet connectivity
      final googleResponse = await http
          .get(Uri.parse('https://httpbin.org/get'))
          .timeout(const Duration(seconds: 5));
      // Test 2: Supabase connectivity
      const apiKey = String.fromEnvironment(
        'SUPABASE_ANON_KEY',
        defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVxbXlkc3lkbGt3eGNmY2R0c2J1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc2MTQ3NTIsImV4cCI6MjA3MzE5MDc1Mn0.anon',
      );
      final response = await http
          .get(
            Uri.parse('https://uqmydsydlkwxcfcdtsbu.supabase.co/rest/v1/'),
            headers: {
              'apikey': apiKey,
            },
          )
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Creates a bucket in Supabase Storage if it doesn't exist.
  ///
  /// [bucket] is the name of the bucket to create (e.g., 'books').
  static Future<bool> createBucket(String bucket) async {
    try {
      await client.storage.createBucket(
        bucket,
        const BucketOptions(public: true),
      );
      return true;
    } catch (e) {
      if (e.toString().contains('Failed host lookup') ||
          e.toString().contains('No address associated with hostname')) {

      } else {
      }
      return false;
    }
  }

  /// Uploads a file to a specific bucket in Supabase Storage.
  ///
  /// [bucket] is the name of the bucket (e.g., 'books' or 'covers').
  /// [path] is the destination path within the bucket.
  /// [file] is the local file to upload.
  static Future<String?> uploadFile({
    required String bucket,
    required String path,
    required File file,
  }) async {
    try {
      // Test connectivity first
      final isConnected = await testConnectivity();
      if (!isConnected) {
        return null;
      }
      // Force update bucket to public just in case it was created as private
      try {
        await client.storage.updateBucket(
          bucket,
          const BucketOptions(public: true),
        );
      } catch (_) {
        // Ignore errors if bucket already public or update not allowed
      }
      // Upload directly without trying to create the bucket (since it already exists)
      await client.storage
          .from(bucket)
          .upload(path, file, fileOptions: const FileOptions(upsert: true));

      // Generate public URL
      final publicUrl = getPublicUrl(bucket, path);
      return publicUrl;
    } catch (e) {
      final errorStr = e.toString();
      // Better detection for missing bucket
      if (errorStr.contains('Bucket not found') || errorStr.contains('404')) {

        try {
          // Attempt to create it (will fail if exists, which is caught)
          await createBucket(bucket);
          await client.storage
              .from(bucket)
              .upload(path, file, fileOptions: const FileOptions(upsert: true));

          final publicUrl = getPublicUrl(bucket, path);
          return publicUrl;
        } catch (retryError) {
          throw Exception('Failed to create bucket and upload: $retryError');
        }
      }

      throw Exception('Supabase uploadFile error: $e');
    }
  }

  /// Uploads raw bytes to a specific bucket in Supabase Storage.
  /// This is especially useful for Flutter Web where dart:io File is not supported.
  static Future<String?> uploadBytes({
    required String bucket,
    required String path,
    required Uint8List bytes,
  }) async {
    try {
      final isConnected = await testConnectivity();
      if (!isConnected) return null;

      try {
        await client.storage.updateBucket(bucket, const BucketOptions(public: true));
      } catch (_) {}

      await client.storage
          .from(bucket)
          .uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: true));

      return getPublicUrl(bucket, path);
    } catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains('Bucket not found') || errorStr.contains('404')) {
        try {
          await createBucket(bucket);
          await client.storage
              .from(bucket)
              .uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: true));
          return getPublicUrl(bucket, path);
        } catch (retryError) {
          throw Exception('Failed to create bucket and upload: $retryError');
        }
      }
      throw Exception('Supabase uploadBytes error: $e');
    }
  }

  /// Gets the public URL for a file in a bucket.
  static String getPublicUrl(String bucket, String path) {
    return client.storage.from(bucket).getPublicUrl(path);
  }
}