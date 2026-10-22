-- CREATE MOU_TEMPLATES TABLE
-- This table stores MOU template versions for client acceptance

-- 1. Create the table
CREATE TABLE IF NOT EXISTS public.mou_templates (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    version text NOT NULL,
    is_active boolean DEFAULT false,
    updated_at timestamptz DEFAULT now(),
    content jsonb DEFAULT '{}'::jsonb
);

-- 2. Enable RLS
ALTER TABLE public.mou_templates ENABLE ROW LEVEL SECURITY;

-- 3. RLS Policies
-- Allow Superadmin to manage templates
CREATE POLICY "Superadmin can manage mou_templates"
ON public.mou_templates
FOR ALL
USING ( is_superadmin() )
WITH CHECK ( is_superadmin() );

-- Allow all authenticated users to read active templates (for signing)
CREATE POLICY "Authenticated users can read active templates"
ON public.mou_templates
FOR SELECT
USING ( auth.role() = 'authenticated' );


-- 4. Insert a default template (optional)
INSERT INTO public.mou_templates (version, is_active, content) VALUES (
    '1.0',
    true,
    '{
        "en": "This Memorandum of Understanding (MOU) is entered into by and between the Service Provider and the Client.\n\n1. SCOPE OF SERVICES\nThe Service Provider agrees to provide DigiInvi software subscription services including invoicing, expense tracking, and business management tools.\n\n2. TERM\nThis agreement is valid for the duration of the active subscription plan.\n\n3. PAYMENT\nThe Client agrees to pay the subscription fees as per the selected plan.\n\n4. DATA PRIVACY\nThe Service Provider will maintain confidentiality of all business data.\n\n5. TERMINATION\nEither party may terminate this agreement with 30 days written notice.\n\nBy signing below, both parties agree to the terms outlined above.",
        "hi": "यह समझौता ज्ञापन (MOU) सेवा प्रदाता और ग्राहक के बीच किया गया है।\n\n1. सेवाओं का दायरा\nसेवा प्रदाता डिजीबिल्स सॉफ्टवेयर सदस्यता सेवाएं प्रदान करने के लिए सहमत है।\n\n2. अवधि\nयह समझौता सक्रिय सदस्यता योजना की अवधि के लिए वैध है।\n\n3. भुगतान\nग्राहक चयनित योजना के अनुसार सदस्यता शुल्क का भुगतान करने के लिए सहमत है।\n\n4. डेटा गोपनीयता\nसेवा प्रदाता सभी व्यावसायिक डेटा की गोपनीयता बनाए रखेगा।\n\n5. समाप्ति\nकोई भी पक्ष 30 दिनों की लिखित सूचना के साथ इस समझौते को समाप्त कर सकता है।"
    }'::jsonb
);

-- Verify
SELECT * FROM public.mou_templates;
