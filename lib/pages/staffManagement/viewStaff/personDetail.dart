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
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
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
      begin: const Offset(0, 0.3),
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
    final fn = _person.firstName.trim();
    final ln = _person.lastName.trim();
    final a = fn.isNotEmpty ? fn[0] : '';
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
        backgroundColor: _person.isActive ? Colors.green : Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    } else {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Update failed'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  Widget _buildDetailCard(String title, String? value, IconData icon, {int delay = 0}) {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, (1 - _fadeAnimation.value) * 20),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: Material(
          elevation: 2,
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          shadowColor: Colors.black.withOpacity(0.1),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: value != null ? () {
              // Add subtle haptic feedback
              HapticFeedback.selectionClick();
            } : null,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    Colors.grey.shade50,
                  ],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF003366),
                          const Color(0xFF004080),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF003366).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      icon,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          value ?? 'Not specified',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: value != null ? Colors.black87 : Colors.grey.shade400,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (value != null)
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.grey.shade400,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResponsiveLayout(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600 && screenWidth <= 1024;
    final isDesktop = screenWidth > 1024;
    final isMobile = screenWidth <= 600;
    
    if (isDesktop) {
      return _buildDesktopLayout();
    } else if (isTablet) {
      return _buildTabletLayout();
    } else {
      return _buildMobileLayout();
    }
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileHeader(compact: true),
          const SizedBox(height: 24),
          _buildDetailsSection(),
          const SizedBox(height: 32),
          _buildActionButton(fullWidth: true),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildTabletLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileHeader(compact: false),
          const SizedBox(height: 32),
          _buildDetailsGrid(crossAxisCount: 2),
          const SizedBox(height: 40),
          Center(child: _buildActionButton(fullWidth: false)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          const SizedBox(width: 32),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailsGrid(crossAxisCount: 1),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader({required bool compact}) {
    final activeColor = _person.isActive ? Colors.green.shade700 : Colors.red.shade700;
    final activeBg = _person.isActive ? Colors.green.shade100 : Colors.red.shade100;

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          padding: EdgeInsets.all(compact ? 20 : 32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.blue.shade50,
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
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
                          color: const Color(0xFF003366).withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: compact ? 45 : 60,
                      backgroundColor: const Color(0xFFE8EEF6),
                      child: Text(
                        _getInitials(),
                        style: TextStyle(
                          color: const Color(0xFF003366),
                          fontWeight: FontWeight.bold,
                          fontSize: compact ? 24 : 32,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: activeColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: compact ? 16 : 20,
                        backgroundColor: activeBg,
                        child: Icon(
                          _person.isActive ? Icons.check : Icons.close,
                          size: compact ? 18 : 24,
                          color: activeColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: compact ? 16 : 24),
              Text(
                _person.fullName,
                style: TextStyle(
                  fontSize: compact ? 24 : 28,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF003366),
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [activeBg, activeColor.withOpacity(0.1)],
                  ),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: activeColor.withOpacity(0.3)),
                ),
                child: Text(
                  _person.isActive ? 'ACTIVE' : 'INACTIVE',
                  style: TextStyle(
                    color: activeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Details',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF003366),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 20),
        ..._getDetailCards(),
      ],
    );
  }

  Widget _buildDetailsGrid({required int crossAxisCount}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Details',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF003366),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 20),
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
      _buildDetailCard('Employee Number', _person.employeeNo, Icons.badge),
      _buildDetailCard('First Name', _person.firstName, Icons.person),
      _buildDetailCard('Last Name', _person.lastName, Icons.person_outline),
      _buildDetailCard('Depot/Region', _person.depot, Icons.location_on),
      _buildDetailCard('Designation', _person.designation, Icons.work),
      _buildDetailCard('Access Level', _person.accessLevel, Icons.security),
      _buildDetailCard('Person ID', _person.personID, Icons.fingerprint),
      _buildDetailCard('UUID', _person.uuid, Icons.code),
    ];
  }

  Widget _buildActionButton({required bool fullWidth}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: fullWidth ? double.infinity : 300,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _person.isActive
                ? [Colors.orange.shade400, Colors.orange.shade600]
                : [Colors.green.shade400, Colors.green.shade600],
          ),
          boxShadow: [
            BoxShadow(
              color: (_person.isActive ? Colors.orange : Colors.green).withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _loading ? null : _toggleActive,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_loading)
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  else
                    Icon(
                      _person.isActive ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white,
                      size: 24,
                    ),
                  const SizedBox(width: 12),
                  Text(
                    _loading
                        ? 'Updating...'
                        : (_person.isActive ? 'Mark as Inactive' : 'Mark as Active'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(_person.fullName),
        backgroundColor: const Color(0xFF003366).withOpacity(0.9),
        foregroundColor: Colors.white,
        elevation: 0,
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
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.grey.shade50,
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: _buildResponsiveLayout(context),
        ),
      ),
    );
  }
}