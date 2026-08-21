import 'package:flutter/material.dart';

import '../../domain/requests/snow_request.dart';
import '../theme/yukitas_colors.dart';

class RequestProgressIndicator extends StatelessWidget {
  const RequestProgressIndicator({
    required this.status,
    super.key,
    this.includeCompleted = false,
  });

  final RequestStatus status;
  final bool includeCompleted;

  int get _activeIndex => switch (status) {
    RequestStatus.draft || RequestStatus.waiting || RequestStatus.matched => 0,
    RequestStatus.moving => 1,
    RequestStatus.arrived => 2,
    RequestStatus.working || RequestStatus.reviewing => 3,
    RequestStatus.completed => 4,
    RequestStatus.cancelled ||
    RequestStatus.disputed ||
    RequestStatus.expired => 0,
  };

  @override
  Widget build(BuildContext context) {
    final labels =
        includeCompleted
            ? const ['受注', '移動中', '到着', '作業', '完了']
            : const ['受注', '移動中', '到着', '作業'];
    final activeIndex = _activeIndex.clamp(0, labels.length - 1);

    return Semantics(
      label: '進捗 ${labels[activeIndex]}',
      child: Column(
        children: [
          SizedBox(
            height: 32,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final slotWidth = constraints.maxWidth / labels.length;
                return Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Positioned(
                      left: slotWidth / 2,
                      right: slotWidth / 2,
                      top: 14,
                      child: Container(height: 4, color: YukitasColors.outline),
                    ),
                    Positioned(
                      left: slotWidth / 2,
                      top: 14,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 380),
                        height: 4,
                        width: activeIndex == 0 ? 0 : slotWidth * activeIndex,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [YukitasColors.sky, YukitasColors.worker],
                          ),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    for (var index = 0; index < labels.length; index++)
                      Positioned(
                        left: slotWidth * index + slotWidth / 2 - 14,
                        top: 1,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color:
                                index <= activeIndex
                                    ? YukitasColors.sky
                                    : const Color(0xFFE6F3F7),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow:
                                index == activeIndex
                                    ? const [
                                      BoxShadow(
                                        color: Color(0x5548BDF7),
                                        blurRadius: 10,
                                        spreadRadius: 3,
                                      ),
                                    ]
                                    : null,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          Row(
            children: List.generate(
              labels.length,
              (index) => Expanded(
                child: Text(
                  labels[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color:
                        index <= activeIndex
                            ? YukitasColors.deep
                            : YukitasColors.muted,
                    fontSize: 10,
                    fontWeight:
                        index == activeIndex
                            ? FontWeight.w900
                            : FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
