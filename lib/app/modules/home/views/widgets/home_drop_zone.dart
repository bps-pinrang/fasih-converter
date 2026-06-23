import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../cubit/home_cubit.dart';
import '../../cubit/home_state.dart';
import 'home_drop_zone_content.dart';

class HomeDropZone extends StatelessWidget {
  const HomeDropZone({super.key});

  @override
  Widget build(BuildContext context) {
    return DottedBorder(
      options: const RoundedRectDottedBorderOptions(
        color: Colors.blueAccent,
        dashPattern: [8, 4],
        radius: Radius.circular(12),
      ),
      child: Material(
        elevation: 0,
        color: const Color(0xFFDEDEDE).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        child: BlocBuilder<HomeCubit, HomeState>(
          builder: (context, state) => InkWell(
            borderRadius: BorderRadius.circular(12),
            // Only trigger file picker when no file is loaded.
            // When loaded, the card is informational; file/survey changes
            // happen via the buttons inside the card.
            onTap: state is HomeFileLoaded
                ? null
                : context.read<HomeCubit>().pickAndLoadBackup,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 100),
              child: SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 16,
                  ),
                  child: HomeDropZoneContent(state: state),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
