import 'package:flutter/material.dart';

import '../models/bike_model_catalog.dart';
import '../theme/app_theme.dart';

class BikeModelSelector extends StatelessWidget {
  const BikeModelSelector({
    required this.brand,
    required this.selectedModel,
    required this.onModelSelected,
    super.key,
  });

  final String? brand;
  final BikeModelData? selectedModel;
  final ValueChanged<BikeModelData> onModelSelected;

  Future<void> _openModelSelector(BuildContext context) async {
    if (brand == null) return;
    final model = await showModalBottomSheet<BikeModelData>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.themedCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _BikeModelSearchSheet(brand: brand!),
    );
    if (model != null) onModelSelected(model);
  }

  @override
  Widget build(BuildContext context) {
    final validSelection =
        brand != null && selectedModel?.brand == brand;
    final modelName = validSelection ? selectedModel!.modelName : null;
    final enabled = brand != null;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Semantics(
            button: enabled,
            label: 'Model${modelName == null ? '' : ': $modelName'}',
            child: Material(
              color: AppColors.themedCard,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: enabled ? () => _openModelSelector(context) : null,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 60),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.themedGreyBorder),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.speed, color: AppColors.orange),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Model *',
                              style: TextStyle(
                                color: AppColors.themedGrey,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              modelName ?? 'Select a model',
                              style: TextStyle(
                                color: enabled
                                    ? AppColors.themedText
                                    : AppColors.themedGrey,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.expand_more,
                        color: enabled
                            ? AppColors.orange
                            : AppColors.themedGrey,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: TextFormField(
            key: ValueKey(validSelection ? selectedModel!.modelName : null),
            initialValue: validSelection ? selectedModel!.engineCCLabel : '',
            enabled: validSelection,
            readOnly: true,
            style: TextStyle(color: AppColors.themedText),
            decoration: InputDecoration(
              labelText: 'Engine CC',
              labelStyle: TextStyle(color: AppColors.themedGrey),
              prefixIcon: const Icon(Icons.flash_on, color: AppColors.orange),
              filled: true,
              fillColor: AppColors.themedCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppColors.themedGreyBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppColors.themedGreyBorder),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppColors.themedGreyBorder),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BikeModelSearchSheet extends StatefulWidget {
  const _BikeModelSearchSheet({required this.brand});

  final String brand;

  @override
  State<_BikeModelSearchSheet> createState() => _BikeModelSearchSheetState();
}

class _BikeModelSearchSheetState extends State<_BikeModelSearchSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final models = BikeModelCatalog.forBrand(widget.brand)
        .where(
          (model) => model.modelName.toLowerCase().contains(
            _query.toLowerCase(),
          ),
        )
        .toList(growable: false);

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
            Text(
              'Choose ${widget.brand} Model',
              style: TextStyle(
                color: AppColors.themedText,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _searchController,
              onChanged: (query) => setState(() => _query = query),
              style: TextStyle(color: AppColors.themedText),
              decoration: InputDecoration(
                hintText: 'Search models...',
                prefixIcon: const Icon(Icons.search, color: AppColors.orange),
                filled: true,
                fillColor: AppColors.themedSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.themedGreyBorder),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: models.isEmpty
                  ? Center(
                      child: Text(
                        _query.isEmpty
                            ? 'No model data is available for ${widget.brand}.'
                            : 'No models match your search.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.themedGrey),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: models.length,
                      itemBuilder: (context, index) {
                        final model = models[index];
                        return ListTile(
                          title: Text(
                            model.modelName,
                            style: TextStyle(color: AppColors.themedText),
                          ),
                          subtitle: Text(
                            '${model.vehicleType} · ${model.engineCCLabel}',
                            style: TextStyle(color: AppColors.themedGrey),
                          ),
                          onTap: () => Navigator.pop(context, model),
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
