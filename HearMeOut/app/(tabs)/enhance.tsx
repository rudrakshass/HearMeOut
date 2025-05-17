import { AudioVisualizer } from '@/components/AudioVisualizer';
import { Card } from '@/components/ui/Card';
import { GradientBackground } from '@/components/ui/GradientBackground';
import { Colors } from '@/constants/Colors';
import { useAudioProcessor } from '@/hooks/useAudioProcessor';
import { useAudioVisualization } from '@/hooks/useAudioVisualization';
import { useColorScheme } from '@/hooks/useColorScheme';
import { Ionicons } from '@expo/vector-icons';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { Audio } from 'expo-av';
import * as Haptics from 'expo-haptics';
import { LinearGradient } from 'expo-linear-gradient';
import { useEffect, useRef, useState } from 'react';
import {
    Alert,
    Animated,
    StyleSheet,
    Switch,
    Text,
    View,
    ViewStyle,
    useWindowDimensions
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

export default function EnhanceAudioScreen() {
  const [isEnhancing, setIsEnhancing] = useState(false);
  const [hasPermission, setHasPermission] = useState<boolean | null>(null);
  const [recording, setRecording] = useState<Audio.Recording | null>(null);
  const [filterStrength, setFilterStrength] = useState(5);
  const [frequencyData, setFrequencyData] = useState<number[] | undefined>(undefined);
  
  // Animation refs
  const pulseAnim = useRef(new Animated.Value(1)).current;
  const waveAnim = useRef(new Animated.Value(0)).current;
  
  const insets = useSafeAreaInsets();
  const colorScheme = useColorScheme();
  const colors = Colors[colorScheme ?? 'light'];
  const { width } = useWindowDimensions();

  const audioProcessor = useAudioProcessor({
    onStatusChange: (status) => {
      if (status === 'error') {
        setIsEnhancing(false);
      }
    },
    onAudioData: (data) => {
      setFrequencyData(data);
    }
  });
  
  // Get visualization data
  const visualizationData = useAudioVisualization(
    isEnhancing && audioProcessor.status === 'listening', 
    filterStrength,
    frequencyData
  );

  // Load saved filter strength
  useEffect(() => {
    const loadSettings = async () => {
      try {
        const settings = await AsyncStorage.getItem('settings');
        if (settings !== null) {
          const parsedSettings = JSON.parse(settings);
          if (parsedSettings.filterStrength) {
            setFilterStrength(parsedSettings.filterStrength);
          }
        }
      } catch (error) {
        console.error('Failed to load settings:', error);
      }
    };
    
    loadSettings();
  }, []);

  // Start pulse animation when processing
  useEffect(() => {
    let pulseAnimation: Animated.CompositeAnimation | null = null;
    let waveAnimation: Animated.CompositeAnimation | null = null;
    
    if (isEnhancing) {
      pulseAnimation = Animated.loop(
        Animated.sequence([
          Animated.timing(pulseAnim, {
            toValue: 1.2,
            duration: 1000,
            useNativeDriver: true,
          }),
          Animated.timing(pulseAnim, {
            toValue: 1,
            duration: 1000,
            useNativeDriver: true,
          }),
        ])
      );
      pulseAnimation.start();
      
      // Wave animation
      waveAnimation = Animated.loop(
        Animated.timing(waveAnim, {
          toValue: 1,
          duration: 2000,
          useNativeDriver: false,
        })
      );
      waveAnimation.start();
    } else {
      pulseAnim.setValue(1);
      waveAnim.setValue(0);
    }
    
    return () => {
      if (pulseAnimation) {
        pulseAnimation.stop();
      }
      if (waveAnimation) {
        waveAnimation.stop();
      }
    };
  }, [isEnhancing, pulseAnim, waveAnim]);

  // Cleanup recording on unmount
  useEffect(() => {
    return () => {
      if (recording) {
        // Use try-catch to handle the possibility of already unloaded recording
        try {
          recording.stopAndUnloadAsync();
        } catch (err) {
          console.log('Recording was already unloaded or not active');
        }
      }
    };
  }, [recording]);

  useEffect(() => {
    checkPermissions();
  }, []);

  const checkPermissions = async () => {
    try {
      const { status: existingStatus } = await Audio.getPermissionsAsync();
      let finalStatus = existingStatus;

      if (existingStatus !== 'granted') {
        const { status } = await Audio.requestPermissionsAsync();
        finalStatus = status;
      }

      setHasPermission(finalStatus === 'granted');
      if (finalStatus !== 'granted') {
        Alert.alert(
          'Permission Required',
          'Please grant microphone access to use audio enhancement features.',
          [{ text: 'OK' }]
        );
      }
    } catch (err) {
      console.warn('Error checking permissions:', err);
      Alert.alert('Error', 'Failed to check microphone permissions');
    }
  };

  const startAudioCapture = async () => {
    try {
      if (!hasPermission) {
        await checkPermissions();
        return;
      }

      // Clean up any existing recording first
      if (recording) {
        try {
          await recording.stopAndUnloadAsync();
        } catch (err) {
          console.log('Recording was already unloaded or not active');
        } finally {
          // Always clear the reference even if there was an error
          setRecording(null);
        }
      }

      await Audio.setAudioModeAsync({
        allowsRecordingIOS: true,
        playsInSilentModeIOS: true,
      });

      const { recording: newRecording } = await Audio.Recording.createAsync(
        Audio.RecordingOptionsPresets.HIGH_QUALITY
      );

      setRecording(newRecording);
      await audioProcessor.startProcessing();
      
      // Provide haptic feedback
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);

    } catch (err) {
      console.error('Failed to start recording', err);
      Alert.alert('Error', 'Failed to start audio capture');
      setIsEnhancing(false);
      
      // Provide error feedback
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
      
      // Ensure recording is cleaned up on error
      if (recording) {
        try {
          await recording.stopAndUnloadAsync();
        } catch (cleanupErr) {
          console.error('Error cleaning up recording:', cleanupErr);
        } finally {
          setRecording(null);
        }
      }
    }
  };

  const stopAudioCapture = async () => {
    try {
      let needsCleanup = false;
      
      if (recording) {
        try {
          await recording.stopAndUnloadAsync();
          needsCleanup = true;
        } catch (err) {
          console.log('Recording was already unloaded or not active');
        } finally {
          // Always clear the reference even if there was an error
          setRecording(null);
        }
      }
      
      audioProcessor.stopProcessing();
      
      // Reset frequency data when stopping
      setFrequencyData(undefined);
      
      // Only provide success feedback if we actually had a recording to stop
      if (needsCleanup) {
        // Provide haptic feedback
        Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      }
    } catch (err) {
      console.error('Failed to stop recording:', err);
      // Still try to clean up even if there's an error
      setRecording(null);
      audioProcessor.stopProcessing();
      
      // Provide error feedback
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
    }
  };

  const handleToggle = async (value: boolean) => {
    if (value === isEnhancing) return; // Prevent duplicate toggles
    
    setIsEnhancing(value);
    try {
      if (value) {
        await startAudioCapture();
      } else {
        await stopAudioCapture();
      }
    } catch (err) {
      console.error('Error toggling audio enhancement:', err);
      setIsEnhancing(false);
      await stopAudioCapture();
    }
  };

  const getStatusStyle = (status: string): ViewStyle => {
    const styles = {
      idle: { backgroundColor: colors.muted },
      initializing: { backgroundColor: colors.warning },
      listening: { backgroundColor: colors.success },
      processing: { backgroundColor: colors.tint },
      error: { backgroundColor: colors.error },
    };
    return styles[status.toLowerCase() as keyof typeof styles] || styles.idle;
  };

  const getStatusLabel = (status: string): string => {
    switch (status.toLowerCase()) {
      case 'idle': return 'Ready';
      case 'initializing': return 'Starting...';
      case 'listening': return 'Listening';
      case 'processing': return 'Enhancing';
      case 'error': return 'Error';
      default: return status;
    }
  };

  // Create wave patterns
  const waves = Array(6).fill(0).map((_, i) => {
    const inputRange = [0, 0.5, 1];
    const heightPercent = [0.2, 0.8, 0.2]; // Height pattern
    const scaleYOutputRange = heightPercent.map(p => p * (1 + i * 0.3));
    
    return {
      scaleY: waveAnim.interpolate({
        inputRange,
        outputRange: scaleYOutputRange,
      }),
      translateX: (-10 + i * 20),
    };
  });

  return (
    <GradientBackground variant="primary" style={styles.container}>
      <View style={[styles.mainContent, { paddingTop: insets.top }]}>
        {/* Status Section */}
        <Card variant="elevated" style={styles.statusContainer}>
          <Text style={[styles.statusLabel, { color: colors.muted }]}>Status</Text>
          <View style={[styles.statusBadge, getStatusStyle(audioProcessor.status)]}>
            <Text style={styles.statusText}>{getStatusLabel(audioProcessor.status)}</Text>
          </View>
          {audioProcessor.error && (
            <Text style={[styles.errorText, { color: colors.error }]}>
              {audioProcessor.error}
            </Text>
          )}
        </Card>

        {/* Main Controls */}
        <View style={styles.controlsContainer}>
          <Animated.View style={{ transform: [{ scale: pulseAnim }] }}>
            <LinearGradient
              colors={[colors.tint, colors.accent]}
              style={styles.enhanceButton}
            >
              <Switch
                value={isEnhancing}
                onValueChange={handleToggle}
                trackColor={{ false: 'rgba(150, 150, 150, 0.4)', true: 'rgba(255, 255, 255, 0.3)' }}
                thumbColor={isEnhancing ? '#ffffff' : '#f4f3f4'}
                style={styles.switch}
                disabled={hasPermission === false}
              />
            </LinearGradient>
          </Animated.View>
          <Text style={[styles.toggleLabel, { color: colors.text }]}>
            {isEnhancing ? 'Enhancement Active' : 'Start Enhancement'}
          </Text>
        </View>

        {/* Visualization */}
        <Card variant="elevated" style={styles.visualizationContainer}>
          <View style={styles.visualizationContent}>
            {isEnhancing ? (
              <AudioVisualizer 
                data={visualizationData}
                isActive={isEnhancing && audioProcessor.status === 'listening'}
                primaryColor={colors.tint}
                secondaryColor={colors.accent}
                barWidth={4}
                barSpacing={3}
              />
            ) : (
              <View style={styles.visualizationPlaceholder}>
                <Ionicons 
                  name="pulse" 
                  size={48} 
                  color={colors.muted} 
                />
                <Text style={[styles.visualizationText, { color: colors.muted }]}>
                  Audio Visualization
                </Text>
              </View>
            )}
          </View>
        </Card>

        {/* Helper Text */}
        <Card variant="outlined" style={styles.helperCard}>
          <Text style={[styles.helperText, { color: colors.text }]}>
            {hasPermission === false 
              ? 'Microphone access is required for audio enhancement'
              : audioProcessor.error 
                ? 'An error occurred. Please try again.'
                : isEnhancing
                  ? 'Audio enhancement is active. Real-time audio is being visualized.'
                  : 'Toggle the switch to start enhancing audio from your surroundings'}
          </Text>
        </Card>
        
        {/* Features Card */}
        {!isEnhancing && (
          <Card variant="elevated" style={styles.featuresCard}>
            <Text style={[styles.featuresTitle, { color: colors.text }]}>
              Features
            </Text>
            
            <View style={styles.featureItem}>
              <Ionicons name="volume-high" size={24} color={colors.tint} />
              <Text style={[styles.featureText, { color: colors.text }]}>
                Voice Enhancement
              </Text>
            </View>
            
            <View style={styles.featureItem}>
              <Ionicons name="volume-mute" size={24} color={colors.tint} />
              <Text style={[styles.featureText, { color: colors.text }]}>
                Background Noise Reduction
              </Text>
            </View>
            
            <View style={styles.featureItem}>
              <Ionicons name="ear" size={24} color={colors.tint} />
              <Text style={[styles.featureText, { color: colors.text }]}>
                Frequency Optimization
              </Text>
            </View>
            
            <View style={styles.featureItem}>
              <Ionicons name="analytics" size={24} color={colors.tint} />
              <Text style={[styles.featureText, { color: colors.text }]}>
                Real-time Audio Visualization
              </Text>
            </View>
          </Card>
        )}
      </View>
    </GradientBackground>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  mainContent: {
    flex: 1,
    padding: 20,
  },
  statusContainer: {
    alignItems: 'center',
    padding: 16,
    marginBottom: 20,
  },
  statusLabel: {
    fontSize: 16,
    marginBottom: 8,
  },
  statusBadge: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 20,
    minWidth: 120,
    alignItems: 'center',
  },
  statusText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
  errorText: {
    fontSize: 14,
    marginTop: 12,
    textAlign: 'center',
  },
  controlsContainer: {
    width: '100%',
    alignItems: 'center',
    marginBottom: 24,
  },
  enhanceButton: {
    width: 120,
    height: 120,
    borderRadius: 60,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 16,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 8,
    elevation: 8,
  },
  switch: {
    transform: [{ scaleX: 1.5 }, { scaleY: 1.5 }],
  },
  toggleLabel: {
    fontSize: 18,
    fontWeight: '600',
    marginTop: 8,
  },
  visualizationContainer: {
    width: '100%',
    height: 200,
    marginBottom: 20,
    overflow: 'hidden',
    padding: 0,
    justifyContent: 'center',
    alignItems: 'center',
  },
  visualizationContent: {
    flex: 1,
    width: '100%',
    justifyContent: 'center',
    alignItems: 'center',
  },
  visualizationPlaceholder: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  visualizationText: {
    marginTop: 12,
    fontSize: 14,
  },
  helperCard: {
    marginBottom: 20,
  },
  helperText: {
    fontSize: 16,
    textAlign: 'center',
    lineHeight: 22,
  },
  featuresCard: {
    padding: 20,
  },
  featuresTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    marginBottom: 16,
  },
  featureItem: {
    flexDirection: 'row',
    alignItems: 'center',
    marginVertical: 8,
  },
  featureText: {
    fontSize: 16,
    marginLeft: 12,
  },
}); 