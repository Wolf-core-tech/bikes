import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class RideExpense {
  final String rideName;
  final String distance;
  final String date;
  final List<ExpenseItem> items;

  const RideExpense({
    required this.rideName,
    required this.distance,
    required this.date,
    required this.items,
  });

  int get total => items.fold(0, (sum, item) => sum + item.amount);

  RideExpense copyWith({List<ExpenseItem>? items}) {
    return RideExpense(
      rideName: rideName,
      distance: distance,
      date: date,
      items: items ?? this.items,
    );
  }
}

class ExpenseItem {
  final String label;
  final int amount;
  final IconData icon;

  const ExpenseItem({
    required this.label,
    required this.amount,
    required this.icon,
  });
}

final rideExpensesNotifier = ValueNotifier<List<RideExpense>>(
  List<RideExpense>.from(sampleRideExpenses),
);

const sampleRideExpenses = [
  RideExpense(
    rideName: 'Ooty Ride',
    distance: '320 KM',
    date: 'Last Sunday',
    items: [
      ExpenseItem(label: 'Petrol', amount: 1200, icon: Icons.local_gas_station),
      ExpenseItem(label: 'Tea', amount: 120, icon: Icons.local_cafe),
      ExpenseItem(label: 'Puncture', amount: 180, icon: Icons.build_circle),
      ExpenseItem(label: 'Bike Service', amount: 350, icon: Icons.two_wheeler),
      ExpenseItem(label: 'Hotels', amount: 350, icon: Icons.hotel),
      ExpenseItem(label: 'Food', amount: 200, icon: Icons.restaurant),
    ],
  ),
  RideExpense(
    rideName: 'Yelagiri Ride',
    distance: '210 KM',
    date: 'May 25',
    items: [
      ExpenseItem(label: 'Petrol', amount: 820, icon: Icons.local_gas_station),
      ExpenseItem(label: 'Tea', amount: 80, icon: Icons.local_cafe),
      ExpenseItem(label: 'Puncture', amount: 0, icon: Icons.build_circle),
      ExpenseItem(label: 'Bike Service', amount: 250, icon: Icons.two_wheeler),
      ExpenseItem(label: 'Hotels', amount: 0, icon: Icons.hotel),
      ExpenseItem(label: 'Food', amount: 350, icon: Icons.restaurant),
    ],
  ),
];

String formatMoney(int amount) => 'Rs.$amount';

IconData expenseIconForPurpose(String purpose) {
  final normalized = purpose.trim().toLowerCase();

  if (normalized.contains('petrol') || normalized.contains('fuel')) {
    return Icons.local_gas_station;
  }
  if (normalized.contains('tea') || normalized.contains('coffee')) {
    return Icons.local_cafe;
  }
  if (normalized.contains('puncture') || normalized.contains('puncher')) {
    return Icons.build_circle;
  }
  if (normalized.contains('service') || normalized.contains('bike')) {
    return Icons.two_wheeler;
  }
  if (normalized.contains('hotel') || normalized.contains('room')) {
    return Icons.hotel;
  }
  if (normalized.contains('food') || normalized.contains('meal')) {
    return Icons.restaurant;
  }

  return Icons.receipt_long;
}

void addExpenseToRide({
  required String rideName,
  required String purpose,
  required int amount,
}) {
  final currentRides = rideExpensesNotifier.value;
  final nextRides = currentRides.map((ride) {
    if (ride.rideName != rideName) return ride;

    return ride.copyWith(
      items: [
        ...ride.items,
        ExpenseItem(
          label: purpose.trim(),
          amount: amount,
          icon: expenseIconForPurpose(purpose),
        ),
      ],
    );
  }).toList();

  rideExpensesNotifier.value = nextRides;
}

