import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

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
  Map<String, dynamic> docketDetailsMap = {}; // store docket details by ID
  double totalSalary = 0.0;

  // Date selection and view type
  DateTime selectedDate = DateTime.now();
  String selectedMonth = '';
  String selectedYear = '';
  String selectedViewType = 'Monthly'; // Daily, Weekly, Monthly

  // For weekly view
  DateTime? weekStartDate;
  DateTime? weekEndDate;

  // 🔹 Salary rates by docket type
  final Map<String, double> salaryRates = {
    'Service Line Maintenance': 20,
    'Meter Testing': 30,
    'Estimate': 50,
    'Per Visit': 10,
    'Pole Disconnection': 130,
    'Material Remove': 66,
    'Meter Replacement Only': 55,
    'Visit with Contractor': 44,
    'Pole Top Maintenance': 80,
  };

  @override
  void initState() {
    super.initState();
    selectedMonth = DateFormat('MM').format(selectedDate);
    selectedYear = DateFormat('yyyy').format(selectedDate);
    _calculateWeekRange();
    fetchAssignments();
  }

  // 🔹 Calculate week start and end dates
  void _calculateWeekRange() {
    int weekday = selectedDate.weekday;
    weekStartDate = selectedDate.subtract(
      Duration(days: weekday - 1),
    ); // Monday
    weekEndDate = weekStartDate!.add(const Duration(days: 6)); // Sunday
  }

  // 🔹 Date parsing helper function
  DateTime? parseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty || dateStr == "-") return null;

    try {
      // Try different date formats
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

  // 🔹 Check if a date falls within the selected period
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
      // 🔹 Step 1: Fetch all docket assignments
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
                // Check if this assignment belongs to the current worker
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

          // 🔹 Step 2: Fetch docket details & calculate salaries
          await fetchDocketDetails();

          // 🔹 Step 3: Filter by selected period
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

  Future<void> fetchDocketDetails() async {
    try {
      final url = Uri.parse(
        'https://powerprox.sltidc.lk/GETDocketDetails2.php',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);

        // Store details mapped by ID for quick lookup
        for (var d in data) {
          docketDetailsMap[d["ID"].toString()] = d;
        }

        // Add docket details and salary info to each assignment
        for (var docket in assignedDockets) {
          final docketId = docket["docketID"].toString();
          final details = docketDetailsMap[docketId];

          if (details != null) {
            final type = details["DocketType"] ?? "Unknown";
            final salary = salaryRates[type] ?? 50.0;
            docket["docketType"] = type;
            docket["salary"] = salary;
          } else {
            docket["docketType"] = "Unknown";
            docket["salary"] = 50.0;
          }
        }
      } else {
        debugPrint("Server error: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error fetching docket details: $e");
    }
  }

  // 🔹 Filter dockets by selected period and calculate total salary
  void filterByPeriod() {
    filteredDockets = assignedDockets.where((docket) {
      // Check both assignedTime and completedTime to include work done in the period
      bool assignedInPeriod = isInSelectedPeriod(docket["assignedTime"]);
      bool completedInPeriod = isInSelectedPeriod(docket["completedTime"]);

      // Include if either assigned or completed in the selected period
      return assignedInPeriod || completedInPeriod;
    }).toList();

    // Calculate total salary for the period
    double periodSum = 0.0;
    for (var docket in filteredDockets) {
      periodSum += (docket["salary"] as double? ?? 0.0);
    }
    totalSalary = periodSum;
  }

  // 🔹 Get period display text
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

  // 🔹 Show date picker based on view type
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

  // 🔹 Show month/year picker
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
                    // Year picker
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
                    // Month picker
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
                // 🔹 View type selector and period display header
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.blue.shade50,
                  child: Column(
                    children: [
                      // View type dropdown
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

                      // Period display
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

                      // Worker info
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
                                "${filteredDockets.length} Dockets in ${getPeriodDisplayText()}",
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 🔹 Dockets list
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
                                "No dockets found for ${getPeriodDisplayText()}",
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
                            final isCompleted = docket["completedTime"] != null;

                            return Card(
                              elevation: 3,
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              child: ListTile(
                                leading: Icon(
                                  isCompleted
                                      ? Icons.check_circle
                                      : Icons.assignment,
                                  color: isCompleted
                                      ? Colors.green
                                      : Colors.blue,
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
                                    Text(
                                      "Uploaded by: ${docket["uploadedBy"] ?? "-"}",
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
                                        color: isCompleted
                                            ? Colors.green
                                            : Colors.orange,
                                      ),
                                      child: Text(
                                        isCompleted
                                            ? "✓ Completed: ${docket["completedTime"]}"
                                            : "⏳ Pending",
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

                // 🔹 Period Total Salary at the bottom
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
