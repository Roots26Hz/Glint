"use client";

import { Play, Pause, FastForward, Rewind } from "lucide-react";
import { useState, useRef, useEffect } from "react";

export function VisualiserStudio() {
  const [isPlaying, setIsPlaying] = useState(false);
  const audioRef = useRef<HTMLAudioElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  
  const audioContextRef = useRef<AudioContext | null>(null);
  const analyserRef = useRef<AnalyserNode | null>(null);
  const sourceRef = useRef<MediaElementAudioSourceNode | null>(null);
  const animationFrameRef = useRef<number>();

  const initAudio = () => {
    if (!audioContextRef.current && audioRef.current) {
      // @ts-ignore
      const AudioCtx = window.AudioContext || window.webkitAudioContext;
      audioContextRef.current = new AudioCtx();
      analyserRef.current = audioContextRef.current.createAnalyser();
      
      // Optimize FFT for visual EQ (higher resolution for bass)
      analyserRef.current.fftSize = 2048;
      // Expand dynamic range to capture deep bass bins without them clipping to 0
      analyserRef.current.minDecibels = -140;
      analyserRef.current.maxDecibels = 0;
      analyserRef.current.smoothingTimeConstant = 0.85;

      sourceRef.current = audioContextRef.current.createMediaElementSource(audioRef.current);
      sourceRef.current.connect(analyserRef.current);
      analyserRef.current.connect(audioContextRef.current.destination);
    }
  };

  const drawVisualizer = () => {
    if (!canvasRef.current || !analyserRef.current) return;
    
    const canvas = canvasRef.current;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    // Get logical CSS pixels from the canvas style/parent
    const rect = canvas.getBoundingClientRect();
    const width = rect.width;
    const height = rect.height;
    
    const bufferLength = analyserRef.current.frequencyBinCount;
    const dataArray = new Uint8Array(bufferLength);
    
    analyserRef.current.getByteFrequencyData(dataArray);

    ctx.clearRect(0, 0, width, height);

    const numBars = 16;
    const gap = 16;
    const barWidth = (width - (gap * (numBars - 1))) / numBars;
    let x = 0;

    for (let i = 0; i < numBars; i++) {
      // Logarithmic mapping matching the Swift app (30Hz to 16kHz)
      // Nyquist = 22050Hz (assuming 44.1kHz), bufferLength = 1024
      const minFreq = 30;
      const maxFreq = 16000;
      const freq = minFreq * Math.pow(maxFreq / minFreq, i / numBars);
      const nextFreq = minFreq * Math.pow(maxFreq / minFreq, (i + 1) / numBars);
      
      const nyquist = audioContextRef.current?.sampleRate ? audioContextRef.current.sampleRate / 2 : 22050;
      
      const lowIndex = Math.max(1, Math.floor((freq / nyquist) * bufferLength));
      const highIndex = Math.min(bufferLength - 1, Math.floor((nextFreq / nyquist) * bufferLength));
      
      let sum = 0;
      let count = 0;
      for (let j = lowIndex; j <= highIndex; j++) {
        sum += dataArray[j];
        count++;
      }
      const avg = count > 0 ? sum / count : 0;

      // Add the Swift app's 1.5dB treble tilt (approximate visual scaling)
      let rawHeight = (avg / 255) * height;
      rawHeight += i * (height * 0.015); // Treble tilt visually mapped
      
      const barHeight = Math.max(height * 0.05, Math.min(height * 0.95, rawHeight * 0.8));

      // Create glowing gradient (Neon Green to Yellow)
      const gradient = ctx.createLinearGradient(0, height, 0, height - barHeight);
      gradient.addColorStop(0, "rgba(57, 255, 20, 1)"); // Neon Green
      gradient.addColorStop(1, "rgba(255, 255, 0, 1)"); // Yellow

      ctx.fillStyle = gradient;
      
      // Add glow
      ctx.shadowBlur = 20;
      ctx.shadowColor = "rgba(57, 255, 20, 0.6)";

      // Draw rounded rect from the bottom up
      ctx.beginPath();
      if (ctx.roundRect) {
        ctx.roundRect(x, height - barHeight, barWidth, barHeight, [10, 10, 0, 0]);
      } else {
        ctx.rect(x, height - barHeight, barWidth, barHeight);
      }
      ctx.fill();

      x += barWidth + gap;
    }

    animationFrameRef.current = requestAnimationFrame(drawVisualizer);
  };

  useEffect(() => {
    const handleResize = () => {
      if (canvasRef.current) {
        const dpr = window.devicePixelRatio || 1;
        const rect = canvasRef.current.parentElement?.getBoundingClientRect();
        if (rect) {
          canvasRef.current.width = rect.width * dpr;
          canvasRef.current.height = 200 * dpr;
          
          // CSS size
          canvasRef.current.style.width = `${rect.width}px`;
          canvasRef.current.style.height = `200px`;

          const ctx = canvasRef.current.getContext("2d");
          if (ctx) ctx.scale(dpr, dpr);
          
          // Draw empty state immediately
          if (!isPlaying && ctx) {
            ctx.clearRect(0, 0, rect.width, 200);
            const numBars = 16;
            const gap = 16;
            const barWidth = (rect.width - (gap * (numBars - 1))) / numBars;
            let x = 0;
            ctx.fillStyle = "rgba(255,255,255,0.1)";
            for (let i = 0; i < numBars; i++) {
              ctx.beginPath();
              if (ctx.roundRect) {
                ctx.roundRect(x, 200 - 10, barWidth, 10, [10, 10, 0, 0]);
              } else {
                ctx.rect(x, 200 - 10, barWidth, 10);
              }
              ctx.fill();
              x += barWidth + gap;
            }
          }
        }
      }
    };
    
    window.addEventListener("resize", handleResize);
    
    // Give layout a tiny moment before measuring
    setTimeout(handleResize, 100);

    return () => {
      window.removeEventListener("resize", handleResize);
      if (animationFrameRef.current) cancelAnimationFrame(animationFrameRef.current);
    };
  }, [isPlaying]);

  useEffect(() => {
    if (isPlaying) {
      if (audioContextRef.current?.state === "suspended") {
        audioContextRef.current.resume();
      }
      if (animationFrameRef.current) cancelAnimationFrame(animationFrameRef.current);
      animationFrameRef.current = requestAnimationFrame(drawVisualizer);
    } else {
      if (animationFrameRef.current) cancelAnimationFrame(animationFrameRef.current);
    }
  }, [isPlaying]);

  const togglePlay = () => {
    if (!audioContextRef.current) {
      initAudio();
    }
    
    if (isPlaying) {
      audioRef.current?.pause();
    } else {
      audioRef.current?.play().catch(e => console.error("Audio playback failed", e));
    }
    setIsPlaying(!isPlaying);
  };

  return (
    <section id="visualiser" className="relative w-full min-h-[100svh] flex flex-col items-center justify-center bg-[#050505] overflow-hidden py-32">
      <audio 
        ref={audioRef} 
        src="/assets/bouncemusic.mp3" 
        loop 
        crossOrigin="anonymous"
        onEnded={() => setIsPlaying(false)} 
      />
      
      {/* Background glow effects */}
      <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[600px] h-[600px] bg-cyan-500/[0.05] rounded-full blur-[150px] pointer-events-none" />
      <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[800px] h-[800px] bg-pink-500/[0.03] rounded-full blur-[150px] pointer-events-none" />

      <div className="relative z-10 text-center max-w-4xl mx-auto px-6 mb-20">
        <h2 className="text-4xl md:text-6xl font-bold tracking-tight mb-6">
          <span className="text-gradient-accent">Visualiser Studio.</span>
        </h2>
        <p className="text-xl md:text-2xl text-white/60">
          Powered by the same visual intelligence behind Glint's desktop experience.
        </p>
      </div>

      <div className="relative z-10 w-full max-w-4xl mx-auto px-6 mt-12 md:mt-24">
        
        {/* Annotation moved outside the visualizer card */}
        {!isPlaying && (
          <div className="absolute -top-16 right-0 md:-top-16 md:-right-16 rotate-[12deg] flex flex-col items-center opacity-90 pointer-events-none z-20">
            <span className="font-serif italic text-[#39FF14] text-lg md:text-xl whitespace-nowrap drop-shadow-[0_0_12px_rgba(57,255,20,0.5)]">
              Play "Bounce" by The Non Violinist Project<br/>to see the equalizer in action!
            </span>
            {/* A beautiful curved arrow pointing down-left toward the visualizer */}
            <svg width="60" height="60" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" className="mt-2 text-[#FFFF00] stroke-current drop-shadow-[0_0_8px_rgba(255,255,0,0.6)]">
              <path d="M19 5C19 5 15 15 7 17" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
              <path d="M11 12L7 17L12 21" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
            </svg>
          </div>
        )}

        <div className="glass-card aspect-[16/10] sm:aspect-video w-full rounded-3xl p-8 flex flex-col items-center justify-center relative overflow-hidden shadow-[0_0_100px_rgba(56,189,248,0.1)] border border-white/10">
          
          {/* Visualizer Canvas Container */}
          <div className="w-full h-[200px] flex items-end justify-center mb-16 px-4">
            <canvas ref={canvasRef} className="w-full h-full" />
          </div>

          {/* Controls */}
          <div className="absolute bottom-8 left-1/2 -translate-x-1/2 flex items-center gap-6 glass px-8 py-4 rounded-full border border-white/10 shadow-2xl">
            <button className="text-white/70 hover:text-white transition-colors">
              <Rewind className="w-6 h-6 fill-current" />
            </button>
            <button
              onClick={togglePlay}
              className="w-14 h-14 bg-white text-black rounded-full flex items-center justify-center hover:scale-105 transition-all shadow-[0_0_20px_rgba(255,255,255,0.3)]"
            >
              {isPlaying ? <Pause className="w-6 h-6 fill-current" /> : <Play className="w-6 h-6 fill-current ml-1" />}
            </button>
            <button className="text-white/70 hover:text-white transition-colors">
              <FastForward className="w-6 h-6 fill-current" />
            </button>
          </div>
        </div>
      </div>
    </section>
  );
}
