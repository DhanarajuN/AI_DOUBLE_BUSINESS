import 'package:flutter/material.dart';

IconData businessIcon(String key) {
  switch (key) {
    case 'shield':
      return Icons.shield_outlined;
    case 'bank':
      return Icons.account_balance_outlined;
    case 'heart':
      return Icons.favorite_border;
    case 'building':
      return Icons.apartment_outlined;
    case 'cap':
      return Icons.school_outlined;
    case 'plane':
      return Icons.flight_outlined;
    case 'scales':
      return Icons.gavel_outlined;
    case 'car':
      return Icons.directions_car_outlined;
    case 'card':
      return Icons.credit_card_outlined;
    case 'globe':
      return Icons.public_outlined;
    case 'case':
      return Icons.work_outline;
    case 'sparkle':
      return Icons.auto_awesome_outlined;
    case 'chat':
      return Icons.chat_bubble_outline;
    case 'docs':
      return Icons.description_outlined;
    case 'tag':
      return Icons.local_offer_outlined;
    case 'user':
      return Icons.person_outline;
    case 'mic':
      return Icons.mic_none_outlined;
    case 'phone':
      return Icons.call_outlined;
    case 'wa':
      return Icons.chat_outlined;
    case 'mail':
      return Icons.mail_outline;
    case 'cal':
      return Icons.calendar_month_outlined;
    case 'chart':
      return Icons.bar_chart_outlined;
    case 'people':
      return Icons.people_outline;
    case 'key':
      return Icons.vpn_key_outlined;
    case 'upload':
      return Icons.upload_outlined;
    case 'trash':
      return Icons.delete_outline;
    case 'doc':
    case 'file':
      return Icons.insert_drive_file_outlined;
    default:
      return Icons.info_outline;
  }
}
