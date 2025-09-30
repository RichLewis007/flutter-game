import 'dart:math';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/collisions.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  final game = MyGame();
  runApp(GameWidget(game: game, overlayBuilderMap: {
    'MainMenu': (context, game) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                game.overlays.remove('MainMenu');
                game.startGame();
              },
              child: const Text('Start Game'),
            ),
          ],
        ),
      );
    },
    'PauseMenu': (context, game) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Paused', style: TextStyle(fontSize: 32, color: Colors.white)),
            ElevatedButton(
              onPressed: () {
                game.overlays.remove('PauseMenu');
                game.resumeGame();
              },
              child: const Text('Resume'),
            ),
          ],
        ),
      );
    }
  }, initialActiveOverlays: const ['MainMenu']));
}

enum PowerUpType { extraLife, invincibility }

class MyGame extends FlameGame
    with HasCollisionDetection, KeyboardEvents, HasDraggables, HasTappables {
  late SpriteComponent player;
  late TextComponent scoreText;
  late TextComponent livesText;
  late TextComponent gameOverText;
  final double baseSpeed = 200;
  int score = 0;
  int lives = 3;
  double difficultyMultiplier = 1.0;
  final Random rng = Random();
  bool isGameOver = false;
  bool invincible = false;
  double invincibleTimer = 0;
  bool isPaused = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
  }

  void startGame() {
    score = 0;
    lives = 3;
    difficultyMultiplier = 1.0;
    invincible = false;
    isGameOver = false;
    isPaused = false;
    children.clear();

    addPlayer();
    addHUD();
    spawnObstacles(3);
    spawnPowerUp();
  }

  void addPlayer() async {
    final sprite = await loadSprite('player.png');
    player = SpriteComponent()
      ..sprite = sprite
      ..size = Vector2(64, 64)
      ..x = size.x / 4
      ..y = size.y / 2;
    player.add(RectangleHitbox());
    add(player);

    final joystick = JoystickComponent(
      knob: CircleComponent(radius: 20, paint: Paint()..color = const Color(0xFF0000FF)),
      background: CircleComponent(radius: 50, paint: Paint()..color = const Color(0x770000FF)),
      margin: const EdgeInsets.only(left: 40, bottom: 40),
    );
    add(joystick);
    add(PlayerController(player, joystick, () => baseSpeed * difficultyMultiplier));
  }

  void addHUD() {
    scoreText = TextComponent(
      text: 'Score: 0',
      position: Vector2(10, 10),
      anchor: Anchor.topLeft,
      textRenderer: TextPaint(style: const TextStyle(color: Colors.white, fontSize: 24)),
    );
    add(scoreText);

    livesText = TextComponent(
      text: 'Lives: 3',
      position: Vector2(10, 40),
      anchor: Anchor.topLeft,
      textRenderer: TextPaint(style: const TextStyle(color: Colors.white, fontSize: 24)),
    );
    add(livesText);

    gameOverText = TextComponent(
      text: 'GAME OVER\nTap to Restart',
      anchor: Anchor.center,
      position: size / 2,
      textRenderer: TextPaint(style: const TextStyle(color: Colors.red, fontSize: 48)),
    );
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

  void spawnPowerUp() async {
    final powerSprite = await loadSprite('powerup.png');
    final type = rng.nextBool() ? PowerUpType.extraLife : PowerUpType.invincibility;
    final powerUp = PowerUp(
      sprite: powerSprite,
      position: Vector2(rng.nextDouble() * (size.x - 64), rng.nextDouble() * (size.y - 64)),
      type: type,
    );
    powerUp.add(RectangleHitbox());
    add(powerUp);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isPaused || isGameOver) return;

    if (invincible) {
      invincibleTimer -= dt;
      if (invincibleTimer <= 0) {
        invincible = false;
      }
    }
  }

  void pauseGame() {
    isPaused = true;
    overlays.add('PauseMenu');
  }

  void resumeGame() {
    isPaused = false;
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    if (isPaused || isGameOver) return;

    if (other is MovingObstacle) {
      if (invincible) return;
      score += 1;
      lives -= 1;
      scoreText.text = 'Score: $score';
      livesText.text = 'Lives: $lives';

      if (lives <= 0) {
        triggerGameOver();
      } else {
        difficultyMultiplier += 0.2;
        resetGame();
      }
    } else if (other is PowerUp) {
      if (other.type == PowerUpType.extraLife) {
        lives += 1;
      } else if (other.type == PowerUpType.invincibility) {
        invincible = true;
        invincibleTimer = 5.0;
      }
      livesText.text = 'Lives: $lives';
      other.removeFromParent();
      Future.delayed(const Duration(seconds: 8), () => spawnPowerUp());
    }
  }

  void triggerGameOver() {
    isGameOver = true;
    add(gameOverText);
  }

  void resetGame() {
    player.x = size.x / 4;
    player.y = size.y / 2;
    children.whereType<MovingObstacle>().forEach((c) => c.removeFromParent());
    spawnObstacles(3 + rng.nextInt(3));
  }

  @override
  KeyEventResult onKeyEvent(
      RawKeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        if (!isPaused && !isGameOver) {
          pauseGame();
        }
      }
      if (!isGameOver && !isPaused) {
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

    if (x < 0 || x + width > screenSize.x) {
      direction.x *= -1;
    }
    if (y < 0 || y + height > screenSize.y) {
      direction.y *= -1;
    }
  }
}

class PowerUp extends SpriteComponent with CollisionCallbacks {
  final PowerUpType type;
  PowerUp({required Sprite sprite, required Vector2 position, required this.type})
      : super(sprite: sprite, position: position, size: Vector2(48, 48));
}
