import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/app_state.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const PlantPalLoader());
}

/// Loads on-device state, then hands the app over. The pet renders
/// before weather or battery arrive — those refresh in the background.
///
/// Stateful so the load future is created once: a stateless loader
/// calling AppState.create() in build would restart the whole load
/// (prefs, notifications, weather) on any rebuild above it.
class PlantPalLoader extends StatefulWidget {
  const PlantPalLoader({super.key});

  @override
  State<PlantPalLoader> createState() => _PlantPalLoaderState();
}

class _PlantPalLoaderState extends State<PlantPalLoader> {
  late final Future<AppState> _stateFuture = AppState.create();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PlantPal',
      theme: plantTheme(),
      home: FutureBuilder<AppState>(
        future: _stateFuture,
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
