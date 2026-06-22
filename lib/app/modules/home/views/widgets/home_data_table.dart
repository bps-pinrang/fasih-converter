import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:json_converter/app/data/services/fasih_table_html_generator.dart';

import '../../cubit/home_cubit.dart';
import '../../cubit/home_state.dart';

class HomeDataTable extends StatefulWidget {
  const HomeDataTable({super.key});

  @override
  State<HomeDataTable> createState() => _HomeDataTableState();
}

class _HomeDataTableState extends State<HomeDataTable> {
  double _webViewHeight = 400;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeCubit, HomeState>(
      builder: (context, state) {
        if (state is! HomeFileLoaded) return const SizedBox.shrink();

        final html = FasihTableHtmlGenerator.wrapWithStyling(
          FasihTableHtmlGenerator.generate(state.template, state.records),
          state.records.length,
        );

        return Container(
          height: _webViewHeight.clamp(
            200,
            MediaQuery.sizeOf(context).height * 0.6,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.blueGrey.withValues(alpha: 0.2),
                spreadRadius: 4,
                offset: const Offset(0, 8),
                blurRadius: 10,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: InAppWebView(
            initialData: InAppWebViewInitialData(data: html),
            initialSettings: InAppWebViewSettings(
              supportZoom: false,
              isInspectable: false,
            ),
            onConsoleMessage: (controller, msg) {
              final h = double.tryParse(msg.message);
              if (h != null && h > 0 && mounted) {
                setState(() => _webViewHeight = h + 2);
              }
            },
          ),
        );
      },
    );
  }
}
