import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'categories.dart';

final categoryServiceProvider = Provider<CategoryService>((ref) {
  return CategoryService();
});

class CategoryService {
  static const _customCategoriesKey = 'custom_categories';
  
  /// Get all categories (predefined + custom), sorted alphabetically
  Future<List<String>> getAllCategoryNames() async {
    final prefs = await SharedPreferences.getInstance();
    final customCategories = prefs.getStringList(_customCategoriesKey) ?? [];
    
    // Combine predefined and custom
    final allCategories = <String>{
      ...categoryNames,
      ...customCategories,
    }.toList();
    
    // Remove Uncategorized for sorting
    allCategories.remove('Uncategorized');
    
    // Sort alphabetically
    allCategories.sort();
    
    // Add Uncategorized at the end
    allCategories.add('Uncategorized');
    
    print('✅ CategoryService: Loaded ${allCategories.length} categories (${customCategories.length} custom)');
    
    return allCategories;
  }
  
  /// Add a new custom category
  Future<void> addCustomCategory(String name) async {
    if (name.trim().isEmpty) return;
    
    final prefs = await SharedPreferences.getInstance();
    final customCategories = prefs.getStringList(_customCategoriesKey) ?? [];
    
    // Don't add if it already exists (case-insensitive)
    final normalizedName = name.trim();
    final existingNames = customCategories.map((c) => c.toLowerCase()).toList();
    
    if (existingNames.contains(normalizedName.toLowerCase())) {
      print('⚠️ CategoryService: Category "$normalizedName" already exists');
      return;
    }
    
    // Don't add if it's a predefined category
    if (categoryNames.map((c) => c.toLowerCase()).contains(normalizedName.toLowerCase())) {
      print('⚠️ CategoryService: "$normalizedName" is a predefined category');
      return;
    }
    
    customCategories.add(normalizedName);
    await prefs.setStringList(_customCategoriesKey, customCategories);
    
    print('✅ CategoryService: Custom category added: $normalizedName');
  }
  
  /// Check if category exists
  Future<bool> categoryExists(String name) async {
    final allCategories = await getAllCategoryNames();
    return allCategories.map((c) => c.toLowerCase()).contains(name.toLowerCase());
  }
  
  /// Get all custom categories (for debugging)
  Future<List<String>> getCustomCategories() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_customCategoriesKey) ?? [];
  }
  
  /// Clear all custom categories (for debugging)
  Future<void> clearCustomCategories() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_customCategoriesKey);
    print('🗑️ CategoryService: All custom categories cleared');
  }
}
