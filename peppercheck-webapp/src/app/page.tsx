import { Header } from "@/components/Header";
import { Footer } from "@/components/Footer";

export default function Home() {
  return (
    <div className="flex min-h-screen flex-col font-sans">
      <Header />
      
      <main className="flex-1 w-full mx-auto max-w-[var(--max-content-width)] px-6 py-12 md:py-24">
        {/* Placeholder for content sections */}
        <div className="flex flex-col gap-12 text-center items-center justify-center min-h-[40vh]">
           <h1 className="text-4xl font-extrabold tracking-tight sm:text-5xl md:text-6xl text-[var(--color-heading)]">
            Peer Referee Platform<br />for Tasks
           </h1>
           <p className="max-w-xl text-lg text-[var(--color-text)] opacity-80">
             (Content placeholder)
           </p>
        </div>
      </main>

      <Footer />
    </div>
  );
}
