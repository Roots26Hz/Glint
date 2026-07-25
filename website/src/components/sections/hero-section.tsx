"use client";

import { useState, useRef } from "react";
import { motion } from "framer-motion";
import Image from "next/image";
import Link from "next/link";
import { Download, ChevronRight, Volume2, VolumeX } from "lucide-react";

export function HeroSection() {
  const [isMuted, setIsMuted] = useState(true);
  const videoRef = useRef<HTMLVideoElement>(null);

  const toggleMute = () => {
    if (videoRef.current) {
      videoRef.current.muted = !isMuted;
      setIsMuted(!isMuted);
    }
  };

  return (
    <section id="home" className="relative min-h-[100svh] flex flex-col items-center justify-center overflow-hidden pt-40">
      {/* Ambient Background Elements */}
      <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[800px] h-[800px] bg-white/[0.03] rounded-full blur-[120px] pointer-events-none" />
      <div className="absolute top-1/4 left-1/4 w-[400px] h-[400px] bg-blue-500/[0.05] rounded-full blur-[100px] pointer-events-none" />
      <div className="absolute bottom-1/4 right-1/4 w-[500px] h-[500px] bg-purple-500/[0.05] rounded-full blur-[100px] pointer-events-none" />

      <div className="relative z-10 flex flex-col items-center text-center px-6 max-w-4xl mx-auto">
        
        <motion.div
          initial={{ opacity: 0, scale: 0.9, y: 20 }}
          animate={{ opacity: 1, scale: 1, y: 0 }}
          transition={{ duration: 0.8, ease: [0.16, 1, 0.3, 1] }}
          className="relative w-24 h-24 md:w-32 md:h-32 mb-8 rounded-[22px] md:rounded-[28px] overflow-hidden shadow-2xl border border-white/10"
        >
          <Image
            src="/assets/icon.png"
            alt="Glint Icon"
            fill
            className="object-cover"
            priority
          />
        </motion.div>

        <motion.h1
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8, delay: 0.1, ease: [0.16, 1, 0.3, 1] }}
          className="text-5xl md:text-7xl font-bold tracking-tight mb-6"
        >
          Music, <span className="text-gradient">reimagined.</span>
        </motion.h1>

        <motion.p
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8, delay: 0.2, ease: [0.16, 1, 0.3, 1] }}
          className="text-lg md:text-xl text-white/60 max-w-2xl mb-12 font-medium"
        >
          A premium macOS music player with beautiful visualizers, seamless Dynamic Island integration, and a cinematic UI.
        </motion.p>

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8, delay: 0.3, ease: [0.16, 1, 0.3, 1] }}
          className="flex flex-col sm:flex-row items-center gap-4"
        >
          <Link
            href="https://github.com/Roots26Hz/Glint/releases/download/Glint/Glint-1.0.dmg"
            className="group relative flex items-center gap-2 bg-white text-black px-8 py-4 rounded-full font-semibold text-lg hover:scale-105 transition-all duration-300"
          >
            <Download className="w-5 h-5" />
            Download for macOS
            <div className="absolute inset-0 rounded-full border border-white/40 scale-110 opacity-0 group-hover:scale-100 group-hover:opacity-100 transition-all duration-300 pointer-events-none" />
          </Link>
          
          <Link
            href="https://github.com/Roots26Hz/Glint"
            target="_blank"
            rel="noopener noreferrer"
            className="group flex items-center gap-2 px-8 py-4 rounded-full font-semibold text-lg text-white/80 hover:text-white hover:bg-white/5 transition-all duration-300"
          >
            View on GitHub
            <ChevronRight className="w-5 h-5 group-hover:translate-x-1 transition-transform" />
          </Link>
        </motion.div>
      </div>

      {/* Video / App Preview Background */}
      <motion.div
        initial={{ opacity: 0, y: 100 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 1.2, delay: 0.4, ease: [0.16, 1, 0.3, 1] }}
        className="relative w-full max-w-6xl mx-auto mt-20 px-6 perspective-1000"
      >
        <div className="relative aspect-video w-full rounded-2xl md:rounded-[32px] overflow-hidden border border-white/10 shadow-[0_20px_100px_rgba(0,0,0,0.5)] transform-gpu rotate-x-12 hover:rotate-x-0 transition-transform duration-1000 ease-out group">
          <div className="absolute inset-0 bg-gradient-to-t from-black/80 via-transparent to-transparent z-10 pointer-events-none" />
          <video
            ref={videoRef}
            src="/assets/glint-promo.mp4"
            autoPlay
            muted={isMuted}
            loop
            playsInline
            className="w-full h-full object-cover"
          />
          {/* Mute/Unmute Button */}
          <button
            onClick={toggleMute}
            className="absolute bottom-6 right-6 z-20 p-3 bg-black/50 hover:bg-white/20 backdrop-blur-md border border-white/10 rounded-full text-white transition-all duration-300 opacity-0 group-hover:opacity-100"
            aria-label={isMuted ? "Unmute video" : "Mute video"}
          >
            {isMuted ? <VolumeX className="w-5 h-5" /> : <Volume2 className="w-5 h-5" />}
          </button>
        </div>
      </motion.div>
    </section>
  );
}
