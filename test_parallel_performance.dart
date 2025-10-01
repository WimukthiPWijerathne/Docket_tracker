import 'dart:async';
import 'lib/pages/seeAssignments/services/depot_summary_service.dart';

/// Simple test to validate parallel API implementation
/// Run this to compare performance between sequential and parallel calls
Future<void> main() async {
  print('=== Testing Parallel API Implementation ===');

  // Test data
  List<String> testDepots = ['Depot A', 'Depot B', 'Depot C'];
  String? testDocketType;

  print('\nTesting original method (now with parallel API calls)...');

  // Test original method with parallel improvements
  Stopwatch stopwatch1 = Stopwatch()..start();
  try {
    var result1 = await DepotSummaryService.getDepotSummary(
      depotNames: testDepots,
      docketType: testDocketType,
    );
    stopwatch1.stop();
    print('Original method completed in ${stopwatch1.elapsedMilliseconds}ms');
    print('Returned ${result1.length} depot summaries');
  } catch (e) {
    stopwatch1.stop();
    print('Original method failed: $e');
  }

  print('\nTesting new parallel batch processing method...');

  // Test new parallel method
  Stopwatch stopwatch2 = Stopwatch()..start();
  try {
    var result2 = await DepotSummaryService.getMultipleDepotSummariesParallel(
      depotNames: testDepots,
      docketType: testDocketType,
    );
    stopwatch2.stop();
    print(
      'Parallel batch method completed in ${stopwatch2.elapsedMilliseconds}ms',
    );
    print('Returned ${result2.length} depot summaries');
  } catch (e) {
    stopwatch2.stop();
    print('Parallel batch method failed: $e');
  }

  print('\nTesting method with metrics...');

  // Test method with metrics
  try {
    var result3 = await DepotSummaryService.getDepotSummaryWithMetrics(
      depotNames: testDepots,
      docketType: testDocketType,
    );

    var data = result3['data'] as List;
    var metrics = result3['metrics'] as Map<String, dynamic>;

    print('Metrics method completed in ${metrics['executionTimeMs']}ms');
    print('Returned ${data.length} depot summaries');
    print('Metrics: $metrics');
  } catch (e) {
    print('Metrics method failed: $e');
  }

  print('\nTesting docket types loading...');

  // Test docket types loading
  Stopwatch stopwatch3 = Stopwatch()..start();
  try {
    var docketTypes = await DepotSummaryService.getAllDocketTypes();
    stopwatch3.stop();
    print('Docket types loaded in ${stopwatch3.elapsedMilliseconds}ms');
    print(
      'Found ${docketTypes.length} docket types: ${docketTypes.take(5).toList()}${docketTypes.length > 5 ? '...' : ''}',
    );
  } catch (e) {
    stopwatch3.stop();
    print('Docket types loading failed: $e');
  }

  print('\n=== Performance Test Complete ===');
}
