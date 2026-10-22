import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bn.dart';
import 'app_localizations_en.dart';
import 'app_localizations_gu.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_kn.dart';
import 'app_localizations_ml.dart';
import 'app_localizations_mr.dart';
import 'app_localizations_ta.dart';
import 'app_localizations_te.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('bn'),
    Locale('en'),
    Locale('gu'),
    Locale('hi'),
    Locale('kn'),
    Locale('ml'),
    Locale('mr'),
    Locale('ta'),
    Locale('te'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'DigiInvi'**
  String get appTitle;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @clients.
  ///
  /// In en, this message translates to:
  /// **'Clients'**
  String get clients;

  /// No description provided for @bills.
  ///
  /// In en, this message translates to:
  /// **'Bills'**
  String get bills;

  /// No description provided for @expenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get expenses;

  /// No description provided for @reports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reports;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcome;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @totalRevenue.
  ///
  /// In en, this message translates to:
  /// **'Total Revenue'**
  String get totalRevenue;

  /// No description provided for @activeClients.
  ///
  /// In en, this message translates to:
  /// **'Active Clients'**
  String get activeClients;

  /// No description provided for @expired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get expired;

  /// No description provided for @blocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get blocked;

  /// No description provided for @billing.
  ///
  /// In en, this message translates to:
  /// **'Billing'**
  String get billing;

  /// No description provided for @newBill.
  ///
  /// In en, this message translates to:
  /// **'New Bill'**
  String get newBill;

  /// No description provided for @clientName.
  ///
  /// In en, this message translates to:
  /// **'Client Name'**
  String get clientName;

  /// No description provided for @mou.
  ///
  /// In en, this message translates to:
  /// **'MOU'**
  String get mou;

  /// No description provided for @mouStatus.
  ///
  /// In en, this message translates to:
  /// **'MOU Status'**
  String get mouStatus;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @accepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get accepted;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @calendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendar;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @overview.
  ///
  /// In en, this message translates to:
  /// **'Overview of your billing status'**
  String get overview;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @paid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paid;

  /// No description provided for @earningTrends.
  ///
  /// In en, this message translates to:
  /// **'Earning Trends'**
  String get earningTrends;

  /// No description provided for @serviceDistribution.
  ///
  /// In en, this message translates to:
  /// **'Service Distribution'**
  String get serviceDistribution;

  /// No description provided for @paidVsPending.
  ///
  /// In en, this message translates to:
  /// **'Paid vs Pending'**
  String get paidVsPending;

  /// No description provided for @noData.
  ///
  /// In en, this message translates to:
  /// **'No data available'**
  String get noData;

  /// No description provided for @myBusiness.
  ///
  /// In en, this message translates to:
  /// **'My Business'**
  String get myBusiness;

  /// No description provided for @createInvoice.
  ///
  /// In en, this message translates to:
  /// **'Create Invoice'**
  String get createInvoice;

  /// No description provided for @salesReturn.
  ///
  /// In en, this message translates to:
  /// **'Sales Return'**
  String get salesReturn;

  /// No description provided for @paidCollections.
  ///
  /// In en, this message translates to:
  /// **'Paid Collections'**
  String get paidCollections;

  /// No description provided for @pendingDues.
  ///
  /// In en, this message translates to:
  /// **'Pending Dues'**
  String get pendingDues;

  /// No description provided for @licenseInformation.
  ///
  /// In en, this message translates to:
  /// **'License Information'**
  String get licenseInformation;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @inactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get inactive;

  /// No description provided for @subscriptionStart.
  ///
  /// In en, this message translates to:
  /// **'Subscription Start'**
  String get subscriptionStart;

  /// No description provided for @subscriptionEnd.
  ///
  /// In en, this message translates to:
  /// **'Subscription End'**
  String get subscriptionEnd;

  /// No description provided for @remainingDays.
  ///
  /// In en, this message translates to:
  /// **'Remaining Days'**
  String get remainingDays;

  /// No description provided for @days.
  ///
  /// In en, this message translates to:
  /// **'{days} Days'**
  String days(Object days);

  /// No description provided for @invoiceSettings.
  ///
  /// In en, this message translates to:
  /// **'Invoice Settings'**
  String get invoiceSettings;

  /// No description provided for @invoicePrefix.
  ///
  /// In en, this message translates to:
  /// **'Invoice Prefix'**
  String get invoicePrefix;

  /// No description provided for @nextNumber.
  ///
  /// In en, this message translates to:
  /// **'Next Number'**
  String get nextNumber;

  /// No description provided for @generalDetails.
  ///
  /// In en, this message translates to:
  /// **'General Details'**
  String get generalDetails;

  /// No description provided for @uploadLogo.
  ///
  /// In en, this message translates to:
  /// **'Upload Logo'**
  String get uploadLogo;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @logoHeight.
  ///
  /// In en, this message translates to:
  /// **'Logo Height'**
  String get logoHeight;

  /// No description provided for @logoWidth.
  ///
  /// In en, this message translates to:
  /// **'Logo Width'**
  String get logoWidth;

  /// No description provided for @security.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get security;

  /// No description provided for @enablePin.
  ///
  /// In en, this message translates to:
  /// **'Enable 4-Digit PIN'**
  String get enablePin;

  /// No description provided for @secureAppPin.
  ///
  /// In en, this message translates to:
  /// **'Secure your app with a PIN code'**
  String get secureAppPin;

  /// No description provided for @biometricLogin.
  ///
  /// In en, this message translates to:
  /// **'Biometric Login'**
  String get biometricLogin;

  /// No description provided for @useFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Use Fingerprint or Face ID'**
  String get useFingerprint;

  /// No description provided for @mouTerms.
  ///
  /// In en, this message translates to:
  /// **'MOU and Terms & Conditions'**
  String get mouTerms;

  /// No description provided for @viewSignAgreement.
  ///
  /// In en, this message translates to:
  /// **'View and sign agreement'**
  String get viewSignAgreement;

  /// No description provided for @businessName.
  ///
  /// In en, this message translates to:
  /// **'Business Name'**
  String get businessName;

  /// No description provided for @contactEmail.
  ///
  /// In en, this message translates to:
  /// **'Contact Email'**
  String get contactEmail;

  /// No description provided for @contactPhone.
  ///
  /// In en, this message translates to:
  /// **'Contact Phone'**
  String get contactPhone;

  /// No description provided for @streetAddress.
  ///
  /// In en, this message translates to:
  /// **'Street Address'**
  String get streetAddress;

  /// No description provided for @city.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get city;

  /// No description provided for @district.
  ///
  /// In en, this message translates to:
  /// **'District'**
  String get district;

  /// No description provided for @pincode.
  ///
  /// In en, this message translates to:
  /// **'Pincode'**
  String get pincode;

  /// No description provided for @gstTaxDetails.
  ///
  /// In en, this message translates to:
  /// **'GST & Tax Details'**
  String get gstTaxDetails;

  /// No description provided for @gstNumber.
  ///
  /// In en, this message translates to:
  /// **'GST Number'**
  String get gstNumber;

  /// No description provided for @businessState.
  ///
  /// In en, this message translates to:
  /// **'Business State'**
  String get businessState;

  /// No description provided for @defaultGstRate.
  ///
  /// In en, this message translates to:
  /// **'Default GST Rate (%)'**
  String get defaultGstRate;

  /// No description provided for @printerFormat.
  ///
  /// In en, this message translates to:
  /// **'Printer Format'**
  String get printerFormat;

  /// No description provided for @bankDetails.
  ///
  /// In en, this message translates to:
  /// **'Bank Details'**
  String get bankDetails;

  /// No description provided for @bankName.
  ///
  /// In en, this message translates to:
  /// **'Bank Name'**
  String get bankName;

  /// No description provided for @accountNumber.
  ///
  /// In en, this message translates to:
  /// **'Account Number'**
  String get accountNumber;

  /// No description provided for @ifscCode.
  ///
  /// In en, this message translates to:
  /// **'IFSC Code'**
  String get ifscCode;

  /// No description provided for @accountHolderName.
  ///
  /// In en, this message translates to:
  /// **'Account Holder Name'**
  String get accountHolderName;

  /// No description provided for @upiId.
  ///
  /// In en, this message translates to:
  /// **'UPI ID'**
  String get upiId;

  /// No description provided for @payeeName.
  ///
  /// In en, this message translates to:
  /// **'Payee Name (for UPI)'**
  String get payeeName;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logOut;

  /// No description provided for @transactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get transactions;

  /// No description provided for @manageBillsInvoices.
  ///
  /// In en, this message translates to:
  /// **'Manage your bills and invoices'**
  String get manageBillsInvoices;

  /// No description provided for @searchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search by Namme, Invoice, Amount...'**
  String get searchPlaceholder;

  /// No description provided for @invoices.
  ///
  /// In en, this message translates to:
  /// **'Invoices'**
  String get invoices;

  /// No description provided for @purchases.
  ///
  /// In en, this message translates to:
  /// **'Purchases'**
  String get purchases;

  /// No description provided for @quotations.
  ///
  /// In en, this message translates to:
  /// **'Quotations'**
  String get quotations;

  /// No description provided for @purchaseOrders.
  ///
  /// In en, this message translates to:
  /// **'Purchases'**
  String get purchaseOrders;

  /// No description provided for @returns.
  ///
  /// In en, this message translates to:
  /// **'Returns'**
  String get returns;

  /// No description provided for @noBillsMatch.
  ///
  /// In en, this message translates to:
  /// **'No bills match your search'**
  String get noBillsMatch;

  /// No description provided for @noBillsFound.
  ///
  /// In en, this message translates to:
  /// **'No bills found'**
  String get noBillsFound;

  /// No description provided for @acceptTerms.
  ///
  /// In en, this message translates to:
  /// **'Accept Terms & Conditions'**
  String get acceptTerms;

  /// No description provided for @readSignMou.
  ///
  /// In en, this message translates to:
  /// **'You must read and sign the MOU & Terms before creating invoices.'**
  String get readSignMou;

  /// No description provided for @reviewSign.
  ///
  /// In en, this message translates to:
  /// **'Review & Sign'**
  String get reviewSign;

  /// No description provided for @deleteInvoice.
  ///
  /// In en, this message translates to:
  /// **'Delete Invoice'**
  String get deleteInvoice;

  /// No description provided for @deleteConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this invoice? This action cannot be undone.'**
  String get deleteConfirmation;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @offlineMode.
  ///
  /// In en, this message translates to:
  /// **'Offline Mode'**
  String get offlineMode;

  /// No description provided for @returned.
  ///
  /// In en, this message translates to:
  /// **'RETURNED'**
  String get returned;

  /// No description provided for @updatePaymentStatus.
  ///
  /// In en, this message translates to:
  /// **'Update Payment Status'**
  String get updatePaymentStatus;

  /// No description provided for @partial.
  ///
  /// In en, this message translates to:
  /// **'Partial'**
  String get partial;

  /// No description provided for @newBillTitle.
  ///
  /// In en, this message translates to:
  /// **'New Bill'**
  String get newBillTitle;

  /// No description provided for @createInvoiceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create a new invoice for a customer'**
  String get createInvoiceSubtitle;

  /// No description provided for @customerDetails.
  ///
  /// In en, this message translates to:
  /// **'Customer Details'**
  String get customerDetails;

  /// No description provided for @customerNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Customer Name'**
  String get customerNameLabel;

  /// No description provided for @contactNumber.
  ///
  /// In en, this message translates to:
  /// **'Contact Number (WhatsApp)'**
  String get contactNumber;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @invoiceDetails.
  ///
  /// In en, this message translates to:
  /// **'Invoice Details'**
  String get invoiceDetails;

  /// No description provided for @invoiceDate.
  ///
  /// In en, this message translates to:
  /// **'Invoice Date'**
  String get invoiceDate;

  /// No description provided for @invoiceNumber.
  ///
  /// In en, this message translates to:
  /// **'Invoice Number'**
  String get invoiceNumber;

  /// No description provided for @clientId.
  ///
  /// In en, this message translates to:
  /// **'Client ID'**
  String get clientId;

  /// No description provided for @placeOfSupply.
  ///
  /// In en, this message translates to:
  /// **'Place of Supply (State)'**
  String get placeOfSupply;

  /// No description provided for @billItems.
  ///
  /// In en, this message translates to:
  /// **'Bill Items'**
  String get billItems;

  /// No description provided for @itemDescription.
  ///
  /// In en, this message translates to:
  /// **'Item Description, Product...'**
  String get itemDescription;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get quantity;

  /// No description provided for @rate.
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get rate;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @addItem.
  ///
  /// In en, this message translates to:
  /// **'Add Item'**
  String get addItem;

  /// No description provided for @paymentDetails.
  ///
  /// In en, this message translates to:
  /// **'Payment Details'**
  String get paymentDetails;

  /// No description provided for @addPayment.
  ///
  /// In en, this message translates to:
  /// **'Add Payment'**
  String get addPayment;

  /// No description provided for @subTotal.
  ///
  /// In en, this message translates to:
  /// **'Sub Total'**
  String get subTotal;

  /// No description provided for @taxRate.
  ///
  /// In en, this message translates to:
  /// **'Tax Rate (%)'**
  String get taxRate;

  /// No description provided for @grandTotal.
  ///
  /// In en, this message translates to:
  /// **'Grand Total'**
  String get grandTotal;

  /// No description provided for @advancePaid.
  ///
  /// In en, this message translates to:
  /// **'Advance Paid'**
  String get advancePaid;

  /// No description provided for @balanceDue.
  ///
  /// In en, this message translates to:
  /// **'Balance Due'**
  String get balanceDue;

  /// No description provided for @saveBill.
  ///
  /// In en, this message translates to:
  /// **'Save Bill'**
  String get saveBill;

  /// No description provided for @scanBarcode.
  ///
  /// In en, this message translates to:
  /// **'Scan Barcode'**
  String get scanBarcode;

  /// No description provided for @transportDetails.
  ///
  /// In en, this message translates to:
  /// **'Additional Details (Transport)'**
  String get transportDetails;

  /// No description provided for @ewayBillNo.
  ///
  /// In en, this message translates to:
  /// **'e-Way Bill No'**
  String get ewayBillNo;

  /// No description provided for @vehicleNo.
  ///
  /// In en, this message translates to:
  /// **'Vehicle No'**
  String get vehicleNo;

  /// No description provided for @transportMode.
  ///
  /// In en, this message translates to:
  /// **'Transport Mode'**
  String get transportMode;

  /// No description provided for @newProductFound.
  ///
  /// In en, this message translates to:
  /// **'New Product Found'**
  String get newProductFound;

  /// No description provided for @barcode.
  ///
  /// In en, this message translates to:
  /// **'Barcode'**
  String get barcode;

  /// No description provided for @productName.
  ///
  /// In en, this message translates to:
  /// **'Product Name'**
  String get productName;

  /// No description provided for @sellingPrice.
  ///
  /// In en, this message translates to:
  /// **'Selling Price'**
  String get sellingPrice;

  /// No description provided for @saveAndAdd.
  ///
  /// In en, this message translates to:
  /// **'Save & Add'**
  String get saveAndAdd;

  /// No description provided for @lowStockWarning.
  ///
  /// In en, this message translates to:
  /// **'Low Stock for {productName}! Only {stock} {unit} remaining.'**
  String lowStockWarning(Object productName, Object stock, Object unit);

  /// No description provided for @productAdded.
  ///
  /// In en, this message translates to:
  /// **'{productName} added'**
  String productAdded(Object productName);

  /// No description provided for @manualEwayBillOption.
  ///
  /// In en, this message translates to:
  /// **'Manual Option A: Enter details from GST portal'**
  String get manualEwayBillOption;

  /// No description provided for @noPaymentsAdded.
  ///
  /// In en, this message translates to:
  /// **'No payments added yet.'**
  String get noPaymentsAdded;

  /// No description provided for @selectClient.
  ///
  /// In en, this message translates to:
  /// **'Select Client'**
  String get selectClient;

  /// No description provided for @searchClientPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search Client Name or ID'**
  String get searchClientPlaceholder;

  /// No description provided for @noClientsFound.
  ///
  /// In en, this message translates to:
  /// **'No clients found'**
  String get noClientsFound;

  /// No description provided for @billCount.
  ///
  /// In en, this message translates to:
  /// **'{count} Bills'**
  String billCount(Object count);

  /// No description provided for @clientStatement.
  ///
  /// In en, this message translates to:
  /// **'Client Statement'**
  String get clientStatement;

  /// No description provided for @totalBilled.
  ///
  /// In en, this message translates to:
  /// **'Total Billed'**
  String get totalBilled;

  /// No description provided for @downloadPdf.
  ///
  /// In en, this message translates to:
  /// **'Download PDF'**
  String get downloadPdf;

  /// No description provided for @invoiceNo.
  ///
  /// In en, this message translates to:
  /// **'Invoice #'**
  String get invoiceNo;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @customer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get customer;

  /// No description provided for @service.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get service;

  /// No description provided for @advanceByDate.
  ///
  /// In en, this message translates to:
  /// **'Advance By Date'**
  String get advanceByDate;

  /// No description provided for @received.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get received;

  /// No description provided for @balance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get balance;

  /// No description provided for @salesReturns.
  ///
  /// In en, this message translates to:
  /// **'Sales Returns / Credit Notes'**
  String get salesReturns;

  /// No description provided for @linkClientTitle.
  ///
  /// In en, this message translates to:
  /// **'Link Client to Me?'**
  String get linkClientTitle;

  /// No description provided for @linkClientContent.
  ///
  /// In en, this message translates to:
  /// **'This will update the Client\'s Tenant ID to match YOUR current account.'**
  String get linkClientContent;

  /// No description provided for @deleteClientTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Client?'**
  String get deleteClientTitle;

  /// No description provided for @deleteClientContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this client and all associated data?'**
  String get deleteClientContent;

  /// No description provided for @linkToMe.
  ///
  /// In en, this message translates to:
  /// **'Link to Me'**
  String get linkToMe;

  /// No description provided for @forceLink.
  ///
  /// In en, this message translates to:
  /// **'Force Link to Me'**
  String get forceLink;

  /// No description provided for @deleteClient.
  ///
  /// In en, this message translates to:
  /// **'Delete Client'**
  String get deleteClient;

  /// No description provided for @clientLinkedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Fixed! Client linked to your branding.'**
  String get clientLinkedSuccess;

  /// No description provided for @supportDiagnostic.
  ///
  /// In en, this message translates to:
  /// **'Support / Diagnostic'**
  String get supportDiagnostic;

  /// No description provided for @view.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view;

  /// No description provided for @tenantLink.
  ///
  /// In en, this message translates to:
  /// **'Tenant Link'**
  String get tenantLink;

  /// No description provided for @accountingReports.
  ///
  /// In en, this message translates to:
  /// **'Accounting Reports'**
  String get accountingReports;

  /// No description provided for @reportType.
  ///
  /// In en, this message translates to:
  /// **'Report Type'**
  String get reportType;

  /// No description provided for @dateRange.
  ///
  /// In en, this message translates to:
  /// **'Date Range'**
  String get dateRange;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @end.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get end;

  /// No description provided for @viewReport.
  ///
  /// In en, this message translates to:
  /// **'View Report / Summary'**
  String get viewReport;

  /// No description provided for @reportPreview.
  ///
  /// In en, this message translates to:
  /// **'Report Preview'**
  String get reportPreview;

  /// No description provided for @gstr3bSummary.
  ///
  /// In en, this message translates to:
  /// **'GSTR-3B Summary'**
  String get gstr3bSummary;

  /// No description provided for @downloadExcel.
  ///
  /// In en, this message translates to:
  /// **'Download Excel'**
  String get downloadExcel;

  /// No description provided for @downloadCsv.
  ///
  /// In en, this message translates to:
  /// **'CSV'**
  String get downloadCsv;

  /// No description provided for @downloadGstr1.
  ///
  /// In en, this message translates to:
  /// **'Download GSTR-1 Excel Utility'**
  String get downloadGstr1;

  /// No description provided for @gstr1Msg.
  ///
  /// In en, this message translates to:
  /// **'GSTR-1 is available in Excel only'**
  String get gstr1Msg;

  /// No description provided for @gstr3bMsg.
  ///
  /// In en, this message translates to:
  /// **'View Summary below. Export coming soon.'**
  String get gstr3bMsg;

  /// No description provided for @noDataReport.
  ///
  /// In en, this message translates to:
  /// **'No data found for selected period'**
  String get noDataReport;

  /// No description provided for @pdfNotSupportedGstr.
  ///
  /// In en, this message translates to:
  /// **'PDF not supported for GSTR reports yet.'**
  String get pdfNotSupportedGstr;

  /// No description provided for @downloadNote.
  ///
  /// In en, this message translates to:
  /// **'Note: Files will be downloaded or shared depending on your device capability.'**
  String get downloadNote;

  /// No description provided for @head.
  ///
  /// In en, this message translates to:
  /// **'Head'**
  String get head;

  /// No description provided for @value.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get value;

  /// No description provided for @info.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get info;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @income.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get income;

  /// No description provided for @expense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get expense;

  /// No description provided for @receivables.
  ///
  /// In en, this message translates to:
  /// **'Receivables'**
  String get receivables;

  /// No description provided for @gstr1Sales.
  ///
  /// In en, this message translates to:
  /// **'GSTR-1 (Sales)'**
  String get gstr1Sales;

  /// No description provided for @gstr3b.
  ///
  /// In en, this message translates to:
  /// **'GSTR-3B (Summary)'**
  String get gstr3b;

  /// No description provided for @balanceSheet.
  ///
  /// In en, this message translates to:
  /// **'Balance Sheet'**
  String get balanceSheet;

  /// No description provided for @selectAsOnDate.
  ///
  /// In en, this message translates to:
  /// **'Select As On Date'**
  String get selectAsOnDate;

  /// No description provided for @downloadBalanceSheet.
  ///
  /// In en, this message translates to:
  /// **'Download Balance Sheet (PDF)'**
  String get downloadBalanceSheet;

  /// No description provided for @asOnDate.
  ///
  /// In en, this message translates to:
  /// **'As On Date:'**
  String get asOnDate;

  /// No description provided for @assets.
  ///
  /// In en, this message translates to:
  /// **'Assets'**
  String get assets;

  /// No description provided for @liabilities.
  ///
  /// In en, this message translates to:
  /// **'Liabilities'**
  String get liabilities;

  /// No description provided for @equity.
  ///
  /// In en, this message translates to:
  /// **'Equity'**
  String get equity;

  /// No description provided for @cashBank.
  ///
  /// In en, this message translates to:
  /// **'Cash & Bank Balance'**
  String get cashBank;

  /// No description provided for @accountsReceivable.
  ///
  /// In en, this message translates to:
  /// **'Accounts Receivable'**
  String get accountsReceivable;

  /// No description provided for @gstPayable.
  ///
  /// In en, this message translates to:
  /// **'GST Payable'**
  String get gstPayable;

  /// No description provided for @netProfitRetained.
  ///
  /// In en, this message translates to:
  /// **'Net Profit (Retained Earnings)'**
  String get netProfitRetained;

  /// No description provided for @totalAssets.
  ///
  /// In en, this message translates to:
  /// **'Total Assets'**
  String get totalAssets;

  /// No description provided for @totalLiabilities.
  ///
  /// In en, this message translates to:
  /// **'Total Liabilities'**
  String get totalLiabilities;

  /// No description provided for @totalEquity.
  ///
  /// In en, this message translates to:
  /// **'Total Equity'**
  String get totalEquity;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export Failed:'**
  String get exportFailed;

  /// No description provided for @reportDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Disclaimer: System-generated report. CA verification recommended.'**
  String get reportDisclaimer;

  /// No description provided for @profitAndLoss.
  ///
  /// In en, this message translates to:
  /// **'Profit & Loss'**
  String get profitAndLoss;

  /// No description provided for @financialOverview.
  ///
  /// In en, this message translates to:
  /// **'Financial Overview'**
  String get financialOverview;

  /// No description provided for @profit.
  ///
  /// In en, this message translates to:
  /// **'Profit'**
  String get profit;

  /// No description provided for @outstandingReceivables.
  ///
  /// In en, this message translates to:
  /// **'Outstanding Receivables'**
  String get outstandingReceivables;

  /// No description provided for @noOutstanding.
  ///
  /// In en, this message translates to:
  /// **'Great! No outstanding bills.'**
  String get noOutstanding;

  /// No description provided for @totalOutstandingBalance.
  ///
  /// In en, this message translates to:
  /// **'Total Outstanding Balance'**
  String get totalOutstandingBalance;

  /// No description provided for @clientsPending.
  ///
  /// In en, this message translates to:
  /// **'{count} Clients Pending'**
  String clientsPending(Object count);

  /// No description provided for @overdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get overdue;

  /// No description provided for @daily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get daily;

  /// No description provided for @month.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get month;

  /// No description provided for @year.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get year;

  /// No description provided for @incomeLedger.
  ///
  /// In en, this message translates to:
  /// **'Income Ledger'**
  String get incomeLedger;

  /// No description provided for @noIncomeEntries.
  ///
  /// In en, this message translates to:
  /// **'No income entries found.'**
  String get noIncomeEntries;

  /// No description provided for @invoiceHash.
  ///
  /// In en, this message translates to:
  /// **'Invoice #'**
  String get invoiceHash;

  /// No description provided for @cnHash.
  ///
  /// In en, this message translates to:
  /// **'CN #'**
  String get cnHash;

  /// No description provided for @gstTaxLedger.
  ///
  /// In en, this message translates to:
  /// **'GST / Tax Ledger'**
  String get gstTaxLedger;

  /// No description provided for @exportExcelGstr1.
  ///
  /// In en, this message translates to:
  /// **'Export Excel (GSTR-1)'**
  String get exportExcelGstr1;

  /// No description provided for @pdfReport.
  ///
  /// In en, this message translates to:
  /// **'PDF Report'**
  String get pdfReport;

  /// No description provided for @totalGstCollected.
  ///
  /// In en, this message translates to:
  /// **'Total GST Collected'**
  String get totalGstCollected;

  /// No description provided for @taxableValue.
  ///
  /// In en, this message translates to:
  /// **'Taxable Value'**
  String get taxableValue;

  /// No description provided for @invoiceValue.
  ///
  /// In en, this message translates to:
  /// **'Invoice Value'**
  String get invoiceValue;

  /// No description provided for @dateInv.
  ///
  /// In en, this message translates to:
  /// **'Date / Inv'**
  String get dateInv;

  /// No description provided for @taxable.
  ///
  /// In en, this message translates to:
  /// **'Taxable'**
  String get taxable;

  /// No description provided for @gst.
  ///
  /// In en, this message translates to:
  /// **'GST'**
  String get gst;

  /// No description provided for @noInvoicesFound.
  ///
  /// In en, this message translates to:
  /// **'No invoices found for this period'**
  String get noInvoicesFound;

  /// No description provided for @excelExported.
  ///
  /// In en, this message translates to:
  /// **'Excel exported successfully'**
  String get excelExported;

  /// No description provided for @savedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Saved successfully'**
  String get savedSuccessfully;

  /// No description provided for @errorOccurred.
  ///
  /// In en, this message translates to:
  /// **'Error occurred'**
  String get errorOccurred;

  /// No description provided for @deleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete?'**
  String get deleteTitle;

  /// No description provided for @deleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this?'**
  String get deleteConfirm;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @action.
  ///
  /// In en, this message translates to:
  /// **'Action'**
  String get action;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @exportReport.
  ///
  /// In en, this message translates to:
  /// **'Exported Report: {fileName}'**
  String exportReport(Object fileName);

  /// No description provided for @purchaseLedger.
  ///
  /// In en, this message translates to:
  /// **'Purchase Ledger'**
  String get purchaseLedger;

  /// No description provided for @noPurchaseRecords.
  ///
  /// In en, this message translates to:
  /// **'No purchase records found.'**
  String get noPurchaseRecords;

  /// No description provided for @analyzingBill.
  ///
  /// In en, this message translates to:
  /// **'Analyzing Bill...'**
  String get analyzingBill;

  /// No description provided for @scanBill.
  ///
  /// In en, this message translates to:
  /// **'SCAN BILL'**
  String get scanBill;

  /// No description provided for @mobileFeature.
  ///
  /// In en, this message translates to:
  /// **'Mobile Feature'**
  String get mobileFeature;

  /// No description provided for @mobileFeatureMsg.
  ///
  /// In en, this message translates to:
  /// **'AI-powered bill scanning is currently exclusive to our mobile experience to ensure high accuracy using on-device hardware. \n\nPlease use the DigiInvi mobile app for the best scanning results.'**
  String get mobileFeatureMsg;

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'GOT IT'**
  String get gotIt;

  /// No description provided for @yearEndSummary.
  ///
  /// In en, this message translates to:
  /// **'Year-End Summary'**
  String get yearEndSummary;

  /// No description provided for @fiscalYear.
  ///
  /// In en, this message translates to:
  /// **'Fiscal Year {year}'**
  String fiscalYear(Object year);

  /// No description provided for @revenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get revenue;

  /// No description provided for @netProfitCaps.
  ///
  /// In en, this message translates to:
  /// **'NET PROFIT'**
  String get netProfitCaps;

  /// No description provided for @downloadAnnualReport.
  ///
  /// In en, this message translates to:
  /// **'Download Annual Report (PDF)'**
  String get downloadAnnualReport;

  /// No description provided for @monthlyBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Monthly Breakdown'**
  String get monthlyBreakdown;

  /// No description provided for @reconnectMessage.
  ///
  /// In en, this message translates to:
  /// **'Reconnect to see latest data.'**
  String get reconnectMessage;

  /// No description provided for @renewLicense.
  ///
  /// In en, this message translates to:
  /// **'Renew Your License'**
  String get renewLicense;

  /// No description provided for @renewLicenseMsg.
  ///
  /// In en, this message translates to:
  /// **'Tap below to send a renewal request to our team.'**
  String get renewLicenseMsg;

  /// No description provided for @requestRenewal.
  ///
  /// In en, this message translates to:
  /// **'Request Renewal Now'**
  String get requestRenewal;

  /// No description provided for @renewalSent.
  ///
  /// In en, this message translates to:
  /// **'Renewal request sent successfully! We will contact you soon.'**
  String get renewalSent;

  /// No description provided for @renewalFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send request: {error}'**
  String renewalFailed(Object error);

  /// No description provided for @activeBusiness.
  ///
  /// In en, this message translates to:
  /// **'Active Business'**
  String get activeBusiness;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @incomeLedgerDesc.
  ///
  /// In en, this message translates to:
  /// **'Track all incoming payments'**
  String get incomeLedgerDesc;

  /// No description provided for @accountSummary.
  ///
  /// In en, this message translates to:
  /// **'Account Summary'**
  String get accountSummary;

  /// No description provided for @accountSummaryDesc.
  ///
  /// In en, this message translates to:
  /// **'Overview of earnings and expenses'**
  String get accountSummaryDesc;

  /// No description provided for @clientStatementDesc.
  ///
  /// In en, this message translates to:
  /// **'View individual client ledgers'**
  String get clientStatementDesc;

  /// No description provided for @expenseTracker.
  ///
  /// In en, this message translates to:
  /// **'Expense Tracker'**
  String get expenseTracker;

  /// No description provided for @expenseTrackerDesc.
  ///
  /// In en, this message translates to:
  /// **'Log and track business expenses'**
  String get expenseTrackerDesc;

  /// No description provided for @profitAndLossDesc.
  ///
  /// In en, this message translates to:
  /// **'Analyze your financial performance'**
  String get profitAndLossDesc;

  /// No description provided for @outstandingReceivablesDesc.
  ///
  /// In en, this message translates to:
  /// **'Track unpaid bills & overdue clients'**
  String get outstandingReceivablesDesc;

  /// No description provided for @gstTaxLedgerDesc.
  ///
  /// In en, this message translates to:
  /// **'Track collected taxes & taxable values'**
  String get gstTaxLedgerDesc;

  /// No description provided for @accountingReportsDesc.
  ///
  /// In en, this message translates to:
  /// **'Export data to CSV / Excel'**
  String get accountingReportsDesc;

  /// No description provided for @yearEndSummaryDesc.
  ///
  /// In en, this message translates to:
  /// **'Annual revenue & expense breakdown'**
  String get yearEndSummaryDesc;

  /// No description provided for @balanceSheetDesc.
  ///
  /// In en, this message translates to:
  /// **'Assets, Liabilities & Equity Statement'**
  String get balanceSheetDesc;

  /// No description provided for @manageFinances.
  ///
  /// In en, this message translates to:
  /// **'Manage your business finances'**
  String get manageFinances;

  /// No description provided for @totalPaid.
  ///
  /// In en, this message translates to:
  /// **'Total Paid'**
  String get totalPaid;

  /// No description provided for @outstandingBalance.
  ///
  /// In en, this message translates to:
  /// **'Outstanding Balance'**
  String get outstandingBalance;

  /// No description provided for @pendingReceivables.
  ///
  /// In en, this message translates to:
  /// **'Pending Receivables'**
  String get pendingReceivables;

  /// No description provided for @paymentDistribution.
  ///
  /// In en, this message translates to:
  /// **'Payment Distribution'**
  String get paymentDistribution;

  /// No description provided for @enableAuditTrail.
  ///
  /// In en, this message translates to:
  /// **'Enable Audit Trail'**
  String get enableAuditTrail;

  /// No description provided for @trackInvoiceEdits.
  ///
  /// In en, this message translates to:
  /// **'Track invoice edits and deletions for compliance'**
  String get trackInvoiceEdits;

  /// No description provided for @incomeTaxComputation.
  ///
  /// In en, this message translates to:
  /// **'Income Tax Computation'**
  String get incomeTaxComputation;

  /// No description provided for @incomeTaxComputationDesc.
  ///
  /// In en, this message translates to:
  /// **'Estimate taxable income & tax liability'**
  String get incomeTaxComputationDesc;

  /// No description provided for @grossTotalIncome.
  ///
  /// In en, this message translates to:
  /// **'Gross Total Income'**
  String get grossTotalIncome;

  /// No description provided for @totalExpenses.
  ///
  /// In en, this message translates to:
  /// **'Total Expenses'**
  String get totalExpenses;

  /// No description provided for @netTaxableIncome.
  ///
  /// In en, this message translates to:
  /// **'Net Taxable Income'**
  String get netTaxableIncome;

  /// No description provided for @estimatedTax.
  ///
  /// In en, this message translates to:
  /// **'Estimated Tax'**
  String get estimatedTax;

  /// No description provided for @oldRegime.
  ///
  /// In en, this message translates to:
  /// **'Old Regime'**
  String get oldRegime;

  /// No description provided for @newRegime.
  ///
  /// In en, this message translates to:
  /// **'New Regime'**
  String get newRegime;

  /// No description provided for @taxDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'This is an estimated calculation. Please consult a Chartered Accountant.'**
  String get taxDisclaimer;

  /// No description provided for @licenseExpired.
  ///
  /// In en, this message translates to:
  /// **'License Expired. Your account is now in Read-Only mode.'**
  String get licenseExpired;

  /// No description provided for @createNew.
  ///
  /// In en, this message translates to:
  /// **'Create New'**
  String get createNew;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'bn',
    'en',
    'gu',
    'hi',
    'kn',
    'ml',
    'mr',
    'ta',
    'te',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bn':
      return AppLocalizationsBn();
    case 'en':
      return AppLocalizationsEn();
    case 'gu':
      return AppLocalizationsGu();
    case 'hi':
      return AppLocalizationsHi();
    case 'kn':
      return AppLocalizationsKn();
    case 'ml':
      return AppLocalizationsMl();
    case 'mr':
      return AppLocalizationsMr();
    case 'ta':
      return AppLocalizationsTa();
    case 'te':
      return AppLocalizationsTe();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
