import { useEffect, useRef, useState } from 'react';

// Number of bars in the visualizer
const BAR_COUNT = 32;

// Range of heights for the visualization bars (as percentages)
const MIN_HEIGHT = 0.05;
const MAX_HEIGHT = 0.9;

// Base height factor when not active
const BASE_HEIGHT = 0.1;

// How quickly the visualization responds to changes
const SMOOTHING_FACTOR = 0.3;

// Interface for the visualization data
export interface VisualizationData {
  bars: number[];
  peak: number;
}

/**
 * Hook to create realistic audio visualization
 * @param isActive Whether audio is currently being processed
 * @param sensitivity How sensitive the visualization is (1-10)
 */
export const useAudioVisualization = (isActive: boolean, sensitivity: number = 5) => {
  // Store the current visualization data
  const [visualizationData, setVisualizationData] = useState<VisualizationData>({
    bars: Array(BAR_COUNT).fill(BASE_HEIGHT),
    peak: 0
  });

  // Animation timing reference
  const animationRef = useRef<number | null>(null);
  
  // Target values for smooth transitions
  const targetValues = useRef<number[]>(Array(BAR_COUNT).fill(BASE_HEIGHT));
  
  // Current values for smooth transitions
  const currentValues = useRef<number[]>(Array(BAR_COUNT).fill(BASE_HEIGHT));
  
  // Generate random data that mimics audio frequency patterns
  const generateRandomData = () => {
    const sensitivityFactor = sensitivity / 10;
    
    if (!isActive) {
      // When inactive, return low amplitude values
      return Array(BAR_COUNT).fill(0).map(() => 
        BASE_HEIGHT + (Math.random() * 0.05)
      );
    }
    
    // Create a "center heavy" distribution for more realistic audio pattern
    return Array(BAR_COUNT).fill(0).map((_, i) => {
      // Create frequency distribution - middle frequencies tend to be louder
      const frequencyFactor = 1 - Math.abs((i - (BAR_COUNT / 2)) / (BAR_COUNT / 2));
      
      // Random base value
      const randomBase = Math.random();
      
      // Sometimes add "peaks" to simulate beats or louder sounds
      const peakProbability = Math.random() < 0.1 ? 1.5 : 1;
      
      // Calculate height based on all factors
      const height = MIN_HEIGHT + 
                    (randomBase * frequencyFactor * sensitivityFactor * peakProbability) * 
                    (MAX_HEIGHT - MIN_HEIGHT);
                    
      return Math.min(MAX_HEIGHT, height);
    });
  };
  
  // Apply smoothing to transitions
  const smoothValues = (targetValues: number[], currentValues: number[]) => {
    return currentValues.map((current, i) => {
      const target = targetValues[i];
      return current + (target - current) * SMOOTHING_FACTOR;
    });
  };
  
  // Calculate the current peak value
  const calculatePeak = (values: number[]) => {
    const max = Math.max(...values);
    return max > visualizationData.peak 
      ? max 
      : visualizationData.peak * 0.95; // Peak decays slowly
  };
  
  // Process frame in animation loop
  const processFrame = () => {
    // Generate new target values
    targetValues.current = generateRandomData();
    
    // Smooth the transition
    currentValues.current = smoothValues(targetValues.current, currentValues.current);
    
    // Calculate peak
    const peak = calculatePeak(currentValues.current);
    
    // Update state with new data
    setVisualizationData({
      bars: [...currentValues.current],
      peak
    });
    
    // Continue animation loop if active
    if (isActive) {
      animationRef.current = requestAnimationFrame(processFrame);
    }
  };
  
  // Start and stop the visualization when isActive changes
  useEffect(() => {
    if (isActive) {
      // Start animation loop
      animationRef.current = requestAnimationFrame(processFrame);
    } else {
      // Cancel any running animation
      if (animationRef.current !== null) {
        cancelAnimationFrame(animationRef.current);
        animationRef.current = null;
      }
      
      // Reset to base values when inactive
      const baseValues = Array(BAR_COUNT).fill(BASE_HEIGHT);
      targetValues.current = baseValues;
      
      // Smooth transition to base
      const smoothTransition = () => {
        currentValues.current = smoothValues(baseValues, currentValues.current);
        
        // Check if values are close enough to base
        const isSettled = currentValues.current.every(v => Math.abs(v - BASE_HEIGHT) < 0.01);
        
        setVisualizationData({
          bars: [...currentValues.current],
          peak: visualizationData.peak * 0.9 // Decay peak when inactive
        });
        
        if (!isSettled) {
          // Continue transitioning until settled
          requestAnimationFrame(smoothTransition);
        }
      };
      
      // Start smooth transition to base state
      requestAnimationFrame(smoothTransition);
    }
    
    // Cleanup on unmount
    return () => {
      if (animationRef.current !== null) {
        cancelAnimationFrame(animationRef.current);
      }
    };
  }, [isActive, sensitivity]);
  
  return visualizationData;
}; 