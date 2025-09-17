import 'package:flutter/material.dart';
import '../loginScreen/login_page.dart';
import '../addDocket/docket_type_selection_page.dart';
import '../docket_selection_page.dart';
import '../assign.dart';
import '../workersProfile/workersProfile.dart';
// Assigned Dockets page
import '../AssignedDockets/assigned_dockets_page.dart';
// Workers Summary page
import '../../pages/workersSummey/workers_summery_page.dart';
// Staff page
import '../staffManagement/staffHomePage.dart';

// 🔹 Technician Portal page (simple placeholder for now)
class TechnicianPortalPage extends StatelessWidget {
  const TechnicianPortalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Technician Portal"),
        backgroundColor: const Color(0xFF003366),
      ),
      body: const Center(
        child: Text(
          "Welcome to the Technician Portal",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class OptionsPage extends StatefulWidget {
  final String role; // role parameter
  const OptionsPage({super.key, required this.role});

  @override
  State<OptionsPage> createState() => _OptionsPageState();
}

class _OptionsPageState extends State<OptionsPage>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late List<Animation<double>> _cardAnimations;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Create staggered animations for cards
    _cardAnimations = List.generate(
      7, // increased max cards since we added Technician Portal
      (index) => Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: Interval(
          (index * 0.1).clamp(0.0, 0.8),
          (0.6 + (index * 0.1)).clamp(0.2, 1.0),
          curve: Curves.easeOutCubic,
        ),
      )),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Docket Tracker',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF003366),
                Color(0xFF004080),
                Color(0xFF0056B3),
              ],
            ),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  size: 20,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => const LoginPage(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF8FAFE),
              Colors.white,
              Color(0xFFF0F7FF),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return _buildResponsiveLayout(constraints);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildResponsiveLayout(BoxConstraints constraints) {
    final screenWidth = constraints.maxWidth;

    int crossAxisCount;
    double horizontalPadding;

    if (screenWidth > 1000) {
      crossAxisCount = 4;
      horizontalPadding = 40;
    } else if (screenWidth > 700) {
      crossAxisCount = 3;
      horizontalPadding = 32;
    } else if (screenWidth > 500) {
      crossAxisCount = 2;
      horizontalPadding = 24;
    } else {
      crossAxisCount = 2;
      horizontalPadding = 16;
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeHeader(screenWidth),
            SizedBox(height: screenWidth > 600 ? 40 : 32),
            _buildOptionsGrid(crossAxisCount, screenWidth),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader(double screenWidth) {
    return Container(
      padding: EdgeInsets.all(screenWidth > 600 ? 24 : 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Color(0xFFF8FAFE),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome ${widget.role.toUpperCase()}!',
            style: TextStyle(
              fontSize: screenWidth > 600 ? 32 : 26,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF003366),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose an option to continue',
            style: TextStyle(
              fontSize: screenWidth > 600 ? 18 : 16,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsGrid(int crossAxisCount, double screenWidth) {
    final options = _getAvailableOptions();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.0,
      ),
      itemCount: options.length,
      itemBuilder: (context, index) {
        if (index >= _cardAnimations.length) {
          return _buildOptionCard(
            context,
            options[index]['title'],
            options[index]['icon'],
            options[index]['gradient'],
            options[index]['onTap'],
            screenWidth,
          );
        }

        return AnimatedBuilder(
          animation: _cardAnimations[index],
          builder: (context, child) {
            final animation = _cardAnimations[index];
            return Transform.scale(
              scale: 0.8 + (animation.value * 0.2),
              child: Opacity(
                opacity: animation.value,
                child: _buildOptionCard(
                  context,
                  options[index]['title'],
                  options[index]['icon'],
                  options[index]['gradient'],
                  options[index]['onTap'],
                  screenWidth,
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<Map<String, dynamic>> _getAvailableOptions() {
    List<Map<String, dynamic>> options = [];

    // Add Docket (CE, CS, CRO)
    if (widget.role == "ce" || widget.role == "cs" || widget.role == "cro") {
      options.add({
        'title': 'Add Docket',
        'icon': Icons.assignment_add,
        'gradient': const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFD700), Color(0xFFFFC107)],
        ),
        'onTap': () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const DocketTypeSelectionPage(),
            ),
          );
        },
      });
    }

    // View Current Docket (CE, CS)
    if (widget.role == "ce" || widget.role == "cs") {
      options.add({
        'title': 'View Current Docket',
        'icon': Icons.assessment,
        'gradient': const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4FC3F7), Color(0xFF29B6F6)],
        ),
        'onTap': () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const DocketSelectionPage(),
            ),
          );
        },
      });
    }

    // View Workers (CE, CS only)
    if (widget.role == "ce" || widget.role == "cs") {
      options.add({
        'title': 'View Workers in the Depo',
        'icon': Icons.people,
        'gradient': const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF81C784), Color(0xFF66BB6A)],
        ),
        'onTap': () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => WorkerListPage(loggedInRole: widget.role),
            ),
          );
        },
      });
    }

    // Workers Summary (CE, CS only)
    if (widget.role == "ce" || widget.role == "cs") {
      options.add({
        'title': 'Workers Summary',
        'icon': Icons.bar_chart,
        'gradient': const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFBA68C8), Color(0xFFAB47BC)],
        ),
        'onTap': () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const WorkersSummaryPage(),
            ),
          );
        },
      });
    }

    // Staff (CE only)
    if (widget.role == "ce") {
      options.add({
        'title': 'Staff',
        'icon': Icons.admin_panel_settings,
        'gradient': const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF8A65), Color(0xFFFF7043)],
        ),
        'onTap': () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const StaffHomePage(),
            ),
          );
        },
      });
    }

    // Technician Portal (All except worker)
    if (widget.role != "worker") {
      options.add({
        'title': 'Technician Portal',
        'icon': Icons.build_circle,
        'gradient': const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF42A5F5), Color(0xFF1E88E5)],
        ),
        'onTap': () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const TechnicianPortalPage(),
            ),
          );
        },
      });
    }

    // Assigned Dockets (All Roles)
    options.add({
      'title': 'Assigned Dockets',
      'icon': Icons.assignment_turned_in,
      'gradient': const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFA5D6A7), Color(0xFF81C784)],
      ),
      'onTap': () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const AssignedDocketsPage(),
          ),
        );
      },
    });

    return options;
  }

  Widget _buildOptionCard(
    BuildContext context,
    String title,
    IconData icon,
    LinearGradient gradient,
    VoidCallback onTap,
    double screenWidth,
  ) {
    final isLargeScreen = screenWidth > 600;

    return Card(
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Color(0xFFF8FAFE)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: EdgeInsets.all(isLargeScreen ? 24 : 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: isLargeScreen ? 70 : 60,
                    height: isLargeScreen ? 70 : 60,
                    decoration: BoxDecoration(
                      gradient: gradient,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: gradient.colors[1].withOpacity(0.4),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      icon,
                      color: const Color(0xFF003366),
                      size: isLargeScreen ? 36 : 32,
                    ),
                  ),
                  SizedBox(height: isLargeScreen ? 20 : 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isLargeScreen ? 16 : 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF003366),
                      letterSpacing: 0.3,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
