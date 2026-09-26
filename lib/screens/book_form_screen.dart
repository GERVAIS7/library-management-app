import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/author.dart';
import '../models/book.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';

/// Used for BOTH creating a new Book and editing an existing one.
/// Pass an existing [book] to edit it; leave null to create.
class BookFormScreen extends StatefulWidget {
  final Book? book;
  const BookFormScreen({super.key, this.book});

  @override
  State<BookFormScreen> createState() => _BookFormScreenState();
}

class _BookFormScreenState extends State<BookFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestoreService = FirestoreService();
  final _storageService = StorageService();
  final _authService = AuthService();

  // Cached ONCE in initState (not re-created on every rebuild), otherwise
  // the dropdown resets on every keystroke/image pick and selection is lost.
  late final Stream<List<Author>> _authorsStream;

  late TextEditingController _titleController;
  late TextEditingController _isbnController;
  late TextEditingController _genreController;
  late TextEditingController _copiesController;

  String? _selectedAuthorId;

  // Image is kept as raw bytes (not dart:io File), so this works
  // identically on web (Chrome) and on Android/iOS.
  Uint8List? _pickedImageBytes;
  String _existingImageUrl = '';
  bool _isSaving = false;

  bool get _isEditing => widget.book != null;

  @override
  void initState() {
    super.initState();
    _authorsStream = _firestoreService.streamAuthors();

    final b = widget.book;
    _titleController = TextEditingController(text: b?.title ?? '');
    _isbnController = TextEditingController(text: b?.isbn ?? '');
    _genreController = TextEditingController(text: b?.genre ?? '');
    _copiesController = TextEditingController(text: (b?.copiesAvailable ?? 1).toString());
    _selectedAuthorId = b?.authorId;
    _existingImageUrl = b?.coverImageUrl ?? '';
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() => _pickedImageBytes = bytes);
    }
  }

  /// Opens a small dialog to create a new Author without leaving this
  /// screen. Returns the new author's ID (or null if cancelled).
  Future<String?> _showAddAuthorDialog() async {
    final nameController = TextEditingController();
    final yearController = TextEditingController();
    final nationalityController = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Author'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
              autofocus: true,
            ),
            TextField(
              controller: yearController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Birth Year'),
            ),
            TextField(
              controller: nationalityController,
              decoration: const InputDecoration(labelText: 'Nationality'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              final newId = await _firestoreService.addAuthor(Author(
                id: '',
                name: nameController.text.trim(),
                birthYear: int.tryParse(yearController.text) ?? 0,
                nationality: nationalityController.text.trim(),
              ));
              if (ctx.mounted) Navigator.pop(ctx, newId);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAuthorId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please select an author')));
      return;
    }

    setState(() => _isSaving = true);
    final uid = _authService.currentUser!.uid;

    try {
      String imageUrl = _existingImageUrl;
      if (_pickedImageBytes != null) {
        // Image upload failure (e.g. Storage not enabled yet) should not
        // block saving the rest of the book. A hard timeout prevents this
        // from hanging forever if Storage is unreachable/not enabled.
        try {
          imageUrl = await _storageService
              .uploadBookCover(
                bytes: _pickedImageBytes!,
                ownerId: uid,
              )
              .timeout(const Duration(seconds: 10));
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Image upload failed (Storage may not be enabled yet) — saved without cover.',
                ),
              ),
            );
          }
        }
      }

      if (_isEditing) {
        final updated = widget.book!.copyWith(
          title: _titleController.text.trim(),
          authorId: _selectedAuthorId,
          isbn: _isbnController.text.trim(),
          genre: _genreController.text.trim(),
          coverImageUrl: imageUrl,
          copiesAvailable: int.tryParse(_copiesController.text) ?? 1,
        );
        await _firestoreService.updateBook(updated);
      } else {
        final newBook = Book(
          id: '',
          title: _titleController.text.trim(),
          authorId: _selectedAuthorId!,
          isbn: _isbnController.text.trim(),
          genre: _genreController.text.trim(),
          coverImageUrl: imageUrl,
          copiesAvailable: int.tryParse(_copiesController.text) ?? 1,
          ownerId: uid,
          createdAt: DateTime.now(),
        );
        await _firestoreService.addBook(newBook);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Book' : 'Add Book')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 160,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _pickedImageBytes != null
                      ? Image.memory(_pickedImageBytes!, fit: BoxFit.cover)
                      : _existingImageUrl.isNotEmpty
                          ? Image.network(_existingImageUrl, fit: BoxFit.cover)
                          : const Center(child: Icon(Icons.add_a_photo, size: 40)),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              StreamBuilder<List<Author>>(
                stream: _authorsStream,
                builder: (context, snapshot) {
                  final authors = snapshot.data ?? [];

                  // Guard against a stale selection that no longer matches
                  // any item in the current list (avoids a Dropdown assertion
                  // crash if an author was deleted elsewhere).
                  final validSelection =
                      authors.any((a) => a.id == _selectedAuthorId) ? _selectedAuthorId : null;

                  const addNewValue = '__add_new_author__';

                  return DropdownButtonFormField<String>(
                    value: validSelection,
                    decoration: const InputDecoration(
                      labelText: 'Author',
                      border: OutlineInputBorder(),
                    ),
                    hint: authors.isEmpty
                        ? const Text('No authors yet — add one below')
                        : const Text('Select an author'),
                    items: [
                      ...authors.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))),
                      const DropdownMenuItem(
                        value: addNewValue,
                        child: Row(
                          children: [
                            Icon(Icons.add, size: 18),
                            SizedBox(width: 6),
                            Text('Add New Author'),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (v) async {
                      if (v == addNewValue) {
                        final newAuthorId = await _showAddAuthorDialog();
                        if (newAuthorId != null) {
                          setState(() => _selectedAuthorId = newAuthorId);
                        }
                      } else {
                        setState(() => _selectedAuthorId = v);
                      }
                    },
                  );
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _isbnController,
                decoration: const InputDecoration(labelText: 'ISBN', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _genreController,
                decoration: const InputDecoration(labelText: 'Genre', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _copiesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Copies Available',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || int.tryParse(v) == null) ? 'Enter a number' : null,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_isEditing ? 'Save Changes' : 'Add Book'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
