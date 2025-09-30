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
  final double baseSpeed = 200;
  int score = 0;
  double difficultyMultiplier = 1.0;
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
    add(PlayerController(player, joystick, () => baseSpeed * difficultyMultiplier));

    spawnObstacles(3);
  }

  void spawnObstacles(int count) async {
    final obstacleSprite = await loadSprite('obstacle.png');
    for (int i = 0; i < count; i++) {
      final obstacle = MovingObstacle(
        sprite: obstacleSprite,
        position: Vector2(
          rng.nextDouble() * (size.x - 64),
          rng.nextDouble() * (size.y - 64),
        ),
        speed: (100 + rng.nextInt(150)) * difficultyMultiplier,
        screenSize: size,
      );
      obstacle.add(RectangleHitbox());
      add(obstacle);
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    if (other is MovingObstacle) {
      score += 1;
      scoreText.text = 'Score: $score';
      difficultyMultiplier += 0.2; // increase difficulty
      resetGame();
    }
  }

  void resetGame() {
    player.x = size.x / 4;
    player.y = size.y / 2;
    // Remove obstacles and respawn more with higher speed
    children.whereType<MovingObstacle>().forEach((c) => c.removeFromParent());
    spawnObstacles(3 + rng.nextInt(3)); // 3-5 moving obstacles
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
  final double Function() speedProvider;

  PlayerController(this.player, this.joystick, this.speedProvider);

  @override
  void update(double dt) {
    super.update(dt);
    if (joystick.direction != JoystickDirection.idle) {
      player.position.add(joystick.relativeDelta * speedProvider() * dt);
    }
  }
}

class MovingObstacle extends SpriteComponent with CollisionCallbacks {
  final double speed;
  final Vector2 screenSize;
  Vector2 direction = Vector2.zero();
  final Random rng = Random();

  MovingObstacle({
    required Sprite sprite,
    required Vector2 position,
    required this.speed,
    required this.screenSize,
  }) : super(sprite: sprite, position: position, size: Vector2(64, 64)) {
    direction = Vector2(rng.nextDouble() * 2 - 1, rng.nextDouble() * 2 - 1).normalized();
  }

  @override
  void update(double dt) {
    super.update(dt);
    position += direction * speed * dt;

    // Bounce off screen edges
    if (x < 0 || x + width > screenSize.x) {
      direction.x *= -1;
    }
    if (y < 0 || y + height > screenSize.y) {
      direction.y *= -1;
    }
  }
}
