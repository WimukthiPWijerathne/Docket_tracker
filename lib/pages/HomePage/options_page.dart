import 'package:flutter/material.dart';
import '../loginScreen/login_page.dart';
import '../addDocket/docket_type_selection_page.dart';
import '../docket_selection_page.dart';
import '../workersProfile/workersProfile.dart';
// Create a new page for Assigned Dockets
import '../AssignedDockets/assigned_dockets_page.dart';
// 🔹 Import Workers Summary page (you can create this later)
import '../../pages/workersSummey/workers_summery_page.dart';
import '../../pages/staffManagement/staffHomePage.dart';
import '../../pages/technicianPortal/technicianPortalPage.dart';
import '../seeAssignments/options.dart';
import '../eDocket/e_docket.dart';
import '../Payments/paymentPageOptions.dart';
import '../viewDockets/viewDocketsSummary.dart';
import '../addDocketX/cameraCapture/captureImage.dart';
import '../pendingDockets/pendingDockets.dart';
// Technician notification banner
import '../../widgets/technician_notification_banner.dart';

class OptionsPage extends StatefulWidget {
  final String role; // role parameter
  const OptionsPage({super.key, required this.role});

  @override
  State<OptionsPage> createState() => _OptionsPageState();
}

class _OptionsPageState extends State<OptionsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Docket Tracker'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Text
              Text(
                'Welcome ${widget.role.toUpperCase()}!',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose an option to continue',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 40),

              // Show technician notification banner only for workers
              if (widget.role == 'worker')
                TechnicianNotificationBanner(
                  userUUID: 'E-997',
                  employeeNo: 'E-997',
                ),

              // Options Grid
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    // ---- Add Docket (CE, CS, CRO) ----
                    if (widget.role == "ce" ||
                        widget.role == "cs" ||
                        widget.role == "cro")
                      _buildOptionCard(
                        context,
                        'Add Docket',
                        Icons.assignment,
                        const Color(0xFFFFD700),
                        () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const DocketTypeSelectionPage(),
                            ),
                          );
                        },
                      ),

                    // ---- Add Docket X (CE, CS, CRO) ----
                    if (widget.role == "ce" ||
                        widget.role == "cs" ||
                        widget.role == "cro")
                      _buildOptionCard(
                        context,
                        'Add Docket X',
                        Icons.add_a_photo,
                        const Color(0xFF4CAF50),
                        () {
                          openDocketCamera(context);
                        },
                      ),

                    // ---- View Current Docket (CE, CS) ----
                    if (widget.role == "ce" || widget.role == "cs")
                      _buildOptionCard(
                        context,
                        'View Current Docket',
                        Icons.assessment,
                        const Color(0xFFFFD700),
                        () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const DocketSelectionPage(),
                            ),
                          );
                        },
                      ),

                    // ---- View Workers (CE, CS only) ----
                    if (widget.role == "ce" || widget.role == "cs")
                      _buildOptionCard(
                        context,
                        'View Workers in the Depo',
                        Icons.people,
                        const Color(0xFFFFD700),
                        () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  WorkerListPage(loggedInRole: widget.role),
                            ),
                          );
                        },
                      ),

                    // ---- 🔹 Workers Summary (CE, CS only) ----
                    if (widget.role == "ce" || widget.role == "cs")
                      _buildOptionCard(
                        context,
                        'Workers Summary',
                        Icons.bar_chart,
                        const Color(0xFFFFD700),
                        () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const WorkersSummaryPage(),
                            ),
                          );
                        },
                      ),

                    // ---- Staff Management (CE only) ----
                    if (widget.role == "ce")
                      _buildOptionCard(
                        context,
                        'Staff Management',
                        Icons.manage_accounts,
                        const Color(0xFFFFD700),
                        () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => StaffHomePage()),
                          );
                        },
                      ),

                    // ---- Technician Portal (All Roles) ----
                    _buildOptionCard(
                      context,
                      'Technician Portal',
                      Icons.engineering,
                      const Color(0xFFFFD700),
                      () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const TechnicianPortalPage(),
                          ),
                        );
                      },
                    ),

                    // ---- Assigned Dockets (All Roles) ----
                    _buildOptionCard(
                      context,
                      'Assigned Dockets',
                      Icons.assignment_turned_in,
                      const Color(0xFFFFD700),
                      () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                AssignedDocketsPage(userRole: widget.role),
                          ),
                        );
                      },
                    ),

                    // ---- See Assignments (All Roles) ----
                    _buildOptionCard(
                      context,
                      'See Assignments',
                      Icons.visibility,
                      const Color(0xFFFFD700),
                      () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SeeAssignmentsOptionsPage(),
                          ),
                        );
                      },
                    ),

                    // ---- E-Docket (All Roles) ----
                    _buildOptionCard(
                      context,
                      'E-Docket',
                      Icons.description,
                      const Color(0xFFFFD700),
                      () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const EDocketPage(),
                          ),
                        );
                      },
                    ),

                    // ---- Payments (CE, CS only) ----
                    if (widget.role == "ce" || widget.role == "cs")
                      _buildOptionCard(
                        context,
                        'Payments',
                        Icons.payment,
                        const Color(0xFFFFD700),
                        () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const PaymentPageOptions(),
                            ),
                          );
                        },
                      ),

                    // ---- View Dockets (CE, CS only) ----
                    if (widget.role == "ce" || widget.role == "cs")
                      _buildOptionCard(
                        context,
                        'View Dockets',
                        Icons.dashboard,
                        const Color(0xFFFFD700),
                        () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ViewDocketSummaryXPage(),
                            ),
                          );
                        },
                      ),

                    // ---- Pending Dockets (All Roles) ----
                    _buildOptionCard(
                      context,
                      'Pending Dockets',
                      Icons.pending_actions,
                      const Color(0xFFFF9800),
                      () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const PendingDocketsPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Card Builder
  Widget _buildOptionCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: color,
                child: Icon(icon, color: const Color(0xFF003366)),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
