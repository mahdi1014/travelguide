import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/place_provider.dart';
import '../repositories/place_repository.dart';
import '../widgets/place_card.dart';
import '../pages/destination_item_page.dart';
import '../theme.dart';
import '../models/place.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _scroll = ScrollController();
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    final provider = context.read<PlaceProvider>();
    provider.refresh();
    _scroll.addListener(() {
      if (_scroll.position.pixels >
          _scroll.position.maxScrollExtent - 300) {
        provider.loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  // ---- delete flow (no owner required) ----
  Future<void> _confirmAndDelete(Place place) async {
    // tiny delay ensures the popup menu route is closed
    await Future<void>.delayed(Duration.zero);

    final ok = await showDialog<bool>(
          context: context,
          useRootNavigator: true, // important when called from inside overlays
          builder: (dialogCtx) => AlertDialog(
            title: const Text('Delete place?'),
            content: const Text('This action cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogCtx).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok || !mounted) return;

    bool success = false;
    try {
      // No-owner variant: repo just deletes by id and returns true/false
      success = await PlaceRepository().deletePlace(place.id);
    } catch (e) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      });
      return;
    }

    if (!mounted) return;

    // Defer provider mutation & snackbar to next frame to avoid build-time setState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (success) {
        context.read<PlaceProvider>().removePlace(place.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Place deleted')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not found or not allowed to delete')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final name = user?.userMetadata?['name'] as String? ??
        (user?.email?.split('@').first ?? 'Explorer');

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hey $name',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            const Text('Where are you going?',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
          ),
        ],
        backgroundColor: kCol1,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: (t) => context.read<PlaceProvider>().debounceSearch(t),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search places (e.g., Cox\'s Bazar, Sylhet Tea Garden)',
              ),
            ),
          ),
          Expanded(
            child: Consumer<PlaceProvider>(
              builder: (context, p, _) {
                if (p.items.isEmpty && p.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                return RefreshIndicator(
                  onRefresh: () => p.refresh(search: p.query),
                  child: ListView.builder(
                    controller: _scroll,
                    itemCount: p.items.length + (p.hasMore ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i >= p.items.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final place = p.items[i];

                      return KeyedSubtree(
                        key: ValueKey(place.id),
                        child: PlaceCard(
                          place: place,
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    DestinationItemPage(place: place),
                              ),
                            );
                          },
                          onEdit: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    DestinationItemPage(place: place),
                              ),
                            );
                          },
                          onDelete: () => _confirmAndDelete(place),
                          onToggleFavorite: () async {
                            final uid =
                                Supabase.instance.client.auth.currentUser?.id;
                            if (uid == null) return;
                            final makeFav = !place.isFavorite;
                            await PlaceRepository().toggleFavorite(
                              placeId: place.id,
                              userId: uid,
                              makeFavorite: makeFav,
                            );
                            context
                                .read<PlaceProvider>()
                                .setFavorite(place.id, makeFav);
                          },
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: const BottomAppBar(
        color: kCol1,
        shape: CircularNotchedRectangle(),
        child: SizedBox(height: 56),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_place',
        backgroundColor: kCol2,
        foregroundColor: Colors.white,
        label: const Text('ADD PLACE'),
        icon: const Icon(Icons.add_location_alt),
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const DestinationItemPage()),
          );
          if (!mounted) return;
          context.read<PlaceProvider>().refresh(
                search: context.read<PlaceProvider>().query,
              );
        },
      ),
    );
  }
}
