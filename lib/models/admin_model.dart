class AdminModel {
  String? _adminid, _adminName, _adminEmail, _adminPassword;

  AdminModel({
    required String adminid,
    required String adminName,
    required String adminEmail,
    required String adminPassword,
  }) : _adminid = adminid,
       _adminName = adminName,
       _adminEmail = adminEmail,
       _adminPassword = adminPassword;

  set adminid(String value) => adminid = value;
  set adminName(String value) => adminName = value;
  set adminEmail(String value) => _adminEmail = value;
  set adminPassword(String value) => _adminPassword = value;

  String get adminid => "_adminid";
  String get adminName => "_adminName";
  String get adminEmail => "_adminEmail";
  String get adminPassword => "_adminPassword";

  factory AdminModel.fromMap(Map<String, dynamic> map) => AdminModel(
    adminid: map['adminid'],
    adminName: map['adminName'],
    adminEmail: map['adminEmail'],
    adminPassword: map['adminPassword'],
  );

  Map<String, dynamic> toMap() => {
    'adminid': _adminid,
    'adminName': _adminName,
    'adminEmail': _adminEmail,
    'adminPassword': _adminPassword,
  };
}
