import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';

class SnakeGame extends StatefulWidget {
  const SnakeGame({super.key});

  @override
  State<SnakeGame> createState() => _SnakeGameState();
}

class _SnakeGameState extends State<SnakeGame> {
  static const int gridSize = 15;
  static const Duration tickDuration = Duration(milliseconds: 250);

  List<Point<int>> _snake = [];
  Point<int> _food = const Point(0, 0);
  int _direction = 0; // 0=up, 1=right, 2=down, 3=left
  int _score = 0;
  int _highScore = 0;
  bool _isGameOver = false;
  bool _isPaused = false;
  Timer? _timer;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _startGame();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startGame() {
    _snake = [
      const Point(7, 7),
      const Point(7, 8),
      const Point(7, 9),
    ];
    _direction = 0;
    _score = 0;
    _isGameOver = false;
    _isPaused = false;
    _placeFood();
    _timer?.cancel();
    _timer = Timer.periodic(tickDuration, (_) => _tick());
    setState(() {});
  }

  void _placeFood() {
    while (true) {
      final p = Point(_random.nextInt(gridSize), _random.nextInt(gridSize));
      if (!_snake.contains(p)) {
        _food = p;
        return;
      }
    }
  }

  void _tick() {
    if (_isGameOver || _isPaused) return;

    setState(() {
      final head = _snake.first;
      Point<int> newHead;
      switch (_direction) {
        case 0: // up
          newHead = Point(head.x, head.y - 1);
          break;
        case 1: // right
          newHead = Point(head.x + 1, head.y);
          break;
        case 2: // down
          newHead = Point(head.x, head.y + 1);
          break;
        case 3: // left
          newHead = Point(head.x - 1, head.y);
          break;
        default:
          newHead = head;
      }

      // Wall collision
      if (newHead.x < 0 || newHead.x >= gridSize || newHead.y < 0 || newHead.y >= gridSize) {
        _gameOver();
        return;
      }

      // Self collision
      if (_snake.contains(newHead)) {
        _gameOver();
        return;
      }

      _snake.insert(0, newHead);

      if (newHead == _food) {
        _score += 10;
        _placeFood();
      } else {
        _snake.removeLast();
      }
    });
  }

  void _gameOver() {
    _isGameOver = true;
    _timer?.cancel();
    if (_score > _highScore) _highScore = _score;
    setState(() {});
  }

  void _changeDirection(int newDir) {
    if ((_direction - newDir).abs() == 2) return; // منع العكس
    _direction = newDir;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1116),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E1116),
        title: const Text('🐍 لعبة الدودة', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause, color: Colors.white),
            onPressed: () => setState(() => _isPaused = !_isPaused),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _startGame,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildScore('النقاط', _score, const Color(0xFF10A37F)),
                _buildScore('الأعلى', _highScore, const Color(0xFF764ba2)),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF10A37F), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10A37F).withValues(alpha: 0.2),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: gridSize,
                        ),
                        itemCount: gridSize * gridSize,
                        itemBuilder: (context, index) {
                          final x = index % gridSize;
                          final y = index ~/ gridSize;
                          final p = Point(x, y);

                          Color color;
                          if (_snake.first == p) {
                            color = const Color(0xFF10A37F);
                          } else if (_snake.contains(p)) {
                            color = const Color(0xFF10A37F).withValues(alpha: 0.7);
                          } else if (_food == p) {
                            color = const Color(0xFFFF6B6B);
                          } else {
                            color = Colors.transparent;
                          }

                          return Container(
                            margin: const EdgeInsets.all(1),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        },
                      ),
                      if (_isGameOver)
                        Container(
                          color: Colors.black.withValues(alpha: 0.7),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'انتهت اللعبة!',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'نقاطك: $_score',
                                  style: const TextStyle(color: Colors.white70, fontSize: 20),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  onPressed: _startGame,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('العب مرة أخرى'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10A37F),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          _buildControls(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildScore(String label, int score, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 14)),
        const SizedBox(height: 4),
        Text(
          '$score',
          style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _controlButton(Icons.keyboard_arrow_up, 0),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _controlButton(Icons.keyboard_arrow_left, 3),
            const SizedBox(width: 60),
            _controlButton(Icons.keyboard_arrow_right, 1),
          ],
        ),
        _controlButton(Icons.keyboard_arrow_down, 2),
      ],
    );
  }

  Widget _controlButton(IconData icon, int direction) {
    return Container(
      margin: const EdgeInsets.all(4),
      child: Material(
        color: const Color(0xFF10A37F).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _changeDirection(direction),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            child: Icon(icon, color: const Color(0xFF10A37F), size: 32),
          ),
        ),
      ),
    );
  }
}
