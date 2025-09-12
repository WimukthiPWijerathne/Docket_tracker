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
    weekStartDate = selectedDate.subtract(Duration(days: weekday - 1)); // Monday
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
      print('Fetching assignments for worker: ${widget.workerId} (${widget.workerName})');
      
      // Step 1: Fetch all docket assignments
      final url = Uri.parse('http://13.61.22.169:3000/docket_assignment');
      print('API Request: $url');
      
      final response = await http.get(
        url,
        headers: {'Accept': 'application/json'},
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        dynamic responseData = jsonDecode(response.body);
        List<dynamic> assignments = [];
        
        // Handle different response formats
        if (responseData is List) {
          assignments = responseData;
        } else if (responseData is Map) {
          if (responseData['data'] is List) {
            assignments = responseData['data'];
          } else if (responseData['assignments'] is List) {
            assignments = responseData['assignments'];
          } else if (responseData['status'] == 'success') {
            assignments = responseData['data'] is List ? responseData['data'] : [];
          }
        }
        
        print('Found ${assignments.length} total assignments');

        // Filter assignments for this worker
        assignedDockets = assignments.where((assignment) {
          try {
            final assignedPersons = (assignment['assignedPersons']?.toString() ?? "").toLowerCase();
            final workerId = widget.workerId.toLowerCase();
            final workerName = widget.workerName.toLowerCase();
            
            // Check if this assignment belongs to the current worker
            return assignedPersons.contains(workerId) || 
                   assignedPersons.contains(workerName) ||
                   (assignment['assignedTo']?.toString().toLowerCase() == workerId) ||
                   (assignment['assignedTo']?.toString().toLowerCase() == workerName);
          } catch (e) {
            print('Error processing assignment: $e');
            return false;
          }
        }).map<Map<String, dynamic>>((a) {
          return {
            'assignmentID': a['assignmentID']?.toString() ?? a['id']?.toString() ?? '',
            'docketID': a['docketID']?.toString() ?? a['docketId']?.toString() ?? '',
            'assignedPersons': a['assignedPersons']?.toString() ?? '',
            'assignedTime': a['assignedTime']?.toString() ?? a['assignedDate']?.toString() ?? '',
            'uploadedBy': a['uploadedBy']?.toString() ?? '',
            'uploadedTime': a['uploadedTime']?.toString() ?? a['createdAt']?.toString() ?? '',
            'completedTime': a['completedTime']?.toString() ?? a['completedAt']?.toString() ?? '',
          };
        }).toList();

        print('Found ${assignedDockets.length} assignments for this worker');
        
        // Step 2: Fetch docket details & calculate salaries
        if (assignedDockets.isNotEmpty) {
          await fetchDocketDetails();
        } else {
          // No assignments found for this worker
          setState(() {
            filteredDockets = [];
            totalSalary = 0.0;
          });
        }
        
        // Step 3: Filter by selected period
        filterByPeriod();
      } else {
        throw Exception('Failed to load assignments: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in fetchAssignments: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading assignments: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> fetchDocketDetails() async {
    try {
      print('Fetching docket details...');
      final url = Uri.parse('http://13.61.22.169:3000/dockets');
      final response = await http.get(
        url,
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        dynamic responseData = jsonDecode(response.body);
        List<dynamic> dockets = [];
        
        // Handle different response formats
        if (responseData is List) {
          dockets = responseData;
        } else if (responseData is Map) {
          if (responseData['data'] is List) {
            dockets = responseData['data'];
          } else if (responseData['dockets'] is List) {
            dockets = responseData['dockets'];
          } else if (responseData['status'] == 'success') {
            dockets = responseData['data'] is List ? responseData['data'] : [];
          }
        }
        
        print('Found ${dockets.length} dockets');
        
        // Clear previous details
        docketDetailsMap.clear();
        
        // Store details mapped by ID for quick lookup
        for (var d in dockets) {
          try {
            final id = d['ID']?.toString() ?? d['id']?.toString();
            if (id != null) {
              docketDetailsMap[id] = d;
            }
          } catch (e) {
            print('Error processing docket: $e');
          }
        }
        
        print('Stored ${docketDetailsMap.length} docket details');

        // Add docket details and salary info to each assignment
        for (var docket in assignedDockets) {
          try {
            final docketId = docket['docketID']?.toString() ?? '';
            final details = docketDetailsMap[docketId];
            
            if (details != null) {
              final type = (details['DocketType'] ?? details['docketType'] ?? 'Unknown').toString();
              final salary = salaryRates[type] ?? 50.0;
              
              // Update docket with all available details
              docket.addAll({
                'docketType': type,
                'salary': salary.toDouble(),
                'depot': details['depot']?.toString() ?? 'Unknown',
                'status': details['status']?.toString() ?? 'Unknown',
                'createdAt': details['createdAt']?.toString() ?? '',
                'updatedAt': details['updatedAt']?.toString() ?? '',
              });
              
              print('Processed docket $docketId: $type (${salary}LKR)');
            } else {
              docket['docketType'] = 'Unknown';
              docket['salary'] = 50.0;
              print('No details found for docket ID: $docketId');
            }
          } catch (e) {
            print('Error processing docket assignment: $e');
            docket['docketType'] = 'Error';
            docket['salary'] = 0.0;
          }
        }
      } else {
        print('Server error: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to load docket details: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in fetchDocketDetails: $e');
      rethrow; // Re-throw to be caught by the parent method
    }
  }

  // Filter dockets by selected period and calculate total salary
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
        DateTime tempDate = DateTime(int.parse(selectedYear), int.parse(selectedMonth));
        
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
                    Text('Year: ${tempDate.year}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                    Text('Month: ${DateFormat('MMMM').format(tempDate)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Expanded(
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                                color: isSelected ? Colors.blue : Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  DateFormat('MMM').format(DateTime(2023, month)),
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.black,
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
        title: Text("${widget.workerName} - ${selectedViewType} Salary"),
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
                              value: selectedViewType,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                fillColor: Colors.white,
                                filled: true,
                              ),
                              items: ['Daily', 'Weekly', 'Monthly'].map((String value) {
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
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
                                color: Colors.white
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
                              const Icon(Icons.arrow_drop_down, color: Colors.white),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Worker info
                      Row(
                        children: [
                          const Icon(Icons.person, size: 40, color: Color(0xFF003366)),
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
                              Icon(Icons.assignment_outlined, 
                                   size: 64, 
                                   color: Colors.grey.shade400),
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
                                  isCompleted ? Icons.check_circle : Icons.assignment,
                                  color: isCompleted ? Colors.green : Colors.blue,
                                  size: 32,
                                ),
                                title: Text(
                                  "Docket ID: ${docket["docketID"]}",
                                  style: const TextStyle(fontWeight: FontWeight.bold),
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
                                    Text("Assigned: ${docket["assignedTime"] ?? "-"}"),
                                    Text("Uploaded by: ${docket["uploadedBy"] ?? "-"}"),
                                    const SizedBox(height: 8),
                                    Container(
                                      margin: const EdgeInsets.only(top: 4),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 4, horizontal: 8),
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
                                      vertical: 6, horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.green.shade300),
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
                            "${selectedViewType} Salary:",
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
                            vertical: 8, horizontal: 16),
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