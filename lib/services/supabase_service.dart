import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  SupabaseClient? _client;

  SupabaseClient get client => _client!;
  bool get isInitialized => _client != null;

  static final SupabaseService _instance = SupabaseService._internal();
  SupabaseService._internal();
  factory SupabaseService() => _instance;

  /// Call once from AuthGate with your project keys
  Future<void> init({required String url, required String anonKey}) async {
    if (isInitialized) return;
    await Supabase.initialize(url: url, anonKey: anonKey);
    _client = Supabase.instance.client;
  }
}

final supa = SupabaseService();
