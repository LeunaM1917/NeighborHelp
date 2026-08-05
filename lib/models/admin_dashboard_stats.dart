class AdminDashboardStats {
  const AdminDashboardStats({
    required this.customerCount,
    required this.providerCount,
    required this.bookingCount,
    required this.pendingVerificationCount,
    required this.pendingBookingCount,
    required this.activeServiceCount,
  });

  final int customerCount;
  final int providerCount;
  final int bookingCount;
  final int pendingVerificationCount;
  final int pendingBookingCount;
  final int activeServiceCount;
}
