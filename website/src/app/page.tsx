import { Navbar } from "@/components/layout/navbar";
import { Footer } from "@/components/layout/footer";
import { HeroSection } from "@/components/sections/hero-section";
import { FeatureShowcase } from "@/components/sections/feature-showcase";
import { AlbumArtworkShowcase } from "@/components/sections/album-artwork-showcase";
import { VisualiserStudio } from "@/components/sections/visualiser-studio";
import { DownloadSection } from "@/components/sections/download-section";
import { AboutSection } from "@/components/sections/about-section";

export default function Home() {
  return (
    <>
      <Navbar />
      
      <main className="flex flex-col items-center justify-center w-full min-h-screen">
        <HeroSection />
        <FeatureShowcase />
        <VisualiserStudio />
        <AlbumArtworkShowcase />
        <AboutSection />
        <DownloadSection />
      </main>

      <Footer />
    </>
  );
}
