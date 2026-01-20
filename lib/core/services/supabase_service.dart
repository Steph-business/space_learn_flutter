import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final client = Supabase.instance.client;

  /// Test connectivity to Supabase
  static Future<bool> testConnectivity() async {
    try {
      // Test 1: Basic internet connectivity
      print('🌐 Testing basic internet...');
      final googleResponse = await http.get(
        Uri.parse('https://httpbin.org/get'),
      ).timeout(const Duration(seconds: 5));
      print('🌐 Basic internet test: ${googleResponse.statusCode}');
      
      // Test 2: Supabase connectivity
      print('🌐 Testing Supabase...');
      final response = await http.get(
        Uri.parse('https://uqmydsydlkwxcfcdtsbu.supabase.co/rest/v1/'),
        headers: {
          'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVxbXlkc3lkbGt3eGNmY2R0c2J1Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NzYxNDc1MiwiZXhwIjoyMDczMTkwNzUyfQ.DwBlZ_KXwFnO22Bu1a5f_PZcBSrBYWLC2frv-JeXebA',
        },
      ).timeout(const Duration(seconds: 10));
      
      print('🌐 Supabase connectivity test: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Supabase connectivity test failed: $e');
      return false;
    }
  }

  /// Creates a bucket in Supabase Storage if it doesn't exist.
  ///
  /// [bucket] is the name of the bucket to create (e.g., 'books').
  static Future<bool> createBucket(String bucket) async {
    try {
      await client.storage.createBucket(bucket);
      print('Bucket "$bucket" created successfully.');
      return true;
    } catch (e) {
      if (e.toString().contains('Failed host lookup') ||
          e.toString().contains('No address associated with hostname')) {
        print(
          'Error creating bucket "$bucket": Supabase project may be paused or deleted. Please check your Supabase dashboard and ensure the project is active.',
        );
      } else {
        print('Error creating bucket "$bucket": $e');
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
      print('🔍 Testing Supabase connectivity...');
      final isConnected = await testConnectivity();
      if (!isConnected) {
        print('❌ Cannot connect to Supabase');
        return null;
      }
      
      print('📤 Uploading to bucket: $bucket');
      print('📁 File path: $path');
      print('📄 Local file: ${file.path}');

      // Upload directly without trying to create the bucket (since it already exists)
      await client.storage
          .from(bucket)
          .upload(path, file, fileOptions: const FileOptions(upsert: true));

      // Generate public URL
      final publicUrl = 'https://uqmydsydlkwxcfcdtsbu.supabase.co/storage/v1/object/public/$bucket/$path';
      print('🔗 Generated URL: $publicUrl');

      return publicUrl;
    } catch (e) {
      print('❌ Error uploading to Supabase: $e');
      
      // If bucket doesn't exist, try to create it
      if (e.toString().contains('Bucket not found')) {
        print('🔧 Bucket not found, attempting to create it...');
        if (await createBucket(bucket)) {
          print('✅ Bucket created, retrying upload...');
          // Retry upload after creating bucket
          await client.storage
              .from(bucket)
              .upload(path, file, fileOptions: const FileOptions(upsert: true));
          final publicUrl = 'https://uqmydsydlkwxcfcdtsbu.supabase.co/storage/v1/object/public/$bucket/$path';
          print('🔗 Generated URL: $publicUrl');
          return publicUrl;
        }
      }
      
      return null;
    }
  }

  /// Gets the public URL for a file in a bucket.
  static String getPublicUrl(String bucket, String path) {
    return 'https://uqmydsydlkwxcfcdtsbu.supabase.co/storage/v1/object/public/$bucket/$path';
  }
}
