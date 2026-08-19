class BusinessCategory {
  final String id;
  final String name;
  final List<String> subCategories;
  const BusinessCategory({required this.id, required this.name, required this.subCategories});
}

const kBusinessCategories = <BusinessCategory>[
  BusinessCategory(id: 'insurance', name: 'Insurance', subCategories: ['Life Insurance', 'Health Insurance', 'Motor Insurance', 'General Insurance', 'Reinsurance']),
  BusinessCategory(id: 'banking', name: 'Banking & Finance', subCategories: ['Retail Banking', 'Loans & Credit', 'Wealth Management', 'Payments', 'NBFC']),
  BusinessCategory(id: 'medical_aesthetics', name: 'Medical Aesthetics', subCategories: ['Skin Tightening', 'Laser Hair Removal', 'Skin Resurfacing', 'Tattoo Removal', 'Pigmentation Treatment', 'Body Contouring', 'Vascular Treatment']),
  BusinessCategory(id: 'healthcare', name: 'Healthcare & Clinics', subCategories: ['General Physician', 'Dental', 'Physiotherapy', 'Diagnostics', 'Pharmacy']),
  BusinessCategory(id: 'realestate', name: 'Real Estate', subCategories: ['Residential Sales', 'Commercial Sales', 'Rentals', 'Property Management', 'Interiors']),
  BusinessCategory(id: 'education', name: 'Education & Coaching', subCategories: ['K-12 Tutoring', 'Test Prep', 'Skill Courses', 'Higher Education Counselling', 'Corporate Training']),
  BusinessCategory(id: 'travel', name: 'Travel & Hospitality', subCategories: ['Hotels & Stays', 'Flight Booking', 'Holiday Packages', 'Visa Services', 'Car Rentals']),
  BusinessCategory(id: 'legal', name: 'Legal Services', subCategories: ['Corporate Law', 'Family Law', 'Property Law', 'Intellectual Property', 'Litigation']),
  BusinessCategory(id: 'automotive', name: 'Automotive', subCategories: ['Sales', 'Service & Repair', 'Spare Parts', 'Detailing', 'Roadside Assistance']),
  BusinessCategory(id: 'retail', name: 'Retail & E-commerce', subCategories: ['Fashion', 'Electronics', 'Grocery', 'Home & Living', 'Marketplace Seller']),
  BusinessCategory(id: 'telecom', name: 'Telecom & ISP', subCategories: ['Mobile Services', 'Broadband', 'Enterprise Connectivity', 'DTH', 'Device Sales']),
  BusinessCategory(id: 'professional', name: 'Professional Services', subCategories: ['Accounting', 'Consulting', 'Marketing Agency', 'IT Services', 'HR & Staffing']),
  BusinessCategory(id: 'other', name: 'Something Else', subCategories: ['General']),
];

BusinessCategory? businessCategoryById(String? id) {
  if (id == null) return null;
  for (final c in kBusinessCategories) {
    if (c.id == id) return c;
  }
  return null;
}

const kAvailabilityDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

const kBusinessTypes = ['Products', 'Services', 'Services + Products'];

const kPrimaryGoals = ['Sell Products', 'Book Appointments', 'Generate Leads', 'Provide Support'];
