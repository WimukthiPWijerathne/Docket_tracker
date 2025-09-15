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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } else {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Update failed'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  Widget _buildDetailCard(String title, String? value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Colors.grey.shade50],
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF003366).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF003366),
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
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value ?? 'Not specified',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: value != null ? Colors.black87 : Colors.grey.shade400,
                      ),
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

  Widget _buildResponsiveLayout(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Enhanced breakpoints for better responsiveness
    final isVerySmall = screenWidth < 360;        // Very small phones
    final isSmall = screenWidth < 600;            // Regular phones  
    final isMedium = screenWidth >= 600 && screenWidth < 900;   // Small tablets
    final isLarge = screenWidth >= 900 && screenWidth < 1200;   // Large tablets
    final isXLarge = screenWidth >= 1200;         // Desktop/Large screens
    
    // Dynamic padding based on screen size
    double getPadding() {
      if (isVerySmall) return 12;
      if (isSmall) return 16;
      if (isMedium) return 24;
      if (isLarge) return 32;
      return 40;
    }
    
    // Max width constraints for content
    double getMaxWidth() {
      if (isXLarge) return 1200;
      if (isLarge) return 900;
      return double.infinity;
    }

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: getMaxWidth()),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(getPadding()),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile header with responsive sizing
              _buildProfileHeader(
                compact: isVerySmall,
                medium: isSmall || isMedium,
                large: isLarge || isXLarge,
              ),
              SizedBox(height: isSmall ? 20 : 32),
              
              // Details section with responsive layout
              if (isSmall)
                _buildMobileDetailsLayout()
              else if (isMedium)
                _buildTabletDetailsLayout()
              else
                _buildDesktopDetailsLayout(),
              
              SizedBox(height: isSmall ? 24 : 40),
              
              // Action button with responsive positioning
              if (isSmall)
                _buildActionButton(fullWidth: true)
              else
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: _buildActionButton(fullWidth: true),
                  ),
                ),
              
              SizedBox(height: getPadding()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader({
    required bool compact,
    required bool medium,
    required bool large,
  }) {
    final activeColor = _person.isActive ? Colors.green.shade700 : Colors.red.shade700;
    final activeBg = _person.isActive ? Colors.green.shade100 : Colors.red.shade100;

    // Responsive sizing
    final avatarRadius = compact ? 35.0 : (medium ? 45.0 : 55.0);
    final statusRadius = compact ? 12.0 : (medium ? 16.0 : 18.0);
    final titleSize = compact ? 20.0 : (medium ? 24.0 : 28.0);
    final statusIconSize = compact ? 14.0 : (medium ? 18.0 : 20.0);

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(compact ? 16 : (medium ? 24 : 32)),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Colors.blue.shade50],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              // Avatar with status indicator
              Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF003366).withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: avatarRadius,
                      backgroundColor: const Color(0xFFE8EEF6),
                      child: Text(
                        _getInitials(),
                        style: TextStyle(
                          color: const Color(0xFF003366),
                          fontWeight: FontWeight.bold,
                          fontSize: avatarRadius * 0.6,
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
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: statusRadius,
                        backgroundColor: activeBg,
                        child: Icon(
                          _person.isActive ? Icons.check : Icons.close,
                          size: statusIconSize,
                          color: activeColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: compact ? 12 : (medium ? 16 : 20)),
              
              // Name
              Text(
                _person.fullName,
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF003366),
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: 12),
              
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: activeBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: activeColor.withOpacity(0.3)),
                ),
                child: Text(
                  _person.isActive ? 'ACTIVE' : 'INACTIVE',
                  style: TextStyle(
                    color: activeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: compact ? 11 : 12,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileDetailsLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Details',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF003366),
          ),
        ),
        const SizedBox(height: 16),
        ..._getDetailCards(),
      ],
    );
  }

  Widget _buildTabletDetailsLayout() {
    final cards = _getDetailCards();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Details',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF003366),
          ),
        ),
        const SizedBox(height: 20),
        // Display cards in a 2-column grid
        for (int i = 0; i < cards.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(child: cards[i]),
                const SizedBox(width: 16),
                if (i + 1 < cards.length)
                  Expanded(child: cards[i + 1])
                else
                  const Expanded(child: SizedBox()),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDesktopDetailsLayout() {
    final cards = _getDetailCards();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Details',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF003366),
          ),
        ),
        const SizedBox(height: 24),
        // Display cards in a 3-column grid for desktop
        for (int i = 0; i < cards.length; i += 3)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(child: cards[i]),
                const SizedBox(width: 16),
                if (i + 1 < cards.length)
                  Expanded(child: cards[i + 1])
                else
                  const Expanded(child: SizedBox()),
                const SizedBox(width: 16),
                if (i + 2 < cards.length)
                  Expanded(child: cards[i + 2])
                else
                  const Expanded(child: SizedBox()),
              ],
            ),
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
    return FadeTransition(
      opacity: _fadeAnimation,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: fullWidth ? double.infinity : null,
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
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _loading ? null : _toggleActive,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
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
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
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
        title: Text(
          _person.fullName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: const Color(0xFF003366).withOpacity(0.95),
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF003366), Color(0xFF004080)],
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.grey.shade100, Colors.white],
          ),
        ),
        child: SafeArea(
          child: _buildResponsiveLayout(context),
        ),
      ),
    );
  }
}