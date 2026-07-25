import fs from "fs";
import path from "path";
import { MarqueeGallery } from "./marquee-gallery";

export function AlbumArtworkShowcase() {
  const listPath = path.join(process.cwd(), "src", "lib", "artwork-list.txt");
  let artworks: string[] = [];
  
  try {
    const list = fs.readFileSync(listPath, "utf-8");
    artworks = list.split("\n").filter(Boolean).map(f => `/assets/AlbumArtWork/${f}`);
  } catch (error) {
    console.error("Error reading artwork list:", error);
    // fallback
    artworks = Array(16).fill("/assets/poster.jpg");
  }

  return (
    <section className="relative w-full bg-black py-32 overflow-hidden">
      <div className="absolute inset-0 bg-gradient-to-b from-black via-blue-900/10 to-black pointer-events-none" />
      
      <div className="max-w-[1400px] mx-auto px-6 mb-20 relative z-10 text-center">
        <h2 className="text-4xl md:text-6xl font-bold tracking-tight mb-6">
          A gorgeous collection.
        </h2>
        <p className="text-xl text-white/60 max-w-2xl mx-auto">
          Every track you play is beautifully framed by Glint's intelligent color extraction, turning your screen into a canvas.
        </p>
      </div>

      <div className="w-full relative z-10">
        <MarqueeGallery artworks={artworks} />
      </div>
    </section>
  );
}
