/// A place the requester has registered for quick reuse when creating a
/// request - their own home, or (spec 03章 遠隔家族) a relative's home they
/// manage requests for remotely. [beneficiaryName] captures who actually
/// lives there when it differs from the account holder, matching the
/// requests model's ownerId / beneficiaryId split.
class SavedPlace {
  const SavedPlace({
    required this.id,
    required this.label,
    required this.approximateAddress,
    required this.latitude,
    required this.longitude,
    this.beneficiaryName,
    this.notifyOnSnowfall = true,
  });

  final String id;
  final String label;
  final String approximateAddress;
  final double latitude;
  final double longitude;
  final String? beneficiaryName;
  final bool notifyOnSnowfall;

  SavedPlace copyWith({
    String? label,
    String? approximateAddress,
    double? latitude,
    double? longitude,
    String? beneficiaryName,
    bool clearBeneficiaryName = false,
    bool? notifyOnSnowfall,
  }) {
    return SavedPlace(
      id: id,
      label: label ?? this.label,
      approximateAddress: approximateAddress ?? this.approximateAddress,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      beneficiaryName:
          clearBeneficiaryName ? null : (beneficiaryName ?? this.beneficiaryName),
      notifyOnSnowfall: notifyOnSnowfall ?? this.notifyOnSnowfall,
    );
  }
}
