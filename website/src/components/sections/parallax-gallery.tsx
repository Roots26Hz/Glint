"use client";

import { useRef } from "react";
import { motion, useScroll, useTransform } from "framer-motion";

export function ParallaxGallery({ artworks }: { artworks: string[] }) {
  const containerRef = useRef<HTMLDivElement>(null);
  
  // Confine the parallax effect strictly to this section's visibility
  const { scrollYProgress } = useScroll({
    target: containerRef,
    offset: ["start end", "end start"]
  });

  // Create columns
  const colCount = 4;
  const cols: string[][] = Array.from({ length: colCount }, () => []);
  
  artworks.forEach((src, i) => {
    cols[i % colCount].push(src);
  });

  // Different translation speeds for each column
  const y1 = useTransform(scrollYProgress, [0, 1], ["0%", "-30%"]);
  const y2 = useTransform(scrollYProgress, [0, 1], ["-20%", "20%"]);
  const y3 = useTransform(scrollYProgress, [0, 1], ["0%", "-40%"]);
  const y4 = useTransform(scrollYProgress, [0, 1], ["-10%", "30%"]);

  const transforms = [y1, y2, y3, y4];

  return (
    <div ref={containerRef} className="relative h-[1000px] xl:h-[1200px] w-full overflow-hidden flex gap-4 md:gap-6 justify-center px-4 -mt-20 mask-v-fade">
      <div className="absolute inset-0 bg-gradient-to-b from-black via-transparent to-black z-20 pointer-events-none" />
      
      {cols.map((colItems, colIndex) => (
        <motion.div
          key={colIndex}
          style={{ y: transforms[colIndex] }}
          className="flex flex-col gap-4 md:gap-6 pt-10"
        >
          {colItems.map((src, idx) => (
            <div 
              key={`${colIndex}-${idx}`}
              className="relative w-64 md:w-80 xl:w-[400px] overflow-hidden rounded-xl md:rounded-[32px] border border-white/10 shadow-2xl transition-all duration-500 hover:scale-[1.03] hover:z-30 hover:shadow-cyan-500/20 group cursor-pointer"
            >
              {/* Force image aspect ratio naturally */}
              <img 
                src={src} 
                alt="Album Artwork" 
                loading="lazy" 
                className="w-full h-auto block"
              />
            </div>
          ))}
        </motion.div>
      ))}
    </div>
  );
}
