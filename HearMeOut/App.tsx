import React, { useEffect, useState } from 'react';
import { StatusBar } from 'expo-status-bar';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { Provider as PaperProvider } from 'react-native-paper';
import { Platform, LogBox } from 'react-native';
import { KeepAwake } from 'expo-keep-awake';

// Import contexts
import { AudioProvider } from './src/contexts/AudioContext';
import { BluetoothProvider } from './src/contexts/BluetoothContext';
import { SettingsProvider } from './src/contexts/SettingsContext';

// Import screens
import HomeScreen from './src/screens/HomeScreen';
import SettingsScreen from './src/screens/SettingsScreen';

// Import theme
import { theme } from './src/constants/colors';

// Ignore specific warnings that might be caused by third-party libraries
LogBox.ignoreLogs([
  'Possible Unhandled Promise Rejection',
  'Require cycle:',
  'Non-serializable values were found in the navigation state'
]);

// Create navigation stack
const Stack = createNativeStackNavigator();

export default function App() {
  // Keep screen awake during audio processing
  useEffect(() => {
    // Enable keep-awake
    return () => {
      // Clean up
    };
  }, []);

  return (
    <SafeAreaProvider>
      <PaperProvider theme={theme}>
        <SettingsProvider>
          <BluetoothProvider>
            <AudioProvider>
              <NavigationContainer>
                <Stack.Navigator 
                  initialRouteName="Home"
                  screenOptions={{
                    headerStyle: {
                      backgroundColor: theme.colors.primary,
                    },
                    headerTintColor: '#fff',
                    headerTitleStyle: {
                      fontWeight: '500',
                    },
                  }}
                >
                  <Stack.Screen 
                    name="Home" 
                    component={HomeScreen} 
                    options={{ title: 'AudioFocus' }} 
                  />
                  <Stack.Screen 
                    name="Settings" 
                    component={SettingsScreen} 
                    options={{ title: 'Settings' }} 
                  />
                </Stack.Navigator>
              </NavigationContainer>
              <StatusBar style="auto" />
              <KeepAwake />
            </AudioProvider>
          </BluetoothProvider>
        </SettingsProvider>
      </PaperProvider>
    </SafeAreaProvider>
  );
}