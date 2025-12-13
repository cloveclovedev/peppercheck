import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import Link from 'next/link'

export default async function DashboardPage() {
  const supabase = await createClient()

  const { data: { user } } = await supabase.auth.getUser()

  if (!user) {
    // Basic protection
    redirect('/pricing') // Ideally login page
  }

  // Fetch subscription
  const { data: subscription } = await supabase
    .from('user_subscriptions')
    .select('*, plan:subscription_plans(*)')
    .eq('user_id', user.id)
    .single()

  return (
    <div className='min-h-screen bg-gray-50 py-12 px-4 sm:px-6 lg:px-8'>
      <div className='max-w-3xl mx-auto'>
        <h1 className='text-3xl font-bold text-gray-900 mb-8'>Dashboard</h1>

        <div className='bg-white shadow overflow-hidden sm:rounded-lg'>
          <div className='px-4 py-5 sm:px-6'>
            <h3 className='text-lg leading-6 font-medium text-gray-900'>User Profile</h3>
            <p className='mt-1 max-w-2xl text-sm text-gray-500'>{user.email}</p>
          </div>
          <div className='border-t border-gray-200 px-4 py-5 sm:p-0'>
            <dl className='sm:divide-y sm:divide-gray-200'>
              <div className='py-4 sm:py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6'>
                <dt className='text-sm font-medium text-gray-500'>Subscription Status</dt>
                <dd className='mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2'>
                  {subscription
                    ? (
                      <span
                        className={`px-2 inline-flex text-xs leading-5 font-semibold rounded-full ${
                          subscription.status === 'active'
                            ? 'bg-green-100 text-green-800'
                            : 'bg-red-100 text-red-800'
                        }`}
                      >
                        {subscription.status}
                      </span>
                    )
                    : (
                      'No Active Subscription'
                    )}
                </dd>
              </div>

              {subscription && (
                <>
                  <div className='py-4 sm:py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6'>
                    <dt className='text-sm font-medium text-gray-500'>Current Plan</dt>
                    <dd className='mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2'>
                      {/* Assuming plan relationship returns an object or plan_id */}
                      {subscription.plan?.name || subscription.plan_id}
                    </dd>
                  </div>
                  <div className='py-4 sm:py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6'>
                    <dt className='text-sm font-medium text-gray-500'>Current Period End</dt>
                    <dd className='mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2'>
                      {new Date(subscription.current_period_end).toLocaleDateString()}
                    </dd>
                  </div>
                </>
              )}
            </dl>
          </div>
          <div className='px-4 py-5 sm:px-6'>
            {subscription?.status === 'active'
              ? (
                <button className='text-red-600 hover:text-red-800 font-medium'>
                  Cancel Subscription (Coming Soon)
                </button>
              )
              : (
                <Link href='/pricing' className='text-indigo-600 hover:text-indigo-800 font-medium'>
                  Upgrade Plan
                </Link>
              )}
          </div>
        </div>
      </div>
    </div>
  )
}
