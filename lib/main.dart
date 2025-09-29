import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

void main() {
  final game = MyGame();
  runApp(GameWidget(game: game));
}

class MyGame extends FlameGame {
  late SpriteComponent player;

  @override
  Future<void> onLoad() async {
    final sprite = await loadSprite('player.png');
    player = SpriteComponent()
      ..sprite = sprite
      ..size = Vector2(100, 100)
      ..x = size.x / 2 - 50
      ..y = size.y / 2 - 50;
    add(player);
  }

  @override
  void update(double dt) {
    super.update(dt);
    // Move player slowly to the right
    player.x += 50 * dt;
  }
}
