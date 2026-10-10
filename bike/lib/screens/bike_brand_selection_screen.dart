import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/bike_model.dart';
import '../models/yamaha_model_catalog.dart';
import '../providers/bike_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/bike_brand_logo.dart';
import '../widgets/uppercase_text_formatter.dart';

class BikeBrandSelectionScreen extends StatefulWidget {
  final Function(BikeBrand)? onBrandSelected;

  const BikeBrandSelectionScreen({super.key, this.onBrandSelected});

  @override
  State<BikeBrandSelectionScreen> createState() =>
      _BikeBrandSelectionScreenState();
}

class _BikeBrandSelectionScreenState extends State<BikeBrandSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<BikeBrand> _filteredBrands = BikeBrand.values.toList();

  @override
  void initState() {
    super.initState();
    _filteredBrands = BikeBrand.values.toList();
  }

  void _filterBrands(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredBrands = BikeBrand.values.toList();
      } else {
        _filteredBrands = BikeBrand.values
            .where(
              (brand) =>
                  brand.displayName.toLowerCase().contains(query.toLowerCase()),
            )
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.themedBackground,
      appBar: AppBar(
        title: const Text('Select Bike Brand'),
        backgroundColor: AppColors.themedBackground,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _filterBrands,
              style: TextStyle(color: AppColors.themedText),
              decoration: InputDecoration(
                hintText: 'Search brand...',
                hintStyle: TextStyle(color: AppColors.themedGrey),
                prefixIcon: Icon(Icons.search, color: AppColors.orange),
                filled: true,
                fillColor: AppColors.themedCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.orange,
                    width: 1,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.orange,
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.orange,
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
          // Brand List
          Expanded(
            child: _filteredBrands.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.two_wheeler_outlined,
                          size: 64,
                          color: AppColors.themedGrey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No brands found',
                          style: TextStyle(
                            color: AppColors.themedGrey,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredBrands.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (context, index) {
                      final brand = _filteredBrands[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _BrandCard(
                          brand: brand,
                          onTap: () {
                            widget.onBrandSelected?.call(brand);
                            Navigator.pop(context, brand);
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class _BrandCard extends StatelessWidget {
  final BikeBrand brand;
  final VoidCallback onTap;

  const _BrandCard({required this.brand, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.themedCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.orange, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(child: BikeBrandLogo(brand: brand)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                brand.displayName,
                style: TextStyle(
                  color: AppColors.themedText,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: AppColors.orange,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class AddBikeDialog extends StatefulWidget {
  const AddBikeDialog({super.key});

  @override
  State<AddBikeDialog> createState() => _AddBikeDialogState();
}

class _AddBikeDialogState extends State<AddBikeDialog> {
  BikeBrand? _selectedBrand;
  String? _selectedYamahaModel;
  final TextEditingController _bikeNameController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _colorController = TextEditingController();
  final TextEditingController _licensePlateController = TextEditingController();
  final TextEditingController _engineCapacityController =
      TextEditingController();
  int? _yearOfPurchase;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.themedSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.orange, width: 1.5),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Add Your Bike',
                style: TextStyle(
                  color: AppColors.orange,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),

              // Brand Selection
              Text(
                'Select Brand *',
                style: TextStyle(
                  color: AppColors.themedText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () async {
                  final result = await Navigator.push<BikeBrand>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BikeBrandSelectionScreen(),
                    ),
                  );
                  if (result != null) {
                    setState(() {
                      if (_selectedBrand != result) {
                        _modelController.clear();
                        _engineCapacityController.clear();
                        _selectedYamahaModel = null;
                      }
                      _selectedBrand = result;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.themedCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedBrand != null
                          ? AppColors.orange
                          : AppColors.themedGrey,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedBrand?.displayName ?? 'Tap to select brand',
                        style: TextStyle(
                          color: _selectedBrand != null
                              ? AppColors.themedText
                              : AppColors.themedGrey,
                          fontSize: 14,
                        ),
                      ),
                      if (_selectedBrand != null)
                        BikeBrandLogo(brand: _selectedBrand!),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Bike Name
              Text(
                'Bike Name *',
                style: TextStyle(
                  color: AppColors.themedText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _bikeNameController,
                style: TextStyle(color: AppColors.themedText),
                decoration: InputDecoration(
                  hintText: 'e.g., My Royal Enfield',
                  hintStyle: TextStyle(color: AppColors.themedGrey),
                  filled: true,
                  fillColor: AppColors.themedCard,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: AppColors.orange,
                      width: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Model
              if (_selectedBrand == BikeBrand.yamahaMotorIndia) ...[
                DropdownButtonFormField<String>(
                  initialValue: _selectedYamahaModel,
                  isExpanded: true,
                  dropdownColor: AppColors.themedCard,
                  decoration: InputDecoration(
                    labelText: 'Model',
                    prefixIcon: const Icon(
                      Icons.speed,
                      color: AppColors.orange,
                    ),
                    filled: true,
                    fillColor: AppColors.themedCard,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: AppColors.orange,
                        width: 1,
                      ),
                    ),
                  ),
                  hint: const Text('Select Yamaha model'),
                  items: yamahaModelEngineCc.keys
                      .map(
                        (model) => DropdownMenuItem<String>(
                          value: model,
                          child: Text(
                            model,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (model) {
                    if (model == null) return;
                    setState(() {
                      _selectedYamahaModel = model;
                      _modelController.text = model;
                      _engineCapacityController.text =
                          yamahaModelEngineCc[model]!;
                    });
                  },
                ),
              ] else ...[
                Text(
                  'Model',
                  style: TextStyle(
                    color: AppColors.themedText,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _modelController,
                  style: TextStyle(color: AppColors.themedText),
                  decoration: InputDecoration(
                    hintText: 'e.g., Classic 350',
                    hintStyle: TextStyle(color: AppColors.themedGrey),
                    filled: true,
                    fillColor: AppColors.themedCard,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: AppColors.orange,
                        width: 1,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Color
              Text(
                'Color',
                style: TextStyle(
                  color: AppColors.themedText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _colorController,
                style: TextStyle(color: AppColors.themedText),
                decoration: InputDecoration(
                  hintText: 'e.g., Black',
                  hintStyle: TextStyle(color: AppColors.themedGrey),
                  filled: true,
                  fillColor: AppColors.themedCard,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: AppColors.orange,
                      width: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // License Plate
              Text(
                'License Plate',
                style: TextStyle(
                  color: AppColors.themedText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _licensePlateController,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [UppercaseTextFormatter()],
                style: TextStyle(color: AppColors.themedText),
                decoration: InputDecoration(
                  hintText: 'e.g., TN-01-XX-0001',
                  hintStyle: TextStyle(color: AppColors.themedGrey),
                  filled: true,
                  fillColor: AppColors.themedCard,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: AppColors.orange,
                      width: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Engine Capacity
              const Text(
                'Engine Capacity (CC)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _engineCapacityController,
                keyboardType: TextInputType.number,
                readOnly: _selectedBrand == BikeBrand.yamahaMotorIndia,
                style: TextStyle(color: AppColors.themedText),
                decoration: InputDecoration(
                  hintText: 'e.g., 350',
                  hintStyle: TextStyle(color: AppColors.themedGrey),
                  filled: true,
                  fillColor: AppColors.themedCard,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: AppColors.orange,
                      width: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Year of Purchase
              Text(
                'Year of Purchase',
                style: TextStyle(
                  color: AppColors.themedText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final result = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (result != null) {
                    setState(() => _yearOfPurchase = result.year);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.themedCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _yearOfPurchase != null
                          ? AppColors.orange
                          : AppColors.themedGrey,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _yearOfPurchase?.toString() ?? 'Select year',
                        style: TextStyle(
                          color: _yearOfPurchase != null
                              ? AppColors.themedText
                              : AppColors.themedGrey,
                          fontSize: 14,
                        ),
                      ),
                      const Icon(
                        Icons.calendar_today,
                        color: AppColors.orange,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.themedSurface,
                        side: const BorderSide(
                          color: AppColors.orange,
                          width: 1,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: AppColors.orange),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed:
                          _selectedBrand == null ||
                              _bikeNameController.text.isEmpty
                          ? null
                          : () {
                              final bike = Bike(
                                id: 'bike_${DateTime.now().millisecondsSinceEpoch}',
                                name: _bikeNameController.text,
                                brand: _selectedBrand!,
                                model: _modelController.text.isNotEmpty
                                    ? _modelController.text
                                    : null,
                                yearOfPurchase: _yearOfPurchase,
                                licensePlate:
                                    _licensePlateController.text.isNotEmpty
                                    ? _licensePlateController.text
                                    : null,
                                color: _colorController.text.isNotEmpty
                                    ? _colorController.text
                                    : null,
                                engineCapacity:
                                    _engineCapacityController.text.isNotEmpty
                                    ? double.tryParse(
                                        _engineCapacityController.text,
                                      )
                                    : null,
                              );

                              context.read<BikeProvider>().addBike(bike);
                              Navigator.pop(context, bike);

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Bike "${bike.name}" added successfully! 🏍️',
                                  ),
                                  backgroundColor: AppColors.orange,
                                ),
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.orange,
                        disabledBackgroundColor: AppColors.orange.withValues(
                          alpha: 0.5,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Add Bike',
                        style: TextStyle(
                          color: AppColors.themedBackground,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _bikeNameController.dispose();
    _modelController.dispose();
    _colorController.dispose();
    _licensePlateController.dispose();
    _engineCapacityController.dispose();
    super.dispose();
  }
}
