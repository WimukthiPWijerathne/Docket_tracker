import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../model/person.dart';
import '../model/httpServicePeople.dart';

class PersonDetailPage extends StatefulWidget {
  final Person person;
  
  const PersonDetailPage({super.key, required this.person});

  @override
  State<PersonDetailPage> createState() => _PersonDetailPageState();
}

class _PersonDetailPageState extends State<PersonDetailPage>
    with TickerProviderStateMixin {
  final _svc = PeopleService();
  late Person _person;
  bool _loading = false;
  
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _person = widget.person;
    
    // Initialize animations
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    // Start animations
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  String _getInitials() {
    // Extract first name and remove common titles
    String firstName = _person.firstName.trim();
    final ln = _person.lastName.trim();
    
    // Remove common titles from first name
    final titles = ['mr', 'mrs', 'ms'];
    final nameParts = firstName.split(' ');
    
    // If first part is a title, use the next part as first name
    if (nameParts.length > 1 && titles.contains(nameParts[0].toLowerCase())) {
      firstName = nameParts[1];
    } else {
      firstName = nameParts[0];
    }
    
    final a = firstName.isNotEmpty ? firstName[0] : '';
    final b = ln.isNotEmpty ? ln[0] : '';
    return (a + b).toUpperCase();
  }

  Future<void> _toggleActive() async {
    setState(() => _loading = true);
    
    final ok = await _svc.setAvailability(
      personID: _person.personID, 
      active: !_person.isActive
    );
    
    if (ok) {
      setState(() {
        _person = _person.copyWith(available: _person.isActive ? 'No' : 'Yes');
        _loading = false;
      });
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          '${_person.fullName} marked ${_person.isActive ? "Active" : "Inactive"}'
        ),
        backgroundColor: _person.isActive ? Colors.green.shade700 : Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ));
    } else {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Update failed'),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ));
    }
  }

  Widget _buildDetailCard(String title, String? value, IconData icon) {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, (1 - _fadeAnimation.value) * 10),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: child,
          ),
        );
      },
      child: Card(
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.05),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.only(bottom: 12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF003366),
                        const Color(0xFF004080),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF003366).withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value ?? 'Not specified',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: value != null ? const Color(0xFF003366) : Colors.grey.shade400,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResponsiveLayout(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    if (screenWidth > 1200) {
      return _buildDesktopLayout();
    } else if (screenWidth > 768) {
      return _buildTabletLayout();
    } else {
      return _buildMobileLayout();
    }
  }

  Widget _buildMobileLayout() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildProfileHeader(compact: true),
                const SizedBox(height: 24),
                _buildDetailsSection(),
                const SizedBox(height: 32),
                _buildActionButton(fullWidth: true),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabletLayout() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Center(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: constraints.maxWidth > 900 ? 700 : constraints.maxWidth * 0.9,
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _buildProfileHeader(compact: false),
                  const SizedBox(height: 32),
                  _buildDetailsGrid(crossAxisCount: 2),
                  const SizedBox(height: 40),
                  _buildActionButton(fullWidth: false),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopLayout() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1000),
            padding: const EdgeInsets.all(32),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left column - Profile
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildProfileHeader(compact: false),
                      const SizedBox(height: 32),
                      _buildActionButton(fullWidth: true),
                    ],
                  ),
                ),
                const SizedBox(width: 40),
                // Right column - Details
                Expanded(
                  flex: 3,
                  child: _buildDetailsGrid(crossAxisCount: 1),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileHeader({required bool compact}) {
    final activeColor = _person.isActive ? Colors.green.shade700 : Colors.red.shade700;
    final activeBg = _person.isActive ? Colors.green.shade50 : Colors.red.shade50;

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Card(
          elevation: 4,
          shadowColor: Colors.black.withOpacity(0.12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            padding: EdgeInsets.all(compact ? 20 : 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  const Color(0xFFF0F7FF),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF003366).withOpacity(0.2),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: compact ? 36 : 42,
                        backgroundColor: const Color(0xFFE8F4FD),
                        child: Text(
                          _getInitials(),
                          style: TextStyle(
                            color: const Color(0xFF003366),
                            fontWeight: FontWeight.w700,
                            fontSize: compact ? 18 : 20,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child:                       Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: activeColor.withOpacity(0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(3),
                        child: CircleAvatar(
                          radius: compact ? 12 : 14,
                          backgroundColor: activeBg,
                          child: Icon(
                            _person.isActive ? Icons.check_circle : Icons.cancel,
                            size: compact ? 16 : 18,
                            color: activeColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 16 : 20),
                Text(
                  _person.fullName,
                  style: TextStyle(
                    fontSize: compact ? 18 : 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF003366),
                    letterSpacing: 0.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [activeBg, activeColor.withOpacity(0.1)],
                    ),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: activeColor.withOpacity(0.3), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: activeColor.withOpacity(0.15),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _person.isActive ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        color: activeColor,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _person.isActive ? 'ACTIVE' : 'INACTIVE',
                        style: TextStyle(
                          color: activeColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsSection() {
    return Column(
      children: [
        Container(
          alignment: Alignment.centerLeft,
          margin: const EdgeInsets.only(bottom: 20),
          child: Text(
            'Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF003366),
              letterSpacing: 0.2,
            ),
          ),
        ),
        ..._getDetailCards(),
      ],
    );
  }

  Widget _buildDetailsGrid({required int crossAxisCount}) {
    return Column(
      children: [
        Container(
          alignment: Alignment.centerLeft,
          margin: const EdgeInsets.only(bottom: 24),
          child: Text(
            'Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1F2937),
              letterSpacing: 0.2,
            ),
          ),
        ),
        if (crossAxisCount == 1)
          ..._getDetailCards()
        else
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 12,
            childAspectRatio: 3.5,
            children: _getDetailCards(),
          ),
      ],
    );
  }

  List<Widget> _getDetailCards() {
    return [
      _buildDetailCard('Employee Number', _person.employeeNo, Icons.badge_outlined),
      _buildDetailCard('First Name', _person.firstName, Icons.person_outline),
      _buildDetailCard('Last Name', _person.lastName, Icons.person_outline_outlined),
      _buildDetailCard('Depot/Region', _person.depot, Icons.location_on_outlined),
      _buildDetailCard('Designation', _person.designation, Icons.work_outline),
      _buildDetailCard('Access Level', _person.accessLevel, Icons.security_outlined),
      _buildDetailCard('Person ID', _person.personID, Icons.fingerprint_outlined),
      _buildDetailCard('UUID', _person.uuid, Icons.code_outlined),
    ];
  }

  Widget _buildActionButton({required bool fullWidth}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: fullWidth ? double.infinity : 280,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _person.isActive
                ? [Colors.orange.shade400, Colors.orange.shade600]
                : [Colors.green.shade400, Colors.green.shade600],
          ),
          boxShadow: [
            BoxShadow(
              color: (_person.isActive ? Colors.orange.shade400 : Colors.green.shade400).withOpacity(0.25),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _loading ? null : _toggleActive,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_loading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  else
                    Icon(
                      _person.isActive ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white,
                      size: 20,
                    ),
                  const SizedBox(width: 12),
                  Text(
                    _loading
                        ? 'Updating...'
                        : (_person.isActive ? 'Mark as Inactive' : 'Mark as Active'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _person.fullName,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            letterSpacing: 0.2,
          ),
        ),
        backgroundColor: const Color(0xFF003366),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF003366),
                const Color(0xFF004080),
              ],
            ),
          ),
        ),
      ),
      body: Container(
        color: const Color(0xFFF8FAFC),
        child: SafeArea(
          child: _buildResponsiveLayout(context),
        ),
      ),
    );
  }
}