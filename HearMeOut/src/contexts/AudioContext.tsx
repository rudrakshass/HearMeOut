import React, { createContext, useState, useContext, useEffect, useRef } from 'react';
import { Audio } from 'expo-av';
import * as FileSystem from 'expo-file-system';
import { useBluetooth } from './BluetoothContext';
import { useSettings } from './SettingsContext';
import * as tf from '@tensorflow/tfjs';
import * as tfjs from '@tensorflow/tfjs-react-native';

// Processing state type
export type ProcessingState = 'idle' | 'initializing' | 'processing' | 'paused' | 'error';

// Audio buffer type for raw audio processing
interface AudioBuffer {
  pcmData: Float32Array;
  sampleRate: number;
  channels: number;
}

// Context type
interface AudioContextType {
  isInitialized: boolean;
  processingState: ProcessingState;
  audioLevel: number; // Current input audio level (0-100)
  outputLevel: number; // Current output audio level (0-100)
  startProcessing: () => Promise<void>;
  stopProcessing: () => Promise<void>;
  pauseProcessing: () => Promise<void>;
  resumeProcessing: () => Promise<void>;
  error: string | null;
  modelLoaded: boolean;
  modelLoadProgress: number;
}

// Create context with default values
const AudioContext = createContext<AudioContextType>({
  isInitialized: false,
  processingState: 'idle',
  audioLevel: 0,
  outputLevel: 0,
  startProcessing: async () => {},
  stopProcessing: async () => {},
  pauseProcessing: async () => {},
  resumeProcessing: async () => {},
  error: null,
  modelLoaded: false,
  modelLoadProgress: 0,
});

