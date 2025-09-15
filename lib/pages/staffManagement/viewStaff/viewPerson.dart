import 'package:flutter/material.dart';

import '../model/httpServicePeople.dart';
import '../model/person.dart';


const List<String> kDesignations = [
  'All',
  'Admin', 'CE', 'SEE', 'EE', 'TO', 'CSS', 'RO', 'Technician',
];

class ViewPeoplePage extends StatefulWidget {
  const ViewPeoplePage({super.key});

  @override
  State<ViewPeoplePage> createState() => _ViewPeoplePageState();
}

class _ViewPeoplePageState extends State<ViewPeoplePage> {
  final _svc = PeopleService();
  final _search = TextEditingController();

  bool _loading = true;
  String? _error;
  List<Person> _all = [];

  String _category = 'All';

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final people = await _svc.fetchPeople();
      setState(() {
        _all = people;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load: $e';
        _loading = false;
        _all = [];
      });
    }
  }

  List<Person> _applyFilters(bool activeTab) {
    Iterable<Person> list = _all.where((p) => p.isActive == activeTab);
    if (_category != 'All') {
      list = list.where(
            (p) => p.designation.toLowerCase() == _category.toLowerCase(),
      );
    }
    final q = _search.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((p) =>
      p.fullName.toLowerCase().contains(q) ||
          p.employeeNo.toLowerCase().contains(q) ||
          p.depot.toLowerCase().contains(q));
    }
    return list.toList()..sort((a, b) => a.fullName.compareTo(b.fullName));
  }

  // ---------- UI helpers ----------

