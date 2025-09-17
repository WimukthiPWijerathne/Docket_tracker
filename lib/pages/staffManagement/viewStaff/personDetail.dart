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

  // Helper method to determine screen type
  ScreenType _getScreenType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) return ScreenType.mobile;
    if (width < 1024) return ScreenType.tablet;
    if (width < 1440) return ScreenType.desktop;
    return ScreenType.largeDesktop;
  }

  // Get responsive values based on screen type
  ResponsiveValues _getResponsiveValues(ScreenType screenType) {
    switch (screenType) {
      case ScreenType.mobile:
        return ResponsiveValues(
          horizontalPadding: 16.0,
          verticalPadding: 16.0,
          cardSpacing: 12.0,
          avatarRadius: 32.0,
          titleFontSize: 18.0,
          subtitleFontSize: 14.0,
          gridCrossAxisCount: 1,
          maxContentWidth: double.infinity,
          useCompactLayout: true,
        );
      case ScreenType.tablet:
        return ResponsiveValues(
          horizontalPadding: 24.0,
          verticalPadding: 20.0,
          cardSpacing: 16.0,
          avatarRadius: 40.0,
          titleFontSize: 20.0,
          subtitleFontSize: 16.0,
          gridCrossAxisCount: 2,
          maxContentWidth: 800.0,
          useCompactLayout: false,
        );
      case ScreenType.desktop:
        return ResponsiveValues(
          horizontalPadding: 32.0,
          verticalPadding: 24.0,
          cardSpacing: 16.0,
          avatarRadius: 48.0,
          titleFontSize: 24.0,
          subtitleFontSize: 18.0,
          gridCrossAxisCount: 2,
          maxContentWidth: 1100.0,
          useCompactLayout: false,
        );
      case ScreenType.largeDesktop:
        return ResponsiveValues(
          horizontalPadding: 40.0,
          verticalPadding: 32.0,
          cardSpacing: 20.0,
          avatarRadius: 52.0,
          titleFontSize: 26.0,
          subtitleFontSize: 20.0,
          gridCrossAxisCount: 2,
          maxContentWidth: 1300.0,
          useCompactLayout: false,
        );
    }
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

  Future<void> _showConfirmationDialog() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  const Color(0xFFF8FAFC),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: (_person.isActive ? Colors.orange.shade100 : Colors.green.shade100).withOpacity(0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated Icon with pulsing effect
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 1000),
                    tween: Tween(begin: 0.8, end: 1.0),
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                (_person.isActive ? Colors.orange.shade100 : Colors.green.shade100).withOpacity(0.3),
                                (_person.isActive ? Colors.orange.shade200 : Colors.green.shade200).withOpacity(0.1),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (_person.isActive ? Colors.orange.shade300 : Colors.green.shade300).withOpacity(0.4),
                                blurRadius: 15,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Icon(
                            _person.isActive ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            size: 40,
                            color: _person.isActive ? Colors.orange.shade700 : Colors.green.shade700,
                          ),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Title with enhanced styling
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: (_person.isActive ? Colors.orange.shade50 : Colors.green.shade50),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (_person.isActive ? Colors.orange.shade200 : Colors.green.shade200),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'Confirm ${_person.isActive ? 'Deactivation' : 'Activation'}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _person.isActive ? Colors.orange.shade800 : Colors.green.shade800,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Content with better styling
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Are you sure you want to mark',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF003366).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF003366).withOpacity(0.2)),
                          ),
                          child: Text(
                            _person.fullName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF003366),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'as ${_person.isActive ? 'Inactive' : 'Active'}?',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Action buttons with enhanced styling
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.shade200,
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              onTap: () => Navigator.of(context).pop(false),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.close_rounded,
                                      color: Colors.grey.shade600,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'CANCEL',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 16),
                      
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: _person.isActive
                                  ? [Colors.orange.shade500, Colors.orange.shade700]
                                  : [Colors.green.shade500, Colors.green.shade700],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (_person.isActive ? Colors.orange.shade400 : Colors.green.shade400).withOpacity(0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              onTap: () => Navigator.of(context).pop(true),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _person.isActive ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _person.isActive ? 'DEACTIVATE' : 'ACTIVATE',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (confirm == true) {
      await _toggleActive();
    }
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
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _person.isActive ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Status Updated!',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '${_person.fullName} marked ${_person.isActive ? "Active" : "Inactive"}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: _person.isActive ? Colors.green.shade700 : Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
        elevation: 8,
      ));
    } else {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.error_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Update Failed!',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Unable to update ${_person.fullName} status',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
        elevation: 8,
      ));
    }
  }

  Widget _buildDetailCard(String title, String? value, IconData icon, ResponsiveValues values, {bool isFlexible = false}) {
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
        margin: EdgeInsets.only(bottom: values.cardSpacing),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: IntrinsicHeight(
            child: Padding(
              padding: EdgeInsets.all(values.useCompactLayout ? 12 : 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: values.useCompactLayout ? 32 : 40,
                    height: values.useCompactLayout ? 32 : 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF003366),
                          const Color(0xFF004080),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF003366).withOpacity(0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      icon,
                      color: Colors.white,
                      size: values.useCompactLayout ? 16 : 18,
                    ),
                  ),
                  SizedBox(width: values.useCompactLayout ? 12 : 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: values.useCompactLayout ? 10 : 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: values.useCompactLayout ? 2 : 4),
                        Text(
                          value ?? 'Not specified',
                          style: TextStyle(
                            fontSize: values.useCompactLayout ? 12 : 14,
                            fontWeight: FontWeight.w600,
                            color: value != null ? const Color(0xFF003366) : Colors.grey.shade400,
                            letterSpacing: 0.1,
                          ),
                          maxLines: isFlexible ? null : (values.useCompactLayout ? 1 : 2),
                          overflow: isFlexible ? null : TextOverflow.ellipsis,
                          softWrap: isFlexible,
                        ),
                      ],
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

  Widget _buildProfileHeader(ResponsiveValues values) {
    final activeColor = _person.isActive ? Colors.green.shade700 : Colors.red.shade700;
    final activeBg = _person.isActive ? Colors.green.shade50 : Colors.red.shade50;

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Card(
          elevation: values.useCompactLayout ? 2 : 4,
          shadowColor: Colors.black.withOpacity(0.12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: EdgeInsets.all(values.useCompactLayout ? 16 : 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  const Color(0xFFF0F7FF),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
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
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: values.avatarRadius,
                        backgroundColor: const Color(0xFFE8F4FD),
                        child: Text(
                          _getInitials(),
                          style: TextStyle(
                            color: const Color(0xFF003366),
                            fontWeight: FontWeight.w700,
                            fontSize: values.avatarRadius * 0.4,
                            letterSpacing: 0.5,
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
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: activeColor.withOpacity(0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(2),
                        child: CircleAvatar(
                          radius: values.avatarRadius * 0.25,
                          backgroundColor: activeBg,
                          child: Icon(
                            _person.isActive ? Icons.check_circle : Icons.cancel,
                            size: values.avatarRadius * 0.3,
                            color: activeColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: values.useCompactLayout ? 12 : 16),
                Text(
                  _person.fullName,
                  style: TextStyle(
                    fontSize: values.titleFontSize,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF003366),
                    letterSpacing: 0.2,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: values.useCompactLayout ? 8 : 12),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: values.useCompactLayout ? 12 : 16,
                    vertical: values.useCompactLayout ? 6 : 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [activeBg, activeColor.withOpacity(0.1)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: activeColor.withOpacity(0.3), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: activeColor.withOpacity(0.15),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _person.isActive ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        color: activeColor,
                        size: values.useCompactLayout ? 14 : 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _person.isActive ? 'ACTIVE' : 'INACTIVE',
                        style: TextStyle(
                          color: activeColor,
                          fontWeight: FontWeight.w600,
                          fontSize: values.useCompactLayout ? 10 : 11,
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

  Widget _buildActionButton(ResponsiveValues values, {required bool fullWidth}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: fullWidth ? double.infinity : (values.useCompactLayout ? 200 : 280),
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
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _loading ? null : _showConfirmationDialog,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: EdgeInsets.symmetric(
                vertical: values.useCompactLayout ? 12 : 16,
                horizontal: 16,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_loading)
                    SizedBox(
                      width: values.useCompactLayout ? 16 : 20,
                      height: values.useCompactLayout ? 16 : 20,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  else
                    Icon(
                      _person.isActive ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white,
                      size: values.useCompactLayout ? 16 : 20,
                    ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _loading
                          ? 'Updating...'
                          : (_person.isActive ? 'Mark as Inactive' : 'Mark as Active'),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: values.useCompactLayout ? 12 : 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

  // New method for flexible detail layout on desktop
  Widget _buildDetailsFlexibleLayout(ResponsiveValues values) {
    return Wrap(
      spacing: values.cardSpacing,
      runSpacing: values.cardSpacing,
      children: _getDetailCards(values, isFlexible: true),
    );
  }

  List<Widget> _getDetailCards(ResponsiveValues values, {bool isFlexible = false}) {
    final details = [
      {'title': 'Employee Number', 'value': _person.employeeNo, 'icon': Icons.badge_outlined},
      {'title': 'Name', 'value': '${_person.firstName} ${_person.lastName}'.trim(), 'icon': Icons.person_outline},
      {'title': 'Branch', 'value': 'Kelaniya', 'icon': Icons.business_outlined},
      {'title': 'Depot', 'value': _person.depot, 'icon': Icons.location_on_outlined},
      {'title': 'Designation', 'value': _person.designation, 'icon': Icons.work_outline},
      {'title': 'Access Level', 'value': _person.accessLevel, 'icon': Icons.security_outlined},
      {'title': 'Person ID', 'value': _person.personID, 'icon': Icons.fingerprint_outlined},
    ];

    return details.map((detail) {
      if (isFlexible) {
        return SizedBox(
          width: (MediaQuery.of(context).size.width > 1200) ? 
                 (MediaQuery.of(context).size.width - 200) * 0.4 / 2 : 
                 (MediaQuery.of(context).size.width - 150) * 0.5 / 2,
          child: _buildDetailCard(
            detail['title'] as String,
            detail['value'] as String?,
            detail['icon'] as IconData,
            values,
            isFlexible: true,
          ),
        );
      } else {
        return _buildDetailCard(
          detail['title'] as String,
          detail['value'] as String?,
          detail['icon'] as IconData,
          values,
          isFlexible: false,
        );
      }
    }).toList();
  }

  Widget _buildResponsiveLayout(BuildContext context) {
    final screenType = _getScreenType(context);
    final values = _getResponsiveValues(screenType);
    final screenWidth = MediaQuery.of(context).size.width;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        // Mobile layout
        if (screenType == ScreenType.mobile) {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: values.horizontalPadding,
                vertical: values.verticalPadding,
              ),
              child: Column(
                children: [
                  _buildProfileHeader(values),
                  SizedBox(height: values.cardSpacing * 1.5),
                  Container(
                    alignment: Alignment.centerLeft,
                    margin: EdgeInsets.only(bottom: values.cardSpacing),
                    child: Text(
                      'Details',
                      style: TextStyle(
                        fontSize: values.subtitleFontSize,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF003366),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                                            ..._getDetailCards(values),
                  SizedBox(height: values.cardSpacing * 2),
                  _buildActionButton(values, fullWidth: true),
                  SizedBox(height: values.verticalPadding),
                ],
              ),
            ),
          );
        }
        
        // Tablet layout
        else if (screenType == ScreenType.tablet) {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Center(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: values.maxContentWidth,
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: values.horizontalPadding,
                  vertical: values.verticalPadding,
                ),
                child: Column(
                  children: [
                    _buildProfileHeader(values),
                    SizedBox(height: values.cardSpacing * 2),
                    Container(
                      alignment: Alignment.centerLeft,
                      margin: EdgeInsets.only(bottom: values.cardSpacing * 1.5),
                      child: Text(
                        'Details',
                        style: TextStyle(
                          fontSize: values.subtitleFontSize,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF003366),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: values.gridCrossAxisCount,
                      crossAxisSpacing: values.cardSpacing,
                      mainAxisSpacing: values.cardSpacing,
                      childAspectRatio: 3.0,
                      children: _getDetailCards(values),
                    ),
                    SizedBox(height: values.cardSpacing * 2.5),
                    _buildActionButton(values, fullWidth: false),
                    SizedBox(height: values.verticalPadding),
                  ],
                ),
              ),
            ),
          );
        }
        
        // Desktop and Large Desktop layout
        else {
          // Always use split layout for desktop/web view
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Center(
              child: Container(
                constraints: BoxConstraints(maxWidth: values.maxContentWidth),
                padding: EdgeInsets.symmetric(
                  horizontal: values.horizontalPadding,
                  vertical: values.verticalPadding,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left column - Profile
                    Expanded(
                      flex: screenWidth > 1200 ? 2 : 3,
                      child: Column(
                        children: [
                          _buildProfileHeader(values),
                          SizedBox(height: values.cardSpacing * 2),
                          _buildActionButton(values, fullWidth: true),
                        ],
                      ),
                    ),
                    SizedBox(width: values.cardSpacing * 2),
                    // Right column - Details
                    Expanded(
                      flex: screenWidth > 1200 ? 3 : 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Details',
                            style: TextStyle(
                              fontSize: values.subtitleFontSize,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF003366),
                              letterSpacing: 0.2,
                            ),
                          ),
                          SizedBox(height: values.cardSpacing * 1.5),
                          // Use flexible layout for details instead of grid
                          _buildDetailsFlexibleLayout(values),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenType = _getScreenType(context);
    final values = _getResponsiveValues(screenType);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _person.fullName,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: values.useCompactLayout ? 14 : 16,
            letterSpacing: 0.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: const Color(0xFF003366),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: screenType == ScreenType.mobile,
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

// Enums and helper classes for responsive design
enum ScreenType {
  mobile,
  tablet,
  desktop,
  largeDesktop,
}

class ResponsiveValues {
  final double horizontalPadding;
  final double verticalPadding;
  final double cardSpacing;
  final double avatarRadius;
  final double titleFontSize;
  final double subtitleFontSize;
  final int gridCrossAxisCount;
  final double maxContentWidth;
  final bool useCompactLayout;

  ResponsiveValues({
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.cardSpacing,
    required this.avatarRadius,
    required this.titleFontSize,
    required this.subtitleFontSize,
    required this.gridCrossAxisCount,
    required this.maxContentWidth,
    required this.useCompactLayout,
  });
}