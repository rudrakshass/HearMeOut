import { useCallback, useEffect, useRef, useState } from 'react';

export type AudioProcessorStatus = 'idle' | 'initializing' | 'listening' | 'processing' | 'error';

interface AudioProcessorState {
  status: AudioProcessorStatus;
  filterStrength: number;
  error?: string;
}

interface UseAudioProcessorOptions {
  onStatusChange?: (status: AudioProcessorStatus) => void;
  filterStrength?: number;
}

const DEFAULT_OPTIONS: UseAudioProcessorOptions = {
  filterStrength: 5
};

export function useAudioProcessor(options: UseAudioProcessorOptions = DEFAULT_OPTIONS) {
  const { onStatusChange, filterStrength = 5 } = options;
  
  const [state, setState] = useState<AudioProcessorState>({
    status: 'idle',
    filterStrength,
  });

  const processingInterval = useRef<number | null>(null);
  const isActive = useRef(false);

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      if (processingInterval.current !== null) {
        clearInterval(processingInterval.current);
      }
    };
  }, []);

  // Update status callback
  useEffect(() => {
    if (onStatusChange) {
      onStatusChange(state.status);
    }
  }, [state.status, onStatusChange]);

  const simulateAudioProcessing = useCallback(() => {
    // Simulate varying processing times (200-800ms)
    const processingTime = 200 + Math.random() * 600;
    
    setState(prev => ({
      ...prev,
      status: 'processing'
    }));

    setTimeout(() => {
      if (isActive.current) {
        setState(prev => ({
          ...prev,
          status: 'listening'
        }));
      }
    }, processingTime);
  }, []);

  const startProcessing = useCallback(async () => {
    try {
      isActive.current = true;
      
      // Simulate initialization delay
      setState(prev => ({
        ...prev,
        status: 'initializing',
        error: undefined
      }));

      await new Promise(resolve => setTimeout(resolve, 1000));

      // Start the processing loop
      setState(prev => ({
        ...prev,
        status: 'listening'
      }));

      // Simulate periodic processing
      processingInterval.current = window.setInterval(() => {
        if (Math.random() > 0.7) { // 30% chance to trigger processing
          simulateAudioProcessing();
        }
      }, 2000);

    } catch (error) {
      setState(prev => ({
        ...prev,
        status: 'error',
        error: error instanceof Error ? error.message : 'Failed to start audio processing'
      }));
    }
  }, [simulateAudioProcessing]);

  const stopProcessing = useCallback(() => {
    isActive.current = false;
    
    if (processingInterval.current !== null) {
      clearInterval(processingInterval.current);
      processingInterval.current = null;
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
    isProcessing: state.status !== 'idle' && state.status !== 'error',
    startProcessing,
    stopProcessing,
    updateFilterStrength,
  };
} 