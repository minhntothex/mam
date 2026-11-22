// Mâm (mam) — Supabase Edge Function: POST /functions/v1/scan-bill
// Verifies Supabase JWT, keeps GEMINI_API_KEY server-side, and returns
// structured JSON matching `OcrScanResult` in `app/lib/models/bill_models.dart`.

import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const MAX_BASE64_CHARS = 3_000_000; // ~2.2 MB binary image limit

const EXTRACTION_PROMPT = `Bạn là bộ trích xuất hóa đơn ăn uống Việt Nam (giấy nhiệt, GrabFood, ShopeeFood, nhà hàng).
Hãy đọc ảnh hóa đơn và trả về DUY NHẤT một JSON object hợp lệ theo đúng schema sau (tất cả số tiền là số nguyên VNĐ, không dấu phẩy/chấm):
{
  "title": "Tên quán hoặc nhà hàng (string hoặc null)",
  "billDate": "YYYY-MM-DD (string hoặc null)",
  "items": [
    {
      "name": "Tên món",
      "quantity": 1,
      "lineTotal": 120000,
      "itemDiscount": 0
    }
  ],
  "taxAmount": 0,
  "serviceChargeAmount": 0,
  "shippingAmount": 0,
  "billDiscountAmount": 0,
  "ocrGrandTotal": 0,
  "confidence": "high" | "medium" | "low"
}
Quy tắc:
- lineTotal là thành tiền của cả dòng (đã nhân số lượng), trước giảm giá riêng của dòng.
- Nếu giảm giá gắn riêng cho 1 món thì đưa vào itemDiscount của món đó; giảm giá/voucher toàn hóa đơn đưa vào billDiscountAmount (số dương).
- ocrGrandTotal là tổng tiền cuối cùng in trên hóa đơn để app tự đối chiếu.
- Không thêm markdown hay giải thích ngoài JSON.`;

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  // 1. Verify authenticated user JWT
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return jsonResponse({ error: "Missing Authorization header" }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const geminiApiKey = Deno.env.get("GEMINI_API_KEY");

  if (!supabaseUrl || !supabaseAnonKey || !geminiApiKey) {
    return jsonResponse({ error: "Server configuration incomplete" }, 500);
  }

  const supabase = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const {
    data: { user },
    error: authError,
  } = await supabase.auth.getUser();

  if (authError || !user) {
    return jsonResponse({ error: "Unauthorized" }, 401);
  }

  // 2. Parse & validate payload
  let payload: { imageBase64?: string; mimeType?: string };
  try {
    payload = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }

  const imageBase64 = (payload.imageBase64 ?? "").trim();
  const mimeType = (payload.mimeType ?? "image/jpeg").trim();

  if (!imageBase64) {
    return jsonResponse({ error: "imageBase64 is required" }, 400);
  }
  if (imageBase64.length > MAX_BASE64_CHARS) {
    return jsonResponse({ error: "Image payload too large (max ~2MB)" }, 400);
  }

  // 3. Call Gemini 2.5 Flash structured JSON output
  try {
    const geminiRes = await fetch(
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-goog-api-key": geminiApiKey,
        },
        body: JSON.stringify({
          contents: [
            {
              parts: [
                { text: EXTRACTION_PROMPT },
                { inline_data: { mime_type: mimeType, data: imageBase64 } },
              ],
            },
          ],
          generationConfig: {
            responseMimeType: "application/json",
            temperature: 0.1,
          },
        }),
      },
    );

    if (!geminiRes.ok) {
      const detail = await geminiRes.text();
      return jsonResponse(
        { error: "Upstream OCR provider failed", detail },
        502,
      );
    }

    const geminiJson = await geminiRes.json();
    const rawText: string =
      geminiJson?.candidates?.[0]?.content?.parts?.[0]?.text ?? "{}";

    const parsed = JSON.parse(rawText);
    return jsonResponse(parsed, 200);
  } catch (err) {
    return jsonResponse(
      { error: "Failed to parse OCR response", detail: String(err) },
      502,
    );
  }
});
