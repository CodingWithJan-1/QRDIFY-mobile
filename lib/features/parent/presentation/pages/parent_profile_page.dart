import '../../../../core/storage/private_file_picker.dart';

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/images/profile_photo_processor.dart';
import '../../../../shared/presentation/user_profile_avatar.dart';
import '../../../auth/domain/auth_user.dart';
import '../widgets/parent_design.dart';

class ParentProfilePage extends StatefulWidget {
  const ParentProfilePage({
    required this.user,
    required this.onUploadPhoto,
    required this.onRemovePhoto,
    super.key,
  });

  final AuthUser user;
  final Future<AuthUser> Function(List<int> bytes) onUploadPhoto;
  final Future<AuthUser> Function() onRemovePhoto;

  @override
  State<ParentProfilePage> createState() => _ParentProfilePageState();
}

class _ParentProfilePageState extends State<ParentProfilePage> {
  late AuthUser _user = widget.user;
  Uint8List? _draft;
  bool _busy = false;
  String? _error;
  String? _message;

  Future<void> _choosePhoto() async {
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      final file = await PrivateFilePicker.pickFile(
        maxBytes: ProfilePhotoProcessor.maxSourceBytes,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      );
      if (file == null) return;
      final length = await file.length();
      if (length > ProfilePhotoProcessor.maxSourceBytes) {
        throw const FormatException('Choose a photo no larger than 10 MiB.');
      }
      final photo = await ProfilePhotoProcessor.prepare(
        await file.readAsBytes(),
      );
      if (mounted) setState(() => _draft = photo);
    } catch (error) {
      if (mounted) setState(() => _error = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _savePhoto() async {
    final photo = _draft;
    if (photo == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      final user = await widget.onUploadPhoto(photo);
      if (mounted) {
        setState(() {
          _user = user;
          _draft = null;
          _message = 'Profile photo saved.';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removePhoto() async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove profile photo?'),
        content: const Text('Your initials will appear in your account menu.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      final user = await widget.onRemovePhoto();
      if (mounted) {
        setState(() {
          _user = user;
          _draft = null;
          _message = 'Profile photo removed.';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      backgroundColor: ParentDesign.background,
      appBar: AppBar(title: const Text('My profile')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: _draft == null
                ? UserProfileAvatar(
                    name: _user.name,
                    photoUrl: _user.photoUrl,
                    radius: 56,
                  )
                : ClipOval(
                    child: Image.memory(
                      _draft!,
                      width: 112,
                      height: 112,
                      fit: BoxFit.cover,
                    ),
                  ),
          ),
          const SizedBox(height: 20),
          Text(
            _user.name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          Text(_user.displayIdentifier, textAlign: TextAlign.center),
          const SizedBox(height: 28),
          const Text(
            'Profile photo',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose a JPG, PNG or WebP up to 10 MiB. Photos are resized and compressed automatically.',
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _busy ? null : _choosePhoto,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('Choose photo'),
          ),
          if (_draft != null) ...[
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _savePhoto,
              child: const Text('Save photo'),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                      _draft = null;
                      _error = null;
                      _message = null;
                    }),
              child: const Text('Cancel selection'),
            ),
          ],
          if (_user.photoUrl != null)
            TextButton(
              onPressed: _busy ? null : _removePhoto,
              child: const Text('Remove photo'),
            ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _message!,
                style: const TextStyle(color: Colors.green),
              ),
            ),
        ],
      ),
    ),
  );

  String _errorMessage(Object error) => switch (error) {
    ApiException exception => exception.message,
    FormatException exception => exception.message,
    _ => 'Unable to update your photo. Please try again.',
  };
}
