import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class DocketTypeSelectionPage extends StatefulWidget {
  const DocketTypeSelectionPage({super.key});

  @override
  State<DocketTypeSelectionPage> createState() =>
      _DocketTypeSelectionPageState();
}

class _DocketTypeSelectionPageState extends State<DocketTypeSelectionPage> {
  static const List<String> _allDocketTypes = [
    'Service Line Maintenance',
    'Meter Testing',
    'Estimate',
    'Per Visit',
    'Pole Disconnection',
    'Material Remove',
    'Meter Replacement Only',
    'Visit with Contractor',
    'Pole Top Maintenance',
  ];

  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<String> filtered = _allDocketTypes
        .where((t) => t.toLowerCase().contains(_query))
        .toList();

    final double width = MediaQuery.of(context).size.width;
    final int crossAxisCount = width >= 900
        ? 4
        : width >= 600
        ? 3
        : 2; // keep 2 on phones

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Docket Type'),
        backgroundColor: const Color(0xFF003366),
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search docket types...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                          },
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.count(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: filtered
                      .map(
                        (type) => _DocketTypeCard(
                          title: type,
                          icon: _iconFor(type),
                          onTap: () => _openCameraForDocket(type),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openCameraForDocket(String docketType) async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
      );
      if (!mounted) return;
      if (photo == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera cancelled for $docketType')),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Captured image for $docketType: ${photo.name}'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open camera for $docketType: $error'),
        ),
      );
    }
  }

  IconData _iconFor(String title) {
    switch (title) {
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
        return Icons.widgets;
    }
  }
}

class _DocketTypeCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _DocketTypeCard({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFF5F5F5),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: const Color(0xFFFFD700).withOpacity(0.25),
        overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.pressed) ||
              states.contains(WidgetState.focused) ||
              states.contains(WidgetState.hovered)) {
            return const Color(0xFFFFD700).withOpacity(0.18);
          }
          return null;
        }),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: const Color(0xFF003366), size: 32),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF003366),
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DocketTypePlaceholderPage extends StatelessWidget {
  final String title;

  const DocketTypePlaceholderPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color(0xFF003366),
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFFFFFFF),
      body: Center(
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF003366),
          ),
        ),
      ),
    );
  }
}
