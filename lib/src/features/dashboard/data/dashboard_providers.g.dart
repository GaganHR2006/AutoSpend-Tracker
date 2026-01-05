// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dashboard_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$totalBalanceHash() => r'f61869ed6cf07bc2ac9706a954b75dcb18643e1d';

/// See also [totalBalance].
@ProviderFor(totalBalance)
final totalBalanceProvider = AutoDisposeStreamProvider<double>.internal(
  totalBalance,
  name: r'totalBalanceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$totalBalanceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TotalBalanceRef = AutoDisposeStreamProviderRef<double>;
String _$recentTransactionsHash() =>
    r'0f3446ac7972f0cc853729ff08e129a1107e7fc1';

/// See also [recentTransactions].
@ProviderFor(recentTransactions)
final recentTransactionsProvider =
    AutoDisposeStreamProvider<List<Transaction>>.internal(
      recentTransactions,
      name: r'recentTransactionsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$recentTransactionsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef RecentTransactionsRef = AutoDisposeStreamProviderRef<List<Transaction>>;
String _$spendingByCategoryHash() =>
    r'e27d9c0ac86711ec54d920d072f4623ada3c3fcc';

/// See also [spendingByCategory].
@ProviderFor(spendingByCategory)
final spendingByCategoryProvider =
    AutoDisposeStreamProvider<Map<String, double>>.internal(
      spendingByCategory,
      name: r'spendingByCategoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$spendingByCategoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SpendingByCategoryRef =
    AutoDisposeStreamProviderRef<Map<String, double>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
