import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'game/vagoneiro_arena_game.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'O Vagoneiro',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: GameWidget(game: VagoneiroArenaGame()),
      ),
    );
  }
}
