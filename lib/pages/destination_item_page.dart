import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/place.dart';
import '../providers/place_provider.dart';
import '../repositories/place_repository.dart';

class DestinationItemPage extends StatefulWidget {
  final Place? place; // null => Add mode, otherwise Edit mode
  const DestinationItemPage({super.key, this.place});

  @override
  State<DestinationItemPage> createState() => _DestinationItemPageState();
}

class _DestinationItemPageState extends State<DestinationItemPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _map = TextEditingController();
  PlatformFile? _pickedFile;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.place;
    if (p != null) {
      _title.text = p.title;
      _desc.text = p.description;
      _map.text = p.mapUrl;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _map.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _pickedFile = result.files.single);
    }
  }

  int _wordCount(String s) =>
      s.trim().split(RegExp(r"\s+")).where((e) => e.isNotEmpty).length;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = PlaceRepository();
      final provider = context.read<PlaceProvider>();
      final userId = Supabase.instance.client.auth.currentUser!.id;

      if (widget.place == null) {
        if (_pickedFile == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a photo.')),
          );
          return;
        }
        final created = await repo.createPlace(
          title: _title.text.trim(),
          description: _desc.text.trim(),
          mapUrl: _map.text.trim(),
          imageFile: _pickedFile!,
          userId: userId,
        );
        await provider.addPlace(created);
      } else {
        final updated = await repo.updatePlace(
          id: widget.place!.id,
          title: _title.text.trim(),
          description: _desc.text.trim(),
          mapUrl: _map.text.trim(),
          imageFile: _pickedFile,
        );
        await provider.replacePlace(updated);
      }

      if (mounted) Navigator.of(context).pop();
    } on StorageException catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload failed: ${e.message}')));
    } on AuthException catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.place != null;

    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit Place' : 'Add Place')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _title,
                    decoration: const InputDecoration(labelText: 'Place Title'),
                    validator: (v) => (v == null || v.trim().length < 3)
                        ? 'Enter a title (min 3 chars)'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _desc,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Description (20–30 words)',
                    ),
                    validator: (v) {
                      final wc = _wordCount(v ?? '');
                      if (wc < 18) return 'Please write ~20–30 words (min 18).';
                      if (wc > 40) return 'Too long — target ~20–30 words.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _map,
                    decoration: const InputDecoration(
                      labelText: 'Google Map Link (https://...)',
                    ),
                    validator: (v) => (v == null || !v.startsWith('http'))
                        ? 'Enter a valid map URL'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.photo_library),
                          label: Text(
                            _pickedFile == null
                                ? 'Select Photo'
                                : _pickedFile!.name,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save),
                    label: Text(editing ? 'Save Changes' : 'Add Place'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
