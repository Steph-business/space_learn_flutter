import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final client = Supabase.instance.client;

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
      await client.storage
          .from(bucket)
          .upload(path, file, fileOptions: const FileOptions(upsert: true));

      // Return the public URL
      return client.storage.from(bucket).getPublicUrl(path);
    } catch (e) {
      print('Error uploading to Supabase: $e');
      return null;
    }
  }

  /// Gets the public URL for a file in a bucket.
  static String getPublicUrl(String bucket, String path) {
    return client.storage.from(bucket).getPublicUrl(path);
  }
}
