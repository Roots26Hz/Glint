"use client";

import { motion } from "framer-motion";
import { User } from "lucide-react";
import Image from "next/image";
import Link from "next/link";
import React, { useRef, useState } from "react";

const team = [
  {
    name: "Rutav Desai",
    username: "@Roots26Hz",
    role: "Glint Founder",
    instagram: "https://instagram.com/rutavdesai_26_",
    linkedin: "https://www.linkedin.com/in/rutav-desai/",
    github: "https://github.com/Roots26Hz",
    image: "/assets/rutav.jpeg", 
  },
  {
    name: "Rehaan Bele",
    username: "@renexaan",
    role: "Co-Founder",
    instagram: "https://instagram.com/mujheyehbhitheekhai",
    linkedin: "https://linkedin.com/in/renexaan",
    github: "https://github.com/renexaan",
    image: "/assets/rehaan.png", 
  },
];

const Card = ({ member }: { member: typeof team[0] }) => {
  const cardRef = useRef<HTMLDivElement>(null);
  const [mousePosition, setMousePosition] = useState({ x: 0, y: 0 });
  const [isHovering, setIsHovering] = useState(false);

  const handleMouseMove = (e: React.MouseEvent<HTMLDivElement>) => {
    if (!cardRef.current) return;
    const rect = cardRef.current.getBoundingClientRect();
    setMousePosition({
      x: e.clientX - rect.left,
      y: e.clientY - rect.top,
    });
  };

  return (
    <motion.div
      ref={cardRef}
      onMouseMove={handleMouseMove}
      onMouseEnter={() => setIsHovering(true)}
      onMouseLeave={() => setIsHovering(false)}
      initial={{ opacity: 0, y: 30 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, margin: "-100px" }}
      transition={{ duration: 0.8, ease: "easeOut" }}
      animate={{ y: [0, -8, 0] }}
      // @ts-ignore
      transition={{ 
        y: { repeat: Infinity, duration: 6, ease: "easeInOut" },
        opacity: { duration: 0.8, ease: "easeOut" }
      }}
      whileHover={{ scale: 1.02, rotateY: 2, rotateX: 2 }}
      className="relative w-full md:w-[380px] p-[1px] rounded-3xl overflow-hidden group perspective-1000"
    >
      {/* Animated Gradient Border */}
      <div 
        className="absolute inset-0 bg-gradient-to-br from-white/10 to-transparent opacity-50 group-hover:opacity-100 transition-opacity duration-500" 
      />
      
      {/* Mouse Follow Glow */}
      <motion.div
        className="absolute inset-0 z-0 opacity-0 group-hover:opacity-100 transition-opacity duration-500 pointer-events-none"
        style={{
          background: `radial-gradient(400px circle at ${mousePosition.x}px ${mousePosition.y}px, rgba(255,255,255,0.06), transparent 40%)`,
        }}
      />

      <div className="relative z-10 flex flex-col items-center p-8 bg-[#0a0a0a]/80 backdrop-blur-3xl rounded-[23px] h-full border border-white/5 shadow-2xl">
        {/* Avatar */}
        <div className="w-24 h-24 rounded-full bg-gradient-to-tr from-white/10 to-white/5 p-1 mb-6 shadow-xl relative group-hover:shadow-white/5 transition-all duration-500">
          <div className="w-full h-full rounded-full bg-[#111] flex items-center justify-center border border-white/10 overflow-hidden relative">
            {member.image ? (
              <Image src={member.image} alt={member.name} fill className="object-cover" />
            ) : (
              <User className="w-10 h-10 text-white/30" />
            )}
          </div>
        </div>

        {/* Info */}
        <h3 className="text-2xl font-bold tracking-tight mb-1">{member.name}</h3>
        <span className="text-white/40 text-sm font-medium mb-4">{member.username}</span>
        
        <div className="px-4 py-1.5 rounded-full bg-white/5 border border-white/10 text-white/70 text-sm font-medium mb-6">
          {member.role}
        </div>

        {/* Elegant Divider */}
        <div className="w-full h-px bg-gradient-to-r from-transparent via-white/10 to-transparent mb-6" />

        {/* Socials */}
        <div className="flex items-center gap-4">
          <Link 
            href={member.instagram} 
            target="_blank" 
            className="p-3 rounded-full bg-white/5 border border-white/5 hover:bg-white/10 hover:border-white/20 transition-all duration-300 hover:scale-110 hover:-translate-y-1"
          >
            <svg viewBox="0 0 24 24" className="w-5 h-5 stroke-current text-white/70" fill="none" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <rect width="20" height="20" x="2" y="2" rx="5" ry="5"/>
              <path d="M16 11.37A4 4 0 1 1 12.63 8 4 4 0 0 1 16 11.37z"/>
              <line x1="17.5" x2="17.51" y1="6.5" y2="6.5"/>
            </svg>
          </Link>
          <Link 
            href={member.linkedin} 
            target="_blank" 
            className="p-3 rounded-full bg-white/5 border border-white/5 hover:bg-white/10 hover:border-white/20 transition-all duration-300 hover:scale-110 hover:-translate-y-1"
          >
            <svg viewBox="0 0 24 24" className="w-5 h-5 stroke-current text-white/70" fill="none" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <path d="M16 8a6 6 0 0 1 6 6v7h-4v-7a2 2 0 0 0-2-2 2 2 0 0 0-2 2v7h-4v-7a6 6 0 0 1 6-6z"/>
              <rect width="4" height="12" x="2" y="9"/>
              <circle cx="4" cy="4" r="2"/>
            </svg>
          </Link>
          <Link 
            href={member.github} 
            target="_blank" 
            className="p-3 rounded-full bg-white/5 border border-white/5 hover:bg-white/10 hover:border-white/20 transition-all duration-300 hover:scale-110 hover:-translate-y-1"
          >
            <svg viewBox="0 0 24 24" className="w-5 h-5 fill-current text-white/70" aria-hidden="true"><path d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0022 12.017C22 6.484 17.522 2 12 2z"></path></svg>
          </Link>
        </div>
      </div>
    </motion.div>
  );
};

export function AboutSection() {
  return (
    <section id="about" className="relative w-full py-32 overflow-hidden bg-black flex flex-col items-center">
      {/* Background Ambience */}
      <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[800px] h-[400px] bg-blue-500/5 blur-[150px] rounded-[100%] pointer-events-none" />
      
      <motion.div 
        initial={{ opacity: 0, y: 20 }}
        whileInView={{ opacity: 1, y: 0 }}
        viewport={{ once: true, margin: "-100px" }}
        transition={{ duration: 0.8 }}
        className="text-center mb-16 relative z-10"
      >
        <h2 className="text-4xl md:text-5xl font-bold tracking-tight mb-4">The Team Behind Glint</h2>
        <p className="text-white/50 max-w-lg mx-auto text-lg">
          Crafted with obsession by developers who love macOS.
        </p>
      </motion.div>

      <div className="flex flex-col md:flex-row gap-8 md:gap-12 relative z-10 px-6">
        {team.map((member) => (
          <Card key={member.username} member={member} />
        ))}
      </div>
    </section>
  );
}
