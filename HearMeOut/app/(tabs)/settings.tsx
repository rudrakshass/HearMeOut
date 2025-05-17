import { Button } from '@/components/ui/Button';
import { Card } from '@/components/ui/Card';
import { GradientBackground } from '@/components/ui/GradientBackground';
import { Colors } from '@/constants/Colors';
import { useColorScheme } from '@/hooks/useColorScheme';
import { Ionicons } from '@expo/vector-icons';
import AsyncStorage from '@react-native-async-storage/async-storage';
import Slider from '@react-native-community/slider';
import * as Haptics from 'expo-haptics';
import { LinearGradient } from 'expo-linear-gradient';
import { useEffect, useState } from 'react';
import {
    Alert,
    ScrollView,
    StyleSheet,
    Switch,
    Text,
    View
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

const APP_VERSION = '1.0.0';

export default function SettingsScreen() {
  const [noiseReduction, setNoiseReduction] = useState(true);
  const [voiceEnhancement, setVoiceEnhancement] = useState(true);
  const [autoAdjust, setAutoAdjust] = useState(false);
  const [filterStrength, setFilterStrength] = useState(5);
  const [autoConnect, setAutoConnect] = useState(false);
  const [isLoading, setIsLoading] = useState(true);
  
  const insets = useSafeAreaInsets();
  const colorScheme = useColorScheme();
  const colors = Colors[colorScheme ?? 'light'];

  // Load settings from AsyncStorage
  useEffect(() => {
    const loadSettings = async () => {
      try {
        const settings = await AsyncStorage.getItem('settings');
        if (settings !== null) {
          const parsedSettings = JSON.parse(settings);
          setNoiseReduction(parsedSettings.noiseReduction ?? true);
          setVoiceEnhancement(parsedSettings.voiceEnhancement ?? true);
          setAutoAdjust(parsedSettings.autoAdjust ?? false);
          setFilterStrength(parsedSettings.filterStrength ?? 5);
          setAutoConnect(parsedSettings.autoConnect ?? false);
        }
      } catch (error) {
        console.error('Failed to load settings:', error);
      } finally {
        setIsLoading(false);
      }
    };

    loadSettings();
  }, []);

  // Save settings to AsyncStorage whenever they change
  useEffect(() => {
    if (isLoading) return; // Don't save during initial load
    
    const saveSettings = async () => {
      try {
        await AsyncStorage.setItem('settings', JSON.stringify({
          noiseReduction,
          voiceEnhancement,
          autoAdjust,
          filterStrength,
          autoConnect,
        }));
      } catch (error) {
        console.error('Failed to save settings:', error);
        Alert.alert('Error', 'Failed to save settings');
      }
    };

    saveSettings();
  }, [noiseReduction, voiceEnhancement, autoAdjust, filterStrength, autoConnect, isLoading]);

  const handleReset = async () => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    
    try {
      await AsyncStorage.removeItem('settings');
      setNoiseReduction(true);
      setVoiceEnhancement(true);
      setAutoAdjust(false);
      setFilterStrength(5);
      setAutoConnect(false);
      
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      Alert.alert('Settings Reset', 'Your settings have been restored to defaults.');
    } catch (error) {
      console.error('Failed to reset settings:', error);
      Alert.alert('Error', 'Failed to reset settings');
    }
  };
  
  const handleToggle = (setting: string, value: boolean) => {
    Haptics.selectionAsync();
    
    switch (setting) {
      case 'noiseReduction':
        setNoiseReduction(value);
        break;
      case 'voiceEnhancement':
        setVoiceEnhancement(value);
        break;
      case 'autoAdjust':
        setAutoAdjust(value);
        break;
      case 'autoConnect':
        setAutoConnect(value);
        break;
    }
  };

  return (
    <GradientBackground variant="secondary" style={styles.container}>
      <ScrollView 
        style={styles.scrollView}
        contentContainerStyle={{ paddingTop: insets.top, paddingBottom: insets.bottom + 20 }}
      >
        {/* Audio Enhancement Section */}
        <Text style={[styles.sectionTitle, { color: colors.text }]}>Audio Enhancement</Text>
        <Card variant="elevated" style={styles.section}>
          <View style={styles.setting}>
            <View style={styles.settingInfo}>
              <Text style={[styles.settingTitle, { color: colors.text }]}>Noise Reduction</Text>
              <Text style={[styles.settingDescription, { color: colors.muted }]}>
                Reduce background noise and distractions
              </Text>
            </View>
            <Switch
              value={noiseReduction}
              onValueChange={(value) => handleToggle('noiseReduction', value)}
              trackColor={{ false: 'rgba(150, 150, 150, 0.4)', true: `${colors.tint}80` }}
              thumbColor={noiseReduction ? colors.tint : '#f4f3f4'}
            />
          </View>

          <View style={styles.divider} />

          <View style={styles.setting}>
            <View style={styles.settingInfo}>
              <Text style={[styles.settingTitle, { color: colors.text }]}>Voice Enhancement</Text>
              <Text style={[styles.settingDescription, { color: colors.muted }]}>
                Enhance speech clarity and volume
              </Text>
            </View>
            <Switch
              value={voiceEnhancement}
              onValueChange={(value) => handleToggle('voiceEnhancement', value)}
              trackColor={{ false: 'rgba(150, 150, 150, 0.4)', true: `${colors.tint}80` }}
              thumbColor={voiceEnhancement ? colors.tint : '#f4f3f4'}
            />
          </View>

          <View style={styles.divider} />

          <View style={styles.setting}>
            <View style={styles.settingInfo}>
              <Text style={[styles.settingTitle, { color: colors.text }]}>Auto-Adjust</Text>
              <Text style={[styles.settingDescription, { color: colors.muted }]}>
                Automatically adjust settings based on environment
              </Text>
            </View>
            <Switch
              value={autoAdjust}
              onValueChange={(value) => handleToggle('autoAdjust', value)}
              trackColor={{ false: 'rgba(150, 150, 150, 0.4)', true: `${colors.tint}80` }}
              thumbColor={autoAdjust ? colors.tint : '#f4f3f4'}
            />
          </View>

          <View style={styles.divider} />

          <View style={styles.sliderSetting}>
            <View style={styles.settingInfo}>
              <Text style={[styles.settingTitle, { color: colors.text }]}>Filter Strength</Text>
              <Text style={[styles.settingDescription, { color: colors.muted }]}>
                Adjust the intensity of audio processing
              </Text>
            </View>
            
            <Text style={[styles.sliderValue, { color: colors.tint }]}>
              {filterStrength}
            </Text>
            
            <View style={styles.sliderContainer}>
              <Slider
                style={styles.slider}
                value={filterStrength}
                onValueChange={(value) => {
                  setFilterStrength(Math.round(value));
                  if (Math.round(value) !== Math.round(filterStrength)) {
                    Haptics.selectionAsync();
                  }
                }}
                minimumValue={1}
                maximumValue={10}
                step={1}
                minimumTrackTintColor={colors.tint}
                maximumTrackTintColor={colorScheme === 'dark' ? '#444' : '#ddd'}
                thumbTintColor={colors.tint}
              />
              <View style={styles.sliderLabels}>
                <Text style={[styles.sliderLabel, { color: colors.muted }]}>Subtle</Text>
                <Text style={[styles.sliderLabel, { color: colors.muted }]}>Strong</Text>
              </View>
            </View>
          </View>
        </Card>

        {/* Bluetooth Section */}
        <Text style={[styles.sectionTitle, { color: colors.text }]}>Bluetooth</Text>
        <Card variant="elevated" style={styles.section}>
          <View style={styles.setting}>
            <View style={styles.settingInfo}>
              <Text style={[styles.settingTitle, { color: colors.text }]}>Auto-Connect</Text>
              <Text style={[styles.settingDescription, { color: colors.muted }]}>
                Automatically connect to known devices
              </Text>
            </View>
            <Switch
              value={autoConnect}
              onValueChange={(value) => handleToggle('autoConnect', value)}
              trackColor={{ false: 'rgba(150, 150, 150, 0.4)', true: `${colors.tint}80` }}
              thumbColor={autoConnect ? colors.tint : '#f4f3f4'}
            />
          </View>
        </Card>

        {/* About Section */}
        <Text style={[styles.sectionTitle, { color: colors.text }]}>About</Text>
        <Card variant="elevated" style={styles.section}>
          <View style={styles.aboutContent}>
            <View style={styles.logoContainer}>
              <LinearGradient
                colors={[colors.tint, colors.accent]}
                style={styles.logoBackground}
                start={{ x: 0, y: 0 }}
                end={{ x: 1, y: 1 }}
              >
                <Ionicons name="ear-outline" size={36} color="#fff" />
              </LinearGradient>
              <Text style={[styles.appName, { color: colors.text }]}>HearMeOut</Text>
              <Text style={[styles.version, { color: colors.muted }]}>Version {APP_VERSION}</Text>
            </View>
            
            <Text style={[styles.aboutText, { color: colors.muted }]}>
              Assistive Audio Companion for Neurodivergent Users
            </Text>
          </View>
        </Card>
        
        {/* Reset Button */}
        <View style={styles.buttonContainer}>
          <Button
            title="Reset All Settings"
            variant="outline"
            icon="refresh-circle-outline"
            onPress={handleReset}
          />
        </View>
      </ScrollView>
    </GradientBackground>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  scrollView: {
    flex: 1,
    paddingHorizontal: 20,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    marginTop: 24,
    marginBottom: 12,
    paddingHorizontal: 4,
  },
  section: {
    marginBottom: 8,
  },
  setting: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: 12,
  },
  divider: {
    height: StyleSheet.hairlineWidth,
    backgroundColor: 'rgba(150, 150, 150, 0.2)',
    marginVertical: 4,
  },
  sliderSetting: {
    paddingVertical: 12,
  },
  settingInfo: {
    flex: 1,
    marginRight: 16,
  },
  settingTitle: {
    fontSize: 16,
    fontWeight: '600',
    marginBottom: 4,
  },
  settingDescription: {
    fontSize: 14,
    lineHeight: 20,
  },
  sliderContainer: {
    marginTop: 12,
    width: '100%',
  },
  slider: {
    width: '100%',
    height: 40,
  },
  sliderValue: {
    textAlign: 'center',
    fontSize: 24,
    fontWeight: 'bold',
    marginTop: 12,
  },
  sliderLabels: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingHorizontal: 4,
  },
  sliderLabel: {
    fontSize: 14,
  },
  aboutContent: {
    alignItems: 'center',
    padding: 16,
  },
  logoContainer: {
    alignItems: 'center',
    marginBottom: 16,
  },
  logoBackground: {
    width: 80,
    height: 80,
    borderRadius: 20,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 12,
  },
  appName: {
    fontSize: 24,
    fontWeight: 'bold',
    marginBottom: 4,
  },
  version: {
    fontSize: 14,
    fontStyle: 'italic',
  },
  aboutText: {
    textAlign: 'center',
    lineHeight: 22,
  },
  buttonContainer: {
    alignItems: 'center',
    marginTop: 32,
    marginBottom: 16,
  },
}); 