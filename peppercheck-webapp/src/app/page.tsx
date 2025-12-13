import Link from 'next/link'

export default function Home() {
  return (
    <div className='min-h-screen bg-white flex flex-col justify-center items-center'>
      <main className='text-center px-4'>
        <h1 className='text-5xl font-bold tracking-tight text-gray-900 sm:text-6xl'>
          PepperCheck
        </h1>
        <p className='mt-6 text-lg leading-8 text-gray-600'>
          The best way to manage your points and subscriptions.
        </p>
        <div className='mt-10 flex items-center justify-center gap-x-6'>
          <Link
            href='/dashboard'
            className='rounded-md bg-indigo-600 px-3.5 py-2.5 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600'
          >
            Go to Dashboard
          </Link>
          <Link href='/pricing' className='text-sm font-semibold leading-6 text-gray-900'>
            View Pricing <span aria-hidden='true'>→</span>
          </Link>
        </div>
      </main>
    </div>
  )
}
