import 'package:json_converter/app/data/models/fasih_record.dart';
import 'package:json_converter/app/data/services/fasih_backup_writer.dart';

class RespondentLoadResult {
  final List<FasihRecord> records;
  final List<RespondentMeta> meta;
  final String envJson;

  const RespondentLoadResult({
    required this.records,
    required this.meta,
    required this.envJson,
  });
}
