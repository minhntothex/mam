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

const PRIMARY_MODEL = (Deno.env.get("GEMINI_MODEL") ?? "gemini-3.8-flash").trim();
const FALLBACK_MODELS = Array.from(
  new Set([PRIMARY_MODEL, "gemini-3.6-flash", "gemini-3.5-flash-lite"]),
);

const EXTRACTION_PROMPT = `Bạn là bộ trích xuất hóa đơn ăn uống (hóa đơn giấy nhiệt Việt Nam, GrabFood, ShopeeFood, nhà hàng VN hoặc quốc tế).
Hãy đọc ảnh hóa đơn và trả về DUY NHẤT một JSON object hợp lệ theo đúng schema sau:
{
  "title": "Tên quán hoặc nhà hàng (string hoặc null)",
  "billDate": "YYYY-MM-DD (string hoặc null)",
  "currencyCode": "VND" | "USD",
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
- Xác định currencyCode là "USD" nếu hóa đơn ghi giá bằng $ / USD; ngược lại dùng "VND".
- Mọi số tiền PHẢI là số nguyên theo đơn vị nhỏ nhất (minor unit, không dấu phẩy/chấm):
  + Nếu VND: số nguyên đồng (vd: 120.000đ -> 120000).
  + Nếu USD: số nguyên cents (vd: $12.50 -> 1250).
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

function extractGeminiErrorMessage(rawText: string): string {
  try {
    const parsed = JSON.parse(rawText);
    const msg = parsed?.error?.message;
    if (typeof msg === "string" && msg.trim().length > 0) {
      return msg.trim();
    }
  } catch {
    // Fall back to raw text snippet
  }
  const trimmed = rawText.trim();
  return trimmed.length > 220 ? `${trimmed.slice(0, 220)}...` : trimmed;
}

function shouldFallbackModel(status: number, errMessage: string): boolean {
  if (
    status === 404 ||
    status === 429 ||
    status === 500 ||
    status === 502 ||
    status === 503 ||
    status === 504
  ) {
    return true;
  }
  const lower = errMessage.toLowerCase();
  return (
    lower.includes("no longer available") ||
    lower.includes("not found") ||
    lower.includes("deprecated") ||
    lower.includes("high demand") ||
    lower.includes("overloaded") ||
    lower.includes("temporarily") ||
    lower.includes("unavailable") ||
    lower.includes("rate limit")
  );
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

  // 3. Call Gemini Flash structured JSON output (with automatic fallback on 404/deprecated)
  let lastErrorMessage = "Upstream OCR provider failed";
  let lastStatus = 502;

  for (let i = 0; i < FALLBACK_MODELS.length; i++) {
    const model = FALLBACK_MODELS[i];
    try {
      const geminiRes = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent`,
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
        const rawErr = await geminiRes.text();
        lastErrorMessage = extractGeminiErrorMessage(rawErr);
        lastStatus = geminiRes.status;
        if (i + 1 < FALLBACK_MODELS.length && shouldFallbackModel(geminiRes.status, lastErrorMessage)) {
          continue;
        }
        return jsonResponse(
          { error: lastErrorMessage, model, upstreamStatus: lastStatus },
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
        { error: `Failed to parse OCR response: ${String(err)}`, model },
        502,
      );
    }
  }

  return jsonResponse({ error: lastErrorMessage, upstreamStatus: lastStatus }, 502);
});
