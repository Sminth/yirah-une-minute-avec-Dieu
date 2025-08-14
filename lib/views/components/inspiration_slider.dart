import 'dart:async';

import 'package:flutter/material.dart';

class InspirationSlider extends StatefulWidget {
  const InspirationSlider({super.key, this.messages, this.interval});

  final List<String>? messages;
  final Duration? interval;

  @override
  State<InspirationSlider> createState() => _InspirationSliderState();
}

class _InspirationSliderState extends State<InspirationSlider>
    with TickerProviderStateMixin {
  late final PageController _controller;
  Timer? _auto;
  int _index = 0;

  List<String> get _messages =>
      widget.messages ??
      const [
        "Mon enfant, le temps n'est qu'une variable. Je t'aime simplement. Si tu n'as qu'une minute pour moi, cela me va.",
        "Je suis avec toi dans le silence comme dans la louange.",
        "Repose-toi en moi, car je suis ta paix.",
        "Approche-toi, et je m'approcherai de toi.",
        "Je t'aime.",
      ];

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _startAuto();
  }

  void _startAuto() {
    _auto?.cancel();
    _auto = Timer.periodic(widget.interval ?? const Duration(seconds: 20), (_) {
      if (!mounted) return;
      final int next = (_index + 1) % _messages.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _auto?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 84,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              physics: const BouncingScrollPhysics(),
              onPageChanged: (i) => setState(() => _index = i),
              itemCount: _messages.length,
              itemBuilder: (context, i) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      child: Text(
                        _messages[i],
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _messages.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _index == i ? 10 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _index == i
                      ? (isDark ? Colors.white70 : Colors.black54)
                      : (isDark ? Colors.white24 : Colors.black26),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}
