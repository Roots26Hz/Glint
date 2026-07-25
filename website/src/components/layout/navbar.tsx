// Replacement
"use client";

import { useState, useEffect } from "react";
import { motion } from "framer-motion";
import { Download, Menu, X, Coffee } from "lucide-react";
import Image from "next/image";
import Link from "next/link";

const navItems = [
  { name: "Home", href: "#home" },
  { name: "Features", href: "#features" },
  { name: "Visualiser Studio", href: "#visualiser" },
];

export function Navbar() {
  const [activeSection, setActiveSection] = useState("home");
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);

  useEffect(() => {
    const handleScroll = () => {
      const sections = ["home", "features", "visualiser", "download"];
      const scrollPosition = window.scrollY + window.innerHeight / 2;

      for (const section of sections) {
        const element = document.getElementById(section);
        if (element) {
          const { offsetTop, offsetHeight } = element;
          if (
            scrollPosition >= offsetTop &&
            scrollPosition < offsetTop + offsetHeight
          ) {
            setActiveSection(section);
          }
        }
      }
    };

    window.addEventListener("scroll", handleScroll);
    return () => window.removeEventListener("scroll", handleScroll);
  }, []);

  return (
    <motion.header
      initial={{ y: -100 }}
      animate={{ y: 0 }}
      transition={{ duration: 0.5, ease: "easeOut" }}
      className="fixed top-6 left-0 right-0 z-50 flex justify-center px-6 pointer-events-none"
    >
      <div className="pointer-events-auto flex items-center justify-between bg-[#0a0a0a]/70 backdrop-blur-2xl border border-white/10 shadow-2xl px-6 py-3 w-full max-w-5xl rounded-full">
        {/* Logo */}
        <Link href="#home" className="flex items-center gap-3 group">
          <div className="relative w-8 h-8 rounded-[8px] overflow-hidden shadow-lg border border-white/10 group-hover:scale-105 transition-transform">
            <Image
              src="/assets/icon.png"
              alt="Glint Logo"
              fill
              className="object-cover"
            />
          </div>
          <span className="font-semibold text-lg tracking-tight">Glint</span>
        </Link>

        {/* Desktop Nav */}
        <nav className="hidden md:flex items-center gap-1">
          {navItems.map((item) => (
            <Link
              key={item.name}
              href={item.href}
              className={`px-4 py-2 rounded-full text-sm font-medium transition-all duration-300 ${
                activeSection === item.href.replace("#", "")
                  ? "bg-white/10 text-white"
                  : "text-white/60 hover:text-white hover:bg-white/5"
              }`}
            >
              {item.name}
            </Link>
          ))}
        </nav>

        {/* CTAs */}
        <div className="hidden md:flex items-center gap-3">
          <Link
            href="https://github.com"
            target="_blank"
            rel="noopener noreferrer"
            className="p-2 rounded-full text-white/70 hover:text-white hover:bg-white/10 transition-colors"
          >
            <svg viewBox="0 0 24 24" className="w-5 h-5 fill-current" aria-hidden="true"><path d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0022 12.017C22 6.484 17.522 2 12 2z"></path></svg>
          </Link>
          
          <Link
            href="https://buymeacoffee.com"
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center gap-2 bg-[#FFDD00] text-black px-5 py-2 rounded-full text-sm font-medium hover:scale-105 hover:bg-[#FFDD00]/90 transition-all duration-300"
          >
            <Coffee className="w-4 h-4" />
            Support Us
          </Link>
          
          <Link
            href="#download"
            className="flex items-center gap-2 bg-white text-black px-5 py-2 rounded-full text-sm font-medium hover:scale-105 hover:bg-white/90 transition-all duration-300"
          >
            <Download className="w-4 h-4" />
            Download
          </Link>
        </div>

        {/* Mobile Toggle */}
        <button
          className="md:hidden p-2 text-white/70 hover:text-white transition-colors"
          onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
        >
          {mobileMenuOpen ? <X className="w-6 h-6" /> : <Menu className="w-6 h-6" />}
        </button>
      </div>

      {/* Mobile Menu */}
      {mobileMenuOpen && (
        <div className="absolute top-20 left-6 right-6 p-4 glass-card rounded-2xl flex flex-col gap-4 pointer-events-auto md:hidden">
          {navItems.map((item) => (
            <Link
              key={item.name}
              href={item.href}
              onClick={() => setMobileMenuOpen(false)}
              className="text-lg font-medium px-4 py-3 rounded-xl hover:bg-white/5 transition-colors"
            >
              {item.name}
            </Link>
          ))}
          <div className="h-px bg-white/10 my-2" />
          <Link
            href="https://github.com"
            target="_blank"
            className="flex items-center gap-3 px-4 py-3 text-lg font-medium hover:bg-white/5 rounded-xl transition-colors"
          >
            <svg viewBox="0 0 24 24" className="w-5 h-5 fill-current" aria-hidden="true"><path d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0022 12.017C22 6.484 17.522 2 12 2z"></path></svg>
            GitHub
          </Link>
          <Link
            href="https://buymeacoffee.com"
            target="_blank"
            rel="noopener noreferrer"
            onClick={() => setMobileMenuOpen(false)}
            className="flex justify-center items-center gap-2 bg-[#FFDD00] text-black px-4 py-3 mt-2 rounded-xl text-lg font-medium hover:bg-[#FFDD00]/90 transition-colors"
          >
            <Coffee className="w-5 h-5" />
            Buy Us a Coffee
          </Link>
          <Link
            href="#download"
            onClick={() => setMobileMenuOpen(false)}
            className="flex justify-center items-center gap-2 bg-white text-black px-4 py-3 mt-2 rounded-xl text-lg font-medium hover:bg-white/90 transition-colors"
          >
            <Download className="w-5 h-5" />
            Download DMG
          </Link>
        </div>
      )}
    </motion.header>
  );
}
