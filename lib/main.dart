import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/app_state.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const PlantPalLoader());
}

/// Loads on-device state, then hands the app over. The pet renders
/// before weather or battery arrive — those refresh in the background.
class PlantPalLoader extends StatelessWidget {
  const PlantPalLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PlantPal',
      theme: plantTheme(),
      home: FutureBuilder<AppState>(
        future: AppState.create(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Scaffold(
              body: Center(
                child: Text('PlantPal could not start. Try reopening it.'),
              ),
            );
          }
          final state = snapshot.data;
          if (state == null) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return HomeScreen(state: state);
        },
      ),
    );
  }
}

/// Entry point used by widget tests and golden previews, where the
/// state is already built.
class PlantPalApp extends StatelessWidget {
  const PlantPalApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PlantPal',
      theme: plantTheme(),
      home: HomeScreen(state: state),
    );
  }
}
