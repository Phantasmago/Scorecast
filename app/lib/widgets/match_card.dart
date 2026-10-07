import 'package:flutter/material.dart';
import '../contracts/models.dart';

class MatchCard extends StatelessWidget {
  final SportMatch match;
  final VoidCallback? onTap;
  const MatchCard({super.key, required this.match, this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = match.score;
    final scoreText = s.displayScore ??
        (s.home != null && s.away != null ? '${s.home} – ${s.away}' : 'vs');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(child: Text(match.home.name, overflow: TextOverflow.ellipsis)),
              Column(
                children: [
                  Text(scoreText, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (match.isLive)
                        Container(
                          width: 7, height: 7,
                          margin: const EdgeInsets.only(right: 4),
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        ),
                      Text(match.displayStatus(),
                          style: TextStyle(
                              fontSize: 12,
                              color: match.isLive ? Colors.red : Theme.of(context).hintColor)),
                    ],
                  ),
                ],
              ),
              Expanded(
                  child: Text(match.away.name,
                      textAlign: TextAlign.right, overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      ),
    );
  }
}
