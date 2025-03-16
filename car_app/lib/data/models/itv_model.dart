class ItvUpdateModel {
  final DateTime itvDate;

  ItvUpdateModel({
    required this.itvDate,
  });

  Map<String, dynamic> toJson() => {
    'itv_date': itvDate.toIso8601String(),
  };
}

class ItvResponseModel {
  final String id;
  final DateTime? lastItvDate;
  final DateTime? nextItvDate;

  ItvResponseModel({
    required this.id,
    this.lastItvDate,
    this.nextItvDate,
  });

  factory ItvResponseModel.fromJson(Map<String, dynamic> json) {
    return ItvResponseModel(
      id: json['id'],
      lastItvDate: json['last_itv_date'] != null ? DateTime.parse(json['last_itv_date']) : null,
      nextItvDate: json['next_itv_date'] != null ? DateTime.parse(json['next_itv_date']) : null,
    );
  }
} 