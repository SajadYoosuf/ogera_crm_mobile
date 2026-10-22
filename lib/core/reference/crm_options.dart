/// Option lists shared with the CRM web app. Keeping them here means the phone
/// offers exactly the values the columns already hold — a mobile-entered record
/// filters and reports identically to a web-entered one.
class CrmOptions {
  const CrmOptions._();

  /// Lead source slugs, as the API's `GET /lead-sources` returns them. The
  /// picker offers these; the id is looked up when the contact is saved.
  static const contactSources = <String>[
    'meta',
    'website',
    'showroom',
    'gmb',
    'whatsapp',
    'offline',
  ];

  static String sourceLabel(String value) => switch (value.toLowerCase()) {
    'meta' => 'Meta',
    'website' || 'online' => 'Website',
    'showroom' => 'Showroom',
    'gmb' => 'Google My Business',
    'whatsapp' => 'WhatsApp',
    'offline' => 'Offline',
    _ => value,
  };

  /// House stages live in Settings > Lists & Options on the web
  /// (`GET /settings/enums/house_stage`). The API stores the value
  /// ("under_construction"); people see the label ("Under construction").
  /// This is the server's default list, used until the real one loads or when
  /// the phone is offline.
  static const defaultHouseStages = <String, String>{
    'ready': 'Ready',
    'under_construction': 'Under construction',
    'renovation': 'Renovation',
  };

  /// A readable label for a stored house stage. Values the admin added later
  /// read as their words: "site_ready" -> "Site ready".
  static String houseStageLabel(String? value, [Map<String, String>? labels]) {
    if (value == null || value.isEmpty) return '';
    final known = (labels ?? defaultHouseStages)[value];
    if (known != null) return known;
    final words = value.replaceAll('_', ' ').trim();
    return words.isEmpty ? value : words[0].toUpperCase() + words.substring(1);
  }

  static const awarenessLevels = <String>[
    'Steel tankine kurich ottum arivilla',
    'Paisa kooduthala yenna chintha',
    'Vangan thalparyam und',
  ];

  static const waterSourceSuggestions = <String>[
    'Borewell',
    'Open Well',
    'Corporation',
    'Panchayath supply',
    'Other',
  ];

  static const currentTankSuggestions = <String>[
    'Concrete',
    'PVC',
    'Plastic',
    'Stainless steel',
    'None',
  ];

  static const tankSizeSuggestions = <String>[
    '500',
    '750',
    '1000',
    '1500',
    '2000',
    '3000',
  ];

  static const districts = <String>[
    'Malappuram',
    'Kozhikode',
    'Thrissur',
    'Palakkad',
    'Wayanad',
    'Kannur',
    'Kasaragod',
    'Ernakulam',
    'Idukki',
    'Kottayam',
    'Alappuzha',
    'Pathanamthitta',
    'Kollam',
    'Thiruvananthapuram',
  ];

  /// Malappuram district panchayaths, mirroring `src/lib/panchayaths.ts`.
  static const panchayaths = <String>[
    'Amarambalam',
    'Chaliyar',
    'Chungathara',
    'Karulai',
    'Moothedam',
    'Vazhikkadavu',
    'Edakkara',
    'Kalikavu',
    'Pothukallu',
    'Chokkad',
    'Mampad',
    'Karuvarakundu',
    'Pandikkad',
    'Edavanna',
    'Porur',
    'Thrikkalangodu',
    'Thiruvali',
    'Tuvvur',
    'Wandoor',
    'Chelembra',
    'Cherukavu',
    'Pallikkal',
    'Vazhayur',
    'Vazhakkad',
    'Pulikkal',
    'Urangattiri',
    'Kavanur',
    'Keezhuparamba',
    'Pulpatta',
    'Cheacode',
    'Kuzhimanna',
    'Areacode',
    'Anakkayam',
    'Morayur',
    'Oorakam',
    'Ponmala',
    'Pookkottur',
    'Aliparamba',
    'Edappatta',
    'Elamkulam',
    'Melattur',
    'Keezhattur',
    'Thazhekkode',
    'Vettathur',
    'Kuruva',
    'Mankada',
    'Makkaraparamba',
    'Pulamanthole',
    'Moorkkanad',
    'Koottilangadi',
    'Puzhakkattiri',
    'Kodur',
    'Angadippuram',
    'Athavanad',
    'Edayur',
    'Irimbiliyam',
    'Marakkara',
    'Kuttippuram',
    'ARNagar',
    'Edarikode',
    'Othukkungal',
    'Parappur',
    'Thennala',
    'Vengara',
    'Kannamangalam',
    'Thenhipalam',
    'Vallikkunnu',
    'Moonniyur',
    'Nannambra',
    'Peruvalloor',
    'Cheriyamundam',
    'Kalpakanchery',
    'Ozhur',
    'Tanalur',
    'Valavannur',
    'Ponmundam',
    'Niramaruthur',
    'Perumanna Klari',
    'Purathur',
    'Thalakkad',
    'Triprangode',
    'Vettom',
    'Thirunavaya',
    'Mangalam',
    'Tavanur',
    'Vattamkulam',
    'Edapal',
    'Alamkode',
    'Maranchery',
    'Nannammukku',
    'Perumpadappa',
    'Veliancode',
    'Muthuvalloor',
    'Kaladi',
  ];
}
