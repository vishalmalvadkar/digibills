import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; 
import 'package:printing/printing.dart'; // NEW
import 'package:pdf/pdf.dart'; // NEW
import 'package:pdf/widgets.dart' as pw; // NEW
import 'dart:typed_data'; // NEW

import '../models/bill_model.dart';
import '../models/settings_model.dart';
import '../models/user_model.dart';
import '../models/credit_note_model.dart';
import '../widgets/bill_items_table.dart';
import 'package:flutter/services.dart';
import '../services/bills_service.dart';
import '../services/settings_service.dart';
import '../services/license_service.dart';
import '../services/user_service.dart';
import '../services/credit_note_service.dart';
import '../theme/app_colors.dart';
import '../utils/pdf_invoice_helper.dart';
import '../utils/pdf_thermal_helper.dart'; // NEW
import '../utils/snackbar_helper.dart';
import '../utils/upi_helper.dart'; 
import 'create_bill_screen.dart';
import 'edit_bill_screen.dart'; // NEW
import 'bill_history_screen.dart'; // NEW
import 'bills_screen.dart'; 
import '../providers/shell_provider.dart';
import 'package:provider/provider.dart';
import '../utils/responsive.dart';
import 'package:universal_io/io.dart' as io; // Safe IO access
import 'package:flutter/foundation.dart' show kIsWeb; // Web check
import '../services/bluetooth_print_service.dart'; // Hybrid Service

class BillViewScreen extends StatefulWidget {
  final String billId;
  const BillViewScreen({super.key, required this.billId});

  @override
  State<BillViewScreen> createState() => _BillViewScreenState();
}

class _BillViewScreenState extends State<BillViewScreen> {
  BillModel? _bill;
  AppSettings? _settings;
  UserModel? _userModel;
  List<CreditNoteModel> _creditNotes = [];
  
  bool _isLoading = true;
  String _errorMessage = '';

  // UUID Pattern for checking ID type
  static final RegExp DEFAULT_UUID_PATTERN = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');

  String? _createdByName; // NEW

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // 1. Parallel Fetching (Optimized for speed)
      final results = await Future.wait([
        BillsService().getBillById(widget.billId),
        CreditNoteService().getCreditNotesForBill(widget.billId),
        SettingsService().fetchSettings(),
        _fetchUserIfNeeded(),
      ]);

      final fetchedBill = results[0] as BillModel?;
      final fetchedNotes = results[1] as List<CreditNoteModel>;
      final fetchedSettings = results[2] as AppSettings?;
      // _userModel is updated inside _fetchUserIfNeeded

      if (fetchedBill == null) {
        throw 'Invoice not found (ID: ${widget.billId})';
      }

      // Fetch Creator Name if exists and user is Owner
      String? creatorName;
      if (fetchedBill.createdBy != null && _userModel?.role != 'staff') {
         try {
           final creator = await UserService().getUser(fetchedBill.createdBy!);
           creatorName = creator?.name ?? creator?.email;
         } catch (e) {
           debugPrint('Error fetching creator: $e');
         }
      }
      
      if (mounted) {
        setState(() {
          _bill = fetchedBill;
          _creditNotes = fetchedNotes;
          _settings = fetchedSettings;
          _createdByName = creatorName;
          _isLoading = false;
        });
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateShell();
  }

