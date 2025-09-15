class Person {
  final String personID;
  final String firstName;
  final String lastName;
  final String depot;
  final String available; // "Yes" / "No"
  final String employeeNo;
  final String designation; // Admin, CE, SEE, EE, TO, CSS, RO, Technician
  final String accessLevel; // keep as string for easier binding
  final String uuid;

  const Person({
    required this.personID,
    required this.firstName,
    required this.lastName,
    required this.depot,
    required this.available,
    required this.employeeNo,
    required this.designation,
    required this.accessLevel,
    required this.uuid,
  });

  bool get isActive => (available.toLowerCase() == 'yes');

  String get fullName => [firstName, lastName].where((s) => s.trim().isNotEmpty).join(' ').trim();

  factory Person.fromJson(Map<String, dynamic> j) {
    String _s(dynamic v) => (v ?? '').toString();
    return Person(
      personID: _s(j['personID']),
      firstName: _s(j['firstName']),
      lastName: _s(j['lastName']),
      depot: _s(j['depot']),
      available: _s(j['available']),
      employeeNo: _s(j['employeeNo']),
      designation: _s(j['designation']),
      accessLevel: _s(j['accessLevel']),
      uuid: _s(j['uuid']),
    );
  }

  Map<String, dynamic> toJson() => {
    'personID': personID,
    'firstName': firstName,
    'lastName': lastName,
    'depot': depot,
    'available': available,
    'employeeNo': employeeNo,
    'designation': designation,
    'accessLevel': accessLevel,
    'uuid': uuid,
  };

  Person copyWith({
    String? personID,
    String? firstName,
    String? lastName,
    String? depot,
    String? available,
    String? employeeNo,
    String? designation,
    String? accessLevel,
    String? uuid,
  }) {
    return Person(
      personID: personID ?? this.personID,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      depot: depot ?? this.depot,
      available: available ?? this.available,
      employeeNo: employeeNo ?? this.employeeNo,
      designation: designation ?? this.designation,
      accessLevel: accessLevel ?? this.accessLevel,
      uuid: uuid ?? this.uuid,
    );
  }
}
