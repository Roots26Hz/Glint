"use client";

import { useRef } from "react";
import { motion, useScroll, useTransform } from "framer-motion";
import Image from "next/image";

const features = [
  {
    title: "Now Playing Live Activity",
    description: "When Apple Music plays, the notch grows small ears: album artwork on the left, a soundwave on the right, automatically tinted to match the current cover.",
    image: "/assets/Glintscreenshots/compact.png",
    colSpan: "col-span-12 md:col-span-12",
    layout: "row", // row means image on side, text on other
  },
  {
    title: "Hover-Expanded Player",
    description: "Hover over the notch and a full Liquid Glass player drops down: artwork, title, a seekable progress bar, and seamless playback controls.",
    image: "/assets/Glintscreenshots/expanded.png",
    colSpan: "col-span-12 md:col-span-7",
    layout: "col",
  },
  {
    title: "Volume & Brightness HUDs",
    description: "Glint handles volume and brightness keys itself, replacing the macOS Control Center pill with elegant, smooth-animating level bars right below the notch.",
    image: "/assets/Glintscreenshots/volume.png",
    colSpan: "col-span-12 md:col-span-5",
    layout: "col",
  },
  {
    title: "Bluetooth & Battery Banners",
    description: "Connect your AirPods or plug in the charger, and a sleek iOS-style banner slides down to show you device names, icons, and battery percentages.",
    image: "/assets/Glintscreenshots/bluetooth.png",
    colSpan: "col-span-12 md:col-span-5",
    layout: "col",
  },
  {
    title: "Menu-Bar Control Panel",
    description: "A comprehensive mini control center accessible from your menu bar. Toggle modules, adjust hover delays, and configure low-battery alerts in seconds.",
    image: "/assets/Glintscreenshots/menupanel.png",
    colSpan: "col-span-12 md:col-span-7",
    layout: "col",
    maxWidth: "max-w-[500px]" // scaled down to match other previews
  }
];

export function FeatureShowcase() {
  const containerRef = useRef<HTMLDivElement>(null);
  const { scrollYProgress } = useScroll({
    target: containerRef,
    offset: ["start end", "end start"]
  });

  return (
    <section id="features" ref={containerRef} className="relative w-full bg-black py-32 overflow-hidden">
      <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_center,_var(--tw-gradient-stops))] from-blue-900/10 via-black to-black pointer-events-none" />
      
      <div className="max-w-[1400px] mx-auto px-6 mb-24 relative z-10 text-center md:text-left">
        <h2 className="text-5xl md:text-7xl font-bold tracking-tight mb-8 leading-tight">
          Designed for <br className="hidden md:block"/>
          <span className="text-gradient">perfection.</span>
        </h2>
        <p className="text-xl md:text-2xl text-white/60 max-w-3xl leading-relaxed">
          Every feature in Glint has been meticulously crafted to feel native, responsive, and incredibly beautiful, turning dead space into a command center.
        </p>
      </div>

      <div className="flex flex-col gap-32 md:gap-48 px-6 max-w-[1400px] mx-auto relative z-10">
        {features.map((feature, index) => {
          const isEven = index % 2 === 0;
          
          return (
            <motion.div
              key={feature.title}
              initial={{ opacity: 0, y: 50 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, margin: "-100px" }}
              transition={{ duration: 0.8, ease: [0.16, 1, 0.3, 1] }}
              className={`flex flex-col ${isEven ? 'md:flex-row' : 'md:flex-row-reverse'} gap-12 md:gap-20 items-center justify-between w-full`}
            >
              {/* Text Content */}
              <div className="w-full md:w-5/12 space-y-6">

                <h3 className="text-3xl md:text-5xl font-bold tracking-tight leading-tight">{feature.title}</h3>
                <p className="text-lg md:text-xl text-white/60 leading-relaxed">
                  {feature.description}
                </p>
              </div>

              {/* Floating Image (No bounding box, impossible to clip) */}
              <div className="w-full md:w-7/12 relative flex items-center justify-center">
                {/* Glow behind the floating UI */}
                <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[80%] h-[50%] bg-blue-500/10 blur-[100px] rounded-full pointer-events-none" />
                
                <motion.div 
                  whileHover={{ scale: 1.05 }}
                  transition={{ type: "spring", stiffness: 300, damping: 20 }}
                  className="relative w-full flex items-center justify-center py-10"
                >
                  <img
                    src={feature.image}
                    alt={feature.title}
                    loading="lazy"
                    className={`w-full ${feature.maxWidth || "max-w-[900px]"} h-auto object-contain drop-shadow-[0_20px_50px_rgba(0,0,0,0.5)] z-20`}
                  />
                </motion.div>
              </div>
            </motion.div>
          );
        })}
      </div>
    </section>
  );
}
