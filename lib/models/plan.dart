class PlanFeature {
  final String label;
  final bool included;
  const PlanFeature(this.label, this.included);
}

class Plan {
  final String id;
  final String name;
  final Map<String, num>? price;
  final int conversations;
  final int minutes;
  final int tokens;
  final bool hot;
  final List<PlanFeature> features;

  const Plan({
    required this.id,
    required this.name,
    required this.price,
    required this.conversations,
    required this.minutes,
    required this.tokens,
    this.hot = false,
    required this.features,
  });
}

const kPlans = <Plan>[
  Plan(
    id: 'starter',
    name: 'Starter',
    price: {'in': 199, 'gcc': 9, 'us': 3},
    conversations: 250,
    minutes: 300,
    tokens: 400000,
    features: [
      PlanFeature('One domain agent', true),
      PlanFeature('Voice + chat', true),
      PlanFeature('Web widget & subdomain', true),
      PlanFeature('WhatsApp', false),
      PlanFeature('App & GPT stores', false),
      PlanFeature('Directory promotion', false),
    ],
  ),
  Plan(
    id: 'growth',
    name: 'Growth',
    price: {'in': 499, 'gcc': 24, 'us': 6},
    conversations: 750,
    minutes: 900,
    tokens: 1500000,
    hot: true,
    features: [
      PlanFeature('Three domain agents', true),
      PlanFeature('Voice + chat', true),
      PlanFeature('Web widget & subdomain', true),
      PlanFeature('WhatsApp & email', true),
      PlanFeature('App & GPT stores', false),
      PlanFeature('Directory promotion', false),
    ],
  ),
  Plan(
    id: 'pro',
    name: 'Pro',
    price: {'in': 999, 'gcc': 49, 'us': 12},
    conversations: 2000,
    minutes: 2400,
    tokens: 5000000,
    features: [
      PlanFeature('Unlimited agents', true),
      PlanFeature('Voice + chat', true),
      PlanFeature('Web widget & subdomain', true),
      PlanFeature('WhatsApp & email', true),
      PlanFeature('Branded app & GPT stores', true),
      PlanFeature('Directory promotion', true),
    ],
  ),
  Plan(
    id: 'enterprise',
    name: 'Enterprise',
    price: null,
    conversations: 0,
    minutes: 0,
    tokens: 0,
    features: [
      PlanFeature('Everything in Pro', true),
      PlanFeature('In-region or on-prem', true),
      PlanFeature('SSO, DPA, retention controls', true),
      PlanFeature('CRM & telephony', true),
      PlanFeature('Committed volume pricing', true),
      PlanFeature('Named solutions engineer', true),
    ],
  ),
];

Plan planById(String? id) => kPlans.firstWhere((p) => p.id == id, orElse: () => kPlans[1]);

class Currency {
  final String symbol;
  final String label;
  final String locale;
  const Currency({required this.symbol, required this.label, required this.locale});
}

const kCurrencies = <String, Currency>{
  'in': Currency(symbol: '₹', label: 'India ₹', locale: 'en_IN'),
  'gcc': Currency(symbol: 'AED ', label: 'Gulf AED', locale: 'en'),
  'us': Currency(symbol: '\$', label: 'Global \$', locale: 'en_US'),
};
