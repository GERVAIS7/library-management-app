import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

/// Read + Update screen for the authenticated User's own profile document.
/// Registration (Create) happens on sign-up; this closes the loop so the
/// User entity gets full CRUD like Book, Author, and Loan.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  final _firestoreService = FirestoreService();

  late Future<AppUser?> _userFuture;
  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();

  bool _isSaving = false;
  AppUser? _loadedUser;

  @override
  void initState() {
    super.initState();
    _userFuture = _loadUser();
  }

  Future<AppUser?> _loadUser() async {
    final uid = _authService.currentUser!.uid;
    final user = await _firestoreService.getUser(uid);
    if (user != null) {
      _loadedUser = user;
      _displayNameController.text = user.displayName;
      _bioController.text = user.bio;
    }
    return user;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _loadedUser == null) return;
    setState(() => _isSaving = true);
    try {
      final updated = AppUser(
        uid: _loadedUser!.uid,
        displayName: _displayNameController.text.trim(),
        email: _loadedUser!.email,
        bio: _bioController.text.trim(),
        photoUrl: _loadedUser!.photoUrl,
        memberSince: _loadedUser!.memberSince,
      );
      await _firestoreService.updateUser(updated);
      // Keep Firebase Auth's own display name in sync too.
      await _authService.currentUser!.updateDisplayName(updated.displayName);

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Profile updated.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to update: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: FutureBuilder<AppUser?>(
        future: _userFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final user = snapshot.data;
          if (user == null) {
            return const Center(child: Text('Profile not found.'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const CircleAvatar(radius: 40, child: Icon(Icons.person, size: 40)),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _displayNameController,
                    decoration: const InputDecoration(
                      labelText: 'Display Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: user.email,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Email (cannot be changed here)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _bioController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Bio',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Member since ${DateFormat.yMMMd().format(user.memberSince)}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save Changes'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
