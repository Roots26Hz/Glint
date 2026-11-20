"use client";

import { motion } from "framer-motion";
import { Download, CheckCircle2, Apple } from "lucide-react";
import Image from "next/image";

export function DownloadSection() {
  const handleDownloadTracking = () => {
    // Basic client-side tracking event
    console.log("Download event tracked");
    
    // In a real scenario with NextAuth/Prisma or analytics API:
    fetch('/api/analytics/download', { method: 'POST' }).catch(console.error);
    
    // Continue with the default link behavior
  };

  return (
    <section id="download" className="relative w-full py-32 bg-black overflow-hidden">
      <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[600px] h-[600px] bg-white/[0.03] rounded-full blur-[100px] pointer-events-none" />

      <div className="relative z-10 max-w-4xl mx-auto px-6 text-center">
        <motion.div
          initial={{ opacity: 0, y: 30 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.8 }}
          className="glass-card p-12 md:p-16 flex flex-col items-center max-w-2xl mx-auto"
        >
          <div className="w-24 h-24 relative mb-8 shadow-2xl rounded-[20px] overflow-hidden border border-white/10">
            <Image
              src="/assets/icon.png"
              alt="Glint Icon"
              fill
              className="object-cover"
            />
          </div>

          <h2 className="text-3xl md:text-5xl font-bold mb-4 tracking-tight">Get Glint today.</h2>
          <p className="text-lg text-white/60 mb-8 max-w-md">
            Experience the most beautiful music player ever designed for macOS.
          </p>

          <a
            href="https://github.com/Roots26Hz/Glint/releases/latest/download/Glint.dmg"
            onClick={handleDownloadTracking}
            className="group relative flex items-center gap-3 bg-white text-black px-8 py-4 rounded-full font-semibold text-lg hover:scale-105 transition-all duration-300 shadow-[0_0_40px_rgba(255,255,255,0.2)] hover:shadow-[0_0_60px_rgba(255,255,255,0.4)] w-full sm:w-auto justify-center"
          >
            <Download className="w-5 h-5" />
            Download for macOS
            <div className="absolute inset-0 rounded-full border border-white/40 scale-110 opacity-0 group-hover:scale-100 group-hover:opacity-100 transition-all duration-300 pointer-events-none" />
          </a>

          <div className="mt-8 flex flex-col sm:flex-row items-center gap-6 text-sm text-white/40 font-medium">
            <div className="flex items-center gap-2">
              <Apple className="w-4 h-4" />
              macOS 26.0+ required
            </div>
            <div className="hidden sm:block w-1 h-1 bg-white/20 rounded-full" />
            <div className="flex items-center gap-2">
              <CheckCircle2 className="w-4 h-4" />
              Latest version · updates in-app
            </div>
          </div>
        </motion.div>
      </div>
    </section>
  );
}
