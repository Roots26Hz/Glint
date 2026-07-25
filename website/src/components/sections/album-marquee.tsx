"use client";

import { motion } from "framer-motion";
import Image from "next/image";

interface AlbumMarqueeProps {
  items: string[];
  speed?: number;
  direction?: "left" | "right";
}

export function AlbumMarquee({ items, speed = 30, direction = "left" }: AlbumMarqueeProps) {
  // Duplicate items to ensure smooth infinite scrolling
  const duplicatedItems = [...items, ...items, ...items];
  
  return (
    <div className="relative flex w-[200vw] sm:w-[300vw] overflow-hidden group">
      <motion.div
        animate={{
          x: direction === "left" ? ["0%", "-33.33%"] : ["-33.33%", "0%"]
        }}
        transition={{
          repeat: Infinity,
          ease: "linear",
          duration: speed
        }}
        className="flex gap-4 sm:gap-6 pr-4 sm:pr-6 hover:[animation-play-state:paused]"
      >
        {duplicatedItems.map((src, i) => (
          <div
            key={`${src}-${i}`}
            className="relative h-32 sm:h-48 rounded-xl sm:rounded-2xl overflow-hidden shrink-0 shadow-xl border border-white/10 transition-transform duration-500 hover:scale-105 hover:z-10 group-hover:opacity-60 hover:!opacity-100 cursor-pointer"
          >
            <img
              src={src}
              alt={`Album Artwork ${i}`}
              className="h-full w-auto object-contain"
              loading="lazy"
            />
          </div>
        ))}
      </motion.div>
    </div>
  );
}