  void _updateShell() {
    if (Responsive.isDesktop(context)) {
      final bill = _bill;
      final isReadOnly = (_userModel != null && !LicenseService().isLicenseValid(_userModel!));
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<ShellState>().update(
            title: bill != null ? 'Invoice: ${bill.invoiceNumber}' : 'Invoice Details',
            leading: BackButton(onPressed: () => Navigator.of(context).pop()),
            actions: [
              if (bill != null) ...[
                IconButton(
                  icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 20, color: Colors.green),
                  onPressed: () => PdfInvoiceHelper.openWhatsApp(context, bill, overrideSettings: _settings, creditNotes: _creditNotes),
                  tooltip: 'Share on WhatsApp',
                ),
                IconButton(
                  icon: const Icon(Icons.download_rounded, size: 20, color: AppColors.primary),
                  onPressed: () => PdfInvoiceHelper.generateAndDownload(bill, overrideSettings: _settings, creditNotes: _creditNotes),
                  tooltip: 'Download PDF',
                ),
                if (!isReadOnly) ...[
                  IconButton(
                    icon: const Icon(Icons.print, size: 20),
                    onPressed: _printPdf,
                    tooltip: 'Print Invoice',
                  ),
                  // IconButton(
                  //   icon: const Icon(Icons.edit_note, size: 20),
                  //   onPressed: _updateStatus,
                  //   tooltip: 'Update Status',
                  // ),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: _editBill, // NEW
                    tooltip: 'Edit Invoice',
                  ),
                  IconButton(
                    icon: const Icon(Icons.history, size: 20),
                    onPressed: _viewHistory, // NEW
                    tooltip: 'View History',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                    onPressed: _confirmDelete,
                    tooltip: 'Delete Invoice',
                  ),
                ],
              ],
            ],
          );
        }
      });
    }
  }

  Future<UserModel?> _fetchUserIfNeeded() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      try {
        _userModel = await UserService().getUser(currentUser.id);
        return _userModel;
      } catch (_) {}
    }
    return null;
  }

  Future<void> _printPdf() async {
    if (_bill == null || _settings == null) return;
    
    // RE-FETCH SETTINGS RIGHT BEFORE PRINT TO ENSURE LATEST FORMAT
    try {
      final latestSettings = await SettingsService().fetchSettings(forceRefresh: true);
      _settings = latestSettings;
    } catch (e) {
      debugPrint("Warning: Could not refresh settings before print: $e");
    }

    try {
      debugPrint("Starting Direct Print Process...");
      final format = _settings!.printFormat; // Using refreshed copy

      Uint8List pdfData;
      PdfPageFormat pdfFormat = PdfPageFormat.a4; // Default
      
      if (format == 'Thermal58' || format == 'Thermal80') {
         final bool is58 = format == 'Thermal58';
         
         debugPrint("Generating Thermal ${is58 ? '58' : '80'}mm PDF...");
         pdfData = await PdfThermalHelper.generateThermalPdf(
           _bill!, 
           _settings!, 
           is58mm: is58, 
           creditNotes: _creditNotes,
           isWeb: kIsWeb,
         );

         // Use a custom finite-height format to force Android to crop the receipt
         final double h = PdfThermalHelper.estimateHeight(_bill!, _creditNotes);
         pdfFormat = PdfPageFormat(
           (is58 ? 57 : 80) * PdfPageFormat.mm, 
           h, 
           marginAll: 0
         );
      } else {
         debugPrint("Generating A4 Invoice PDF...");
         pdfData = await PdfInvoiceHelper.generateInvoicePdf(_bill!);
         pdfFormat = PdfPageFormat.a4;
      }

      debugPrint("Invoking Printing.layoutPdf (Instant)...");

      // For thermal, we use dynamicLayout: false to ensure the OS respects our exact height
      // For A4, we keep dynamicLayout: true for standard multi-page behavior.
      final bool isThermal = format.startsWith('Thermal');
      
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfData,
        format: pdfFormat, 
        dynamicLayout: !isThermal, 
        usePrinterSettings: false, 
        name: 'Invoice-${_bill!.invoiceNumber}',
      );
      debugPrint("Printer Selection Dialog Triggered.");
    } catch (e) {
      debugPrint("Error in _printPdf: $e");
      if (mounted) SnackbarHelper.showError(context, 'Print Error: $e');
    }
  }

  Future<void> _refresh() async {
     await _loadData();
  }

  Future<void> _editBill() async {
    if (_bill == null) return;
    
    // Check if legacy
    bool isSupabase = DEFAULT_UUID_PATTERN.hasMatch(widget.billId);
    if (!isSupabase) {
       SnackbarHelper.showError(context, 'Cannot edit legacy invoice.');
       return;
    }

    final result = await Navigator.push(
      context, 
      MaterialPageRoute(builder: (_) => EditBillScreen(bill: _bill!))
    );

    if (result == true) {
      _refresh();
    }
  }

  void _viewHistory() {
    if (_bill == null) return;
    Navigator.push(
      context, 
      MaterialPageRoute(builder: (_) => BillHistoryScreen(billId: widget.billId, invoiceNumber: _bill!.invoiceNumber))
    );
  }

  Future<void> _updateStatus() async {
    if (_bill == null) return;
    
    String? newStatus;
    DateTime? paymentDate = _bill!.paymentReceivedDate;

    // 1. Select Status
    await showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: ['Pending', 'Paid', 'Partial'].map((status) {
              return ListTile(
                title: Text(status),
                leading: Icon(
                  status == 'Paid' ? Icons.check_circle : (status == 'Partial' ? Icons.timelapse : Icons.pending),
                  color: status == 'Paid' ? AppColors.success : (status == 'Partial' ? Colors.orange : AppColors.warning),
                ),
                onTap: () {
                  newStatus = status;
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        );
      },
    );

    if (newStatus == null || newStatus == _bill!.paymentStatus) return;

    // 2. Select Date (if Paid or Partial)
    if (newStatus == 'Paid' || newStatus == 'Partial') {
      final picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
      );
      if (picked != null) {
        paymentDate = picked;
      } else {
        return; // Cancelled
      }
    } else {
      paymentDate = null; // Clear date if pending
    }

    // 3. Update (Hybrid)
    try {
      bool isSupabase = DEFAULT_UUID_PATTERN.hasMatch(widget.billId);
      
      if (isSupabase) {
          await BillsService().updateBillStatus(widget.billId, newStatus!, paymentDate);
      } else {
         if (mounted) SnackbarHelper.showError(context, 'Cannot edit legacy invoice. Please recreate.');
         return;
      }
      
      if (mounted) {
         SnackbarHelper.showSuccess(context, 'Status updated');
         _refresh();
      }
    } catch (e) {
       if (mounted) SnackbarHelper.showError(context, 'Error updating status: $e');
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Invoice'),
        content: const Text('Are you sure you want to delete this invoice? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
       try {
         bool isSupabase = DEFAULT_UUID_PATTERN.hasMatch(widget.billId);
         if (isSupabase) {
            await BillsService().deleteBill(widget.billId);
         } else {
            if (mounted) SnackbarHelper.showError(context, 'Cannot delete legacy invoice. Please contact support.');
            return;
         }
         
         if (mounted) {
           Navigator.pop(context); 
         }
       } catch (e) {
         if (mounted) SnackbarHelper.showError(context, 'Failed to delete: $e');
       }
    }
  }

  Future<void> _addPayment(double amount, DateTime date, String mode) async {
    if (_bill == null) return;
    try {
      final payment = PaymentRecord(amount: amount, date: date, mode: mode);
      await BillsService().addPayment(_bill!.billId, payment);
      if (mounted) {
        SnackbarHelper.showSuccess(context, 'Payment added');
        _refresh();
      }
    } catch (e) {
      if (mounted) SnackbarHelper.showError(context, 'Error adding payment: $e');
    }
  }

  Future<void> _deletePayment(String paymentId) async {
    if (_bill == null) return;
    try {
      await BillsService().deletePayment(_bill!.billId, paymentId);
      if (mounted) {
        SnackbarHelper.showSuccess(context, 'Payment deleted');
        _refresh();
      }
    } catch (e) {
       if (mounted) SnackbarHelper.showError(context, 'Error deleting payment: $e');
    }
  }

  Future<void> _showAddPaymentDialog() async {
    final amountController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String selectedMode = 'Cash';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Payment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                decoration: const InputDecoration(labelText: 'Amount (₹)', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Date'),
                subtitle: Text(DateFormat('dd MMM yyyy').format(selectedDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setDialogState(() => selectedDate = picked);
                  }
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedMode,
                decoration: const InputDecoration(labelText: 'Mode', border: OutlineInputBorder()),
                items: ['Cash', 'UPI', 'Bank Transfer', 'Cheque'].map((mode) => DropdownMenuItem(value: mode, child: Text(mode))).toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedMode = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final amt = double.tryParse(amountController.text);
                if (amt == null || amt <= 0) {
                  SnackbarHelper.showError(context, 'Invalid amount');
                  return;
                }
                Navigator.pop(context);
                _addPayment(amt, selectedDate, selectedMode);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }



  Future<void> _showBluetoothDialog() async {
    final service = BluetoothPrintService();
    await service.init();
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Select Bluetooth Printer"),
        content: FutureBuilder<List<dynamic>>(
          future: service.getBondedDevices(), 
          builder: (ctx, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();
            final devices = snapshot.data ?? [];
            if (devices.isEmpty) return const Text("No paired devices found. Pair in Android Settings.");
            
            return SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: devices.length,
                itemBuilder: (ctx, i) {
                  final d = devices[i]; 
                  // In print_bluetooth_thermal, it's BluetoothInfo
                  // We use dynamic access to keep web code happy (stub returns dynamic)
                  final name = d.name; // Both libs use 'name'
                  final address = d.macAdress; // print_bluetooth_thermal uses 'macAdress'
                  
                  return ListTile(
                    title: Text(name),
                    subtitle: Text(address),
                    leading: const Icon(Icons.print),
                    onTap: () async {
                       Navigator.pop(ctx);
                       SnackbarHelper.showSuccess(context, "Connecting to $name...");
                       final connected = await service.connect(d);
                       if (connected) {
                           if (_bill != null && _settings != null) {
                             final pdfData = await PdfThermalHelper.generateThermalPdf(_bill!, _settings!, creditNotes: _creditNotes);
                             await service.printThermalPdf(pdfData);
                             if (mounted) SnackbarHelper.showSuccess(context, "Sent to printer");
                           }
                       } else {
                          if (mounted) SnackbarHelper.showError(context, "Failed to connect");
                       }
                    },
                  );
                },
              ),
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_errorMessage.isNotEmpty) return Scaffold(body: Center(child: Text(_errorMessage)));
    if (_bill == null || _settings == null) return const Scaffold(body: Center(child: Text('Bill not found')));

    final bill = _bill!;
    final settings = _settings!;
    
    // License Check (Optional)
    final isReadOnly = (_userModel != null && !LicenseService().isLicenseValid(_userModel!));
    final date = DateFormat('dd MMM yyyy').format(bill.billDate);

    return Scaffold(
          backgroundColor: AppColors.background,
          appBar: Responsive.isDesktop(context) 
            ? null 
            : AppBar(
                title: const Text('Invoice Details'),
                backgroundColor: Colors.white,
                foregroundColor: AppColors.textDark,
                elevation: 0,
                centerTitle: true,
                automaticallyImplyLeading: true,
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(1),
                  child: Container(color: AppColors.border, height: 1),
                ),
                actions: [
                  IconButton(
                    icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.green, size: 20),
                    onPressed: () => PdfInvoiceHelper.openWhatsApp(context, bill, overrideSettings: _settings, creditNotes: _creditNotes),
                    tooltip: 'Share on WhatsApp',
                  ),
                  IconButton(
                    icon: const Icon(Icons.download_rounded),
                    onPressed: () => PdfInvoiceHelper.generateAndDownload(bill, overrideSettings: _settings, creditNotes: _creditNotes),
                    tooltip: 'Download Invoice',
                  ),
                  if (!isReadOnly) ...[
                      IconButton(
                        icon: const Icon(Icons.print),
                        onPressed: _printPdf,
                      ),
                      // REMOVED DUPLICATE UPDATE STATUS ICON
                       IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: _editBill, // NEW
                        tooltip: 'Edit',
                      ),
                      IconButton(
                        icon: const Icon(Icons.history),
                        onPressed: _viewHistory, // NEW
                        tooltip: 'History',
                      ),
                    /*
                    // Native Android Bluetooth Print (Disabled for Build Stability)
                    if (!kIsWeb && io.Platform.isAndroid)
                        IconButton(
                          icon: const Icon(Icons.bluetooth_audio, color: Colors.blue),
                          tooltip: 'Bluetooth Print',
                          onPressed: () {
                             _showBluetoothDialog();
                          },
                        ),
                    */
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.error),
                      onPressed: _confirmDelete,
                    ),
                  ]
                ],
              ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                 if (isReadOnly)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    color: Colors.red.shade50,
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "License Expired. Read Only Mode.",
                            style: TextStyle(
                                color: Colors.red.shade900, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),

                // check if desktop and add buttons
                if (Responsive.isDesktop(context) && !isReadOnly)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton.icon(
                          icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 16),
                          label: const Text('WhatsApp'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                          onPressed: () => PdfInvoiceHelper.openWhatsApp(context, bill, overrideSettings: _settings, creditNotes: _creditNotes),
                        ),
                      const SizedBox(width: 12),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.download_rounded, size: 16),
                          label: const Text('Download'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                          onPressed: () => PdfInvoiceHelper.generateAndDownload(bill, overrideSettings: _settings, creditNotes: _creditNotes),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.print, size: 16),
                          label: const Text('Print'),
                          onPressed: _printPdf,
                        ),
                         const SizedBox(width: 12),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Update Status'),
                          onPressed: _updateStatus,
                        ),
                         const SizedBox(width: 12),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Edit'),
                          onPressed: _editBill, // NEW
                        ),
                         const SizedBox(width: 12),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.history, size: 16),
                          label: const Text('History'),
                          onPressed: _viewHistory, // NEW
                        ),
                         const SizedBox(width: 12),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.delete, size: 16, color: AppColors.error),
                          label: const Text('Delete', style: TextStyle(color: AppColors.error)),
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.error)),
                          onPressed: _confirmDelete,
                        ),
                      ],
                    ),
                  ),

                // Invoice Card (Wrapped in Stack for Stamp)
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  settings.tenantName,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.copy, size: 16, color: AppColors.textGrey),
                                      tooltip: 'Copy Invoice No',
                                      onPressed: () {
                                        Clipboard.setData(ClipboardData(text: bill.invoiceNumber));
                                        SnackbarHelper.showSuccess(context, 'Invoice Number copied!');
                                      },
                                    ),
                                    if (!isReadOnly)
                                      InkWell(
                                        onTap: _updateStatus,
                                        child: Row(
                                          children: [
                                            if (_creditNotes.isNotEmpty) ...[
                                              Container(
                                                margin: const EdgeInsets.only(right: 8),
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: AppColors.error.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: AppColors.error.withOpacity(0.3)),
                                                ),
                                                child: const Text('RETURNED', style: TextStyle(color: AppColors.error, fontSize: 10, fontWeight: FontWeight.bold)),
                                              ),
                                            ],
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: _getStatusColor(bill.paymentStatus).withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: _getStatusColor(bill.paymentStatus).withOpacity(0.3)),
                                              ),
                                              child: Row(
                                                children: [
                                                  Text(
                                                    bill.paymentStatus.toUpperCase(),
                                                    style: TextStyle(
                                                      color: _getStatusColor(bill.paymentStatus),
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Icon(Icons.edit, size: 12, color: _getStatusColor(bill.paymentStatus)),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    else 
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(bill.paymentStatus).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: _getStatusColor(bill.paymentStatus).withOpacity(0.3)),
                                        ),
                                        child: Text(
                                          bill.paymentStatus.toUpperCase(),
                                          style: TextStyle(
                                            color: _getStatusColor(bill.paymentStatus),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            
                            
                            const Divider(height: 40, color: AppColors.border),
                            
                            if (bill.ewayBillNo != null && bill.ewayBillNo!.isNotEmpty) ...[
                                  Container(
                                    margin: const EdgeInsets.only(top: 8), 
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                                    ),
                                    child: const Text('E-WAY BILL', style: TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                            
                            // ... existing content continues ...


                        if (Responsive.isMobile(context)) ...[
                          // MOBILE LAYOUT - SEQUENTIAL GROUPING
                          const Text('Client Details', style: TextStyle(color: AppColors.textGrey, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          _infoRow('Client', bill.customerName),
                          if (bill.clientId.isNotEmpty) _infoRow('Client ID', bill.clientId),
                          if (bill.clientAddress.isNotEmpty) _infoRow('Address', bill.clientAddress),
                          if (bill.clientCity != null && bill.clientCity!.isNotEmpty) _infoRow('City', bill.clientCity!),
                          if (bill.placeOfSupply.isNotEmpty) _infoRow('State', bill.placeOfSupply),
                          if (bill.gstNumber != null && bill.gstNumber!.isNotEmpty) _infoRow('Client GST', bill.gstNumber!),
                          
                          const SizedBox(height: 16),
                          const Text('Invoice Details', style: TextStyle(color: AppColors.textGrey, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          _infoRow('Invoice No', bill.invoiceNumber),
                          _infoRow('Bill Date', date),
                          if (bill.paymentReceivedDate != null) 
                            _infoRow('Payment Date', DateFormat('dd MMM yyyy').format(bill.paymentReceivedDate!)),

                           const SizedBox(height: 16),
                           const Text('Logistics & Tax', style: TextStyle(color: AppColors.textGrey, fontWeight: FontWeight.bold)),
                           const SizedBox(height: 8),
                           if (settings.gstNumber.isNotEmpty) _infoRow('Seller GST', settings.gstNumber),
                           if (bill.ewayBillNo != null && bill.ewayBillNo!.isNotEmpty) _infoRow('e-Way Bill No', bill.ewayBillNo!),
                           if (bill.vehicleNo != null && bill.vehicleNo!.isNotEmpty) _infoRow('Vehicle No', bill.vehicleNo!),

                          if (bill.shippingName != null && bill.shippingName!.isNotEmpty) ...[
                             const SizedBox(height: 12),
                             const Text('Shipped To', style: TextStyle(color: AppColors.textGrey, fontWeight: FontWeight.bold)),
                             const SizedBox(height: 4),
                             Text(bill.shippingName!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                             if (bill.shippingAddress != null) Text(bill.shippingAddress!, style: const TextStyle(fontSize: 14)),
                             const SizedBox(height: 12),
                          ],
                        ] else ...[
                          // DESKTOP LAYOUT - COLUMNS
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // LEFT COLUMN: Customer & Shipping
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Client Details', style: TextStyle(color: AppColors.textGrey, fontWeight: FontWeight.bold, fontSize: 12)),
                                    const SizedBox(height: 8),
                                    _infoRow('Client', bill.customerName),
                                    if (bill.clientId.isNotEmpty) _infoRow('Client ID', bill.clientId),
                                    if (bill.clientAddress.isNotEmpty) _infoRow('Address', bill.clientAddress),
                                    if (bill.clientCity != null && bill.clientCity!.isNotEmpty) _infoRow('City', bill.clientCity!),
                                    if (bill.placeOfSupply.isNotEmpty) _infoRow('State', bill.placeOfSupply),
                                    if (bill.gstNumber != null && bill.gstNumber!.isNotEmpty) _infoRow('Client GST', bill.gstNumber!),
                                    
                                    if (bill.shippingName != null && bill.shippingName!.isNotEmpty) ...[
                                       const SizedBox(height: 16),
                                       const Text('Shipped To', style: TextStyle(color: AppColors.textGrey, fontWeight: FontWeight.bold, fontSize: 12)),
                                       const SizedBox(height: 8),
                                       Row(
                                         crossAxisAlignment: CrossAxisAlignment.start,
                                         children: [
                                           const SizedBox(width: 100), // Spacing to align with labels if needed, or remove for left align
                                           Expanded(
                                             child: Column(
                                               crossAxisAlignment: CrossAxisAlignment.start,
                                               children: [
                                                 Text(bill.shippingName!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                                 if (bill.shippingAddress != null) Text(bill.shippingAddress!, style: const TextStyle(fontSize: 14)),
                                               ],
                                             ),
                                           ),
                                         ],
                                       ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 24),
                              // RIGHT COLUMN: Invoice Metadata
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Invoice Details', style: TextStyle(color: AppColors.textGrey, fontWeight: FontWeight.bold, fontSize: 12)),
                                    const SizedBox(height: 8),
                                    _infoRow('Invoice No', bill.invoiceNumber),
                                    _infoRow('Bill Date', date),
                                    if (bill.paymentReceivedDate != null) 
                                      _infoRow('Payment Date', DateFormat('dd MMM yyyy').format(bill.paymentReceivedDate!)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // LOGISTICS BAR (Full Width)
                          if (settings.gstNumber.isNotEmpty || (bill.ewayBillNo != null && bill.ewayBillNo!.isNotEmpty) || (bill.vehicleNo != null && bill.vehicleNo!.isNotEmpty)) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  if (settings.gstNumber.isNotEmpty) 
                                    Expanded(child: _compactInfo('Seller GST', settings.gstNumber)),
                                  
                                  if (bill.ewayBillNo != null && bill.ewayBillNo!.isNotEmpty) ...[
                                    Container(width: 1, height: 24, color: Colors.grey.shade300, margin: const EdgeInsets.symmetric(horizontal: 16)),
                                    Expanded(child: _compactInfo('e-Way Bill No', bill.ewayBillNo!)),
                                  ],

                                  if (bill.vehicleNo != null && bill.vehicleNo!.isNotEmpty) ...[
                                    Container(width: 1, height: 24, color: Colors.grey.shade300, margin: const EdgeInsets.symmetric(horizontal: 16)),
                                    Expanded(child: _compactInfo('Vehicle No', bill.vehicleNo!)),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ],
                        
                        const SizedBox(height: 12),
                        const Text('Items', style: TextStyle(color: AppColors.textGrey, fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 12),

                        // NEW RESPONSIVE ITEM TABLE
                        BillItemsTable(items: bill.items),
                        
                        // Returns / Credit Notes Section
                        if (_creditNotes.isNotEmpty) ...[
                          const Divider(height: 40, color: AppColors.border),
                          const Text('Returns / Credit Notes', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ..._creditNotes.expand((note) => note.items.map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${item.description} (Returned)',
                                    style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.textGrey, fontStyle: FontStyle.italic),
                                  ),
                                ),
                                Text(
                                  '- ₹${item.amount.toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.error),
                                ),
                              ],
                            ),
                          ))),
                        ],
                        
                        const Divider(height: 40, color: AppColors.border),
                        
                        // Calculation Section
                        if (bill.taxPercentage > 0)
                           _infoRow('Subtotal', '₹${(bill.totalAmount / (1 + bill.taxPercentage/100)).toStringAsFixed(2)}'), // Back calc approximation or just sum items if avail
                        
                        // Tax Breakdown
                        if (bill.igstAmount > 0)
                           _infoRow('IGST (${bill.taxPercentage.toStringAsFixed(0)}%)', '₹${bill.igstAmount.toStringAsFixed(2)}'),
                        
                        if (bill.cgstAmount > 0)
                           _infoRow('CGST (${(bill.taxPercentage/2).toStringAsFixed(1)}%)', '₹${bill.cgstAmount.toStringAsFixed(2)}'),

                        if (bill.sgstAmount > 0)
                           _infoRow('SGST (${(bill.taxPercentage/2).toStringAsFixed(1)}%)', '₹${bill.sgstAmount.toStringAsFixed(2)}'),
                        
                        // Fallback/Legacy
                        if (bill.taxPercentage > 0 && bill.igstAmount == 0 && bill.cgstAmount == 0 && bill.sgstAmount == 0)
                           _infoRow('Tax (${bill.taxPercentage.toStringAsFixed(0)}%)', '₹${bill.taxAmount.toStringAsFixed(2)}'),

                       Row(
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                         children: [
                           const Text(
                             'Grand Total',
                             style: TextStyle(
                               fontSize: 16,
                               fontWeight: FontWeight.w600,
                               color: AppColors.textDark,
                             ),
                           ),
                           Text(
                             '₹${bill.totalAmount.toStringAsFixed(2)}',
                             style: const TextStyle(
                               fontSize: 24,
                               fontWeight: FontWeight.bold,
                               color: AppColors.primary,
                             ),
                           ),
                         ],
                       ),

                       // Returns Total
                       if (bill.returnAmount > 0 || _creditNotes.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _infoRow('Less Returns', '- ₹${bill.returnAmount.toStringAsFixed(2)}', color: AppColors.error, isAmount: true),
                          const Divider(),
                          Row(
                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
                           children: [
                             const Text(
                               'Net Payable',
                               style: TextStyle(
                                 fontSize: 16,
                                 fontWeight: FontWeight.bold,
                                 color: AppColors.textDark,
                               ),
                             ),
                             Text(
                               '₹${(bill.totalAmount - bill.returnAmount).toStringAsFixed(2)}',
                               style: const TextStyle(
                                 fontSize: 20,
                                 fontWeight: FontWeight.bold,
                                 color: AppColors.textDark,
                               ),
                             ),
                           ],
                         ),
                       ],

                        const SizedBox(height: 8),
                        const Divider(),
                        
                        // Payment History
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Payment History',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark,
                                ),
                              ),
                              if (!isReadOnly && bill.paymentStatus.toLowerCase() != 'paid')
                                TextButton.icon(
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Add', style: TextStyle(fontSize: 12)),
                                  onPressed: _showAddPaymentDialog,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (bill.payments.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('No payments recorded yet.', style: TextStyle(fontSize: 12, color: AppColors.textGrey, fontStyle: FontStyle.italic)),
                          )
                        else
                          ...bill.payments.map((p) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${DateFormat('dd MMM yyyy').format(p.date)} (${p.mode})',
                                        style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '₹${p.amount.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success),
                                ),
                                if (!isReadOnly && p.id != null)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.error),
                                    onPressed: () => _deletePayment(p.id!),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                              ],
                            ),
                          )),
                        const SizedBox(height: 8),

                        _infoRow('Total Advance', '- ₹${bill.advanceAmount.toStringAsFixed(2)}', color: AppColors.success, isAmount: true),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Balance Due',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.error,
                              ),
                            ),
                            Text(
                              '₹${(bill.paymentStatus == 'Paid' ? 0.0 : (bill.totalAmount - bill.returnAmount - bill.advanceAmount)).toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.error,
                              ),
                            ),
                          ],
                        ),

                        // Bank Details Section
                        if (bill.paymentStatus.toLowerCase() != 'paid' && settings.bankName.isNotEmpty) ...[
                          const Divider(height: 40, color: AppColors.border),
                          const Text(
                            'Bank Details',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              children: [
                                _infoRow('Bank Name', settings.bankName),
                                _infoRow('Account No', settings.accountNumber),
                                _infoRow('IFSC Code', settings.ifscCode),
                                _infoRow('Acc Holder', settings.accountHolderName),
                                if (settings.upiId.isNotEmpty)
                                  _infoRow('UPI ID', settings.upiId),
                              ],
                            ),
                          ),
                        ],
                        ],
                      ),
                    ),
                  ),


            ],
          ),

          // QR Code Section
          if (bill.paymentStatus.toLowerCase() != 'paid' && settings.upiId.isNotEmpty && settings.payeeName.isNotEmpty) ...[
            const Divider(height: 40, color: AppColors.border),
            Center(
              child: Column(
                children: [
                   const Text(
                    'Scan to Pay',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                      child: QrImageView(
                        data: UpiHelper.generateUpiUrl(
                          pa: settings.upiId,
                          pn: settings.payeeName,
                          am: (bill.totalAmount - bill.returnAmount - bill.advanceAmount),
                          tn: 'Invoice ${bill.invoiceNumber}',
                        ),
                        version: QrVersions.auto,
                      size: 150.0,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Accepted via any UPI App',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textGrey,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Download Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.download_rounded),
              label: const Text('Download Invoice PDF'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                elevation: 0,
              ),
              onPressed: () async {
                try {
                  await PdfInvoiceHelper.generateAndDownload(bill, creditNotes: _creditNotes);
                } catch (e) {
                    if (context.mounted) SnackbarHelper.showError(context, 'PDF Error: $e');
                }
              },
            ),
          ),
        ],
      ),
    ),
  );
 }

  
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Paid': return AppColors.success; // Green
      case 'Partial': return Colors.amber.shade700; // Yellow (Amber for visibility)
      default: return AppColors.error; // Red (Pending)
    }
  }

  Widget _infoRow(String label, String value, {bool isAmount = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: AppColors.textGrey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isAmount ? FontWeight.bold : FontWeight.w500,
                color: color ?? AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _tableHeader(String text, {TextAlign align = TextAlign.left}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold, 
          fontSize: 11, // Smaller font for PWA fit
        ),
        textAlign: align,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _tableCell(String text, {TextAlign align = TextAlign.left, Color? color, FontWeight? fontWeight}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11, // Smaller font for PWA fit
          color: color, 
          fontWeight: fontWeight
        ),
        textAlign: align,
        maxLines: 1,
        overflow: TextOverflow.ellipsis, // Critical: Prevent wrapping
      ),
    );
  }
  Widget _compactInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textGrey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
      ],
    );
  }
}
