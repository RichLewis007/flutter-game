import 'dart:math';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/collisions.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  final game = MyGame();
  runApp(GameWidget(game: game));
}

class MyGame extends FlameGame
    with HasCollisionDetection, KeyboardEvents, HasDraggables, HasTappables {
  late SpriteComponent player;
  late TextComponent scoreText;
  final double speed = 200;
  int score = 0;
  final Random rng = Random();

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final sprite = await loadSprite('player.png');
    player = SpriteComponent()
      ..sprite = sprite
      ..size = Vector2(64, 64)
      ..x = size.x / 4
      ..y = size.y / 2;
    player.add(RectangleHitbox());
    add(player);

    scoreText = TextComponent(
      text: 'Score: 0',
      position: Vector2(10, 10),
      anchor: Anchor.topLeft,
      textRenderer: TextPaint(style: const TextStyle(color: Colors.white, fontSize: 24)),
    );
    add(scoreText);

    final joystick = JoystickComponent(
      knob: CircleComponent(radius: 20, paint: Paint()..color = const Color(0xFF0000FF)),
      background: CircleComponent(radius: 50, paint: Paint()..color = const Color(0x770000FF)),
      margin: const EdgeInsets.only(left: 40, bottom: 40),
    );
    add(joystick);
    add(PlayerController(player, joystick));

    spawnObstacles(3);
  }

  void spawnObstacles(int count) async {
    final obstacleSprite = await loadSprite('obstacle.png');
    for (int i = 0; i < count; i++) {
      final obstacle = SpriteComponent()
        ..sprite = obstacleSprite
        ..size = Vector2(64, 64)
        ..x = rng.nextDouble() * (size.x - 64)
        ..y = rng.nextDouble() * (size.y - 64);
      obstacle.add(RectangleHitbox());
      add(obstacle);
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    if (other is SpriteComponent && other != player) {
      score += 1;
      scoreText.text = 'Score: $score';
      resetGame();
    }
  }

  void resetGame() {
    player.x = size.x / 4;
    player.y = size.y / 2;
    // Remove all existing obstacles and respawn new ones
    children.whereType<SpriteComponent>().where((c) => c != player).forEach((c) => c.removeFromParent());
    spawnObstacles(3 + rng.nextInt(3)); // Increase difficulty with 3-5 obstacles
  }

  @override
  KeyEventResult onKeyEvent(
      RawKeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        player.y -= 10;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        player.y += 10;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        player.x -= 10;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        player.x += 10;
      }
    }
    return KeyEventResult.handled;
  }
}

class PlayerController extends Component with HasGameRef<MyGame> {
  final SpriteComponent player;
  final JoystickComponent joystick;

  PlayerController(this.player, this.joystick);

  @override
  void update(double dt) {
    super.update(dt);
    if (joystick.direction != JoystickDirection.idle) {
      player.position.add(joystick.relativeDelta * 200 * dt);
    }
  }
}
