import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

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
  final String? location;
  final String? modeOfPay;

  const ExpenseItem({
    required this.label,
    required this.amount,
    required this.icon,
    this.location,
    this.modeOfPay,
  });
}

final rideExpensesNotifier = ValueNotifier<List<RideExpense>>([]);

const sampleRideExpenses = <RideExpense>[];

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
  String? location,
  String? modeOfPay,
}) {
  final currentRides = rideExpensesNotifier.value;
  bool rideExists = false;

  final nextRides = currentRides.map((ride) {
    if (ride.rideName != rideName) return ride;

    rideExists = true;
    return ride.copyWith(
      items: [
        ...ride.items,
        ExpenseItem(
          label: purpose.trim(),
          amount: amount,
          icon: expenseIconForPurpose(purpose),
          location: location,
          modeOfPay: modeOfPay,
        ),
      ],
    );
  }).toList();

  if (!rideExists) {
    final now = DateTime.now();
    nextRides.add(
      RideExpense(
        rideName: rideName,
        distance: '-- KM', // Default distance for custom entered rides
        date: '${now.day}/${now.month}/${now.year}',
        items: [
          ExpenseItem(
            label: purpose.trim(),
            amount: amount,
            icon: expenseIconForPurpose(purpose),
            location: location,
            modeOfPay: modeOfPay,
          ),
        ],
      ),
    );
  }

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
  final _rideNameController = TextEditingController();
  final _purposeController = TextEditingController();
  final _priceController = TextEditingController();
  final _locationController = TextEditingController();
  String? _selectedRideName;
  String? _selectedModeOfPay;

  bool _isFetchingLocation = false;

  final List<String> _expenseKinds = [
    'Petrol',
    'Hotel',
    'Room',
    'Tea shop',
    'Workshop',
    'Services',
  ];

  final List<String> _paymentModes = [
    'Gpay',
    'Hardcash',
    'Friend pay',
  ];

  @override
  void dispose() {
    _rideNameController.dispose();
    _purposeController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _fetchLocation() async {
    setState(() => _isFetchingLocation = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permission permanently denied');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _locationController.text =
          '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to fetch location: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isFetchingLocation = false);
      }
    }
  }

  void _saveExpense() {
    if (!_formKey.currentState!.validate()) return;

    addExpenseToRide(
      rideName: _rideNameController.text.trim(),
      purpose: _purposeController.text,
      amount: int.parse(_priceController.text.trim()),
      location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
      modeOfPay: _selectedModeOfPay,
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
                  Autocomplete<String>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<String>.empty();
                      }
                      return rides.map((r) => r.rideName).where((String option) {
                        return option.toLowerCase().contains(
                              textEditingValue.text.toLowerCase(),
                            );
                      });
                    },
                    onSelected: (String selection) {
                      _rideNameController.text = selection;
                    },
                    fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                      if (_rideNameController.text != textEditingController.text && !focusNode.hasFocus) {
                         textEditingController.text = _rideNameController.text;
                      }
                      textEditingController.addListener(() {
                        if (_rideNameController.text != textEditingController.text) {
                          _rideNameController.text = textEditingController.text;
                        }
                      });
                      
                      return TextFormField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        textCapitalization: TextCapitalization.words,
                        decoration: _fieldDecoration('Ride Name'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter or select a ride';
                          }
                          return null;
                        },
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4.0,
                          color: AppColors.themedCard,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 200, maxWidth: 300),
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (BuildContext context, int index) {
                                final String option = options.elementAt(index);
                                return InkWell(
                                  onTap: () => onSelected(option),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text(option, style: TextStyle(color: AppColors.themedText)),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
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
                  Autocomplete<String>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<String>.empty();
                      }
                      return _expenseKinds.where((String option) {
                        return option.toLowerCase().contains(
                              textEditingValue.text.toLowerCase(),
                            );
                      });
                    },
                    onSelected: (String selection) {
                      _purposeController.text = selection;
                    },
                    fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                      // Synchronize the external controller with the internal one
                      if (_purposeController.text != textEditingController.text && !focusNode.hasFocus) {
                         textEditingController.text = _purposeController.text;
                      }
                      textEditingController.addListener(() {
                        if (_purposeController.text != textEditingController.text) {
                          _purposeController.text = textEditingController.text;
                        }
                      });
                      
                      return TextFormField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        textCapitalization: TextCapitalization.words,
                        decoration: _fieldDecoration('Kind of (Petrol, Hotel, Room, etc.)'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter kind of expense';
                          }
                          return null;
                        },
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4.0,
                          color: AppColors.themedCard,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 200, maxWidth: 300),
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (BuildContext context, int index) {
                                final String option = options.elementAt(index);
                                return InkWell(
                                  onTap: () => onSelected(option),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text(option, style: TextStyle(color: AppColors.themedText)),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    decoration: _fieldDecoration('Amount (Rs.)'),
                    validator: (value) {
                      final amount = int.tryParse(value?.trim() ?? '');
                      if (amount == null || amount <= 0) {
                        return 'Please enter a valid amount';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _locationController,
                          decoration: _fieldDecoration('Latitude & Longitude (Optional)'),
                          style: TextStyle(color: AppColors.themedText, fontSize: 14),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _isFetchingLocation ? null : _fetchLocation,
                        icon: _isFetchingLocation
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.orange),
                              )
                            : const Icon(Icons.my_location, color: AppColors.orange),
                        tooltip: 'Auto fetch location',
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.themedCard,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: _selectedModeOfPay,
                    dropdownColor: AppColors.themedSurface,
                    decoration: _fieldDecoration('Mode of Pay'),
                    items: _paymentModes
                        .map(
                          (mode) => DropdownMenuItem(
                            value: mode,
                            child: Text(mode),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedModeOfPay = value),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _saveExpense,
                      icon: const Icon(Icons.save),
                      label: const Text('Save Expense'),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: TextStyle(
                    color: AppColors.themedText,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (item.location != null || item.modeOfPay != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Text(
                      [
                        if (item.modeOfPay != null) item.modeOfPay,
                        if (item.location != null) '📍 ${item.location}',
                      ].join(' • '),
                      style: const TextStyle(
                        color: Color.fromARGB(255, 150, 150, 150),
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
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
