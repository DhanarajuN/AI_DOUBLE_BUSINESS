class Industry {
  final String id;
  final String name;
  final String iconKey;
  final List<String> services;

  const Industry({required this.id, required this.name, required this.iconKey, required this.services});
}

const kIndustries = <Industry>[
  Industry(id: 'insurance', name: 'Insurance', iconKey: 'shield', services: ['Policy renewal', 'New quote', 'Claim assistance', 'Coverage query', 'Add nominee']),
  Industry(id: 'banking', name: 'Banking & finance', iconKey: 'bank', services: ['Account opening', 'Loan enquiry', 'Card support', 'KYC update', 'EMI query']),
  Industry(id: 'health', name: 'Healthcare & clinics', iconKey: 'heart', services: ['Book appointment', 'Report query', 'Cashless approval', 'Follow-up', 'Vaccination slot']),
  Industry(id: 'realestate', name: 'Real estate', iconKey: 'building', services: ['Site visit', 'Rent enquiry', 'Documentation', 'Price discussion', 'Loan referral']),
  Industry(id: 'education', name: 'Education & coaching', iconKey: 'cap', services: ['Admission enquiry', 'Fee payment', 'Scholarship info', 'Counselling', 'Demo class']),
  Industry(id: 'travel', name: 'Travel & hospitality', iconKey: 'plane', services: ['New booking', 'Visa help', 'Itinerary change', 'Refund / claim', 'Room upgrade']),
  Industry(id: 'legal', name: 'Legal services', iconKey: 'scales', services: ['Consultation', 'Document review', 'Notice drafting', 'Case update', 'Agreement query']),
  Industry(id: 'automotive', name: 'Automotive', iconKey: 'car', services: ['Service booking', 'Insurance renewal', 'Test drive', 'Spare parts', 'Roadside help']),
  Industry(id: 'retail', name: 'Retail & e-commerce', iconKey: 'card', services: ['Order status', 'Return / refund', 'Product query', 'Warranty claim', 'Bulk enquiry']),
  Industry(id: 'telecom', name: 'Telecom & ISP', iconKey: 'globe', services: ['New connection', 'Plan change', 'Outage report', 'Billing query', 'Port request']),
  Industry(id: 'professional', name: 'Professional services', iconKey: 'case', services: ['Consultation', 'Proposal request', 'Invoice query', 'Onboarding', 'Support ticket']),
  Industry(id: 'other', name: 'Something else', iconKey: 'sparkle', services: ['General enquiry', 'Booking', 'Support', 'Callback request', 'Feedback']),
];

Industry industryById(String? id) => kIndustries.firstWhere((i) => i.id == id, orElse: () => kIndustries.first);
