import 'package:leco_docket_tracker/models/docket_details.dart';

// Example: create a DocketDetails object from UI data
DocketDetails createDocketDetailsFromUI({
  required String depot,
  required String docketType,
  required String imageName,
  required String uploadedBy,
  required String assignedTo,
  required String assignedTime,
  required String completedTime,
  required String docketSerial,
}) {
  return DocketDetails(
    depot: depot,
    docketType: docketType,
    imageName: imageName,
    uploadedBy: uploadedBy,
    uploadedTime: DateTime.now(),
    assignedTo: assignedTo,
    assignedTime: assignedTime,
    completedTime: completedTime,
    docketSerial: docketSerial,
  );
}
