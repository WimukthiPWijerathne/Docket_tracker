// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'addworkers.dart';

// class WorkerListPage extends StatefulWidget {
//   const WorkerListPage({super.key});

//   @override
//   State<WorkerListPage> createState() => _WorkerListPageState();
// }

// class _WorkerListPageState extends State<WorkerListPage> {
//   List<Map<String, String>> allWorkers = [];
//   List<Map<String, String>> displayedWorkers = [];
//   String selectedDepot = 'All';
//   bool _isLoading = true;

//   final List<String> depots = ['Kelaniya', 'Kadana', 'Paliyagoda', 'Mahara', 'Wattala'];

//   @override
//   void initState() {
//     super.initState();
//     fetchWorkers();
//   }

//   // Fetch workers from backend
//   Future<void> fetchWorkers() async {
//     setState(() => _isLoading = true);
//     try {
//       final url = Uri.parse('https://powerprox.sltidc.lk/GETPeople2.php'); // replace with your GET API
//       final response = await http.get(url);
//       if (response.statusCode == 200) {
//         final Map<String, dynamic> result = jsonDecode(response.body);

//         if (result['status'] == 'success') {
//           final List data = result['data'];

//           allWorkers = data.map<Map<String, String>>((w) {
//             // Handle availability: if null, default to "1", otherwise use the value
//             String availableStatus = w['available']?.toString() ?? "1";
            
//             return {
//               "personID": w['personID']?.toString() ?? "",
//               "name": "${w['firstName'] ?? ""} ${w['lastName'] ?? ""}".trim(),
//               "depot": w['depot']?.toString() ?? "Unknown",
//               "available": availableStatus,
//               "employeeNo": w['employeeNo']?.toString() ?? "",
//             };
//           }).toList();

//           filterWorkers(selectedDepot);
//         } else {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text(result['message'] ?? "Failed to load workers")),
//           );
//         }
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text("Server error: ${response.statusCode}")),
//         );
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context)
//           .showSnackBar(SnackBar(content: Text("Error: $e")));
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   void filterWorkers(String depot) {
//     setState(() {
//       selectedDepot = depot;
//       if (depot == 'All') {
//         displayedWorkers = List.from(allWorkers);
//       } else {
//         displayedWorkers =
//             allWorkers.where((w) => w['depot'] == depot).toList();
//       }
//     });
//   }

//   String getDepotInitial(String depot) {
//     switch (depot) {
//       case 'Kadana':
//         return 'K';
//       case 'Paliyagoda':
//         return 'P';
//       case 'Mahara':
//         return 'M';
//       case 'Wattala':
//         return 'W';
//       case 'HQ':
//         return 'H';
//       default:
//         return '';
//     }
//   }

//   Widget buildAvailabilityStatus(String available) {
//     bool isAvailable = available == "1";
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: [
//         Container(
//           width: 8,
//           height: 8,
//           decoration: BoxDecoration(
//             shape: BoxShape.circle,
//             color: isAvailable ? Colors.green : Colors.red,
//           ),
//         ),
//         const SizedBox(width: 4),
//         Text(
//           isAvailable ? "Available" : "Not Available",
//           style: TextStyle(
//             color: isAvailable ? Colors.green : Colors.red,
//             fontSize: 10,
//             fontWeight: FontWeight.w500,
//           ),
//         ),
//       ],
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("Workers Profile"),
//         centerTitle: true,
//         backgroundColor: Colors.teal,
//       ),
//       body: SafeArea(
//         child: Column(
//           children: [
//             const SizedBox(height: 12),
//             // Depot filter dropdown
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 16),
//               child: Row(
//                 children: [
//                   const Text(
//                     "Filter by depot: ",
//                     style: TextStyle(fontSize: 16),
//                   ),
//                   const SizedBox(width: 12),
//                   DropdownButton<String>(
//                     value: selectedDepot,
//                     items: ['All', ...depots]
//                         .map((depot) => DropdownMenuItem(
//                             value: depot, child: Text(depot)))
//                         .toList(),
//                     onChanged: (value) {
//                       if (value != null) filterWorkers(value);
//                     },
//                   ),
//                 ],
//               ),
//             ),
//             const SizedBox(height: 12),
//             // Worker grid
//             _isLoading
//                 ? const Expanded(
//                     child: Center(child: CircularProgressIndicator()),
//                   )
//                 : Expanded(
//                     child: Padding(
//                       padding: const EdgeInsets.symmetric(horizontal: 12),
//                       child: GridView.builder(
//                         itemCount: displayedWorkers.length,
//                         gridDelegate:
//                             const SliverGridDelegateWithFixedCrossAxisCount(
//                           crossAxisCount: 2,
//                           mainAxisSpacing: 12,
//                           crossAxisSpacing: 12,
//                           childAspectRatio: 3 / 4,
//                         ),
//                         itemBuilder: (context, index) {
//                           final worker = displayedWorkers[index];
//                           final initial = getDepotInitial(worker['depot']!);
//                           return Card(
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(12),
//                             ),
//                             elevation: 3,
//                             child: Padding(
//                               padding: const EdgeInsets.all(8),
//                               child: Column(
//                                 mainAxisAlignment: MainAxisAlignment.center,
//                                 children: [
//                                   Stack(
//                                     children: [
//                                       CircleAvatar(
//                                         radius: 24,
//                                         backgroundImage: const NetworkImage(
//                                             "https://via.placeholder.com/100"),
//                                       ),
//                                       // Availability indicator on avatar
//                                       Positioned(
//                                         right: 0,
//                                         bottom: 0,
//                                         child: Container(
//                                           width: 12,
//                                           height: 12,
//                                           decoration: BoxDecoration(
//                                             shape: BoxShape.circle,
//                                             color: worker['available'] == "1" 
//                                                 ? Colors.green 
//                                                 : Colors.red,
//                                             border: Border.all(
//                                               color: Colors.white,
//                                               width: 2,
//                                             ),
//                                           ),
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                   const SizedBox(height: 8),
//                                   Text(
//                                     "$initial. ${worker['name']}",
//                                     textAlign: TextAlign.center,
//                                     style: const TextStyle(
//                                         fontWeight: FontWeight.bold,
//                                         fontSize: 14),
//                                   ),
//                                   const SizedBox(height: 4),
//                                   Text(
//                                     worker['depot']!,
//                                     style: const TextStyle(
//                                         color: Colors.grey, fontSize: 12),
//                                   ),
//                                   const SizedBox(height: 2),
//                                   Text(
//                                     "Emp No: ${worker['employeeNo']}",
//                                     style: const TextStyle(
//                                         color: Colors.grey, fontSize: 12),
//                                   ),
//                                   const SizedBox(height: 4),
//                                   // Availability status
//                                   buildAvailabilityStatus(worker['available']!),
//                                 ],
//                               ),
//                             ),
//                           );
//                         },
//                       ),
//                     ),
//                   ),
//             // Add Worker button
//             Padding(
//               padding: const EdgeInsets.all(16),
//               child: SizedBox(
//                 width: double.infinity,
//                 height: 48,
//                 child: ElevatedButton.icon(
//                   onPressed: () async {
//                     final newWorker = await Navigator.of(context).push(
//                       MaterialPageRoute(
//                         builder: (_) => const AddWorkerPage(),
//                       ),
//                     );

//                     // Refresh list from backend after adding
//                     if (newWorker != null) {
//                       fetchWorkers();
//                     }
//                   },
//                   icon: const Icon(Icons.add),
//                   label: const Text(
//                     "Add Worker",
//                     style: TextStyle(fontSize: 16),
//                   ),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.teal,
//                     shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(12)),
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }