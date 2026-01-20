// Setup type definitions for built-in Supabase Runtime APIs
import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { createClient } from 'jsr:@supabase/supabase-js@2'
import { PutObjectCommand, S3Client } from 'npm:@aws-sdk/client-s3@3'
import { getSignedUrl } from 'npm:@aws-sdk/s3-request-presigner@3'

interface UploadRequest {
  task_id: string
  filename: string
  content_type: string
  file_size_bytes: number
  kind: string // "evidence" for now, expandable later
}

interface UploadResponse {
  upload_url: string
  r2_key: string
  expires_in: number
  public_url: string
}

const ALLOWED_CONTENT_TYPES = [
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/gif',
  'image/heic',
  'image/heif',
]

const MAX_FILE_SIZE = 5 * 1024 * 1024 // 5MB
const URL_EXPIRES_IN = 600 // 10 minutes

// Validate file extension matches content type
function validateContentType(filename: string, contentType: string): boolean {
  const ext = filename.toLowerCase().split('.').pop()
  const typeMap: Record<string, string[]> = {
    'image/jpeg': ['jpg', 'jpeg'],
    'image/png': ['png'],
    'image/webp': ['webp'],
    'image/gif': ['gif'],
    'image/heic': ['heic'],
    'image/heif': ['heif'],
  }

  const allowedExts = typeMap[contentType]
  return allowedExts ? allowedExts.includes(ext || '') : false
}

// Generate R2 key based on kind and due_date
function generateR2Key(kind: string, filename: string, dueDateString: string): string {
  // due_dateをパースして日付ベースのパスを生成
  const date = new Date(dueDateString)
  const year = date.getUTCFullYear()
  const month = String(date.getUTCMonth() + 1).padStart(2, '0')
  const day = String(date.getUTCDate()).padStart(2, '0')
  const uuid = crypto.randomUUID()

  const ext = filename.toLowerCase().split('.').pop()
  const cleanFilename = `${uuid}.${ext}`

  switch (kind) {
    case 'evidence':
      return `${kind}/${year}/${month}/${day}/${cleanFilename}`
    default:
      throw new Error(`Unsupported kind: ${kind}`)
  }
}

