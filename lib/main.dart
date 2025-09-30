import 'dart:math';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/collisions.dart';
import 'package:flame/input.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Preload audio
  await FlameAudio.audioCache.loadAll([
    'bgm.wav', 'hit.wav', 'powerup.wav', 'boss_down.wav'
  ]);
  FlameAudio.bgm.initialize();

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
  late TextComponent levelText;
  late TextComponent gameOverText;

  final double baseSpeed = 200;
  int score = 0;
  int lives = 3;
  int level = 1;
  double difficultyMultiplier = 1.0;
  final Random rng = Random();
  bool isGameOver = false;
  bool invincible = false;
  double invincibleTimer = 0;
  bool isPaused = false;
  bool bossActive = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
  }

  void startGame() {
    score = 0;
    lives = 3;
    level = 1;
    difficultyMultiplier = 1.0;
    invincible = false;
    isGameOver = false;
    isPaused = false;
    bossActive = false;
    children.clear();

    addPlayer();
    addHUD();
    spawnWave();
    spawnPowerUp();

    // Start background music (loop)
    FlameAudio.bgm.stop();
    FlameAudio.bgm.play('bgm.wav', volume: 0.4);
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

    levelText = TextComponent(
      text: 'Level: 1',
      position: Vector2(10, 70),
      anchor: Anchor.topLeft,
      textRenderer: TextPaint(style: const TextStyle(color: Colors.yellow, fontSize: 24)),
    );
    add(levelText);

    gameOverText = TextComponent(
      text: 'GAME OVER\nTap to Restart',
      anchor: Anchor.center,
      position: size / 2,
      textRenderer: TextPaint(style: const TextStyle(color: Colors.red, fontSize: 48)),
    );
  }

  void spawnWave() {
    children.whereType<MovingObstacle>().forEach((c) => c.removeFromParent());
    children.whereType<Boss>().forEach((c) => c.removeFromParent());
    bossActive = false;

    if (level % 5 == 0) {
      spawnBoss();
    } else {
      spawnObstacles(level + 2);
    }
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
        speed: (120 + rng.nextInt(160)) * difficultyMultiplier,
        screenSize: size,
      );
      obstacle.add(RectangleHitbox());
      add(obstacle);
    }
  }

  void spawnBoss() async {
    final bossSprite = await loadSprite('boss.png');
    final boss = Boss(
      sprite: bossSprite,
      position: Vector2(size.x * 0.65, size.y * 0.5),
      speed: 200 * difficultyMultiplier,
      screenSize: size,
      hp: 3 + (level ~/ 5),
    );
    boss.add(RectangleHitbox());
    add(boss);
    bossActive = true;
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

    // Advance level if cleared
    if (!bossActive && children.whereType<MovingObstacle>().isEmpty) {
      nextLevel();
    }
    if (bossActive && children.whereType<Boss>().isEmpty) {
      // Boss defeated
      score += 2;
      lives += 2;
      livesText.text = 'Lives: $lives';
      FlameAudio.play('boss_down.wav');
      nextLevel();
    }
  }

  void nextLevel() {
    level += 1;
    levelText.text = 'Level: $level';
    difficultyMultiplier += 0.3;
    spawnWave();
  }

  void pauseGame() {
    isPaused = true;
    FlameAudio.bgm.pause();
    overlays.add('PauseMenu');
  }

  void resumeGame() {
    isPaused = false;
    FlameAudio.bgm.resume();
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    if (isPaused || isGameOver) return;

    if (other is MovingObstacle) {
      if (invincible) return;
      score += 1;
      scoreText.text = 'Score: $score';
      lives -= 1;
      livesText.text = 'Lives: $lives';
      FlameAudio.play('hit.wav');
      resetPlayer();
      if (lives <= 0) {
        triggerGameOver();
      }
    } else if (other is Boss) {
      if (invincible) return;
      other.hp -= 1;
      lives -= 1;
      livesText.text = 'Lives: $lives';
      FlameAudio.play('hit.wav');
      if (lives <= 0) {
        triggerGameOver();
      }
      if (other.hp <= 0) {
        other.removeFromParent();
        bossActive = false;
      }
      resetPlayer();
    } else if (other is PowerUp) {
      if (other.type == PowerUpType.extraLife) {
        lives += 1;
      } else if (other.type == PowerUpType.invincibility) {
        invincible = true;
        invincibleTimer = 5.0;
      }
      livesText.text = 'Lives: $lives';
      FlameAudio.play('powerup.wav');
      other.removeFromParent();
      Future.delayed(const Duration(seconds: 8), () => spawnPowerUp());
    }
  }

  void triggerGameOver() {
    isGameOver = true;
    FlameAudio.bgm.stop();
    add(gameOverText);
  }

  void resetPlayer() {
    player.x = size.x / 4;
    player.y = size.y / 2;
  }

  @override
  bool onTapDown(TapDownInfo info) {
    if (isGameOver) {
      startGame();
    }
    return super.onTapDown(info);
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
    if (x < 0 || x + width > screenSize.x) direction.x *= -1;
    if (y < 0 || y + height > screenSize.y) direction.y *= -1;
  }
}

class Boss extends SpriteComponent with CollisionCallbacks {
  final double speed;
  final Vector2 screenSize;
  int hp;
  Vector2 direction = Vector2.zero();
  final Random rng = Random();

  Boss({
    required Sprite sprite,
    required Vector2 position,
    required this.speed,
    required this.screenSize,
    required this.hp,
  }) : super(sprite: sprite, position: position, size: Vector2(120, 120)) {
    direction = Vector2(rng.nextDouble() * 2 - 1, rng.nextDouble() * 2 - 1).normalized();
  }

  @override
  void update(double dt) {
    super.update(dt);
    position += direction * speed * dt;
    if (x < 0 || x + width > screenSize.x) direction.x *= -1;
    if (y < 0 || y + height > screenSize.y) direction.y *= -1;
  }
}

class PowerUp extends SpriteComponent with CollisionCallbacks {
  final PowerUpType type;
  PowerUp({required Sprite sprite, required Vector2 position, required this.type})
      : super(sprite: sprite, position: position, size: Vector2(48, 48));
}