Widget _summaryPanel() {
  final total = _all.length;
  final active = _all.where((p) => p.isActive).length;
  final inactive = total - active;

  // Minimal stat chip
  Widget buildStatChip(String title, int count, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                color: color.withOpacity(0.8),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 2),
    child: Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Minimal header
            Row(
              children: [
                Icon(
                  Icons.analytics_outlined,
                  color: const Color(0xFF003366),
                  size: 14,
                ),
                const SizedBox(width: 6),
                const Text(
                  'Summary',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const Spacer(),
                if (total > 0)
                  Text(
                    '${((active / total) * 100).toStringAsFixed(0)}% active',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade700,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            // Compact stats row
            Row(
              children: [
                buildStatChip('Total', total, Colors.blueGrey.shade700),
                buildStatChip('Active', active, Colors.green.shade700),
                buildStatChip('Inactive', inactive, Colors.red.shade700),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

  Future<void> _toggleActive(Person p) async {
    final ok =
    await _svc.setAvailability(personID: p.personID, active: !p.isActive);
    if (ok) {
      setState(() {
        final idx = _all.indexWhere((x) => x.personID == p.personID);
        if (idx >= 0) _all[idx] = p.copyWith(available: p.isActive ? 'No' : 'Yes');
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            '${p.fullName} marked ${p.isActive ? "Inactive" : "Active"}'),
      ));
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Update failed'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _edit(Person p) async {
    final first = TextEditingController(text: p.firstName);
    final last = TextEditingController(text: p.lastName);
    final depot = TextEditingController(text: p.depot);
    final emp = TextEditingController(text: p.employeeNo);
    String designation = p.designation;
    String accessLevel = p.accessLevel;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding:
          EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Edit Person',
                      style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                          child: TextField(
                              controller: first,
                              decoration: const InputDecoration(
                                  labelText: 'First name'))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: TextField(
                              controller: last,
                              decoration: const InputDecoration(
                                  labelText: 'Last name'))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                          child: TextField(
                              controller: depot,
                              decoration: const InputDecoration(
                                  labelText: 'Region / Depot'))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: TextField(
                            controller: emp,
                            decoration:
                            const InputDecoration(labelText: 'Employee No'),
                            keyboardType: TextInputType.number,
                          )),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: designation,
                          items: kDesignations
                              .where((e) => e != 'All')
                              .map((d) =>
                              DropdownMenuItem(value: d, child: Text(d)))
                              .toList(),
                          onChanged: (v) => designation = v ?? designation,
                          decoration: const InputDecoration(
                              labelText: 'Designation'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller:
                          TextEditingController(text: accessLevel),
                          onChanged: (v) => accessLevel = v,
                          decoration: const InputDecoration(
                              labelText: 'Access level'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final ok = await _svc.updatePerson(
                              personID: p.personID,
                              fields: {
                                'firstName': first.text.trim(),
                                'lastName': last.text.trim(),
                                'depot': depot.text.trim(),
                                'employeeNo': emp.text.trim(),
                                'designation': designation.trim(),
                                'accessLevel': accessLevel.trim(),
                              },
                            );
                            if (!mounted) return;
                            Navigator.pop(ctx, ok);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF003366),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Save'),
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

    if (saved == true) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Updated'),
        backgroundColor: Colors.green,
      ));
    }
  }

  Widget _personCard(Person p) {
    // Build initials for avatar
    String initials() {
      final fn = p.firstName.trim();
      final ln = p.lastName.trim();
      final a = fn.isNotEmpty ? fn[0] : '';
      final b = ln.isNotEmpty ? ln[0] : '';
      return (a + b).toUpperCase();
    }

    final meta1 = '${p.designation}  •  ${p.employeeNo}';
    final meta2 = 'Region: ${p.depot}  •  Access: ${p.accessLevel}';

    final activeColor =
    p.isActive ? Colors.green.shade700 : Colors.red.shade700;
    final activeBg =
    p.isActive ? Colors.green.shade100 : Colors.red.shade100;

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: LayoutBuilder(
          builder: (ctx, c) {
            final narrow = c.maxWidth < 460;      // wrap long label
            final veryNarrow = c.maxWidth < 360;  // icon-only fallback
            final fullLabel = p.isActive ? 'Make inactive' : 'Make active';
            final shortLabel = p.isActive ? 'Inactive' : 'Active';

            // Action button that adapts to width
            final Widget actionButton = veryNarrow
                ? IconButton(
              tooltip: fullLabel,
              onPressed: () => _toggleActive(p),
              icon: Icon(
                p.isActive ? Icons.visibility_off : Icons.visibility,
                size: 20,
                color: const Color(0xFF003366),
              ),
            )
                : ConstrainedBox(
              constraints: BoxConstraints(
                // keep actions from eating half the card
                maxWidth: narrow ? 120 : 200,
              ),
              child: TextButton.icon(
                onPressed: () => _toggleActive(p),
                icon: Icon(
                  p.isActive ? Icons.visibility_off : Icons.visibility,
                  size: 18,
                ),
                label: Text(
                  narrow ? shortLabel : fullLabel,
                  softWrap: true,            // ✅ allow wrapping
                ),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF003366),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 8),
                ),
              ),
            );

            final actions = Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Edit',
                  onPressed: () => _edit(p),
                  icon: const Icon(Icons.edit, size: 20),
                ),
                actionButton,
              ],
            );

            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // avatar + status
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: const Color(0xFFE8EEF6),
                      child: Text(initials(),
                          style: const TextStyle(
                              color: Color(0xFF003366),
                              fontWeight: FontWeight.bold)),
                    ),
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: CircleAvatar(
                        radius: 11,
                        backgroundColor: activeBg,
                        child: Icon(
                          p.isActive ? Icons.check : Icons.close,
                          size: 14,
                          color: activeColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),

                // text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                      const SizedBox(height: 3),
                      Text(meta1,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.black87)),
                      const SizedBox(height: 2),
                      Text(meta2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.black54, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // actions (width-limited & wrapping)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: narrow ? 150 : 240,
                  ),
                  child: actions,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    final activeList = _applyFilters(true);
    final inactiveList = _applyFilters(false);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('People'),
          backgroundColor: const Color(0xFF003366),
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'Active'),
              Tab(text: 'Inactive'),
            ],
          ),
        ),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      size: 56, color: Colors.redAccent),
                  const SizedBox(height: 12),
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _load,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF003366),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          )
              : Column(
            children: [
              // Summary
              Padding(
                padding:
                const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: _summaryPanel(),
              ),
              // Filters
              Padding(
                padding:
                const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: width >= 700 ? 260 : 180,
                      child: DropdownButtonFormField<String>(
                        value: _category,
                        items: kDesignations
                            .map((d) => DropdownMenuItem(
                            value: d, child: Text(d)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _category = v ?? 'All'),
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _search,
                        decoration: const InputDecoration(
                          hintText:
                          'Search name / employee no / region',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Lists
              Expanded(
                child: TabBarView(
                  children: [
                    // Active
                    RefreshIndicator(
                      onRefresh: _load,
                      color: const Color(0xFF003366),
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                            16, 0, 16, 16),
                        itemCount: activeList.length,
                        itemBuilder: (_, i) =>
                            _personCard(activeList[i]),
                      ),
                    ),
                    // Inactive
                    RefreshIndicator(
                      onRefresh: _load,
                      color: const Color(0xFF003366),
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                            16, 0, 16, 16),
                        itemCount: inactiveList.length,
                        itemBuilder: (_, i) =>
                            _personCard(inactiveList[i]),
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
}
