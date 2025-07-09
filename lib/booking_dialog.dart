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
  String? _selectedPaymentMethod;
  bool _usePickupService = false;
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
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
          maxWidth: MediaQuery.of(context).size.width * 0.9,
        ),
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
                    'Book ${widget.house['address'] ?? 'House'}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  if (hasNewPricing) ...[
                    Text('Price per Item: RM${widget.house['pricePerItem']}',
                        style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.green)),
                    Row(
                      children: [
                        if (widget.house['maxItemQuantity'] != null)
                          Text('Maximum Items: ${widget.house['maxItemQuantity']}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(width: 8),
                        const Tooltip(
                          message: '1 item = 1 box or 1 bag',
                          child: Icon(Icons.info_outline, size: 16, color: Colors.blue),
                        ),
                      ],
                    ),
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
                  ] else if (prices.isNotEmpty) ...[
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

                  const Text('Store Date:', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  _dateField(context, true),

                  const SizedBox(height: 16),
                  const Text('Pickup Date:', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  _dateField(context, false),

                  const SizedBox(height: 16),

                  if (widget.house['offerPickupService'] == true)
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: CheckboxListTile(
                            title: const Text('Use Pickup Service'),
                            subtitle: Text('Additional cost: RM${widget.house['pickupServiceCost'] ?? '0'}'),
                            value: _usePickupService,
                            onChanged: (value) {
                              setState(() {
                                _usePickupService = value ?? false;
                              });
                            },
                            dense: true,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),

                  const Text('Payment Method:', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    hint: const Text('Select payment method'),
                    value: _selectedPaymentMethod,
                    items: _getAvailablePaymentMethods().map<DropdownMenuItem<String>>((method) {
                      return DropdownMenuItem(value: method, child: Text(method));
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedPaymentMethod = value),
                    validator: (value) => value == null || value.isEmpty ? 'Please select a payment method' : null,
                  ),
                  const SizedBox(height: 16),

                  if (_checkInDate != null && _checkOutDate != null && _selectedPriceOption != null)
                    _bookingSummary(hasNewPricing),

                  const SizedBox(height: 16),
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
      ),
    );
  }

  Widget _dateField(BuildContext context, bool isCheckIn) {
    final date = isCheckIn ? _checkInDate : _checkOutDate;
    return InkWell(
      onTap: () => _selectDate(context, isCheckIn),
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
            Text(date != null ? date.toString().split(' ')[0] : 'Select date'),
          ],
        ),
      ),
    );
  }

  Widget _bookingSummary(bool hasNewPricing) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Booking Summary:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          if (hasNewPricing) ...[
            Text('Quantity: $_selectedPriceOption items'),
            Text('Price per item: RM${widget.house['pricePerItem']}'),
            if (_usePickupService && widget.house['pickupServiceCost'] != null)
              Text('Pickup service: RM${widget.house['pickupServiceCost']}'),
          ] else ...[
            Text('Duration: ${_checkOutDate!.difference(_checkInDate!).inDays} days'),
            Text('Price: $_selectedPriceOption'),
          ],
          Text('Total: RM${_calculateTotal()}', style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isCheckIn) async {
    DateTime? availableFrom;
    DateTime? availableTo;

    if (widget.house['availableFrom'] != null) {
      availableFrom = DateTime.tryParse(widget.house['availableFrom'].toString());
    }
    if (widget.house['availableTo'] != null) {
      availableTo = DateTime.tryParse(widget.house['availableTo'].toString());
    }

    final DateTime now = DateTime.now();
    final DateTime startDate = availableFrom ?? now;
    final DateTime endDate = availableTo ?? now.add(const Duration(days: 365));

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isCheckIn
          ? (startDate.isAfter(now) ? startDate : now)
          : (_checkInDate?.add(const Duration(days: 1)) ?? now),
      firstDate: startDate,
      lastDate: endDate,
    );

    if (picked != null) {
      setState(() {
        if (isCheckIn) {
          _checkInDate = picked;
          if (_checkOutDate != null && _checkOutDate!.isBefore(picked.add(const Duration(days: 1)))) {
            _checkOutDate = null;
          }
        } else {
          _checkOutDate = picked;
        }
      });
    }
  }

  List<String> _getAvailablePaymentMethods() {
    final paymentMethods = widget.house['paymentMethods'] as Map<String, dynamic>? ?? {};
    List<String> availableMethods = [];

    if (paymentMethods['cash'] == true) availableMethods.add('Cash');
    if (paymentMethods['online_banking'] == true) availableMethods.add('Online Banking');
    if (paymentMethods['ewallet'] == true) availableMethods.add('E-Wallet');

    return availableMethods;
  }

  double _calculateTotal() {
    if (_checkInDate == null || _checkOutDate == null || _selectedPriceOption == null) return 0;

    final hasNewPricing = widget.house['pricePerItem'] != null && widget.house['pricePerItem'].toString().isNotEmpty;
    double baseTotal = 0;

    if (hasNewPricing) {
      final pricePerItem = double.tryParse(widget.house['pricePerItem'].toString()) ?? 0;
      final quantity = int.tryParse(_selectedPriceOption!) ?? 0;
      baseTotal = pricePerItem * quantity;
    } else {
      final days = _checkOutDate!.difference(_checkInDate!).inDays;
      if (days <= 0) return 0;
      final priceMatch = RegExp(r'RM(\d+(?:\.\d+)?)').firstMatch(_selectedPriceOption!);
      if (priceMatch == null) return 0;
      final price = double.tryParse(priceMatch.group(1)!) ?? 0;
      baseTotal = _selectedPriceOption!.contains('per week') ? price * (days / 7).ceil() : price * days;
    }

    if (_usePickupService && widget.house['pickupServiceCost'] != null) {
      final pickupCost = double.tryParse(widget.house['pickupServiceCost'].toString()) ?? 0;
      baseTotal += pickupCost;
    }

    return baseTotal;
  }

  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) return;
    if (_checkInDate == null || _checkOutDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select store and pickup dates')),
      );
      return;
    }
    if (_selectedPaymentMethod == null || _selectedPaymentMethod!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a payment method')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

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
        houseName: widget.house['address'] ?? 'No Address',
        checkIn: _checkInDate!,
        checkOut: _checkOutDate!,
        totalPrice: total,
        priceBreakdown: priceBreakdown,
        specialRequests: _specialRequestsController.text.trim().isEmpty
            ? null
            : _specialRequestsController.text.trim(),
        paymentMethod: _selectedPaymentMethod,
        usePickupService: _usePickupService,
        quantity: hasNewPricing ? (int.tryParse(_selectedPriceOption!) ?? 0) : null,
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
    if (house['id'] != null) return house['id'];
    final owner = house['owner'] ?? '';
    final address = house['address'] ?? '';
    return '${owner}_${address}'.replaceAll(' ', '_').replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
  }
}
