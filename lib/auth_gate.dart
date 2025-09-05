import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'pages/signup_page.dart';
import 'providers/place_provider.dart';
import 'repositories/place_repository.dart';
import 'services/supabase_service.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _initDone = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      // TODO: Paste your Supabase URL and anon key here.
      // 1) Create a project on https://supabase.com
      // 2) Go to Project Settings → API → Project URL & anon public key
      // 3) Create a public Storage bucket named `place-photos` (public)
      // 4) Create tables (SQL below) and enable RLS + policies
      // 5) Then fill the two strings below:
      const supabaseUrl = 'https://bdzzhzdpikgnonhrpuug.supabase.co';
      const supabaseAnonKey =
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJkenpoemRwaWtnbm9uaHJwdXVnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTcwODIzNDUsImV4cCI6MjA3MjY1ODM0NX0.w3jrVSwbT9v1MgCFOrPBqX8H50tNAtTYyP-GfKtEP-k';

      await supa.init(url: supabaseUrl, anonKey: supabaseAnonKey);
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _initDone = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initDone) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        body: Center(child: Text('Supabase init error: $_error')),
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PlaceProvider(PlaceRepository())),
      ],
      child: Navigator(
        initialRoute: '/',
        onGenerateRoute: (settings) {
          Widget page;
          final user = Supabase.instance.client.auth.currentUser;
          if (settings.name == '/signup') {
            page = const SignUpPage();
          } else if (settings.name == '/login') {
            page = const LoginPage();
          } else {
            page = (user == null) ? const LoginPage() : const HomePage();
          }
          return MaterialPageRoute(builder: (_) => page, settings: settings);
        },
      ),
    );
  }
}

/* ==============================
SQL you can run in Supabase (SQL editor)
=======================================

-- Places owned by creators
create table public.places (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid(),
  title text not null,
  description text not null,
  image_url text not null,
  map_url text not null,
  created_at timestamptz not null default now()
);

-- Favorites: per-user
create table public.favorites (
  user_id uuid not null,
  place_id uuid not null references public.places(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, place_id)
);

-- RLS
alter table public.places enable row level security;
alter table public.favorites enable row level security;

-- Policies:
-- Anyone logged in can read places
create policy "read all places" on public.places for select using (true);
-- Only owner can insert/update/delete their places
create policy "insert own" on public.places for insert with check (auth.uid() = user_id);
create policy "update own" on public.places for update using (auth.uid() = user_id);
create policy "delete own" on public.places for delete using (auth.uid() = user_id);

-- Favorites policies
create policy "read own favorites" on public.favorites for select using (auth.uid() = user_id);
create policy "upsert own favorites" on public.favorites for insert with check (auth.uid() = user_id);
create policy "delete own favorites" on public.favorites for delete using (auth.uid() = user_id);

*/
