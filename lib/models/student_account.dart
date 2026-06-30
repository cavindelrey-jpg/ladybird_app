// lib/models/student_account.dart
// School-managed seat record. Used by admin_accounts.

import 'app_user.dart';

class StudentAccount {
  final String accountId;
  final String? studentName;
  final String classLevel;
  final bool isFirstLogin;
  final AccountStatus status;
  final String tempPassword;
  final bool adminAccessRevoked;
  final String? paymentRef;

  const StudentAccount({
    required this.accountId,
    this.studentName,
    required this.classLevel,
    this.isFirstLogin = false,
    required this.status,
    this.tempPassword = '',
    this.adminAccessRevoked = false,
    this.paymentRef,
  });

  factory StudentAccount.fromFirestore(String id, Map<String, dynamic> d) =>
      StudentAccount(
        accountId: id,
        studentName: d['studentName'],
        classLevel: d['classLevel'] ?? '',
        isFirstLogin: d['isFirstLogin'] ?? false,
        status: AccountStatus.values.firstWhere(
          (s) => s.name == d['status'], orElse: () => AccountStatus.unassigned),
        tempPassword: d['tempPassword'] ?? '',
        adminAccessRevoked: d['adminAccessRevoked'] ?? false,
        paymentRef: d['paymentRef'],
      );

  Map<String, dynamic> toFirestore() => {
    'studentName': studentName,
    'classLevel': classLevel,
    'isFirstLogin': isFirstLogin,
    'status': status.name,
    'tempPassword': tempPassword,
    'adminAccessRevoked': adminAccessRevoked,
    'paymentRef': paymentRef,
  };

  factory StudentAccount.fromAppUser(AppUser user) => StudentAccount(
    accountId: user.id,
    studentName: user.name,
    classLevel: user.classLevel,
    isFirstLogin: user.isFirstLogin,
    status: user.status,
    adminAccessRevoked: user.adminAccessRevoked,
  );

  StudentAccount copyWith({
    AccountStatus? status,
    String? tempPassword,
    bool? adminAccessRevoked,
    String? studentName,
    String? paymentRef,
  }) => StudentAccount(
    accountId: accountId,
    studentName: studentName ?? this.studentName,
    classLevel: classLevel,
    isFirstLogin: isFirstLogin,
    status: status ?? this.status,
    tempPassword: tempPassword ?? this.tempPassword,
    adminAccessRevoked: adminAccessRevoked ?? this.adminAccessRevoked,
    paymentRef: paymentRef ?? this.paymentRef,
  );
}
