import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/app_state.dart';
import '../services/pet_state_resolver.dart';
import 'pixel_pet.dart';

/// Loads a plant's stored avatar bytes (if any) and renders the pet
/// with its current mood. Falls back to the code-drawn pet while
/// loading or when there is no avatar.
///
/// The avatar future is cached per widget, not rebuilt per build:
/// the old stateless version created a new [FutureBuilder] future on
/// every home-screen rebuild (every weather refresh, every water
/// tap), re-reading the file / base64 store for every pet and
/// flashing the code-drawn pet in between. Now it loads once per
/// plant and only reloads when the plant id changes.
class AvatarPet extends StatefulWidget {
  const AvatarPet({
    super.key,
    required this.state,
    required this.plantId,
    required this.mood,
    this.size = 220,
    this.celebrating = false,
    this.windy = false,
  });

  final AppState state;
  final String plantId;
  final PetMood mood;
  final double size;
  final bool celebrating;

  /// Wind effects layer (see PixelPet.windy).
  final bool windy;

  @override
  State<AvatarPet> createState() => _AvatarPetState();
}

class _AvatarPetState extends State<AvatarPet> {
  late Future<Uint8List?> _avatarFuture;

  @override
  void initState() {
    super.initState();
    _avatarFuture = widget.state.photos.readAvatar(widget.plantId);
  }

  @override
  void didUpdateWidget(covariant AvatarPet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.plantId != widget.plantId) {
      _avatarFuture = widget.state.photos.readAvatar(widget.plantId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _avatarFuture,
      builder: (context, snapshot) {
        return PixelPet(
          mood: widget.mood,
          avatarBytes: snapshot.data,
          size: widget.size,
          celebrating: widget.celebrating,
          windy: widget.windy,
        );
      },
    );
  }
}
