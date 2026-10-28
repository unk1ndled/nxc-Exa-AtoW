import Nav from "../components/Nav";
import Hero from "../components/Hero";
import Abstract from "../components/Abstract";
import Architecture from "../components/Architecture";
import Sandbox from "../components/Sandbox";
import Footer from "../components/Footer";

export default function LandingPage() {
  return (
    <div className="bg-paper text-ink text-sm antialiased min-h-screen font-mono">
      <Nav />
      <main className="max-w-content mx-auto px-4 sm:px-8">
        <Hero sectionNumber={1} />
        <Abstract sectionNumber={2} />
        <Architecture sectionNumber={3} />
        <Sandbox sectionNumber={4} />
      </main>
      <Footer />
    </div>
  );
}
