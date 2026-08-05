/// Location hierarchy from `figma_design/src/app/components/Layout.tsx`.
class DavaoProvinceData {
  const DavaoProvinceData({
    required this.province,
    required this.cities,
    required this.municipalities,
  });

  final String province;
  final List<String> cities;
  final List<String> municipalities;
}

const List<DavaoProvinceData> kDavaoRegionLocations = [
  DavaoProvinceData(
    province: 'Davao del Norte',
    cities: ['Panabo City', 'Tagum City', 'Island Garden City of Samal'],
    municipalities: [
      'Asuncion',
      'Braulio E. Dujali',
      'Carmen',
      'Kapalong',
      'New Corella',
      'San Isidro',
      'Santo Tomas',
      'Talaingod',
    ],
  ),
  DavaoProvinceData(
    province: 'Davao del Sur',
    cities: ['Davao City', 'Digos City'],
    municipalities: [
      'Bansalan',
      'Hagonoy',
      'Kiblawan',
      'Magsaysay',
      'Malalag',
      'Matanao',
      'Padada',
      'Santa Cruz',
      'Sulop',
    ],
  ),
  DavaoProvinceData(
    province: 'Davao Oriental',
    cities: ['Mati City'],
    municipalities: [
      'Baganga',
      'Banaybanay',
      'Boston',
      'Caraga',
      'Cateel',
      'Governor Generoso',
      'Lupon',
      'Manay',
      'San Isidro',
      'Tarragona',
    ],
  ),
  DavaoProvinceData(
    province: 'Davao Occidental',
    cities: [],
    municipalities: ['Don Marcelino', 'Jose Abad Santos', 'Malita', 'Santa Maria', 'Sarangani'],
  ),
  DavaoProvinceData(
    province: 'Davao de Oro',
    cities: [],
    municipalities: [
      'Compostela',
      'Laak',
      'Mabini',
      'Maco',
      'Maragusan',
      'Mawab',
      'Monkayo',
      'Montevista',
      'Nabunturan',
      'New Bataan',
      'Pantukan',
    ],
  ),
];
