import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../models/dockets.dart';
import '../../../models/WorkLog.dart';

// Data model for depot summary
class DepotSummaryData {
  final String depotName;
  final int inProgressCount;
  final int completedCount;
  final List<Docket> inProgressDockets;
  final List<Docket> completedDockets;

  DepotSummaryData({
    required this.depotName,
    required this.inProgressCount,
    required this.completedCount,
    required this.inProgressDockets,
    required this.completedDockets,
  });
}

class DepotSummaryService {
  static const String _baseUrl = 'https://powerprox.sltidc.lk';
  static const int _maxConcurrentRequests =
      5; // Limit concurrent requests to avoid overwhelming server

  // Simple cache variables for better refresh performance
  static DateTime? _lastDocketsRefresh;
  static DateTime? _lastWorkLogsRefresh;
  static const Duration _cacheValidDuration = Duration(minutes: 1);

  /// Fetch all dockets from the database with retry logic
  static Future<List<Docket>> _fetchAllDockets({int maxRetries = 3}) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final response = await http
            .get(
              Uri.parse('$_baseUrl/GETDocketDetails2.php'),
              headers: {'Accept': 'application/json'},
            )
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                throw Exception('Request timed out after 30 seconds');
              },
            );

        print(
          'Fetch dockets status: ${response.statusCode} (attempt $attempt)',
        );

        if (response.statusCode == 200) {
          final String responseBody = response.body;

          if (responseBody.isEmpty) {
            print('Empty response body on attempt $attempt');
            if (attempt < maxRetries) continue;
            return [];
          }

          dynamic jsonData = json.decode(responseBody);

          // Handle both array and object responses (same pattern as DocketService)
          if (jsonData is List) {
            return jsonData
                .map((json) => Docket.fromJson(json as Map<String, dynamic>))
                .toList();
          } else if (jsonData is Map<String, dynamic>) {
            // If the API returns an object with a data field containing the array
            if (jsonData.containsKey('data') && jsonData['data'] is List) {
              List dataList = jsonData['data'];
              return dataList
                  .map((json) => Docket.fromJson(json as Map<String, dynamic>))
                  .toList();
            } else if (jsonData.containsKey('dockets') &&
                jsonData['dockets'] is List) {
              List docketsList = jsonData['dockets'];
              return docketsList
                  .map((json) => Docket.fromJson(json as Map<String, dynamic>))
                  .toList();
            } else {
              // Single docket object
              return [Docket.fromJson(jsonData)];
            }
          } else {
            throw Exception('Unexpected response format');
          }
        } else {
          print(
            'Failed to fetch dockets: ${response.statusCode} on attempt $attempt',
          );
          if (attempt < maxRetries) {
            await Future.delayed(
              Duration(seconds: attempt * 2),
            ); // Exponential backoff
            continue;
          }
          return [];
        }
      } catch (e) {
        print('Error fetching dockets on attempt $attempt: $e');
        if (attempt < maxRetries) {
          await Future.delayed(
            Duration(seconds: attempt * 2),
          ); // Exponential backoff
          continue;
        }
        print('All retry attempts failed for fetching dockets');
        return [];
      }
    }
    return [];
  }

  /// Fetch all work logs from the database with retry logic
  static Future<List<WorkLog>> _fetchAllWorkLogs({int maxRetries = 3}) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final response = await http
            .get(
              Uri.parse('$_baseUrl/GETDocketWorkLog.php'),
              headers: {'Content-Type': 'application/json'},
            )
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                throw Exception('Request timed out after 30 seconds');
              },
            );

        print(
          'Fetch work logs status: ${response.statusCode} (attempt $attempt)',
        );

        if (response.statusCode == 200) {
          final String responseBody = response.body;

          if (responseBody.isEmpty) {
            print('Empty response body for work logs on attempt $attempt');
            if (attempt < maxRetries) continue;
            return [];
          }

          final dynamic jsonData = json.decode(responseBody);
          if (jsonData is List) {
            return jsonData
                .map<WorkLog>((item) => WorkLog.fromJson(item))
                .toList();
          } else if (jsonData is Map<String, dynamic>) {
            return [WorkLog.fromJson(jsonData)];
          }

          return [];
        } else {
          print(
            'Failed to fetch work logs: ${response.statusCode} on attempt $attempt',
          );
          if (attempt < maxRetries) {
            await Future.delayed(
              Duration(seconds: attempt * 2),
            ); // Exponential backoff
            continue;
          }
          return [];
        }
      } catch (e) {
        print('Error fetching work logs on attempt $attempt: $e');
        if (attempt < maxRetries) {
          await Future.delayed(
            Duration(seconds: attempt * 2),
          ); // Exponential backoff
          continue;
        }
        print('All retry attempts failed for fetching work logs');
        return [];
      }
    }
    return [];
  }

  /// Get depot-wise summary data for specified depots and docket type
  ///
  /// This method now uses parallel API calls for improved performance.
  /// For multiple depots, consider using [getMultipleDepotSummariesParallel]
  /// or [getDepotSummaryWithMetrics] for better performance and monitoring.
  static Future<List<DepotSummaryData>> getDepotSummary({
    required List<String> depotNames,
    String? docketType,
  }) async {
    try {
      print('=== DEBUG: Starting getDepotSummary ===');
      print('DEBUG: Requested depots: $depotNames, DocketType: $docketType');

      // Fetch all dockets and work logs in parallel for better performance
      final results = await Future.wait([
        _fetchAllDockets(),
        _fetchAllWorkLogs(),
      ]);

      final dockets = results[0] as List<Docket>;
      final workLogs = results[1] as List<WorkLog>;

      print('DEBUG: Fetched ${dockets.length} dockets');
      print('DEBUG: Fetched ${workLogs.length} work logs');

      if (dockets.isNotEmpty) {
        print(
          'DEBUG: First docket sample: ${dockets.first.depot} - ${dockets.first.docketType}',
        );

        // Show all unique depot names in the database
        Set<String> uniqueDepots = dockets.map((d) => d.depot).toSet();
        print('DEBUG: All unique depot names in database: $uniqueDepots');

        // Show all unique docket types
        Set<String> uniqueDocketTypes = dockets
            .map((d) => d.docketType)
            .toSet();
        print('DEBUG: All unique docket types: $uniqueDocketTypes');
      }

      List<DepotSummaryData> summaryData = [];

      // Use the requested depot names (from UI/branch selection) and show all of them
      List<String> depotsToProcess = depotNames.toList();

      print('DEBUG: Processing requested depots: $depotsToProcess');

      for (String depot in depotsToProcess) {
        print('DEBUG: Processing depot: $depot');

        // First, get all dockets for this depot (before docket type filtering)
        List<Docket> allDepotDockets = dockets.where((docket) {
          return docket.depot.toLowerCase().trim() ==
              depot.toLowerCase().trim();
        }).toList();

        print(
          'DEBUG: Found ${allDepotDockets.length} total dockets for depot $depot (before docket type filter)',
        );

        if (allDepotDockets.isNotEmpty) {
          Set<String> actualDocketTypes = allDepotDockets
              .map((d) => d.docketType)
              .toSet();
          print(
            'DEBUG: Actual docket types in depot $depot: $actualDocketTypes',
          );
          if (docketType != null && docketType != 'All Types') {
            print('DEBUG: Looking for docket type: "$docketType"');
          }
        }

        // Now apply docket type filtering
        List<Docket> depotDockets = allDepotDockets.where((docket) {
          // Filter by docket type if specified
          if (docketType != null && docketType != 'All Types') {
            String dbDocketType = docket.docketType.toLowerCase().trim();
            String filterDocketType = docketType.toLowerCase().trim();

            // Try both exact match and contains match for flexibility
            bool matchesDocketType =
                dbDocketType == filterDocketType ||
                dbDocketType.contains(filterDocketType) ||
                filterDocketType.contains(dbDocketType);

            if (!matchesDocketType) {
              print(
                'DEBUG: Docket ${docket.id} filtered out - DB type: "$dbDocketType" doesn\'t match UI filter: "$filterDocketType"',
              );
            } else {
              print(
                'DEBUG: Docket ${docket.id} matches - DB type: "$dbDocketType" matches UI filter: "$filterDocketType"',
              );
            }
            return matchesDocketType;
          }
          return true; // Include all if no docket type filter
        }).toList();

        print(
          'DEBUG: Found ${depotDockets.length} dockets for depot $depot after docket type filtering',
        );
        if (docketType != null && docketType != 'All Types') {
          print('DEBUG: Docket type filter applied: "$docketType"');
          if (depotDockets.isNotEmpty) {
            print(
              'DEBUG: Matching docket types: ${depotDockets.map((d) => d.docketType).toSet().toList()}',
            );
          }
        }

        // Separate completed and in-progress dockets based on WorkLog completedAt
        List<Docket> completedDockets = [];
        List<Docket> inProgressDockets = [];

        for (Docket docket in depotDockets) {
          // Check if docket is completed by looking at WorkLog completedAt field
          bool isCompleted = workLogs.any(
            (workLog) =>
                workLog.docketId == docket.id &&
                workLog.completedAt != null &&
                workLog.completedAt!.isNotEmpty &&
                workLog.completedAt != '0' &&
                workLog.completedAt!.toLowerCase() != 'null',
          );

          if (isCompleted) {
            completedDockets.add(docket);
            print(
              'DEBUG: Docket ${docket.id} (${docket.docketType}) is COMPLETED (has completedAt in worklog)',
            );
          } else {
            // All other dockets are considered in progress
            inProgressDockets.add(docket);
            print(
              'DEBUG: Docket ${docket.id} (${docket.docketType}) is IN PROGRESS',
            );
          }
        }

        print(
          'DEBUG: Depot $depot - In Progress: ${inProgressDockets.length}, Completed: ${completedDockets.length}',
        );

        if (depotDockets.isNotEmpty) {
          print(
            'DEBUG: Depot $depot docket types in results: ${depotDockets.map((d) => d.docketType).toSet().toList()}',
          );
        }

        // Add all requested depots (even if no data) to maintain chart structure
        summaryData.add(
          DepotSummaryData(
            depotName: depot,
            inProgressCount: inProgressDockets.length,
            completedCount: completedDockets.length,
            inProgressDockets: inProgressDockets,
            completedDockets: completedDockets,
          ),
        );
      }

      print('DEBUG: Final summary data count: ${summaryData.length}');

      // Show which depots actually have data vs which are showing zero
      List<String> depotsWithData = summaryData
          .where((data) => data.inProgressCount > 0 || data.completedCount > 0)
          .map((data) => data.depotName)
          .toList();
      print('DEBUG: Depots with actual docket data: $depotsWithData');

      return summaryData;
    } catch (e) {
      print('Error getting depot summary: $e');
      return [];
    }
  }

  /// Get summary for all depots (when no specific depots are requested)
  static Future<List<DepotSummaryData>> getAllDepotsSummary({
    String? docketType,
  }) async {
    return getDepotSummary(depotNames: [], docketType: docketType);
  }

  /// Get all unique docket types from the database
  static Future<List<String>> getAllDocketTypes() async {
    try {
      final dockets = await _fetchAllDockets();

      // Filter out empty, null, or whitespace-only docket types
      Set<String> uniqueDocketTypes = dockets
          .map((d) => d.docketType)
          .where((type) => type.isNotEmpty && type.trim().isNotEmpty)
          .map((type) => type.trim()) // Remove leading/trailing whitespace
          .toSet();

      List<String> sortedTypes = uniqueDocketTypes.toList();
      sortedTypes.sort(); // Sort alphabetically

      print(
        'DEBUG: Available docket types from database (filtered): $sortedTypes',
      );
      print(
        'DEBUG: Total dockets: ${dockets.length}, Unique valid docket types: ${sortedTypes.length}',
      );

      return sortedTypes;
    } catch (e) {
      print('Error fetching docket types: $e');
      return [];
    }
  }

  /// Process multiple depot summaries concurrently with controlled batching
  static Future<List<DepotSummaryData>> getMultipleDepotSummariesParallel({
    required List<String> depotNames,
    String? docketType,
  }) async {
    if (depotNames.isEmpty) {
      return getAllDepotsSummary(docketType: docketType);
    }

    try {
      // First, fetch all data in parallel (same as getDepotSummary)
      final results = await Future.wait([
        _fetchAllDockets(),
        _fetchAllWorkLogs(),
      ]);

      final dockets = results[0] as List<Docket>;
      final workLogs = results[1] as List<WorkLog>;

      // Process depots in batches to control concurrency
      List<DepotSummaryData> allResults = [];

      for (int i = 0; i < depotNames.length; i += _maxConcurrentRequests) {
        final batch = depotNames.skip(i).take(_maxConcurrentRequests).toList();

        // Process batch in parallel
        final batchResults = await Future.wait(
          batch.map(
            (depot) => _processDepotData(depot, dockets, workLogs, docketType),
          ),
        );

        allResults.addAll(batchResults);
      }

      return allResults;
    } catch (e) {
      print('Error in getMultipleDepotSummariesParallel: $e');
      return [];
    }
  }

  /// Process individual depot data - extracted for parallel processing
  static Future<DepotSummaryData> _processDepotData(
    String depot,
    List<Docket> dockets,
    List<WorkLog> workLogs,
    String? docketType,
  ) async {
    print('DEBUG: Processing depot: $depot');

    // Filter dockets for this depot
    List<Docket> allDepotDockets = dockets.where((docket) {
      return docket.depot.toLowerCase().trim() == depot.toLowerCase().trim();
    }).toList();

    print(
      'DEBUG: Found ${allDepotDockets.length} total dockets for depot $depot',
    );

    // Apply docket type filtering
    List<Docket> depotDockets = allDepotDockets.where((docket) {
      if (docketType != null && docketType != 'All Types') {
        String dbDocketType = docket.docketType.toLowerCase().trim();
        String filterDocketType = docketType.toLowerCase().trim();

        return dbDocketType == filterDocketType ||
            dbDocketType.contains(filterDocketType) ||
            filterDocketType.contains(dbDocketType);
      }
      return true;
    }).toList();

    // Separate completed and in-progress dockets
    List<Docket> completedDockets = [];
    List<Docket> inProgressDockets = [];

    for (Docket docket in depotDockets) {
      bool isCompleted = workLogs.any(
        (workLog) =>
            workLog.docketId == docket.id &&
            workLog.completedAt != null &&
            workLog.completedAt!.isNotEmpty &&
            workLog.completedAt != '0' &&
            workLog.completedAt!.toLowerCase() != 'null',
      );

      if (isCompleted) {
        completedDockets.add(docket);
      } else {
        inProgressDockets.add(docket);
      }
    }

    print(
      'DEBUG: Depot $depot - In Progress: ${inProgressDockets.length}, Completed: ${completedDockets.length}',
    );

    return DepotSummaryData(
      depotName: depot,
      inProgressCount: inProgressDockets.length,
      completedCount: completedDockets.length,
      inProgressDockets: inProgressDockets,
      completedDockets: completedDockets,
    );
  }

  /// Enhanced version with better error handling for parallel calls
  static Future<Map<String, dynamic>> getDepotSummaryWithMetrics({
    required List<String> depotNames,
    String? docketType,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      print('=== DEBUG: Starting getDepotSummaryWithMetrics ===');

      // Use parallel processing method
      final summaryData = await getMultipleDepotSummariesParallel(
        depotNames: depotNames,
        docketType: docketType,
      );

      stopwatch.stop();

      return {
        'data': summaryData,
        'metrics': {
          'executionTimeMs': stopwatch.elapsedMilliseconds,
          'depotCount': depotNames.length,
          'totalDockets': summaryData.fold<int>(
            0,
            (sum, depot) => sum + depot.inProgressCount + depot.completedCount,
          ),
        },
      };
    } catch (e) {
      stopwatch.stop();
      print('Error in getDepotSummaryWithMetrics: $e');

      return {
        'data': <DepotSummaryData>[],
        'metrics': {
          'executionTimeMs': stopwatch.elapsedMilliseconds,
          'error': e.toString(),
        },
      };
    }
  }

  /// Clear refresh timestamps to force fresh data on next request
  static void clearRefreshCache() {
    _lastDocketsRefresh = null;
    _lastWorkLogsRefresh = null;
    print('DEBUG: Refresh cache cleared - next requests will fetch fresh data');
  }

  /// Check if cache is still valid for refresh optimization
  static bool _isCacheValid(DateTime? lastRefresh) {
    if (lastRefresh == null) return false;
    return DateTime.now().difference(lastRefresh) < _cacheValidDuration;
  }

  /// Enhanced refresh method with cache control
  static Future<Map<String, dynamic>> refreshAllData({
    required List<String> depotNames,
    String? docketType,
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) {
      clearRefreshCache();
    }

    // Update refresh timestamps
    _lastDocketsRefresh = DateTime.now();
    _lastWorkLogsRefresh = DateTime.now();

    // Use the existing method with metrics
    return await getDepotSummaryWithMetrics(
      depotNames: depotNames,
      docketType: docketType,
    );
  }
}
