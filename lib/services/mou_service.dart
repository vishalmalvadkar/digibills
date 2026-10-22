import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/mou_template_model.dart';

class MouService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // --- Template Management ---

  Stream<List<MouTemplateModel>> streamTemplates() {
    return _supabase
        .from('mou_templates')
        .stream(primaryKey: ['id'])
        .order('updated_at', ascending: false)
        .map((data) => data.map((json) => MouTemplateModel.fromMap(json)).toList());
  }

  Future<MouTemplateModel?> getActiveTemplate() async {
    final response = await _supabase
        .from('mou_templates')
        .select()
        .eq('is_active', true)
        .limit(1);
    
    if (response.isNotEmpty) {
      return MouTemplateModel.fromMap(response.first);
    }
    
    // Auto-create default if none exists
    final all = await _supabase.from('mou_templates').select().limit(1);
    if (all.isEmpty) {
      return await _createDefaultTemplate();
    }
    
    return null;
  }
  
  Future<MouTemplateModel> _createDefaultTemplate() async {
    final defaultContent = {
      'en': '''# Memorandum of Understanding

This Memorandum of Understanding (the "MOU") is entered into by and between **{{company_name}}** (the "Provider") and **{{client_business_name}}** (the "Client").

## 1. Scope of Service
The Provider provides a cloud-based billing and ledger management application. This includes:
*   Digital bill and quote creation.
*   Client ledger and statement tracking.
*   Automated GSTR-1 and GSTR-3B report generation.

## 2. Data Ownership & Privacy
*   **Ownership:** All data entered by the Client remains the sole property of the Client.
*   **Privacy:** The Provider will not share or sell Client data to any third party.
*   **Security:** Data is stored securely on cloud servers, but the Client is responsible for maintaining their login credentials.

## 3. Financial Accuracy & Responsibility
*   The App provides automated tax calculations based on inputs.
*   The final responsibility for the accuracy of GSTR filings and financial statements lies entirely with the Client.
*   The Provider is not liable for any penalties or interest arising from incorrect data entry.

## 4. Limitations & Connectivity
*   The App requires an active internet connection for real-time syncing and cloud storage.
*   The Provider is not responsible for any delay caused by server maintenance or internet outages.

## 5. Validity & Acceptance
*   This agreement is digitally signed and valid under the terms of the Information Technology (IT) Act.
*   Acceptance of these terms is required to access full billing features.

Signed on: **{{date}}**''',
      'hi': '''# समझौता ज्ञापन (MOU)

यह समझौता ज्ञापन (**MOU**) **{{company_name}}** (प्रदाता) और **{{client_business_name}}** (ग्राहक) के बीच किया गया है।

## 1. सेवा का दायरा
प्रदाता एक क्लाउड-आधारित बिलिंग और लेजर प्रबंधन एप्लिकेशन प्रदान करता है। इसमें शामिल हैं:
* डिजिटल बिल और कोटेशन निर्माण।
* ग्राहक लेजर और स्टेटमेंट ट्रैकिंग।
* स्वचालित GSTR-1 और GSTR-3B रिपोर्ट जनरेशन।

## 2. डेटा स्वामित्व और गोपनीयता
* **स्वामित्व:** ग्राहक द्वारा दर्ज किया गया सभी डेटा ग्राहक की एकमात्र संपत्ति है।
* **गोपनीयता:** प्रदाता किसी भी तीसरे पक्ष को ग्राहक डेटा साझा या बेचेगा नहीं।
* **सुरक्षा:** डेटा क्लाउड सर्वर पर सुरक्षित रूप से संग्रहीत किया जाता है, लेकिन लॉगिन जानकारी की सुरक्षा की जिम्मेदारी ग्राहक की है।

## 3. वित्तीय सटीकता और जिम्मेदारी
* ऐप इनपुट के आधार पर स्वचालित टैक्स गणना प्रदान करता है।
* GSTR फाइलिंग और वित्तीय विवरणों की सटीकता की अंतिम जिम्मेदारी पूरी तरह से ग्राहक की है।
* गलत डेटा प्रविष्टि से उत्पन्न होने वाले किसी भी दंड या ब्याज के लिए प्रदाता उत्तरदायी नहीं है।

## 4. सीमाएं और कनेक्टिविटी
* ऐप को रीयल-टाइम सिंकिंग और क्लाउड स्टोरेज के लिए सक्रिय इंटरनेट कनेक्शन की आवश्यकता होती है।
* सर्वर रखरखाव या इंटरनेट आउटेज के कारण होने वाली किसी भी देरी के लिए प्रदाता जिम्मेदार नहीं है।

## 5. वैधता और स्वीकृति
* यह समझौता डिजिटल रूप से हस्ताक्षरित है और सूचना प्रौद्योगिकी (IT) अधिनियम के तहत मान्य है।
* बिलिंग सुविधाओं तक पहुंचने के लिए इन शर्तों को स्वीकार करना अनिवार्य है।

हस्ताक्षर की तिथि: **{{date}}**''',
      'mr': '''# सामंजस्य करार (MOU)

हा सामंजस्य करार (**MOU**) **{{company_name}}** (प्रदाता) आणि **{{client_business_name}}** (ग्राहक) यांच्यामध्ये करण्यात आला आहे.

## 1. सेवेची व्याप्ती
प्रदाता क्लाउड-आधारित बिलिंग आणि लेजर व्यवस्थापन प्लॅटफॉर्म प्रदान करतो. यामध्ये समाविष्ट आहे:
* डिजिटल बिल आणि कोटेशन तयार करणे.
* ग्राहक लेजर आणि स्टेटमेंट ट्रॅकिंग.
* स्वयंचलित GSTR-1 आणि GSTR-3B रिपोर्ट जनरेशन.

## 2. डेटा मालकी आणि गोपनीयता
* **मालकी:** ग्राहकाने प्रविष्ट केलेला सर्व डेटा ग्राहकाची एकमेव मालमत्ता आहे.
* **गोपनीयता:** प्रदाता कोणत्याही तृतीय पक्षाला ग्राहकाचा डेटा सामायिक करणार नाही किंवा विकणार नाही.

## 3. आर्थिक अचूकता आणि जबाबदारी
* ऍप इनपुटवर आधारित स्वयंचलित कर गणना प्रदान करते.
* GSTR फाइलिंग आणि आर्थिक विवरणांच्या अचूकतेची अंतिम जबाबदारी पूर्णपणे ग्राहकाची आहे.

## 4. मर्यादा आणि कनेक्टिव्हिटी
* ऍपला रिअल-टाइम सिंकिंगसाठी इंटरनेट कनेक्शन आवश्यक आहे.

## 5. वैधता आणि स्वीकृती
* हा करार डिजिटल पद्धतीने स्वाक्षरीत आहे आणि आयटी कायद्यांतर्गत वैध आहे.

स्वाक्षरीची तारीख: **{{date}}**''',
    };
    
    final response = await _supabase.from('mou_templates').insert({
        'version': 'v1.0', 
        'is_active': true, 
        'content': defaultContent
    }).select().single();
    
    return MouTemplateModel.fromMap(response);
  }

  Future<void> saveTemplate(MouTemplateModel template) async {
    // Note: Model maps 'id' but Supabase output uses 'id' (UUID).
    // Ensure Model toMap/fromMap handles UUIDs correctly or we map manually.
    // Assuming MouTemplateModel.toMap() produces snake_case keys or we provide map.
    
    final data = template.toMap(); 
    // Remove ID from insert payload if empty, let DB generate
    if (template.id.isEmpty) {
       data.remove('id');
       await _supabase.from('mou_templates').insert(data);
    } else {
       await _supabase.from('mou_templates').update(data).eq('id', template.id);
    }
  }

  Future<void> publishTemplate(String templateId) async {
    // 1. Deactivate all active templates
    // Supabase doesn't support multi-step transactions easily in SDK without RPC.
    // We will do two calls.
    
    await _supabase.from('mou_templates').update({'is_active': false}).eq('is_active', true);
    
    // 2. Activate the target
    await _supabase.from('mou_templates').update({
      'is_active': true, 
      'updated_at': DateTime.now().toIso8601String()
    }).eq('id', templateId);
  }

  // --- Client Acceptance ---

  Future<void> acceptMou({
    required String clientId,
    required String tenantId, 
    required String version,
    required String language,
    required String signatureData, // Base64
  }) async {
    // Update Client Doc with Metadata and Signature
    await _supabase.from('clients').update({
       'mou_accepted': true,
       'mou_meta': {
         'version': version,
         'language': language,
         'signedAt': DateTime.now().toIso8601String(),
         'signature': signatureData, // Store signature directly in JSONB
       }
    }).eq('client_id', clientId);
  }

  // Delete Client MOU
  Future<void> deleteClientMou(String clientId) async {
    await _supabase.from('clients').update({
      'mou_accepted': false,
      'mou_meta': null,
    }).eq('client_id', clientId);
  }
  
  Future<String?> getSignatureData(String clientId) async {
    final response = await _supabase
        .from('clients')
        .select('mou_meta')
        .eq('client_id', clientId)
        .maybeSingle();

    if (response != null && response['mou_meta'] != null) {
      return response['mou_meta']['signature'] as String?;
    }
    return null;
  }
  
  // Fetch template content by specific version (for viewing history)
  Future<MouTemplateModel?> getTemplateByVersion(String version) async {
    final response = await _supabase
        .from('mou_templates')
        .select()
        .eq('version', version)
        .limit(1)
        .maybeSingle();

    if (response != null) {
      return MouTemplateModel.fromMap(response);
    }
    return null;
  }
}
