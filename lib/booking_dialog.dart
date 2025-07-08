import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'database.dart';

class BookingDialog extends StatefulWidget {
  final Map<String, dynamic> house;
  final VoidCallback onBookingComplete;

  const BookingDialog({
    Key? key,
    required this.house,
    required this.onBookingComplete,
  }) : super(key: key);

  @override
  State<BookingDialog> createState() => _BookingDialogState();
}

class _BookingDialogState extends State<BookingDialog> {
  final _formKey = GlobalKey<FormState>();
  DateTime? _checkInDate;
  DateTime? _checkOutDate;
  String? _selectedPriceOption;
  final _specialRequestsController = TextEditingController();
  final DatabaseService _db = DatabaseService();
  bool _isLoading = false;

  @override
  void dispose() {
    _specialRequestsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prices = widget.house['prices'] as List? ?? [];
    final hasNewPricing = widget.house['pricePerItem'] != null && widget.house['pricePerItem'].toString().isNotEmpty;
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Book ${widget.house['name'] ?? 'House'}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                
                // New pricing structure - quantity selection
                if (hasNewPricing) ...[
                  Text('Price per Item: RM${widget.house['pricePerItem']}', 
                    style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.green)),
                  if (widget.house['maxItemQuantity'] != null)
                    Text('Maximum Items: ${widget.house['maxItemQuantity']}', 
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 8),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) => setState(() => _selectedPriceOption = value),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please enter quantity';
                      final quantity = int.tryParse(value);
                      if (quantity == null || quantity <= 0) return 'Please enter a valid quantity';
                      final maxQty = int.tryParse(widget.house['maxItemQuantity']?.toString() ?? '0') ?? 0;
                      if (maxQty > 0 && quantity > maxQty) return 'Maximum quantity is $maxQty';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                ]
                // Legacy pricing structure
                else if (prices.isNotEmpty) ...[
                  const Text('Select Price Option:', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    hint: const Text('Choose a price option'),
                    value: _selectedPriceOption,
                    items: prices.map<DropdownMenuItem<String>>((price) {
                      if (price is Map && price['amount'] != null && price['unit'] != null) {
                        final option = 'RM${price['amount']} ${price['unit']}';
                        return DropdownMenuItem(value: option, child: Text(option));
                      }
                      return const DropdownMenuItem(value: '', child: Text('Invalid price'));
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedPriceOption = value),
                    validator: (value) => value == null || value.isEmpty ? 'Please select a price option' : null,
                  ),
                  const SizedBox(height: 16),
                ],

                // Check-in date
                const Text('Check-in Date:', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => _selectDate(context, true),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today),
                        const SizedBox(width: 8),
                        Text(_checkInDate != null 
                            ? _checkInDate!.toString().split(' ')[0]
                            : 'Select check-in date'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Check-out date
                const Text('Check-out Date:', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => _selectDate(context, false),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today),
                        const SizedBox(width: 8),
                        Text(_checkOutDate != null 
                            ? _checkOutDate!.toString().split(' ')[0]
                            : 'Select check-out date'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Total price display
                if (_checkInDate != null && _checkOutDate != null && _selectedPriceOption != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Booking Summary:', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Duration: ${_checkOutDate!.difference(_checkInDate!).inDays} days'),
                        Text('Price: $_selectedPriceOption'),
                        Text('Total: RM${_calculateTotal()}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),

                // Special requests
                const Text('Special Requests (Optional):', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _specialRequestsController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Any special requests or notes...',
                  ),
                ),
                const SizedBox(height: 20),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitBooking,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: _isLoading 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Submit Booking'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isCheckIn) async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isCheckIn 
          ? (widget.house['availableFrom'] != null 
              ? DateTime.tryParse(widget.house['availableFrom'].toString()) ?? now
              : now)
          : (_checkInDate?.add(const Duration(days: 1)) ?? now.add(const Duration(days: 1))),
      firstDate: isCheckIn ? now : (_checkInDate ?? now),
      lastDate: widget.house['availableTo'] != null 
          ? DateTime.tryParse(widget.house['availableTo'].toString()) ?? now.add(const Duration(days: 365))
          : now.add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        if (isCheckIn) {
          _checkInDate = picked;
          // Clear check-out if it's before the new check-in date
          if (_checkOutDate != null && _checkOutDate!.isBefore(picked.add(const Duration(days: 1)))) {
            _checkOutDate = null;
          }
        } else {
          _checkOutDate = picked;
        }
      });
    }
  }

  double _calculateTotal() {
    if (_checkInDate == null || _checkOutDate == null || _selectedPriceOption == null) return 0;
    
    final hasNewPricing = widget.house['pricePerItem'] != null && widget.house['pricePerItem'].toString().isNotEmpty;
    
    if (hasNewPricing) {
      // New pricing structure - price per item * quantity
      final pricePerItem = double.tryParse(widget.house['pricePerItem'].toString()) ?? 0;
      final quantity = int.tryParse(_selectedPriceOption!) ?? 0;
      return pricePerItem * quantity;
    } else {
      // Legacy pricing structure - price per day/week * duration
      final days = _checkOutDate!.difference(_checkInDate!).inDays;
      if (days <= 0) return 0;
      
      // Extract price from selected option (format: "RM123 per day/week")
      final priceMatch = RegExp(r'RM(\d+(?:\.\d+)?)').firstMatch(_selectedPriceOption!);
      if (priceMatch == null) return 0;
      
      final price = double.tryParse(priceMatch.group(1)!) ?? 0;
      
      if (_selectedPriceOption!.contains('per week')) {
        final weeks = (days / 7).ceil();
        return price * weeks;
      } else {
        return price * days;
      }
    }
  }

  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) return;
    if (_checkInDate == null || _checkOutDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select check-in and check-out dates')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Get username from email lookup
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('AppUsers')
          .where('email', isEqualTo: user.email)
          .limit(1)
          .get();
      
      if (usersSnapshot.docs.isEmpty) throw Exception('User not found');
      final username = usersSnapshot.docs.first.id;

      final total = _calculateTotal();
      final hasNewPricing = widget.house['pricePerItem'] != null && widget.house['pricePerItem'].toString().isNotEmpty;
      
      String priceBreakdown;
      if (hasNewPricing) {
        final quantity = int.tryParse(_selectedPriceOption!) ?? 0;
        priceBreakdown = 'RM${widget.house['pricePerItem']} per item × $quantity items';
      } else {
        final days = _checkOutDate!.difference(_checkInDate!).inDays;
        priceBreakdown = '$_selectedPriceOption for $days days';
      }
      
      await _db.createBooking(
        customerUsername: username,
        ownerUsername: widget.house['ownerUsername'] ?? widget.house['owner'] ?? '',
        houseId: _generateHouseId(widget.house),
        houseName: widget.house['name'] ?? 'Unnamed House',
        checkIn: _checkInDate!,
        checkOut: _checkOutDate!,
        totalPrice: total,
        priceBreakdown: priceBreakdown,
        specialRequests: _specialRequestsController.text.trim().isEmpty 
            ? null 
            : _specialRequestsController.text.trim(),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking submitted successfully!')),
      );

      widget.onBookingComplete();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting booking: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _generateHouseId(Map<String, dynamic> house) {
    if (house['id'] != null) {
      return house['id'];
    }
    final name = house['name'] ?? '';
    final owner = house['owner'] ?? '';
    final address = house['address'] ?? '';
    return '${owner}_${name}_${address}'.replaceAll(' ', '_').replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
  }
}
