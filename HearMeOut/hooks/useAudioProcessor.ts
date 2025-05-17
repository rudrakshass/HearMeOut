import { Audio } from 'expo-av';
import { useCallback, useEffect, useRef, useState } from 'react';

export type AudioProcessorStatus = 'idle' | 'initializing' | 'listening' | 'processing' | 'error';

interface AudioProcessorState {
  status: AudioProcessorStatus;
  filterStrength: number;
  error?: string;
  frequencyData?: number[];
}

interface UseAudioProcessorOptions {
  onStatusChange?: (status: AudioProcessorStatus) => void;
  filterStrength?: number;
  onAudioData?: (frequencyData: number[]) => void;
}

const DEFAULT_OPTIONS: UseAudioProcessorOptions = {
  filterStrength: 5
};

// Number of frequency bands for visualization
const FREQUENCY_BANDS = 32;

export function useAudioProcessor(options: UseAudioProcessorOptions = DEFAULT_OPTIONS) {
  const { onStatusChange, filterStrength = 5, onAudioData } = options;
  
  const [state, setState] = useState<AudioProcessorState>({
    status: 'idle',
    filterStrength,
  });

  const processingInterval = useRef<number | null>(null);
  const recordingRef = useRef<Audio.Recording | null>(null);
  const audioContext = useRef<AudioContext | null>(null);
  const analyser = useRef<AnalyserNode | null>(null);
  const dataArray = useRef<Uint8Array | null>(null);
  const audioStream = useRef<MediaStream | null>(null);
  const isActive = useRef(false);

  // Initialize Web Audio API (for web platform)
  const initializeAudioContext = useCallback(async () => {
    try {
      if (typeof window !== 'undefined' && 'AudioContext' in window) {
        // Get user media for microphone access
        const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
        audioStream.current = stream;
        
        // Create audio context
        audioContext.current = new AudioContext();
        
        // Create analyzer
        analyser.current = audioContext.current.createAnalyser();
        analyser.current.fftSize = 256; // Must be power of 2
        
        // Connect microphone to analyzer
        const source = audioContext.current.createMediaStreamSource(stream);
        source.connect(analyser.current);
        
        // Create data array for frequency data
        const bufferLength = analyser.current.frequencyBinCount;
        dataArray.current = new Uint8Array(bufferLength);
        
        return true;
      }
      return false;
    } catch (error) {
      console.error('Failed to initialize audio context:', error);
      return false;
    }
  }, []);

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      if (processingInterval.current !== null) {
        clearInterval(processingInterval.current);
      }
      
      // Clean up audio resources
      if (audioStream.current) {
        audioStream.current.getTracks().forEach(track => track.stop());
      }
      
      if (audioContext.current) {
        audioContext.current.close();
      }
    };
  }, []);

  // Update status callback
  useEffect(() => {
    if (onStatusChange) {
      onStatusChange(state.status);
    }
  }, [state.status, onStatusChange]);

  // Analyze audio and extract frequency data
  const analyzeAudio = useCallback(() => {
    if (!analyser.current || !dataArray.current) return;
    
    // Get frequency data
    analyser.current.getByteFrequencyData(dataArray.current);
    
    // Convert to normalized values between 0-1 for visualization
    // and reduce to our desired number of bands
    const frequencyStep = Math.ceil(dataArray.current.length / FREQUENCY_BANDS);
    const normalizedData = Array(FREQUENCY_BANDS).fill(0);
    
    for (let i = 0; i < FREQUENCY_BANDS; i++) {
      let sum = 0;
      const startIndex = i * frequencyStep;
      const endIndex = Math.min(startIndex + frequencyStep, dataArray.current.length);
      
      for (let j = startIndex; j < endIndex; j++) {
        sum += dataArray.current[j];
      }
      
      // Normalize between 0-1
      normalizedData[i] = sum / ((endIndex - startIndex) * 255);
    }
    
    // Update state with frequency data
    setState(prev => ({
      ...prev,
      frequencyData: normalizedData
    }));
    
    // Callback with frequency data
    if (onAudioData) {
      onAudioData(normalizedData);
    }
  }, [onAudioData]);

  // Process audio in React Native (simulated for now)
  const processNativeAudio = useCallback(() => {
    // This would be replaced with actual native audio processing
    // if/when RN audio processing APIs are available
    
    // For now, we'll generate somewhat random but realistic data
    // that changes gradually based on previous values
    setState(prev => {
      // Start with previous data or defaults
      const prevData = prev.frequencyData || Array(FREQUENCY_BANDS).fill(0.1);
      
      // Generate new data with some randomness but similar to previous
      const newData = prevData.map(val => {
        // Add random change but keep some consistency with previous frame
        const change = (Math.random() - 0.5) * 0.2;
        return Math.max(0.05, Math.min(0.9, val + change));
      });
      
      // Apply a curve to simulate voice frequencies
      // (middle frequencies are often stronger)
      const enhancedData = newData.map((val, i) => {
        const frequencyFactor = 1 - Math.abs((i - (FREQUENCY_BANDS / 2)) / (FREQUENCY_BANDS / 2)) * 0.7;
        return val * frequencyFactor;
      });
      
      // Call callback if provided
      if (onAudioData) {
        onAudioData(enhancedData);
      }
      
      return {
        ...prev,
        frequencyData: enhancedData,
        status: 'listening'
      };
    });
  }, [onAudioData]);

  const startProcessing = useCallback(async () => {
    try {
      isActive.current = true;
      
      // Change status to initializing
      setState(prev => ({
        ...prev,
        status: 'initializing',
        error: undefined
      }));

      // Initialize audio context on web
      let webAudioInitialized = false;
      if (typeof window !== 'undefined') {
        webAudioInitialized = await initializeAudioContext();
      }

      // Start the processing loop
      setState(prev => ({
        ...prev,
        status: 'listening'
      }));

      // Set up processing interval
      if (webAudioInitialized) {
        // For web: Use actual audio analysis
        processingInterval.current = window.setInterval(() => {
          if (isActive.current) {
            analyzeAudio();
          }
        }, 50); // Update at ~20fps
      } else {
        // For React Native: Use our custom processor
        processingInterval.current = window.setInterval(() => {
          if (isActive.current) {
            processNativeAudio();
          }
        }, 50);
      }

    } catch (error) {
      setState(prev => ({
        ...prev,
        status: 'error',
        error: error instanceof Error ? error.message : 'Failed to start audio processing'
      }));
    }
  }, [analyzeAudio, processNativeAudio, initializeAudioContext]);

  const stopProcessing = useCallback(() => {
    isActive.current = false;
    
    if (processingInterval.current !== null) {
      clearInterval(processingInterval.current);
      processingInterval.current = null;
    }

    // Stop microphone stream if active
    if (audioStream.current) {
      audioStream.current.getTracks().forEach(track => track.stop());
      audioStream.current = null;
    }

    setState(prev => ({
      ...prev,
      status: 'idle',
      error: undefined
    }));
  }, []);

  const updateFilterStrength = useCallback((strength: number) => {
    setState(prev => ({
      ...prev,
      filterStrength: strength
    }));
  }, []);

  return {
    status: state.status,
    filterStrength: state.filterStrength,
    error: state.error,
    frequencyData: state.frequencyData,
    isProcessing: state.status !== 'idle' && state.status !== 'error',
    startProcessing,
    stopProcessing,
    updateFilterStrength,
  };
} 