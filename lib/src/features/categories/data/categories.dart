import 'package:flutter/material.dart';

/// Category model for transactions
class TransactionCategory {
  final String name;
  final String emoji;
  final Color color;

  const TransactionCategory(this.name, this.emoji, this.color);
}

/// Default categories for Quick Categorize and general use
const List<TransactionCategory> defaultCategories = [
  // Expenses - Essentials
  TransactionCategory('Food', '🍔', Colors.orange),
  TransactionCategory('Transport', '🚗', Colors.blue),
  TransactionCategory('Shopping', '🛍️', Colors.pink),
  TransactionCategory('Bills', '📄', Colors.grey),
  TransactionCategory('Rent', '🏠', Colors.brown),
  TransactionCategory('Utilities', '💡', Colors.amber),
  
  // Expenses - Lifestyle
  TransactionCategory('Entertainment', '🎬', Colors.purple),
  TransactionCategory('Health', '💊', Colors.red),
  TransactionCategory('Gym', '💪', Colors.deepPurple),
  TransactionCategory('Personal Care', '💅', Colors.pinkAccent),
  TransactionCategory('Education', '📚', Colors.indigo),
  TransactionCategory('Travel', '✈️', Colors.cyan),
  TransactionCategory('Pets', '🐕', Colors.deepOrange),
  TransactionCategory('Insurance', '🛡️', Colors.blueGrey),
  
  // Social
  TransactionCategory('Friends & Family', '👥', Colors.teal),
  TransactionCategory('Gifts', '🎁', Colors.redAccent),
  
  // Income
  TransactionCategory('Salary', '💰', Colors.green),
  TransactionCategory('Business', '💼', Colors.blueAccent),
  TransactionCategory('Freelance', '💻', Colors.lightGreen),
  TransactionCategory('Investments', '📈', Colors.greenAccent),
  
  // Other
  TransactionCategory('Uncategorized', '❓', Colors.grey),
];

/// Categories for Quick Categorize (excludes Uncategorized)
List<TransactionCategory> get forQuickCategorize => 
    defaultCategories.where((c) => c.name != 'Uncategorized').toList();

/// Get category by name
TransactionCategory? getCategoryByName(String name) {
  try {
    return defaultCategories.firstWhere((c) => c.name == name);
  } catch (_) {
    return null;
  }
}

/// Get all category names
List<String> get categoryNames => defaultCategories.map((c) => c.name).toList();
