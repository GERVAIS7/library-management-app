import 'package:flutter/material.dart';
import '../models/author.dart';
import '../services/firestore_service.dart';

class AuthorsScreen extends StatefulWidget {
  const AuthorsScreen({super.key});

  @override
  State<AuthorsScreen> createState() => _AuthorsScreenState();
}

class _AuthorsScreenState extends State<AuthorsScreen> {
  late final Stream<List<Author>> _authorsStream;
  final _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _authorsStream = _firestoreService.streamAuthors();
  }

  /// Used for BOTH adding a new author and editing an existing one.
  /// Pass [existing] to edit it; leave null to create a new one.
  void _showAuthorDialog({Author? existing}) {
    final isEditing = existing != null;
    final nameController = TextEditingController(text: existing?.name ?? '');
    final yearController =
        TextEditingController(text: existing != null ? existing.birthYear.toString() : '');
    final nationalityController = TextEditingController(text: existing?.nationality ?? '');
    final bioController = TextEditingController(text: existing?.bio ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEditing ? 'Edit Author' : 'Add Author'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
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
              TextField(
                controller: bioController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Bio (optional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;

              if (isEditing) {
                final updated = Author(
                  id: existing.id,
                  name: nameController.text.trim(),
                  birthYear: int.tryParse(yearController.text) ?? existing.birthYear,
                  nationality: nationalityController.text.trim(),
                  bio: bioController.text.trim(),
                  photoUrl: existing.photoUrl,
                );
                await _firestoreService.updateAuthor(updated);
              } else {
                await _firestoreService.addAuthor(Author(
                  id: '',
                  name: nameController.text.trim(),
                  birthYear: int.tryParse(yearController.text) ?? 0,
                  nationality: nationalityController.text.trim(),
                  bio: bioController.text.trim(),
                ));
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(isEditing ? 'Save' : 'Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(Author author) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Author?'),
        content: Text(
          'This will permanently remove "${author.name}". '
          'Any books referencing this author will keep the old author ID. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _firestoreService.deleteAuthor(author.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<Author>>(
        stream: _authorsStream,
        builder: (context, snapshot) {
          final authors = snapshot.data ?? [];
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (authors.isEmpty) {
            return const Center(child: Text('No authors yet. Tap + to add one.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: authors.length,
            itemBuilder: (context, index) {
              final author = authors[index];
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(author.name),
                  subtitle: Text('${author.nationality} · b. ${author.birthYear}'),
                  onTap: () => _showAuthorDialog(existing: author),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _confirmDelete(author),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAuthorDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
