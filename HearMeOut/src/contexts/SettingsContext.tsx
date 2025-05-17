import React, { createContext, useState, useContext, useEffect } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';

// Define settings types
export interface Settings {
  // Audio processing settings
  noiseReductionLevel: number; // 0-100
  speechEnhancementLevel: number; // 0-100
  processingLatency: 'low' | 'balanced' | 'high'; // Tradeoff between quality and latency
  
  // Bluetooth settings
  autoConnect: boolean;
  previousDeviceId: string | null;
  
  // UI settings
  theme: 'light' | 'dark' | 'system';
  hapticFeedback: boolean;
  
  // Advanced settings
  modelType: 'rnnoise' | 'deepfilternet' | 'demucs';
  debugMode: boolean;
}

// Default settings
const defaultSettings: Settings = {
  noiseReductionLevel: 70,
  speechEnhancementLevel: 70,
  processingLatency: 'balanced',
  autoConnect: true,
  previousDeviceId: null,
  theme: 'light',
  hapticFeedback: true,
  modelType: 'rnnoise',
  debugMode: false,
};

// Create context type
interface SettingsContextType {
  settings: Settings;
  setSettings: React.Dispatch<React.SetStateAction<Settings>>;
  updateSetting: <K extends keyof Settings>(key: K, value: Settings[K]) => void;
  resetSettings: () => void;
}

// Create context with default values
const SettingsContext = createContext<SettingsContextType>({
  settings: defaultSettings,
  setSettings: () => {},
  updateSetting: () => {},
  resetSettings: () => {},
});

// Storage key for settings
const SETTINGS_STORAGE_KEY = '@AudioFocus:settings';

// Provider component
export const SettingsProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [settings, setSettings] = useState<Settings>(defaultSettings);
  const [isLoaded, setIsLoaded] = useState(false);

  // Load settings from storage on mount
  useEffect(() => {
    const loadSettings = async () => {
      try {
        const storedSettings = await AsyncStorage.getItem(SETTINGS_STORAGE_KEY);
        if (storedSettings) {
          setSettings(prevSettings => ({
            ...prevSettings,
            ...JSON.parse(storedSettings),
          }));
        }
      } catch (error) {
        console.error('Failed to load settings from storage:', error);
      } finally {
        setIsLoaded(true);
      }
    };

    loadSettings();
  }, []);

  // Save settings to storage when they change
  useEffect(() => {
    const saveSettings = async () => {
      if (!isLoaded) return; // Don't save until initial load is complete
      
      try {
        await AsyncStorage.setItem(SETTINGS_STORAGE_KEY, JSON.stringify(settings));
      } catch (error) {
        console.error('Failed to save settings to storage:', error);
      }
    };

    saveSettings();
  }, [settings, isLoaded]);

  // Update a single setting
  const updateSetting = <K extends keyof Settings>(key: K, value: Settings[K]) => {
    setSettings(prevSettings => ({
      ...prevSettings,
      [key]: value,
    }));
  };

  // Reset settings to default
  const resetSettings = () => {
    setSettings(defaultSettings);
  };

  return (
    <SettingsContext.Provider value={{ settings, setSettings, updateSetting, resetSettings }}>
      {children}
    </SettingsContext.Provider>
  );
};

// Custom hook to use the settings context
export const useSettings = () => useContext(SettingsContext);

export default SettingsContext;