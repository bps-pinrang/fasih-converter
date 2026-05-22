import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../cubit/home_cubit.dart';
import '../../cubit/home_state.dart';

class HomeDataTable extends StatelessWidget {
  const HomeDataTable({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeCubit, HomeState>(
      builder: (context, state) {
        if (state is! HomeFileLoaded) return const SizedBox.shrink();

        final template = state.template;
        final records = state.records;

        final columns = template.fields
            .map((f) => DataColumn2(label: Text(f.label), fixedWidth: 150))
            .toList();

        return Container(
          height: MediaQuery.sizeOf(context).height * 0.5,
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
          padding: const EdgeInsets.all(8),
          child: DataTable2(
            columnSpacing: 12,
            minWidth: template.fields.length * 150.0,
            headingRowColor: WidgetStateProperty.all(Colors.blueGrey.shade100),
            border: TableBorder.all(color: Colors.grey.shade300),
            empty: records.isEmpty
                ? const Center(child: Text('Belum ada data'))
                : null,
            columns: columns,
            rows: records
                .take(200)
                .map(
                  (record) => DataRow2(
                    cells: template.fields
                        .map(
                          (f) => DataCell(
                            Text(
                              record[f.dataKey],
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}
