// supabase/functions/send-fcm-notification/index.ts
// Edge Function: Proxy aman untuk kirim FCM push notification
// Perangkat A (Porter) → Edge Function → FCM → Perangkat B (Admin)
// Perangkat C (User/Porter lain) tidak menerima karena tokennya tidak dikirim

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// ── CORS Headers ───────────────────────────────────────────────────
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

// ── Helper: Generate Google OAuth2 Access Token ────────────────────
// FCM HTTP v1 API butuh OAuth2 token, bukan legacy server key
async function getGoogleAccessToken(
  serviceAccount: Record<string, string>,
): Promise<string> {
  const now = Math.floor(Date.now() / 1000)

  // Build JWT header & payload
  const header = btoa(JSON.stringify({ alg: 'RS256', typ: 'JWT' }))
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')

  const payload = btoa(
    JSON.stringify({
      iss: serviceAccount.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
    }),
  )
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')

  const signingInput = `${header}.${payload}`

  // Parse private key PEM → import sebagai CryptoKey
  const privateKeyPem = serviceAccount.private_key
    .replace(/\\n/g, '\n')
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '')

  const privateKeyBytes = Uint8Array.from(
    atob(privateKeyPem),
    (c) => c.charCodeAt(0),
  )

  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    privateKeyBytes,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  )

  // Sign JWT
  const signatureBuffer = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    cryptoKey,
    new TextEncoder().encode(signingInput),
  )

  const signature = btoa(
    String.fromCharCode(...new Uint8Array(signatureBuffer)),
  )
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')

  const jwt = `${signingInput}.${signature}`

  // Tukar JWT dengan access token Google
  const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  })

  if (!tokenResponse.ok) {
    const err = await tokenResponse.text()
    throw new Error(`Gagal ambil Google token: ${err}`)
  }

  const tokenData = await tokenResponse.json()
  return tokenData.access_token as string
}

// ── Helper: Kirim 1 FCM Message ke 1 Token (1 device) ─────────────
async function sendToDevice(params: {
  accessToken: string
  projectId: string
  fcmToken: string
  title: string
  body: string
  data?: Record<string, string>
}): Promise<{ success: boolean; messageId?: string; error?: string }> {
  const { accessToken, projectId, fcmToken, title, body, data } = params

  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify({
        message: {
          // ← token unik per device = hanya device ini yang terima
          token: fcmToken,
          notification: {
            title,
            body,
          },
          data: data ?? {},
          android: {
            priority: 'high',
            notification: {
              channel_id: 'godah_verifikasi',
              default_sound: true,
              default_vibrate_timings: true,
              icon: 'ic_notification',
            },
          },
          apns: {
            headers: {
              'apns-priority': '10',
            },
            payload: {
              aps: {
                alert: { title, body },
                sound: 'default',
                badge: 1,
                'content-available': 1,
              },
            },
          },
        },
      }),
    },
  )

  const result = await response.json()

  if (!response.ok) {
    // Token expired / tidak valid → kembalikan error tapi jangan crash
    const errCode = result?.error?.details?.[0]?.errorCode ?? result?.error?.message ?? 'UNKNOWN'
    return { success: false, error: errCode }
  }

  return { success: true, messageId: result.name }
}

// ── Main Handler ───────────────────────────────────────────────────
serve(async (req: Request) => {
  // Handle preflight CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (req.method !== 'POST') {
    return new Response(
      JSON.stringify({ error: 'Method not allowed' }),
      { status: 405, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  }

  try {
    // ── 1. Parse request body ──────────────────────────────────────
    const {
      target_admin_id, // ← ID admin spesifik (Perangkat B)
      porter_nama,
      porter_id,
      title,
      body,
      data,
    } = await req.json()

    // Validasi minimal
    if (!title || !body) {
      return new Response(
        JSON.stringify({ error: '`title` dan `body` wajib diisi' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    // ── 2. Ambil service account dari env ──────────────────────────
    const serviceAccountJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')
    if (!serviceAccountJson) {
      throw new Error('Environment variable FIREBASE_SERVICE_ACCOUNT tidak ditemukan')
    }
    const serviceAccount = JSON.parse(serviceAccountJson)
    const projectId: string = serviceAccount.project_id

    // ── 3. Ambil FCM token dari Supabase ───────────────────────────
    // Pakai service role key agar bisa query tanpa RLS
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    let targetTokens: { id: string; fcm_token: string }[] = []

    if (target_admin_id) {
      // Mode: kirim ke 1 admin spesifik → Perangkat B saja ✅
      // Perangkat C (admin lain, user, porter) tidak dapat notif ❌
      const { data: admin, error } = await supabase
        .from('admins')
        .select('id, fcm_token')
        .eq('id', target_admin_id)
        .not('fcm_token', 'is', null)
        .maybeSingle()

      if (error) throw new Error(`Query admin gagal: ${error.message}`)
      if (admin) targetTokens = [admin]
    } else {
      // Mode fallback: kirim ke semua admin (kalau target_admin_id tidak diberikan)
      const { data: admins, error } = await supabase
        .from('admins')
        .select('id, fcm_token')
        .not('fcm_token', 'is', null)

      if (error) throw new Error(`Query admins gagal: ${error.message}`)
      targetTokens = admins ?? []
    }

    if (targetTokens.length === 0) {
      return new Response(
        JSON.stringify({ success: false, message: 'Tidak ada admin dengan FCM token aktif' }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    // ── 4. Ambil Google OAuth2 access token (1x untuk semua) ───────
    const accessToken = await getGoogleAccessToken(serviceAccount)

    // ── 5. Kirim FCM ke masing-masing target ──────────────────────
    const results = await Promise.all(
      targetTokens.map(async (admin) => {
        const result = await sendToDevice({
          accessToken,
          projectId,
          fcmToken: admin.fcm_token,
          title,
          body,
          data: {
            type: 'verifikasi_porter',
            porter_id: porter_id ?? '',
            porter_nama: porter_nama ?? '',
            ...(data ?? {}),
          },
        })

        // Kalau token invalid, bersihkan dari DB
        if (!result.success && result.error === 'UNREGISTERED') {
          await supabase
            .from('admins')
            .update({ fcm_token: null })
            .eq('id', admin.id)
          console.log(`Token admin ${admin.id} dihapus (UNREGISTERED)`)
        }

        return { admin_id: admin.id, ...result }
      }),
    )

    const successCount = results.filter((r) => r.success).length
    const failCount = results.length - successCount

    console.log(`FCM sent: ${successCount} success, ${failCount} failed`)

    return new Response(
      JSON.stringify({
        success: true,
        sent_to: successCount,
        failed: failCount,
        results,
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  } catch (err) {
    console.error('Edge Function error:', err)
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  }
})