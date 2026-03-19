import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinsaep_pos/core/database/database_helper.dart';

final currentShiftProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  return await DatabaseHelper.instance.getOpenShift();
});

final shiftSalesProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, openedAt) async {
  return await DatabaseHelper.instance.getShiftSalesSummary(openedAt, null);
});
