class Channel {
  final String id;
  final String name;
  final String iconKey;
  const Channel({required this.id, required this.name, required this.iconKey});
}

const kChannels = <Channel>[
  Channel(id: 'phone', name: 'Phone call', iconKey: 'phone'),
  Channel(id: 'wa', name: 'WhatsApp', iconKey: 'wa'),
  Channel(id: 'chat', name: 'Web chat', iconKey: 'chat'),
  Channel(id: 'email', name: 'Email', iconKey: 'mail'),
];

Channel channelById(String? id) => kChannels.firstWhere((c) => c.id == id, orElse: () => kChannels.first);

const kTeamSizes = ['Just me', '2-10', '11-50', '51-200', '200+'];
