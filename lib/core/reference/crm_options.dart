/// Option lists shared with the CRM web app. Keeping them here means the phone
/// offers exactly the values the columns already hold — a mobile-entered record
/// filters and reports identically to a web-entered one.
class CrmOptions {
  const CrmOptions._();

  /// `contacts.source` is a VARCHAR(20); these are the values the web form
  /// writes.
  static const contactSources = <String>[
    'showroom',
    'online',
    'offline',
    'Meta',
  ];

  static String sourceLabel(String value) => switch (value) {
    'showroom' => 'Showroom',
    'online' => 'Online',
    'offline' => 'Offline',
    'Meta' => 'Meta',
    _ => value,
  };

  /// House stage is stored as free text, but "Under Construction" carries a
  /// phase suffix, so the form composes it the same way the web form does.
  static const houseStageBases = <String>[
    'Under Construction',
    'Ready',
    'Renovation',
  ];
  static const constructionPhases = <String>[
    'Structure',
    'Plastering',
    'Finishing',
  ];

  static String composeHouseStage(String base, String? phase) =>
      base == 'Under Construction' ? '$base - ${phase ?? 'Structure'}' : base;

  static String baseOfHouseStage(String? value) {
    if (value == null || value.isEmpty) return '';
    return value.startsWith('Under Construction')
        ? 'Under Construction'
        : value;
  }

  static String phaseOfHouseStage(String? value) {
    if (value == null || !value.contains(' - ')) return 'Structure';
    return value.split(' - ').last;
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
