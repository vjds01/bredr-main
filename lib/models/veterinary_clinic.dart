class VeterinaryClinic {
  final String id;
  final String name;
  final String address;
  final bool supportsEmailVerification;
  final bool isDemo;

  const VeterinaryClinic({
    required this.id,
    required this.name,
    required this.address,
    this.supportsEmailVerification = false,
    this.isDemo = false,
  });
}

class VeterinaryClinicDirectory {
  VeterinaryClinicDirectory._();

  static const clinics = <VeterinaryClinic>[
    VeterinaryClinic(
      id: 'breedr_demo',
      name: 'Breedr Demo Veterinary Clinic',
      address: 'Demo clinic for health-verification testing',
      supportsEmailVerification: true,
      isDemo: true,
    ),
    VeterinaryClinic(
      id: 'cabuyao_animal_clinic',
      name: 'Cabuyao Animal Clinic',
      address: 'Cabuyao City, Laguna',
      supportsEmailVerification: true,
    ),
    VeterinaryClinic(
      id: 'sitio_beterinaryo_cabuyao',
      name: 'Sitio Beterinaryo',
      address: 'Centennial Plaza Building, National Highway, Cabuyao City',
      supportsEmailVerification: true,
    ),
    VeterinaryClinic(
      id: 'abc_advance_care',
      name: 'ABC Advance Care Animal Bite Clinic',
      address: 'Sala, Cabuyao City',
    ),
    VeterinaryClinic(
      id: 'hayop_kalinga',
      name: 'Hayop Kalinga Veterinary Clinic',
      address: 'Corner Suki No. 2127 2nd Street, Cabuyao, Laguna',
    ),
  ];

  static VeterinaryClinic? byId(String? id) {
    final normalized = id?.trim() ?? '';
    if (normalized.isEmpty) return null;
    for (final clinic in clinics) {
      if (clinic.id == normalized) return clinic;
    }
    return null;
  }

  static VeterinaryClinic? byName(String? name) {
    final normalized = name?.trim().toLowerCase() ?? '';
    if (normalized.isEmpty) return null;
    for (final clinic in clinics) {
      if (clinic.name.toLowerCase() == normalized) return clinic;
    }
    return null;
  }

  static VeterinaryClinic? resolve({String? id, String? name}) =>
      byId(id) ?? byName(name);
}