class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.themedBackground,
      appBar: AppBar(
        title: const Text('Ride Expenses'),
        backgroundColor: AppColors.themedBackground,
        actions: [
          IconButton(
            tooltip: 'Add expense',
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
              );
            },
          ),
        ],
      ),
      body: ValueListenableBuilder<List<RideExpense>>(
        valueListenable: rideExpensesNotifier,
        builder: (context, rides, _) {
          final totalSpend = rides.fold<int>(
            0,
            (sum, ride) => sum + ride.total,
          );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ExpenseSummaryCard(
                totalSpend: totalSpend,
                ridesCount: rides.length,
              ),
              const SizedBox(height: 18),
              Text(
                'Each Ride',
                style: TextStyle(
                  color: AppColors.themedText,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              ...rides.map(
                (ride) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: RideExpenseCard(
                    ride: ride,
                    onTap: () => showRideExpenseDetails(context, ride),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _purposeController = TextEditingController();
  final _priceController = TextEditingController();
  String? _selectedRideName;

  @override
  void dispose() {
    _purposeController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _saveExpense() {
    if (!_formKey.currentState!.validate()) return;

    addExpenseToRide(
      rideName: _selectedRideName!,
      purpose: _purposeController.text,
      amount: int.parse(_priceController.text.trim()),
    );

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Expense saved')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<RideExpense>>(
      valueListenable: rideExpensesNotifier,
      builder: (context, rides, _) {
        return Scaffold(
          backgroundColor: AppColors.themedBackground,
          appBar: AppBar(
            title: const Text('Add Expense'),
            backgroundColor: AppColors.themedBackground,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Ride',
                    style: TextStyle(
                      color: AppColors.themedText,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedRideName,
                    dropdownColor: AppColors.themedSurface,
                    decoration: _fieldDecoration('Ride'),
                    items: rides
                        .map(
                          (ride) => DropdownMenuItem(
                            value: ride.rideName,
                            child: Text(
                              '${ride.rideName} - ${ride.distance}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedRideName = value),
                    validator: (value) =>
                        value == null ? 'Please select a ride' : null,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Expense Details',
                    style: TextStyle(
                      color: AppColors.themedText,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _purposeController,
                    textCapitalization: TextCapitalization.words,
                    decoration: _fieldDecoration('Purpose'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter purpose';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    decoration: _fieldDecoration('Price'),
                    validator: (value) {
                      final amount = int.tryParse(value?.trim() ?? '');
                      if (amount == null || amount <= 0) {
                        return 'Please enter a valid price';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _saveExpense,
                      icon: const Icon(Icons.save),
                      label: const Text('Save'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.orange,
                        foregroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color.fromARGB(255, 190, 190, 190)),
      filled: true,
      fillColor: AppColors.themedCard,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.themedGreyBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.orange, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
    );
  }
}

class RideExpenseCard extends StatelessWidget {
  final RideExpense ride;
  final VoidCallback onTap;

  const RideExpenseCard({super.key, required this.ride, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.themedCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.themedGreyBorder, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: AppColors.orangeGlow,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.receipt_long, color: AppColors.orange),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ride.rideName,
                    style: TextStyle(
                      color: AppColors.themedText,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${ride.distance}  |  ${ride.date}',
                    style: const TextStyle(
                      color: Color.fromARGB(255, 190, 190, 190),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              formatMoney(ride.total),
              style: const TextStyle(
                color: AppColors.orange,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void showRideExpenseDetails(BuildContext context, RideExpense ride) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.themedSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ride.rideName,
                    style: TextStyle(
                      color: AppColors.themedText,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  formatMoney(ride.total),
                  style: const TextStyle(
                    color: AppColors.orange,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${ride.distance}  |  ${ride.date}',
              style: const TextStyle(
                color: Color.fromARGB(255, 190, 190, 190),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            ...ride.items.map((item) => _ExpenseBreakdownRow(item: item)),
          ],
        ),
      ),
    ),
  );
}

class _ExpenseSummaryCard extends StatelessWidget {
  final int totalSpend;
  final int ridesCount;

  const _ExpenseSummaryCard({
    required this.totalSpend,
    required this.ridesCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.themedCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.orange, width: 1.2),
      ),
      child: Row(
        children: [
          const Icon(Icons.currency_rupee, color: AppColors.orange, size: 34),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Ride Spend',
                  style: TextStyle(
                    color: AppColors.themedText,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$ridesCount rides tracked',
                  style: const TextStyle(
                    color: Color.fromARGB(255, 190, 190, 190),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Text(
            formatMoney(totalSpend),
            style: const TextStyle(
              color: AppColors.orange,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseBreakdownRow extends StatelessWidget {
  final ExpenseItem item;

  const _ExpenseBreakdownRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.orangeGlow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, color: AppColors.orange, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.label,
              style: TextStyle(
                color: AppColors.themedText,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            formatMoney(item.amount),
            style: const TextStyle(
              color: AppColors.orange,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
