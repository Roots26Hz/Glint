"use client";

import { motion } from "framer-motion";

interface MarqueeGalleryProps {
  artworks: string[];
}

export function MarqueeGallery({ artworks }: MarqueeGalleryProps) {
  // Split artworks into 3 rows for a rich visual effect
  // Fallback if artworks is small
  const safeArtworks = artworks.length > 0 ? artworks : Array(16).fill("/assets/poster.jpg");
  
  const third = Math.max(Math.floor(safeArtworks.length / 3), 1);
  const row1 = safeArtworks.slice(0, third);
  const row2 = safeArtworks.slice(third, third * 2);
  const row3 = safeArtworks.slice(third * 2);

  return (
    <div className="relative w-full py-10 overflow-hidden flex flex-col gap-4 md:gap-6 bg-black">
      {/* Fade edges to black for smooth entry/exit */}
      <div className="absolute inset-y-0 left-0 w-24 md:w-48 bg-gradient-to-r from-black to-transparent z-20 pointer-events-none" />
      <div className="absolute inset-y-0 right-0 w-24 md:w-48 bg-gradient-to-l from-black to-transparent z-20 pointer-events-none" />
      
      <MarqueeRow items={row1} direction="left" speed={800} />
      <MarqueeRow items={row2} direction="right" speed={750} />
      <MarqueeRow items={row3} direction="left" speed={850} />
    </div>
  );
}

function MarqueeRow({ items, direction, speed }: { items: string[], direction: "left" | "right", speed: number }) {
  // Duplicate items to create seamless loop
  const duplicatedItems = [...items, ...items, ...items, ...items];
  
  return (
    <div className="flex w-full overflow-hidden">
      <style>{`
        @keyframes scrollMarquee {
          0% { transform: translateX(0%); }
          100% { transform: translateX(-50%); }
        }
      `}</style>
      <div
        className="flex gap-4 md:gap-6 min-w-max"
        style={{
          animation: `scrollMarquee ${speed}s linear infinite`,
          animationDirection: direction === "left" ? "normal" : "reverse"
        }}
      >
        {duplicatedItems.map((src, i) => (
          <div 
            key={`${src}-${i}`}
            className="relative w-56 h-40 md:w-72 md:h-48 xl:w-96 xl:h-56 shrink-0 transition-all duration-300 hover:scale-105 hover:z-30 cursor-pointer glass-card p-3 md:p-4 rounded-2xl md:rounded-3xl border border-white/10 shadow-[0_8px_32px_rgba(255,255,255,0.05)]"
          >
            {/* Premium Inner Image Container */}
            <div className="w-full h-full relative rounded-xl md:rounded-2xl overflow-hidden shadow-inner bg-black/40 flex items-center justify-center">
              <img 
                src={src} 
                alt="Artwork" 
                loading="lazy"
                className="w-full h-full object-contain transition-transform duration-700 hover:scale-110"
              />
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
