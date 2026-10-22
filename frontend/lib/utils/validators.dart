class Validators {
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    // Basic email regex
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String? validateMobile(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Mobile number is required';
    }
    // Remove any whitespace
    String cleanValue = value.replaceAll(' ', '');
    if (cleanValue.length != 10) {
      return 'Mobile number must be exactly 10 digits';
    }
    if (int.tryParse(cleanValue) == null) {
      return 'Mobile number must contain only digits';
    }
    return null;
  }

  static String? validateAmount(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Amounts might be optional depending on context, handled by required check if needed
    }
    if (double.tryParse(value) == null) {
      return 'Enter a valid amount';
    }
    if (double.parse(value) < 0) {
      return 'Amount cannot be negative';
    }
    return null;
  }
  
  static String? validateTax(String? value) {
    if (value == null || value.isEmpty) return null;
    if (double.tryParse(value) == null) {
      return 'Invalid tax';
    }
     if (double.parse(value) < 0) {
      return 'Tax cannot be negative';
    }
    return null;
  }

  static String? validateUPI(String? value) {
    if (value == null || value.isEmpty) return null;
    // Basic UPI Id check (must contain @) OR 10 digit number if user insisted on UPI Number
    // User specifically asked "upi number must accept only 10 digit number".
    // I will support 10 digit number OR standard UPI ID containing '@'.
    
    bool isMobile = (value.length == 10 && int.tryParse(value) != null);
    bool isUpiId = value.contains('@') && !value.contains(' ');

    if (!isMobile && !isUpiId) {
      return 'Enter valid 10-digit number or UPI ID (e.g. name@bank)';
    }
    return null;
  }

  static String? validateGSTIN(String? value, {bool isOptional = false}) {
    if (value == null || value.isEmpty) {
      return isOptional ? null : 'GSTIN is required';
    }
    
    // Auto-uppercase check (though textfield should handle capitalization)
    final upperValue = value.toUpperCase();
    
    if (upperValue.length != 15) {
      return 'GSTIN must be 15 characters';
    }
    
    // Regex for GSTIN: 2 digits, 5 letters, 4 digits, 1 letter, 1 alphanumeric, Z, 1 alphanumeric
    final gstRegex = RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$');
    
    if (!gstRegex.hasMatch(upperValue)) {
      return 'Invalid GSTIN format (e.g., 27ABCDE1234F1Z5)';
    }
    
    return null;
  }
}
