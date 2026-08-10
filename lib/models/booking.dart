enum BookingStatus { confirmed, completed, pending, noshow }

String bookingStatusLabel(BookingStatus s) {
  switch (s) {
    case BookingStatus.confirmed:
      return 'Confirmed';
    case BookingStatus.completed:
      return 'Completed';
    case BookingStatus.pending:
      return 'Pending';
    case BookingStatus.noshow:
      return 'No-show';
  }
}

class Booking {
  final String id;
  final String customerName;
  final String service;
  final String channelId;
  final DateTime time;
  final BookingStatus status;

  const Booking({
    required this.id,
    required this.customerName,
    required this.service,
    required this.channelId,
    required this.time,
    required this.status,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'customerName': customerName,
        'service': service,
        'channelId': channelId,
        'time': time.toIso8601String(),
        'status': status.name,
      };

  factory Booking.fromJson(Map<String, dynamic> json) => Booking(
        id: json['id'] as String,
        customerName: json['customerName'] as String,
        service: json['service'] as String,
        channelId: json['channelId'] as String,
        time: DateTime.parse(json['time'] as String),
        status: BookingStatus.values.firstWhere((s) => s.name == json['status'], orElse: () => BookingStatus.confirmed),
      );
}
