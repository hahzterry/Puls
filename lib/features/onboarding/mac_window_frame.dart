import 'package:flutter/material.dart';

class MacWindowFrame extends StatelessWidget {
  const MacWindowFrame({required this.title, required this.child, super.key});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black12),
          boxShadow: [
            BoxShadow(blurRadius: 40, color: Colors.black.withValues(alpha: 0.15)),
          ],
        ),
        child: Column(children: [
          Container(
            height: 36,
            color: const Color(0xFFEDEDED),
            child: Row(children: [
              const SizedBox(width: 14),
              for (final c in [Colors.red, Colors.amber, Colors.green])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: CircleAvatar(radius: 5, backgroundColor: c),
                ),
              const Spacer(),
              Text(title, style: const TextStyle(fontSize: 12, color: Colors.black45)),
              const Spacer(flex: 2),
            ]),
          ),
          Expanded(child: child),
        ]),
      ),
    );
  }
}

Widget liveAppPreview({required Widget screen, double width = 390, double height = 844}) {
  return FittedBox(
    fit: BoxFit.contain,
    child: SizedBox(
      width: width,
      height: height,
      child: MacWindowFrame(title: 'Puls', child: screen),
    ),
  );
}
