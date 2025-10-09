import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PayingRatesPage extends StatefulWidget {
  const PayingRatesPage({super.key});

  @override
  State<PayingRatesPage> createState() => _PayingRatesPageState();
}

class _PayingRatesPageState extends State<PayingRatesPage> {
  static const Color _primaryColor = Color(0xFF003366);
  static const Color _accentColor = Color(0xFFFFD700);

  // Salary rates by docket type (initialized from current hardcoded values)
  // Note: In the future, you can expand this to support different technician levels
  final Map<String, double> _salaryRates = {
    'Service Line Maintenance': 785.00, // Average of Tech I, II, III
    'Meter Testing': 985.00, // Average of available Tech levels
    'Estimate': 785.00, // Average of available Tech levels
    'Per Visit': 785.00, // Average of available Tech levels
    'Pole Disconnection': 550.00, // Standardized rate
    'Material Remove': 740.00, // Average of available Tech levels
    'Meter Replacement Only': 785.00, // Average of available Tech levels
    'Visit with Contractor': 1280.00, // Standardized rate
    'Pole Top Maintenance': 675.00, // Average rate (gang composition)
  };

  bool _isEditing = false;
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    // Initialize controllers for each rate
    _salaryRates.forEach((key, value) {
      _controllers[key] = TextEditingController(text: value.toString());
    });
  }

  @override
  void dispose() {
    // Dispose all controllers
    _controllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  void _toggleEditMode() {
    setState(() {
      if (_isEditing) {
        // Save changes
        _saveRates();
      }
      _isEditing = !_isEditing;
    });
  }

  void _saveRates() {
    // Update rates from controllers
    _controllers.forEach((key, controller) {
      final value = double.tryParse(controller.text);
      if (value != null && value >= 0) {
        _salaryRates[key] = value;
      } else {
        // Reset to original value if invalid
        controller.text = _salaryRates[key].toString();
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Payment rates updated successfully!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _cancelEdit() {
    setState(() {
      // Reset all controllers to original values
      _controllers.forEach((key, controller) {
        controller.text = _salaryRates[key].toString();
      });
      _isEditing = false;
    });
  }

  void _resetToDefaults() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Defaults'),
        content: const Text(
          'Are you sure you want to reset all rates to default values? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                // Reset to default values (based on incentive rates from the table)
                final defaults = {
                  'Service Line Maintenance': 785.00,
                  'Meter Testing': 985.00,
                  'Estimate': 785.00,
                  'Per Visit': 785.00,
                  'Pole Disconnection': 550.00,
                  'Material Remove': 740.00,
                  'Meter Replacement Only': 785.00,
                  'Visit with Contractor': 1280.00,
                  'Pole Top Maintenance': 675.00,
                };

                _salaryRates.clear();
                _salaryRates.addAll(defaults);

                _controllers.forEach((key, controller) {
                  controller.text = _salaryRates[key].toString();
                });
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Rates reset to default values'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Rates Configuration'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit Rates',
              onPressed: _toggleEditMode,
            ),
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Cancel',
              onPressed: _cancelEdit,
            ),
          if (!_isEditing)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'reset') {
                  _resetToDefaults();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'reset',
                  child: Row(
                    children: [
                      Icon(Icons.refresh, size: 20),
                      SizedBox(width: 8),
                      Text('Reset to Defaults'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Container(
        color: Colors.grey[50],
        child: Column(
          children: [
            // Header Info Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.05),
                border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: _primaryColor, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Work Type Payment Rates',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Configure payment rates for different types of work. These rates will be used to calculate technician payments.\n\nNote: Currently using simplified single-rate structure. Can be expanded to support Tech I, II, III, and Tech Help levels in the future.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                      height: 1.4,
                    ),
                  ),
                  if (_isEditing) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.orange.shade700,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Editing mode: Make your changes and tap the save button',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Rates List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _salaryRates.length,
                itemBuilder: (context, index) {
                  final entry = _salaryRates.entries.elementAt(index);
                  return _buildRateCard(entry.key, entry.value);
                },
              ),
            ),

            // Save Button (when editing)
            if (_isEditing)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _toggleEditMode,
                    icon: const Icon(Icons.save),
                    label: const Text('Save Changes'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentColor,
                      foregroundColor: _primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRateCard(String workType, double currentRate) {
    final controller = _controllers[workType]!;
    final icon = _getIconForWorkType(workType);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: _isEditing
            ? BorderSide(color: _accentColor.withOpacity(0.3), width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: _primaryColor, size: 24),
            ),
            const SizedBox(width: 16),

            // Work Type Name
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    workType,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF003366),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Rate per completed work',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),

            // Rate Value/Input
            Expanded(
              flex: 2,
              child: _isEditing
                  ? TextField(
                      controller: controller,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}'),
                        ),
                      ],
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                      ),
                      decoration: InputDecoration(
                        prefixText: 'Rs. ',
                        prefixStyle: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: _accentColor, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Rs. ${currentRate.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _primaryColor,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForWorkType(String workType) {
    switch (workType) {
      case 'Service Line Maintenance':
        return Icons.handyman;
      case 'Meter Testing':
        return Icons.speed;
      case 'Estimate':
        return Icons.request_quote;
      case 'Per Visit':
        return Icons.directions_walk;
      case 'Pole Disconnection':
        return Icons.power_off;
      case 'Material Remove':
        return Icons.remove_circle_outline;
      case 'Meter Replacement Only':
        return Icons.swap_horiz;
      case 'Visit with Contractor':
        return Icons.group;
      case 'Pole Top Maintenance':
        return Icons.engineering;
      default:
        return Icons.work;
    }
  }
}
