import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'phases/phase_registry.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // There is no hub yet ("O Repositório"), so the app opens the first
    // registered phase directly — the same game it always opened.
    final phase = phaseRegistry.first;
    return MaterialApp(
      title: phase.bossName,
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: GameWidget(game: phase.createGame()),
      ),
    );
  }
}
