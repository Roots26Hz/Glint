// Replacement
import Link from "next/link";
import Image from "next/image";

export function Footer() {
  const currentYear = new Date().getFullYear();

  return (
    <footer className="w-full py-12 px-6 border-t border-white/10 bg-black relative z-10">
      <div className="max-w-6xl mx-auto flex flex-col md:flex-row items-center justify-between gap-6">
        <div className="flex items-center gap-3">
          <div className="relative w-8 h-8 rounded-[8px] overflow-hidden">
            <Image
              src="/assets/icon.png"
              alt="Glint Logo"
              fill
              className="object-cover grayscale opacity-70"
            />
          </div>
          <span className="font-semibold text-white/70">Glint for macOS</span>
        </div>

        <nav className="flex items-center gap-6 text-sm text-white/50">
          <Link href="#features" className="hover:text-white transition-colors">
            Features
          </Link>
          <Link href="#visualiser" className="hover:text-white transition-colors">
            Visualiser
          </Link>
          <Link href="#download" className="hover:text-white transition-colors">
            Download
          </Link>
        </nav>

        <div className="flex flex-col md:flex-row items-center gap-6 text-sm text-white/50">
          <span>&copy; {currentYear} Glint. All rights reserved.</span>
          <Link
            href="https://github.com"
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center gap-2 hover:text-white transition-colors"
          >
            <svg viewBox="0 0 24 24" className="w-4 h-4 fill-current" aria-hidden="true"><path d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0022 12.017C22 6.484 17.522 2 12 2z"></path></svg>
            <span>GitHub</span>
          </Link>
        </div>
      </div>
    </footer>
  );
}
