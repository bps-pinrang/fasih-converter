import 'package:flutter/material.dart';

class RutaDataSource extends DataTableSource {
  RutaDataSource({required this.data, this.selectedRowCount = 10});

  final List<Map<String, dynamic>> data;

  @override
  int selectedRowCount;

  @override
  DataRow? getRow(int index) {
    if (index < data.length) {
      return DataRow.byIndex(
        index: index,
        cells: data[index].values.map((e) => DataCell(Text('$e'))).toList(),
      );
    }
    return null;
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => data.length;
}