// Provider component
export const AudioProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  // State
  const [isInitialized, setIsInitialized] = useState<boolean>(false);
  const [processingState, setProcessingState] = useState<ProcessingState>('idle');
  const [audioLevel, setAudioLevel] = useState<number>(0);
  const [outputLevel, setOutputLevel] = useState<number>(0);
  const [error, setError] = useState<string | null>(null);
  const [modelLoaded, setModelLoaded] = useState<boolean>(false);
  const [modelLoadProgress, setModelLoadProgress] = useState<number>(0);
  
  // References to avoid recreating objects
  const recording = useRef<Audio.Recording | null>(null);
  const audioContext = useRef<AudioContext | null>(null);
  const model = useRef<tf.LayersModel | null>(null);
  const audioProcessor = useRef<any>(null);
  const latencyBuffer = useRef<AudioBuffer[]>([]);
  
  // Get Bluetooth context
  const { connectionState, currentDevice } = useBluetooth();
  
  // Get settings
  const { settings } = useSettings();

  // Initialize TFJS
  useEffect(() => {
    const initTensorFlow = async () => {
      try {
        // Initialize TensorFlow.js
        await tf.ready();
        console.log('TensorFlow.js is ready');
        
        // Load model based on settings
        await loadModel();
      } catch (err: any) {
        setError(`Failed to initialize TensorFlow: ${err.message}`);
      }
    };

    initTensorFlow();
  }, []);

  // Load the selected AI model
  const loadModel = async () => {
    if (model.current) return; // Model already loaded
    
    setModelLoaded(false);
    setModelLoadProgress(0);
    
    try {
      // Determine model path based on settings
      let modelPath;
      switch (settings.modelType) {
        case 'rnnoise':
          modelPath = FileSystem.documentDirectory + 'rnnoise_model';
          break;
        case 'deepfilternet':
          modelPath = FileSystem.documentDirectory + 'deepfilternet_model';
          break;
        case 'demucs':
          modelPath = FileSystem.documentDirectory + 'demucs_model';
          break;
        default:
          modelPath = FileSystem.documentDirectory + 'rnnoise_model';
      }
      
      // Check if model exists, if not, copy from assets
      const modelInfo = await FileSystem.getInfoAsync(modelPath);
      if (!modelInfo.exists) {
        // In a real app, you would download or copy from assets
        console.log('Model not found, would download from server or copy from assets');
        // Placeholder for model loading - in a real app you would implement the actual loading
        
        // Simulate progress
        for (let i = 0; i <= 100; i += 10) {
          setModelLoadProgress(i);
          await new Promise(resolve => setTimeout(resolve, 100));
        }
      }
      
      // Placeholder for actual model loading
      // In real implementation, you would use tf.loadLayersModel() to load the model
      console.log('Model would be loaded here');
      
      // Simulate model creation for this example
      // In a real app, replace this with actual model loading
      model.current = {
        predict: (input: tf.Tensor) => {
          // Simulate prediction - just return the input for now
          return input;
        }
      } as any;
      
      setModelLoaded(true);
      setModelLoadProgress(100);
      console.log('Model loaded');
    } catch (err: any) {
      setError(`Failed to load model: ${err.message}`);
      setModelLoaded(false);
    }
  };

  // Initialize audio system
  const initAudio = async () => {
    if (isInitialized) return true;
    
    try {
      setProcessingState('initializing');
      
      // Request audio recording permissions
      const { status } = await Audio.requestPermissionsAsync();
      if (status !== 'granted') {
        setError('Permission to access microphone was denied');
        setProcessingState('error');
        return false;
      }
      
      // Set audio mode for recording and playback
      await Audio.setAudioModeAsync({
        allowsRecordingIOS: true,
        playsInSilentModeIOS: true,
        staysActiveInBackground: true,
        interruptionModeIOS: 1, // DoNotMix
        interruptionModeAndroid: 1, // DoNotMix
        shouldDuckAndroid: true,
        playThroughEarpieceAndroid: false,
      });
      
      setIsInitialized(true);
      setProcessingState('idle');
      return true;
    } catch (err: any) {
      setError(`Failed to initialize audio: ${err.message}`);
      setProcessingState('error');
      return false;
    }
  };

  // Process audio buffer using the loaded AI model
  const processAudioBuffer = async (buffer: AudioBuffer): Promise<AudioBuffer> => {
    if (!model.current) {
      throw new Error('Model not loaded');
    }
    
    try {
      // Convert audio buffer to tensor
      const inputTensor = tf.tensor(buffer.pcmData);
      
      // Apply noise reduction and speech enhancement based on settings
      // In a real implementation, you would process the audio differently based on the selected model
      
      // Placeholder for audio processing logic
      // In a real implementation, this would be replaced with actual model inference
      
      // Example: Apply RNNoise-like processing
      // const outputTensor = model.current.predict(inputTensor) as tf.Tensor;
      
      // For this prototype, just return the original buffer (placeholder)
      // In a real implementation, you would convert the processed tensor back to audio data
      
      // Update audio levels (for visualization)
      // Calculate RMS of input and output
      const rms = Math.sqrt(
        buffer.pcmData.reduce((sum, val) => sum + val * val, 0) / buffer.pcmData.length
      );
      
      // Convert RMS to dB, then normalize to 0-100 range
      const db = 20 * Math.log10(Math.max(rms, 1e-6));
      const normalizedLevel = Math.min(100, Math.max(0, (db + 60) * (100 / 60)));
      
      setAudioLevel(normalizedLevel);
      setOutputLevel(normalizedLevel * 0.8); // Simulate output level (would be calculated from actual output)
      
      // Return original buffer (placeholder)
      return buffer;
    } catch (error) {
      console.error('Error processing audio:', error);
      throw error;
    }
  };

  // Start audio processing
  const startProcessing = async () => {
    // Check if connected to Bluetooth headphones
    if (connectionState !== 'connected') {
      setError('Please connect to Bluetooth headphones first');
      return;
    }
    
    // Check if model is loaded
    if (!modelLoaded) {
      setError('Audio processing model not loaded');
      return;
    }
    
    // Initialize audio system if needed
    const initialized = await initAudio();
    if (!initialized) return;
    
    try {
      setProcessingState('processing');
      setError(null);
      
      // Start recording from microphone
      await Audio.setAudioModeAsync({
        allowsRecordingIOS: true,
        playsInSilentModeIOS: true,
        interruptionModeIOS: 1, // DoNotMix
        interruptionModeAndroid: 1, // DoNotMix
      });
      
      // Create recording object
      recording.current = new Audio.Recording();
      
      // Prepare recording with appropriate settings
      await recording.current.prepareToRecordAsync({
        android: {
          extension: '.pcm',
          outputFormat: 1, // PCM
          audioEncoder: 1, // DEFAULT
          sampleRate: 44100,
          numberOfChannels: 1,
          bitRate: 16 * 44100,
        },
        ios: {
          extension: '.wav',
          outputFormat: 1, // LINEARPCM
          audioQuality: 1, // MAX
          sampleRate: 44100,
          numberOfChannels: 1,
          bitRate: 16 * 44100,
          linearPCMBitDepth: 16,
          linearPCMIsBigEndian: false,
          linearPCMIsFloat: false,
        },
        web: {
          mimeType: 'audio/webm',
          bitsPerSecond: 128000,
        },
      });
      
      // Set up audio processing
      // This is a simplified example - in a real app, you would:
      // 1. Stream audio data from the recording
      // 2. Process chunks with the AI model
      // 3. Send processed audio to the Bluetooth headphones
      
      // Start recording
      await recording.current.startAsync();
      
      console.log('Audio processing started');
      
      // Set up a simple timer to simulate audio processing
      // In a real implementation, you would process audio data in chunks
      // and send it to the Bluetooth device
      audioProcessor.current = setInterval(() => {
        // Simulate processing and updating levels
        const randomValue = Math.random() * 100;
        setAudioLevel(randomValue);
        
        // Simulate reduced noise in output
        const reducedLevel = randomValue * (1 - settings.noiseReductionLevel / 100);
        setOutputLevel(reducedLevel);
      }, 100);
      
    } catch (err: any) {
      setError(`Failed to start audio processing: ${err.message}`);
      setProcessingState('error');
      
      // Clean up
      if (recording.current) {
        try {
          await recording.current.stopAndUnloadAsync();
        } catch (stopErr) {
          console.error('Error stopping recording:', stopErr);
        }
        recording.current = null;
      }
    }
  };

  // Stop audio processing
  const stopProcessing = async () => {
    try {
      // Clear audio processor interval
      if (audioProcessor.current) {
        clearInterval(audioProcessor.current);
        audioProcessor.current = null;
      }
      
      // Stop recording if active
      if (recording.current) {
        await recording.current.stopAndUnloadAsync();
        recording.current = null;
      }
      
      // Reset audio levels
      setAudioLevel(0);
      setOutputLevel(0);
      
      // Update state
      setProcessingState('idle');
      setError(null);
      
      console.log('Audio processing stopped');
    } catch (err: any) {
      setError(`Failed to stop audio processing: ${err.message}`);
    }
  };

  // Pause audio processing
  const pauseProcessing = async () => {
    if (processingState !== 'processing') return;
    
    try {
      // Clear audio processor interval
      if (audioProcessor.current) {
        clearInterval(audioProcessor.current);
        audioProcessor.current = null;
      }
      
      // Pause recording if active
      if (recording.current && recording.current._canRecord) {
        await recording.current.pauseAsync();
      }
      
      // Update state
      setProcessingState('paused');
      
      console.log('Audio processing paused');
    } catch (err: any) {
      setError(`Failed to pause audio processing: ${err.message}`);
    }
  };

  // Resume audio processing
  const resumeProcessing = async () => {
    if (processingState !== 'paused') return;
    
    try {
      // Resume recording if active
      if (recording.current) {
        await recording.current.startAsync();
      }
      
      // Set up audio processor interval again
      audioProcessor.current = setInterval(() => {
        // Simulate processing and updating levels
        const randomValue = Math.random() * 100;
        setAudioLevel(randomValue);
        
        // Simulate reduced noise in output
        const reducedLevel = randomValue * (1 - settings.noiseReductionLevel / 100);
        setOutputLevel(reducedLevel);
      }, 100);
      
      // Update state
      setProcessingState('processing');
      
      console.log('Audio processing resumed');
    } catch (err: any) {
      setError(`Failed to resume audio processing: ${err.message}`);
    }
  };

  // Clean up on unmount
  useEffect(() => {
    return () => {
      // Stop any active processing
      if (processingState === 'processing' || processingState === 'paused') {
        stopProcessing();
      }
      
      // Clear interval if active
      if (audioProcessor.current) {
        clearInterval(audioProcessor.current);
      }
    };
  }, [processingState]);

  // Context value
  const value = {
    isInitialized,
    processingState,
    audioLevel,
    outputLevel,
    startProcessing,
    stopProcessing,
    pauseProcessing,
    resumeProcessing,
    error,
    modelLoaded,
    modelLoadProgress,
  };

  return (
    <AudioContext.Provider value={value}>
      {children}
    </AudioContext.Provider>
  );
};

// Custom hook to use the Audio context
export const useAudio = () => useContext(AudioContext);

export default AudioContext;