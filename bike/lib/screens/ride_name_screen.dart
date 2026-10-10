import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/ride_provider.dart';
import '../theme/app_theme.dart';
import 'ride_type_screen.dart';

class RideNameScreen extends StatefulWidget {
  final VoidCallback onRideStarted;

  const RideNameScreen({super.key, required this.onRideStarted});

  @override
  State<RideNameScreen> createState() => _RideNameScreenState();
}

class _RideNameScreenState extends State<RideNameScreen> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _continue() {
    final rideName = _nameController.text.trim();
    if (rideName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a trip name to continue')),
      );
      return;
    }

    context.read<RideSetup>().setTripName(rideName);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RideTypeScreen(onRideStarted: widget.onRideStarted),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.themedBackground,
      appBar: AppBar(
        title: const Text('Trip Name'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Give your ride a name',
              style: TextStyle(
                color: AppColors.themedText,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This helps you identify the trip later in the map and ride history.',
              style: TextStyle(color: AppColors.themedGrey, fontSize: 14),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              style: TextStyle(color: AppColors.themedText),
              decoration: InputDecoration(
                labelText: 'Trip Name',
                labelStyle: TextStyle(color: AppColors.themedGrey),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.themedGrey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.orange),
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _continue,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('Continue', style: TextStyle(fontSize: 16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
