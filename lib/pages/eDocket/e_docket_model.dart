import 'dart:convert';

class EDocket {
  final String docketNo;
  final String? year;
  final String? accountNumber;
  final String customerName;
  final String? address;
  final String? meterNumber;
  final String? meterReading;
  final DateTime? date;
  final String? poleNumber;
  final int? selectedErrorIndex;

  EDocket({
    required this.docketNo,
    this.year,
    this.accountNumber,
    required this.customerName,
    this.address,
    this.meterNumber,
    this.meterReading,
    this.date,
    this.poleNumber,
    this.selectedErrorIndex,
  });

  // Produce a 27-length list with 0 for the selected error and 1 for others
  List<int> get errorFlags {
    const total = 27;
    return List<int>.generate(total, (i) {
      if (selectedErrorIndex == null) return 1;
      return i == selectedErrorIndex ? 0 : 1;
    });
  }

  Map<String, dynamic> toJson() {
    return {
      'docket_no': docketNo,
      'year': year,
      'account_number': accountNumber,
      'customer_name': customerName,
      'address': address,
      'meter_number': meterNumber,
      'meter_reading': meterReading,
      'date': date?.toIso8601String(),
      'pole_number': poleNumber,
      'selected_error_index': selectedErrorIndex,
      'error_flags': errorFlags,
    };
  }

  String toJsonString() => jsonEncode(toJson());
}
