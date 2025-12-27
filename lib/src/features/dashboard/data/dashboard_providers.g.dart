// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dashboard_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$totalBalanceHash() => r'0f6c1d4bb58f85b16625e6b3a0289f91c932c48d';

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
    r'6c935f79e87b707efb89b04431279a1ff7077329';

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
    r'7c500710c063c5fb84be3736656fe05936161c7d';

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
