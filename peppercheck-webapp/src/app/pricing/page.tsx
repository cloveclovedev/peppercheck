import { createClient } from '@/lib/supabase/server'
import SubscribeButton from '@/components/SubscribeButton'

export default async function PricingPage() {
  const supabase = await createClient()

  // Fetch plans with prices (Stripe & JPY only for this demo)
  const { data: plans } = await supabase
    .from('subscription_plans')
    .select('*, prices:subscription_plan_prices(*)')
    .eq('is_active', true)
    .order('monthly_points') // Sort by points roughly maps to tiers

  return (
    <div className='min-h-screen bg-gray-50 py-12 px-4 sm:px-6 lg:px-8'>
      <div className='max-w-7xl mx-auto'>
        <div className='text-center'>
          <h2 className='text-3xl font-extrabold text-gray-900 sm:text-4xl'>
            Pricing Plans
          </h2>
          <p className='mt-4 text-xl text-gray-600'>
            Choose the plan that fits your needs.
          </p>
        </div>

        <div className='mt-12 space-y-4 sm:mt-16 sm:space-y-0 sm:grid sm:grid-cols-2 sm:gap-6 lg:max-w-4xl lg:mx-auto xl:max-w-none xl:mx-0 xl:grid-cols-3'>
          {plans?.map((plan) => {
            // Find the Stripe price (assuming JPY or USD default, preferably JPY)
            const price = plan.prices.find((
              p: { provider: string; currency_code: string; amount_minor: number },
            ) => p.provider === 'stripe' && p.currency_code === 'JPY')

            if (!price) return null // Skip plans without Stripe price

            return (
              <div
                key={plan.id}
                className='border border-gray-200 rounded-lg shadow-sm divide-y divide-gray-200 bg-white flex flex-col'
              >
                <div className='p-6 flex-1'>
                  <h3 className='text-lg leading-6 font-medium text-gray-900'>{plan.name}</h3>
                  <p className='mt-4 text-sm text-gray-500'>
                    Includes {plan.monthly_points} points / month
                  </p>
                  <p className='mt-8'>
                    <span className='text-4xl font-extrabold text-gray-900'>
                      ¥{price.amount_minor}
                    </span>
                    <span className='text-base font-medium text-gray-500'>/mo</span>
                  </p>
                  {/* Features listing could go here if features column was JSON array */}
                </div>
                <div className='p-6'>
                  <SubscribeButton planId={plan.id} currency='JPY' />
                </div>
              </div>
            )
          })}
        </div>
      </div>
    </div>
  )
}
