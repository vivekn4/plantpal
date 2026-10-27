import 'package:flutter/material.dart';

import '../services/app_state.dart';
import '../services/pet_state_resolver.dart';
import 'pixel_pet.dart';

/// Loads a plant's stored avatar bytes (if any) and renders the pet
/// with its current mood. Falls back to the code-drawn pet while
/// loading or when there is no avatar.
class AvatarPet extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: state.photos.readAvatar(plantId),
      builder: (context, snapshot) {
        return PixelPet(
          mood: mood,
          avatarBytes: snapshot.data,
          size: size,
          celebrating: celebrating,
          windy: windy,
        );
      },
    );
  }
}