Deno.serve(async (req: Request) => {
  // CORS headers
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
  }

  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Get JWT token from Authorization header
    const authHeader = req.headers.get('Authorization')

    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Missing authorization header' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    // Verify user is authenticated with Supabase
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: authHeader },
        },
      },
    )

    const { data: { user }, error: authError } = await supabaseClient.auth.getUser()

    if (authError || !user) {
      console.error('Authentication failed:', authError?.message || 'No user found')
      return new Response(
        JSON.stringify({
          error: 'Unauthorized: Invalid or expired token',
          debug: authError?.message || 'No user found',
        }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    // Parse request body with proper error handling
    let body: UploadRequest
    try {
      body = await req.json()
    } catch (parseError) {
      console.error('JSON parse error:', parseError)
      return new Response(
        JSON.stringify({ error: 'Invalid JSON format in request body' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const { task_id, filename, content_type, file_size_bytes, kind } = body

    // Validation
    if (!task_id || !filename || !content_type || !file_size_bytes || !kind) {
      const missingFields = []
      if (!task_id) missingFields.push('task_id')
      if (!filename) missingFields.push('filename')
      if (!content_type) missingFields.push('content_type')
      if (!file_size_bytes) missingFields.push('file_size_bytes')
      if (!kind) missingFields.push('kind')

      return new Response(
        JSON.stringify({
          error: `Missing required fields: ${missingFields.join(', ')}`,
          received_fields: Object.keys(body),
          missing_fields: missingFields,
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    // Validate content type
    if (!ALLOWED_CONTENT_TYPES.includes(content_type)) {
      return new Response(
        JSON.stringify({ error: `Content type ${content_type} not allowed` }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    // Validate file extension matches content type
    if (!validateContentType(filename, content_type)) {
      return new Response(
        JSON.stringify({ error: `File extension does not match content type ${content_type}` }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    // Validate file size
    if (file_size_bytes > MAX_FILE_SIZE) {
      return new Response(
        JSON.stringify({
          error: `File size ${file_size_bytes} bytes exceeds maximum ${MAX_FILE_SIZE} bytes`,
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    // Verify user owns the task
    const { data: task, error: taskError } = await supabaseClient
      .from('tasks')
      .select('id, tasker_id, due_date')
      .eq('id', task_id)
      .eq('tasker_id', user.id)
      .single()

    if (taskError || !task) {
      console.error('Task verification error:', taskError)
      return new Response(
        JSON.stringify({
          error: 'Task not found or you do not have permission to upload evidence for this task',
        }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    // due_dateが存在するかチェック
    if (!task.due_date) {
      return new Response(
        JSON.stringify({
          error:
            `Task with id ${task_id} does not have a due_date, which is required for file uploads.`,
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    // Check R2 environment variables
    const cloudflareAccountId = Deno.env.get('CLOUDFLARE_ACCOUNT_ID')
    const r2AccessKeyId = Deno.env.get('R2_ACCESS_KEY_ID')
    const r2SecretAccessKey = Deno.env.get('R2_SECRET_ACCESS_KEY')
    const r2BucketName = Deno.env.get('R2_BUCKET_NAME')

    if (!cloudflareAccountId || !r2AccessKeyId || !r2SecretAccessKey || !r2BucketName) {
      console.error('Missing R2 configuration:', {
        hasAccountId: !!cloudflareAccountId,
        hasAccessKeyId: !!r2AccessKeyId,
        hasSecretAccessKey: !!r2SecretAccessKey,
        hasBucketName: !!r2BucketName,
      })
      return new Response(
        JSON.stringify({
          error: 'Server configuration error: R2 credentials not properly configured',
        }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    // Generate R2 key
    const r2Key = generateR2Key(kind, filename, task.due_date)

    // Initialize S3 client for R2
    const s3Client = new S3Client({
      region: 'auto',
      endpoint: `https://${cloudflareAccountId}.r2.cloudflarestorage.com`,
      credentials: {
        accessKeyId: r2AccessKeyId,
        secretAccessKey: r2SecretAccessKey,
      },
    })

    // Create PutObject command with size constraint
    const putObjectCommand = new PutObjectCommand({
      Bucket: r2BucketName,
      Key: r2Key,
      ContentType: content_type,
      ContentLength: file_size_bytes, // Enforce exact file size
    })

    // Generate presigned URL
    let uploadUrl: string
    try {
      uploadUrl = await getSignedUrl(s3Client, putObjectCommand, {
        expiresIn: URL_EXPIRES_IN,
      })
    } catch (r2Error) {
      console.error('Failed to generate presigned URL:', r2Error)
      return new Response(
        JSON.stringify({ error: 'Failed to generate upload URL. Please check R2 configuration.' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    // Generate Public URL
    const publicDomain = Deno.env.get('R2_PUBLIC_DOMAIN')

    if (!publicDomain) {
      console.error('Missing R2_PUBLIC_DOMAIN environment variable')
      return new Response(
        JSON.stringify({ error: 'Server configuration error: R2 public domain not configured' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const publicUrl = `https://${publicDomain}/${r2Key}`

    const response: UploadResponse = {
      upload_url: uploadUrl,
      r2_key: r2Key,
      expires_in: URL_EXPIRES_IN,
      public_url: publicUrl,
    }

    return new Response(
      JSON.stringify(response),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      },
    )
  } catch (error) {
    console.error('Unexpected error in generate-upload-url:', error)

    // Check if error has specific message for better debugging
    const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred'

    return new Response(
      JSON.stringify({
        error: 'Internal server error',
        debug: `Unexpected error: ${errorMessage}`,
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      },
    )
  }
})

/* To invoke locally:

  1. Run `supabase start` (see: https://supabase.com/docs/reference/cli/supabase-start)
  2. Make an HTTP request:

  curl -i --location --request POST 'http://127.0.0.1:54321/functions/v1/generate-upload-url' \
    --header 'Authorization: Bearer [JWT_TOKEN]' \
    --header 'Content-Type: application/json' \
    --data '{
      "task_id": "123e4567-e89b-12d3-a456-426614174000",
      "filename": "evidence.jpg",
      "content_type": "image/jpeg",
      "file_size_bytes": 1024000,
      "kind": "evidence"
    }'

*/
