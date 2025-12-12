import Stripe from 'npm:stripe@^20.0.0'
import { parse } from 'jsr:@std/csv'
import { join } from 'jsr:@std/path'
import { load } from 'jsr:@std/dotenv'

// Load environment variables
// load() automatically reads .env file.
// To specify paths we can use simple logic or just rely on default behavior which looks for .env in cwd.
// The user has stripe/.env and .env.
// @std/dotenv's load() supports 'envPath' option only for one file or we call it multiple times?
// Actually load() returns a promise with env vars, it doesn't automatically set Deno.env unless export: true is set.
// It defaults to .env.

// Modern approach:
// Try loading stripe/.env
try {
  await load({ envPath: join(Deno.cwd(), 'stripe', '.env'), export: true })
} catch {
  // ignore
}

// Try loading root .env
try {
  await load({ envPath: join(Deno.cwd(), '.env'), export: true })
} catch {
  // ignore
}

const STRIPE_SECRET_KEY = Deno.env.get('STRIPE_SECRET_KEY')
if (!STRIPE_SECRET_KEY) {
  console.error('Error: STRIPE_SECRET_KEY is not set.')
  console.error('Please set it in .env or stripe/.env')
  Deno.exit(1)
}

const stripe = new Stripe(STRIPE_SECRET_KEY, {
  apiVersion: '2024-11-20.acacia',
})

async function readCsv(filename: string) {
  const path = join(Deno.cwd(), 'supabase', 'data', filename)
  try {
    const content = await Deno.readTextFile(path)
    return parse(content, { skipFirstRow: true })
  } catch (e) {
    console.error(`Error reading CSV at ${path}:`, e)
    throw e
  }
}

async function sync() {
  console.log('Starting Stripe Sync...')

  // Map to store app_plan_id -> stripe_product_id to avoid search latency
  const planIdToProductId = new Map<string, string>()

  // 1. Sync Products (Plans)
  const plans = await readCsv('subscription_plans.csv')
  console.log(`Found ${plans.length} plans.`)

  for (const plan of plans) {
    const { id, name } = plan
    const metadata = { app_plan_id: id }

    console.log(`Syncing Product: ${name} (${id})`)

    const search = await stripe.products.search({
      query: `metadata['app_plan_id']:'${id}'`,
    })

    let product
    if (search.data.length > 0) {
      product = search.data[0]
      if (product.name !== name) {
        product = await stripe.products.update(product.id, { name })
        console.log(`  Updated Product: ${product.id}`)
      } else {
        console.log(`  Product exists: ${product.id}`)
      }
    } else {
      product = await stripe.products.create({
        name,
        metadata,
      })
      console.log(`  Created Product: ${product.id}`)
    }
    // Store in map
    planIdToProductId.set(id, product.id)
  }

  // 2. Sync Prices (Only provider = 'stripe')
  const prices = await readCsv('subscription_plan_prices.csv')
  const stripePrices = prices.filter((p: any) => p.provider === 'stripe')
  console.log(`Found ${stripePrices.length} stripe prices.`)

  for (const priceRow of stripePrices) {
    const { plan_id, currency_code, amount_minor } = priceRow
    const lookupKey = `${plan_id}_${currency_code}_${'stripe'}`

    console.log(`Syncing Price: ${lookupKey} (${amount_minor} ${currency_code})`)

    // Use cached ID instead of search
    const productId = planIdToProductId.get(plan_id)

    if (!productId) {
      console.error(`  Error: Product for plan_id='${plan_id}' not found in map. Skipping.`)
      continue
    }

    const priceList = await stripe.prices.list({
      lookup_keys: [lookupKey],
      active: true,
      limit: 1,
    })

    if (priceList.data.length > 0) {
      const existingPrice = priceList.data[0]
      if (
        existingPrice.unit_amount === Number(amount_minor) &&
        existingPrice.currency.toUpperCase() === currency_code
      ) {
        console.log(`  Price exists and matches: ${existingPrice.id}`)
        continue
      } else {
        console.warn(`  Price exists but mismatch. Archiving old.`)
        await stripe.prices.update(existingPrice.id, { active: false, lookup_key: null })
      }
    }

    const newPrice = await stripe.prices.create({
      unit_amount: Number(amount_minor),
      currency: currency_code,
      product: productId,
      recurring: { interval: 'month' },
      lookup_key: lookupKey,
      metadata: { app_plan_id: plan_id },
      transfer_lookup_key: true,
    })
    console.log(`  Created Price: ${newPrice.id}`)
  }

  console.log('Sync Complete.')
}

sync().catch(console.error)
