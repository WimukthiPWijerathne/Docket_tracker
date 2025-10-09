import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:leco_docket_tracker/pages/technicianPortal/services/workLogService.dart';
import 'package:leco_docket_tracker/models/WorkLog.dart';

class WorkersSummaryDetailsPage extends StatefulWidget {
  final String workerId;
  final String workerName;

  const WorkersSummaryDetailsPage({
    super.key,
    required this.workerId,
    required this.workerName,
  });

  @override
  State<WorkersSummaryDetailsPage> createState() =>
      _WorkersSummaryDetailsPageState();
}

class _WorkersSummaryDetailsPageState extends State<WorkersSummaryDetailsPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> assignedDockets = [];
  List<Map<String, dynamic>> filteredDockets = [];
  Map<String, dynamic> docketDetailsMap = {};
  Map<String, WorkLog> workLogsMap = {}; // Store work logs by assignment ID
  Map<String, WorkLog> workLogsByDocketId = {}; // Store work logs by docket ID (for fallback)
  double totalSalary = 0.0;

  // Date selection and view type
  DateTime selectedDate = DateTime.now();
  String selectedMonth = '';
  String selectedYear = '';
  String selectedViewType = 'Monthly';

  // For weekly view
  DateTime? weekStartDate;
  DateTime? weekEndDate;

  // Salary rates by docket type
  // TODO: In future, load these from PayingRatesPage configuration or database
  final Map<String, double> salaryRates = {
    'Service Line Maintenance': 785,
    'Meter Testing': 985,
    'Estimate': 785,
    'Per Visit': 785,
    'Pole Disconnection': 550,
    'Material Remove': 740,
    'Meter Replacement Only': 785,
    'Visit with Contractor': 1280,
    'Pole Top Maintenance': 675,
  };

  @override
  void initState() {
    super.initState();
    selectedMonth = DateFormat('MM').format(selectedDate);
    selectedYear = DateFormat('yyyy').format(selectedDate);
    _calculateWeekRange();
    fetchAssignments();
  }

  void _calculateWeekRange() {
    int weekday = selectedDate.weekday;
    weekStartDate = selectedDate.subtract(Duration(days: weekday - 1));
    weekEndDate = weekStartDate!.add(const Duration(days: 6));
  }

  DateTime? parseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty || dateStr == "-") return null;

    try {
      List<DateFormat> formats = [
        DateFormat('yyyy-MM-dd HH:mm:ss'),
        DateFormat('yyyy-MM-dd'),
        DateFormat('dd/MM/yyyy HH:mm:ss'),
        DateFormat('dd/MM/yyyy'),
        DateFormat('MM/dd/yyyy HH:mm:ss'),
        DateFormat('MM/dd/yyyy'),
      ];

      for (DateFormat format in formats) {
        try {
          return format.parse(dateStr);
        } catch (e) {
          continue;
        }
      }
    } catch (e) {
      debugPrint("Error parsing date: $dateStr - $e");
    }
    return null;
  }

  bool isInSelectedPeriod(String? dateStr) {
    if (dateStr == null) return false;

    DateTime? date = parseDate(dateStr);
    if (date == null) return false;

    switch (selectedViewType) {
      case 'Daily':
        return DateFormat('yyyy-MM-dd').format(date) ==
            DateFormat('yyyy-MM-dd').format(selectedDate);

      case 'Weekly':
        return date.isAfter(weekStartDate!.subtract(const Duration(days: 1))) &&
            date.isBefore(weekEndDate!.add(const Duration(days: 1)));

      case 'Monthly':
      default:
        String dateMonth = DateFormat('MM').format(date);
        String dateYear = DateFormat('yyyy').format(date);
        return dateMonth == selectedMonth && dateYear == selectedYear;
    }
  }

  Future<void> fetchAssignments() async {
    setState(() => _isLoading = true);
    try {
      // Step 1: Fetch all docket assignments
      final url = Uri.parse(
        'https://powerprox.sltidc.lk/GETDocketAssignment2.php',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);

        if (result['status'] == 'success') {
          final List data = result['data'];

          assignedDockets = data
              .where((assignment) {
                final assignedPersons = (assignment['assignedPersons'] ?? "")
                    .toString();
                return assignedPersons.contains(widget.workerId) ||
                    assignedPersons.contains(widget.workerName);
              })
              .map<Map<String, dynamic>>((a) {
                return {
                  "assignmentID": a["assignmentID"],
                  "docketID": a["docketID"],
                  "assignedPersons": a["assignedPersons"],
                  "assignedTime": a["assignedTime"],
                  "uploadedBy": a["uploadedBy"],
                  "uploadedTime": a["uploadedTime"],
                  "completedTime": a["completedTime"],
                };
              })
              .toList();

          // Step 2: Fetch work logs for completion status
          await fetchWorkLogs();

          // Step 3: Fetch docket details & calculate salaries
          await fetchDocketDetails();

          // Step 4: Filter by selected period
          filterByPeriod();
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Fetch work logs to get completion status (same robust method as depot summary)
  Future<void> fetchWorkLogs() async {
    try {
      debugPrint("========================================");
      debugPrint(
        "Fetching work logs for worker: ${widget.workerId} (${widget.workerName})",
      );

      // Fetch ALL work logs (same as depot summary service)
      final allLogs = await WorkLogService.getWorkLogs();
      debugPrint("Total work logs fetched: ${allLogs.length}");

      if (allLogs.isNotEmpty) {
        debugPrint("Sample work logs (first 10):");
        for (int i = 0; i < allLogs.length && i < 10; i++) {
          final log = allLogs[i];
          debugPrint(
            "  Sample $i: AssignmentID='${log.assignmentId}', DocketID='${log.docketId}', EmployeeNo='${log.employeeNo}', CompletedAt='${log.completedAt}'",
          );
        }
      }

      // Map work logs by BOTH assignmentId AND docketId for flexible lookup
      // This matches the depot summary service approach
      workLogsMap.clear();
      workLogsByDocketId.clear();

      debugPrint("Mapping work logs by assignmentId AND docketId...");
      for (var workLog in allLogs) {
        // Primary key: assignmentId
        if (workLog.assignmentId.isNotEmpty) {
          workLogsMap[workLog.assignmentId] = workLog;
        }
        
        // Secondary key: docketId (for fallback matching, same as depot summary)
        if (workLog.docketId.isNotEmpty) {
          workLogsByDocketId[workLog.docketId] = workLog;
        }
        
        debugPrint(
          "  Mapped: AssignmentID='${workLog.assignmentId}', DocketID='${workLog.docketId}', EmployeeNo='${workLog.employeeNo}', CompletedAt='${workLog.completedAt}'",
        );
      }

      debugPrint(
        "WorkLogs mapped: ${workLogsMap.length} by assignmentId, ${workLogsByDocketId.length} by docketId",
      );

      // Show which IDs we have in both maps
      if (workLogsMap.isNotEmpty) {
        final assignmentIds = workLogsMap.keys.take(20).join(', ');
        debugPrint("Assignment IDs in map (first 20): $assignmentIds");
      }
      
      if (workLogsByDocketId.isNotEmpty) {
        final docketIds = workLogsByDocketId.keys.take(20).join(', ');
        debugPrint("Docket IDs in map (first 20): $docketIds");
      }

      debugPrint("========================================");
    } catch (e) {
      debugPrint("❌ Error fetching work logs: $e");
      // Don't throw - allow the app to continue even if work logs fail
    }
  }

  Future<void> fetchDocketDetails() async {
    try {
      debugPrint("========================================");
      debugPrint("Fetching docket details...");
      final url = Uri.parse(
        'https://powerprox.sltidc.lk/GETDocketDetails2.php',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        debugPrint("Fetched ${data.length} docket details");

        for (var d in data) {
          docketDetailsMap[d["ID"].toString()] = d;
        }

        debugPrint("Processing ${assignedDockets.length} assigned dockets...");

        // Show which assignment IDs we're looking for
        final assignmentIds = assignedDockets
            .map((d) => d["assignmentID"].toString())
            .take(20)
            .join(', ');
        debugPrint("Looking for assignment IDs (first 20): $assignmentIds");

        // Add docket details and check completion status from work logs
        // Using the SAME robust completion logic as depot summary service
        for (var docket in assignedDockets) {
          final docketId = docket["docketID"].toString();
          final assignmentId = docket["assignmentID"].toString();
          final details = docketDetailsMap[docketId];

          debugPrint(
            "--- Processing Docket $docketId (Assignment: $assignmentId) ---",
          );

          if (details != null) {
            final type = details["DocketType"] ?? "Unknown";
            docket["docketType"] = type;

            // Look up work log by assignmentId OR docketId (depot summary uses docketId!)
            // Strategy 1: Try assignmentId first (most accurate when it matches)
            WorkLog? workLog = workLogsMap[assignmentId];
            String matchMethod = 'none';

            // Strategy 2: If not found by assignmentId, try docketId (same as depot summary)
            if (workLog == null) {
              workLog = workLogsByDocketId[docketId];
              if (workLog != null) {
                matchMethod = 'docketId';
              }
            } else {
              matchMethod = 'assignmentId';
            }

            debugPrint(
              "WorkLog lookup: Assignment=$assignmentId, Docket=$docketId, Found=${workLog != null}, Method=$matchMethod",
            );

            if (workLog == null) {
              debugPrint("  ⚠️ No workLog found by assignmentId OR docketId");
              debugPrint("  Looking for: AssignmentID=$assignmentId OR DocketID=$docketId");
            }

            if (workLog != null) {
              debugPrint("  - WorkLog ID: ${workLog.id}");
              debugPrint("  - Assignment ID: ${workLog.assignmentId}");
              debugPrint("  - Docket ID: ${workLog.docketId}");
              debugPrint("  - Acknowledged: ${workLog.acknowledgedAt}");
              debugPrint("  - Started: ${workLog.startedAt}");
              debugPrint("  - Completed: ${workLog.completedAt}");
            }

            // ⭐ SAME completion check as depot summary service (lines 318-324)
            // A docket is completed if WorkLog has valid completedAt timestamp
            final isCompleted =
                workLog != null &&
                workLog.completedAt != null &&
                workLog.completedAt!.isNotEmpty &&
                workLog.completedAt != '0' &&
                workLog.completedAt!.toLowerCase() != 'null';

            // Store completion info
            docket["isCompleted"] = isCompleted;
            docket["workLogCompletedAt"] = workLog?.completedAt;

            // Only assign salary if completed
            if (isCompleted) {
              final salary = salaryRates[type] ?? 50.0;
              docket["salary"] = salary;
              debugPrint(
                "✅ Docket $docketId COMPLETED: Type=$type, Salary=Rs.$salary, CompletedAt=${workLog.completedAt}",
              );
            } else {
              docket["salary"] = 0.0; // No salary for incomplete work
              debugPrint(
                "⏳ Docket $docketId IN PROGRESS: Type=$type, No salary yet",
              );
            }
          } else {
            debugPrint("⚠️ No details found for docket $docketId");
            docket["docketType"] = "Unknown";
            docket["isCompleted"] = false;
            docket["salary"] = 0.0;
          }
        }
        debugPrint("========================================");
      } else {
        debugPrint("❌ Server error: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ Error fetching docket details: $e");
    }
  }

  void filterByPeriod() {
    debugPrint("========================================");
    debugPrint("Filtering by period: $selectedViewType");
    debugPrint("Selected date: $selectedDate");
    debugPrint("Total assigned dockets: ${assignedDockets.length}");

    int completedCount = 0;

    filteredDockets = assignedDockets.where((docket) {
      final docketId = docket["docketID"];
      final assignmentId = docket["assignmentID"];
      final isCompleted = docket["isCompleted"] == true;

      if (isCompleted) {
        completedCount++;
      }

      // Only include COMPLETED dockets (same as depot summary logic)
      if (!isCompleted) {
        debugPrint(
          "❌ Docket $docketId (Assignment $assignmentId): Not completed, skipping",
        );
        return false;
      }

      // Check if the completion date falls in the selected period
      // Priority 1: Use WorkLog completedAt (most accurate)
      final completedAt = docket["workLogCompletedAt"];
      if (completedAt != null && completedAt.toString().isNotEmpty) {
        bool inPeriod = isInSelectedPeriod(completedAt);
        if (inPeriod) {
          debugPrint(
            "✅ Docket $docketId (Assignment $assignmentId): Completed on $completedAt, IN period",
          );
        } else {
          debugPrint(
            "⏭️ Docket $docketId (Assignment $assignmentId): Completed on $completedAt, NOT in period",
          );
        }
        return inPeriod;
      }

      // Fallback to checking assignedTime or completedTime (less accurate)
      debugPrint(
        "⚠️ Docket $docketId (Assignment $assignmentId): No workLog completedAt, using fallback dates",
      );
      bool assignedInPeriod = isInSelectedPeriod(docket["assignedTime"]);
      bool completedInPeriod = isInSelectedPeriod(docket["completedTime"]);

      return assignedInPeriod || completedInPeriod;
    }).toList();

    // Calculate total salary for completed dockets in the period
    double periodSum = 0.0;
    for (var docket in filteredDockets) {
      periodSum += (docket["salary"] as double? ?? 0.0);
    }
    totalSalary = periodSum;

    debugPrint("📊 SUMMARY:");
    debugPrint("  - Total assigned dockets: ${assignedDockets.length}");
    debugPrint("  - Completed dockets (all time): $completedCount");
    debugPrint(
      "  - Completed dockets in selected period: ${filteredDockets.length}",
    );
    debugPrint(
      "  - Total salary for period: Rs. ${totalSalary.toStringAsFixed(2)}",
    );
    debugPrint("========================================");
  }

  String getPeriodDisplayText() {
    switch (selectedViewType) {
      case 'Daily':
        return DateFormat('EEEE, MMMM d, yyyy').format(selectedDate);
      case 'Weekly':
        return '${DateFormat('MMM d').format(weekStartDate!)} - ${DateFormat('MMM d, yyyy').format(weekEndDate!)}';
      case 'Monthly':
      default:
        return DateFormat('MMMM yyyy').format(selectedDate);
    }
  }

  Future<void> _selectDate() async {
    switch (selectedViewType) {
      case 'Daily':
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: selectedDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (picked != null) {
          setState(() {
            selectedDate = picked;
            filterByPeriod();
          });
        }
        break;

      case 'Weekly':
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: selectedDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          helpText: 'Select any day in the week',
        );
        if (picked != null) {
          setState(() {
            selectedDate = picked;
            _calculateWeekRange();
            filterByPeriod();
          });
        }
        break;

      case 'Monthly':
      default:
        _selectMonthYear();
        break;
    }
  }

  Future<void> _selectMonthYear() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        DateTime tempDate = DateTime(
          int.parse(selectedYear),
          int.parse(selectedMonth),
        );

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Select Month & Year'),
              content: SizedBox(
                height: 300,
                width: 300,
                child: Column(
                  children: [
                    Text(
                      'Year: ${tempDate.year}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(
                      height: 100,
                      child: YearPicker(
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        selectedDate: tempDate,
                        onChanged: (DateTime date) {
                          setDialogState(() {
                            tempDate = DateTime(date.year, tempDate.month);
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Month: ${DateFormat('MMMM').format(tempDate)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Expanded(
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              childAspectRatio: 2,
                            ),
                        itemCount: 12,
                        itemBuilder: (context, index) {
                          int month = index + 1;
                          bool isSelected = month == tempDate.month;
                          return GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                tempDate = DateTime(tempDate.year, month);
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.blue
                                    : Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  DateFormat(
                                    'MMM',
                                  ).format(DateTime(2023, month)),
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      selectedDate = tempDate;
                      selectedMonth = DateFormat('MM').format(tempDate);
                      selectedYear = DateFormat('yyyy').format(tempDate);
                      filterByPeriod();
                    });
                    Navigator.of(context).pop();
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.workerName} - $selectedViewType Salary"),
        backgroundColor: const Color(0xFF003366),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectDate,
            tooltip: 'Select Date/Period',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.blue.shade50,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Text(
                            'View: ',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF003366),
                            ),
                          ),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedViewType,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                fillColor: Colors.white,
                                filled: true,
                              ),
                              items: ['Daily', 'Weekly', 'Monthly'].map((
                                String value,
                              ) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    selectedViewType = newValue;
                                    if (selectedViewType == 'Weekly') {
                                      _calculateWeekRange();
                                    }
                                    filterByPeriod();
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: _selectDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF003366),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.3),
                                spreadRadius: 1,
                                blurRadius: 3,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                selectedViewType == 'Daily'
                                    ? Icons.today
                                    : selectedViewType == 'Weekly'
                                    ? Icons.view_week
                                    : Icons.calendar_month,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  getPeriodDisplayText(),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.arrow_drop_down,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(
                            Icons.person,
                            size: 40,
                            color: Color(0xFF003366),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.workerName,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF003366),
                                ),
                              ),
                              Text(
                                "Worker ID: ${widget.workerId}",
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                "${filteredDockets.length} Completed Dockets",
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: filteredDockets.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.assignment_outlined,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "No completed dockets found",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: filteredDockets.length,
                          itemBuilder: (context, index) {
                            final docket = filteredDockets[index];

                            return Card(
                              elevation: 3,
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              child: ListTile(
                                leading: const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 32,
                                ),
                                title: Text(
                                  "Docket ID: ${docket["docketID"]}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      "Type: ${docket["docketType"] ?? "Unknown"}",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Assigned: ${docket["assignedTime"] ?? "-"}",
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      margin: const EdgeInsets.only(top: 4),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4,
                                        horizontal: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        color: Colors.green,
                                      ),
                                      child: Text(
                                        "✓ Completed: ${docket["workLogCompletedAt"] ?? docket["completedTime"] ?? "-"}",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.green.shade300,
                                    ),
                                  ),
                                  child: Text(
                                    "Rs. ${docket["salary"]?.toStringAsFixed(2) ?? "0.00"}",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade700,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF003366),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        spreadRadius: 1,
                        blurRadius: 5,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "$selectedViewType Salary:",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            getPeriodDisplayText(),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "Rs. ${totalSalary.toStringAsFixed(2)}",
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
