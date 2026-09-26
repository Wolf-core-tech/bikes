import 'package:flutter/material.dart';

import '../models/bike_brands.dart';
import '../theme/app_theme.dart';

class BikeBrandSelector extends StatelessWidget {
  const BikeBrandSelector({
    required this.selectedBrand,
    required this.onSelected,
    super.key,
  });

  final String? selectedBrand;
  final ValueChanged<String> onSelected;

  Future<void> _openSelector(BuildContext context) async {
    final brand = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.themedCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _BikeBrandSearchSheet(selectedBrand: selectedBrand),
    );

    if (brand != null) onSelected(brand);
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = selectedBrand != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Semantics(
        button: true,
        label: 'Bike Brand${hasSelection ? ': $selectedBrand' : ''}',
        child: Material(
          color: AppColors.themedCard,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () => _openSelector(context),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              constraints: const BoxConstraints(minHeight: 76),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.themedGreyBorder),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Color(0xFFE63946)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Bike Brand *',
                          style: TextStyle(
                            color: AppColors.themedGrey,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          selectedBrand ?? 'Search bike brand...',
                          style: TextStyle(
                            color: hasSelection
                                ? AppColors.themedText
                                : AppColors.themedGrey,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    hasSelection ? Icons.check_circle : Icons.expand_more,
                    color: const Color(0xFFE63946),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BikeBrandSearchSheet extends StatefulWidget {
  const _BikeBrandSearchSheet({required this.selectedBrand});

  final String? selectedBrand;

  @override
  State<_BikeBrandSearchSheet> createState() => _BikeBrandSearchSheetState();
}

class _BikeBrandSearchSheetState extends State<_BikeBrandSearchSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matchingBrands = BikeBrands.all
        .where((brand) => brand.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.82,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.two_wheeler, color: Color(0xFFE63946)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Choose Bike Brand',
                    style: TextStyle(
                      color: AppColors.themedText,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: AppColors.themedGrey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: (value) => setState(() => _query = value.trim()),
              style: TextStyle(color: AppColors.themedText),
              decoration: InputDecoration(
                hintText: 'Search bike brand...',
                hintStyle: TextStyle(color: AppColors.themedGrey),
                prefixIcon: const Icon(Icons.search, color: Color(0xFFE63946)),
                filled: true,
                fillColor: AppColors.themedBackground,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.themedGreyBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.themedGreyBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: Color(0xFFE63946),
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: matchingBrands.isEmpty
                  ? Center(
                      child: Text(
                        'No brands found',
                        style: TextStyle(color: AppColors.themedGrey),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: matchingBrands.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final brand = matchingBrands[index];
                        final isSelected = brand == widget.selectedBrand;

                        return Material(
                          color: isSelected
                              ? AppColors.orangeGlow
                              : AppColors.themedBackground,
                          borderRadius: BorderRadius.circular(14),
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: isSelected
                                    ? const Color(0xFFE63946)
                                    : AppColors.themedGreyBorder,
                              ),
                            ),
                            leading: const Icon(
                              Icons.two_wheeler,
                              color: Color(0xFFE63946),
                            ),
                            title: Text(
                              brand,
                              style: TextStyle(
                                color: AppColors.themedText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            trailing: Icon(
                              isSelected
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: isSelected
                                  ? const Color(0xFFE63946)
                                  : AppColors.themedGrey,
                            ),
                            onTap: () => Navigator.pop(context, brand),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
