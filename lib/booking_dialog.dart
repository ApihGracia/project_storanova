import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'database.dart';

class BookingDialog extends StatefulWidget {
  final Map<String, dynamic> house;
  final VoidCallback onBookingComplete;
  final Map<String, dynamic>? booking; // For edit mode

  const BookingDialog({
    Key? key,
    required this.house,
    required this.onBookingComplete,
    this.booking, // Optional booking data for edit mode
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
  void initState() {
    super.initState();
    _initializeBookingData();
  }

  void _initializeBookingData() {
    if (widget.booking != null) {
      // Edit mode - pre-fill with existing booking data
      try {
        _checkInDate = DatabaseService.parseDateTime(widget.booking!['checkIn']);
        _checkOutDate = DatabaseService.parseDateTime(widget.booking!['checkOut']);
      } catch (e) {
        _checkInDate = DateTime.now();
        _checkOutDate = DateTime.now().add(const Duration(days: 1));
      }
      
      _selectedPriceOption = widget.booking!['priceOption'];
      // Don't set payment method here - it will be validated in _getAvailablePaymentMethods
      _usePickupService = widget.booking!['pickupService'] ?? widget.booking!['usePickupService'] ?? false;
      _specialRequestsController.text = widget.booking!['specialRequests'] ?? '';
      
      // For quantity-based pricing, set the quantity value
      if (widget.booking!['quantity'] != null) {
        _selectedPriceOption = widget.booking!['quantity'].toString();
      }
    }
  }

  @override
  void dispose() {
    _specialRequestsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                    widget.booking != null 
                        ? 'Edit Booking for ${widget.house['address'] ?? 'House'}'
                        : 'Book ${widget.house['address'] ?? 'House'}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  Text('Price per Item: RM${widget.house['pricePerItem'] ?? '0'}',
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
                    initialValue: widget.booking != null ? widget.booking!['quantity']?.toString() : null,
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
                    _bookingSummary(),

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
                              : Text(widget.booking != null ? 'Update Booking' : 'Submit Booking'),
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

  Widget _bookingSummary() {
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
          Text('Quantity: $_selectedPriceOption items'),
          Text('Price per item: RM${widget.house['pricePerItem']}'),
          if (_usePickupService && widget.house['pickupServiceCost'] != null)
            Text('Pickup service: RM${widget.house['pickupServiceCost']}'),
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

    // If no payment methods configured in house, provide default options
    if (availableMethods.isEmpty) {
      availableMethods = ['Cash'];
    }

    // For edit mode, validate the payment method once when methods are available
    if (widget.booking != null && _selectedPaymentMethod == null && availableMethods.isNotEmpty) {
      final originalPaymentMethod = widget.booking!['paymentMethod'];
      if (originalPaymentMethod != null && availableMethods.contains(originalPaymentMethod)) {
        _selectedPaymentMethod = originalPaymentMethod;
      } else {
        _selectedPaymentMethod = availableMethods.first;
      }
    }

    return availableMethods;
  }

  double _calculateTotal() {
    if (_checkInDate == null || _checkOutDate == null || _selectedPriceOption == null) return 0;

    // Only support item-based pricing
    final pricePerItem = double.tryParse(widget.house['pricePerItem']?.toString() ?? '0') ?? 0;
    final quantity = int.tryParse(_selectedPriceOption!) ?? 0;
    double baseTotal = pricePerItem * quantity;

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
      if (widget.booking != null) {
        // Update existing booking - only support item-based pricing
        final quantity = int.parse(_selectedPriceOption!);
        final pricePerItem = double.parse(widget.house['pricePerItem'].toString());
        double totalPrice = quantity * pricePerItem;
        String priceBreakdown = 'RM$pricePerItem per item × $quantity items';

        if (_usePickupService) {
          final pickupCost = double.tryParse(widget.house['pickupServiceCost']?.toString() ?? '50') ?? 50;
          totalPrice += pickupCost;
        }

        // Update booking data
        final updatedBookingData = {
          'checkIn': _checkInDate!.toIso8601String(),
          'checkOut': _checkOutDate!.toIso8601String(),
          'priceOption': _selectedPriceOption,
          'paymentMethod': _selectedPaymentMethod,
          'pickupService': _usePickupService,
          'usePickupService': _usePickupService, // Keep both for compatibility
          'specialRequests': _specialRequestsController.text.trim(),
          'totalPrice': totalPrice,
          'priceBreakdown': priceBreakdown,
          'quantity': quantity,
          'pricePerItem': pricePerItem,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (_usePickupService) {
          final pickupCost = double.tryParse(widget.house['pickupServiceCost']?.toString() ?? '50') ?? 50;
          updatedBookingData['pickupServiceCost'] = pickupCost;
        }

        // Update the booking in Firestore
        try {
          await FirebaseFirestore.instance
              .collection('Bookings')
              .doc(widget.booking!['id'])
              .update(updatedBookingData);
        } catch (e) {
          throw Exception('Unable to update booking. Please check your internet connection and try again.');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking updated successfully!')),
        );
      } else {
        // Create new booking (existing logic)
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw Exception('User not logged in');

        QuerySnapshot? usersSnapshot;
        try {
          usersSnapshot = await FirebaseFirestore.instance
              .collection('AppUsers')
              .where('email', isEqualTo: user.email)
              .limit(1)
              .get();
        } catch (e) {
          throw Exception('Unable to connect to database. Please check your internet connection and try again.');
        }

        if (usersSnapshot.docs.isEmpty) throw Exception('User not found');
        final username = usersSnapshot.docs.first.id;

        final total = _calculateTotal();
        final quantity = int.tryParse(_selectedPriceOption!) ?? 0;
        final priceBreakdown = 'RM${widget.house['pricePerItem']} per item × $quantity items';

        await _db.createBooking(
          customerUsername: username,
          ownerUsername: widget.house['ownerUsername'] ?? widget.house['owner'] ?? '',
          houseId: _generateHouseId(widget.house),
          houseAddress: widget.house['address'] ?? 'No Address',
          checkIn: _checkInDate!,
          checkOut: _checkOutDate!,
          totalPrice: total,
          priceBreakdown: priceBreakdown,
          specialRequests: _specialRequestsController.text.trim().isEmpty
              ? null
              : _specialRequestsController.text.trim(),
          paymentMethod: _selectedPaymentMethod,
          usePickupService: _usePickupService,
          quantity: quantity,
          pricePerItem: double.tryParse(widget.house['pricePerItem'].toString()),
          pickupServiceCost: _usePickupService ? double.tryParse(widget.house['pickupServiceCost']?.toString() ?? '50') : null,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking submitted successfully!')),
        );
      }

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
