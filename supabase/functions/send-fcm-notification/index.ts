import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

async function getGoogleAccessToken(serviceAccount: Record<string, string>): Promise<string> {
  const now = Math.floor(Date.now() / 1000)

  const header = btoa(JSON.stringify({ alg: 'RS256', typ: 'JWT' }))
    .replace(/=/g, '').replace(/\+/g, '-').replace(/\

  const payload = btoa(JSON.stringify({
    iss: serviceAccount.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  })).replace(/=/g, '').replace(/\+/g, '-').replace(/\

  const signingInput = `${header}.${payload}`

  const privateKeyPem = serviceAccount.private_key
    .replace(/\\n/g, '\n')
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '')

  const privateKeyBytes = Uint8Array.from(atob(privateKeyPem), (c) => c.charCodeAt(0))

  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8', privateKeyBytes,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false, ['sign'],
  )

  const signatureBuffer = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5', cryptoKey, new TextEncoder().encode(signingInput),
  )

  const signature = btoa(String.fromCharCode(...new Uint8Array(signatureBuffer)))
    .replace(/=/g, '').replace(/\+/g, '-').replace(/\

  const jwt = `${signingInput}.${signature}`

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
          token: fcmToken,
          notification: { title, body },
          data: data ?? {},
          android: {
            priority: 'high',
            notification: {
              channel_id: 'godah_orders',
              default_sound: true,
              default_vibrate_timings: true,
            },
          },
          apns: {
            headers: { 'apns-priority': '10' },
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
    const errCode = result?.error?.details?.[0]?.errorCode ?? result?.error?.message ?? 'UNKNOWN'
    return { success: false, error: errCode }
  }
  return { success: true, messageId: result.name }
}

serve(async (req: Request) => {
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
    const body = await req.json()
    const {
      target_admin_id,
      porter_nama,
      porter_id,
      target_user_id,
      target_porter_id,
      title,
      body: notifBody,
      data,
      type,
    } = body

    if (!title || !notifBody) {
      return new Response(
        JSON.stringify({ error: '`title` dan `body` wajib diisi' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const serviceAccountJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')
    if (!serviceAccountJson) {
      throw new Error('Environment variable FIREBASE_SERVICE_ACCOUNT tidak ditemukan')
    }
    const serviceAccount = JSON.parse(serviceAccountJson)
    const projectId: string = serviceAccount.project_id

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    let targetToken: string | null = null
    let targetTable: string | null = null
    let targetId: string | null = null

    if (target_user_id) {
      const { data: user } = await supabase
        .from('users')
        .select('fcm_token')
        .eq('id', target_user_id)
        .maybeSingle()
      targetToken = user?.fcm_token ?? null
      targetTable = 'users'
      targetId = target_user_id

    } else if (target_porter_id) {
      const { data: porter } = await supabase
        .from('porters')
        .select('fcm_token')
        .eq('id', target_porter_id)
        .maybeSingle()
      targetToken = porter?.fcm_token ?? null
      targetTable = 'porters'
      targetId = target_porter_id

    } else if (target_admin_id) {
      const { data: admin } = await supabase
        .from('admins')
        .select('fcm_token')
        .eq('id', target_admin_id)
        .maybeSingle()
      targetToken = admin?.fcm_token ?? null
      targetTable = 'admins'
      targetId = target_admin_id

    } else {
      const { data: admins } = await supabase
        .from('admins')
        .select('id, fcm_token')
        .not('fcm_token', 'is', null)

      if (!admins || admins.length === 0) {
        return new Response(
          JSON.stringify({ success: false, message: 'Tidak ada target dengan FCM token aktif' }),
          { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
        )
      }

      const accessToken = await getGoogleAccessToken(serviceAccount)
      const results = await Promise.all(
        admins.map(async (admin) => {
          const result = await sendToDevice({
            accessToken, projectId,
            fcmToken: admin.fcm_token,
            title, body: notifBody,
            data: { type: type ?? 'sistem', porter_id: porter_id ?? '', porter_nama: porter_nama ?? '', ...(data ?? {}) },
          })
          if (!result.success && result.error === 'UNREGISTERED') {
            await supabase.from('admins').update({ fcm_token: null }).eq('id', admin.id)
          }
          return { admin_id: admin.id, ...result }
        }),
      )

      const successCount = results.filter((r) => r.success).length
      return new Response(
        JSON.stringify({ success: true, sent_to: successCount, results }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    if (!targetToken) {
      return new Response(
        JSON.stringify({ success: false, message: 'Target tidak memiliki FCM token' }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const accessToken = await getGoogleAccessToken(serviceAccount)
    const result = await sendToDevice({
      accessToken, projectId,
      fcmToken: targetToken,
      title, body: notifBody,
      data: { type: type ?? 'sistem', ...(data ?? {}) },
    })

    if (!result.success && result.error === 'UNREGISTERED' && targetTable && targetId) {
      await supabase.from(targetTable).update({ fcm_token: null }).eq('id', targetId)
    }

    return new Response(
      JSON.stringify({ success: result.success, ...result }),
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
