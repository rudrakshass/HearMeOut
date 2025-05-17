import React from 'react';
import { View, StyleSheet, ScrollView, Alert } from 'react-native';
import { 
  Button, 
  Card, 
  Title, 
  Text, 
  Switch,
  Divider,
  List,
  RadioButton
} from 'react-native-paper';
import Slider from '@react-native-community/slider';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useNavigation } from '@react-navigation/native';

// Import hooks
import { useSettings } from '../contexts/SettingsContext';
import { useAudio } from '../contexts/AudioContext';

// Import constants
import { colors } from '../constants/colors';

const SettingsScreen: React.FC = () => {
  const navigation = useNavigation();
  const { settings, updateSetting, resetSettings } = useSettings();
  const { processingState, stopProcessing } = useAudio();
  
  // Handle settings reset
  const handleResetSettings = () => {
    Alert.alert(
      'Reset Settings',
      'Are you sure you want to reset all settings to default values?',
      [
        {
          text: 'Cancel',
          style: 'cancel',
        },
        {
          text: 'Reset',
          onPress: async () => {
            // Stop processing if active
            if (processingState === 'processing' || processingState === 'paused') {
              await stopProcessing();
            }
            
            // Reset settings
            resetSettings();
          },
          style: 'destructive',
        },
      ]
    );
  };
  
  // Latency options
  const latencyOptions = [
    { value: 'low', label: 'Low (Higher Quality)' },
    { value: 'balanced', label: 'Balanced' },
    { value: 'high', label: 'High (Lower Quality)' },
  ];
  
  // Model type options
  const modelOptions = [
    { value: 'rnnoise', label: 'RNNoise (Lowest CPU usage)' },
    { value: 'deepfilternet', label: 'DeepFilterNet v2 (Balanced)' },
    { value: 'demucs', label: 'Demucs (Highest quality, high CPU usage)' },
  ];
  
  return (
    <SafeAreaView style={styles.container}>
      <ScrollView contentContainerStyle={styles.scrollContent}>
        {/* Audio Processing Settings Card */}
        <Card style={styles.card}>
          <Card.Content>
            <Title>Audio Processing</Title>
            
            {/* Noise Reduction Level */}
            <View style={styles.sliderContainer}>
              <View style={styles.sliderHeader}>
                <Text>Noise Reduction Level</Text>
                <Text>{`${settings.noiseReductionLevel}%`}</Text>
              </View>
              <Slider
                value={settings.noiseReductionLevel}
                onValueChange={(value:any) => updateSetting('noiseReductionLevel', value)}
                minimumValue={0}
                maximumValue={100}
                step={1}
                minimumTrackTintColor={colors.primary}
                maximumTrackTintColor={colors.divider}
                thumbTintColor={colors.primary}
                style={styles.slider}
              />
              <View style={styles.sliderLabels}>
                <Text style={styles.sliderLabel}>Minimal</Text>
                <Text style={styles.sliderLabel}>Maximum</Text>
              </View>
            </View>
            
            {/* Speech Enhancement Level */}
            <View style={styles.sliderContainer}>
              <View style={styles.sliderHeader}>
                <Text>Speech Enhancement Level</Text>
                <Text>{`${settings.speechEnhancementLevel}%`}</Text>
              </View>
              <Slider
                value={settings.speechEnhancementLevel}
                onValueChange={(value:any) => updateSetting('speechEnhancementLevel', value)}
                minimumValue={0}
                maximumValue={100}
                step={1}
                minimumTrackTintColor={colors.primary}
                maximumTrackTintColor={colors.divider}
                thumbTintColor={colors.primary}
                style={styles.slider}
              />
              <View style={styles.sliderLabels}>
                <Text style={styles.sliderLabel}>Minimal</Text>
                <Text style={styles.sliderLabel}>Maximum</Text>
              </View>
            </View>
            
            {/* Processing Latency */}
            <View style={styles.sectionHeader}>
              <Text>Processing Latency</Text>
              <Text style={styles.sectionSubtitle}>
                Balance between quality and responsiveness
              </Text>
            </View>
            <RadioButton.Group
              onValueChange={(value) => 
                updateSetting('processingLatency', value as 'low' | 'balanced' | 'high')
              }
              value={settings.processingLatency}
            >
              {latencyOptions.map((option) => (
                <RadioButton.Item
                  key={option.value}
                  label={option.label}
                  value={option.value}
                  color={colors.primary}
                  style={styles.radioItem}
                />
              ))}
            </RadioButton.Group>
          </Card.Content>
        </Card>
        
        {/* Bluetooth Settings Card */}
        <Card style={styles.card}>
          <Card.Content>
            <Title>Bluetooth Settings</Title>
            
            {/* Auto Connect */}
            <List.Item
              title="Auto-connect to last device"
              description="Automatically connect to the last used headphones"
              right={() => (
                <Switch
                  value={settings.autoConnect}
                  onValueChange={(value) => updateSetting('autoConnect', value)}
                  color={colors.primary}
                />
              )}
            />
            
            <Divider style={styles.divider} />
            
            {/* Haptic Feedback */}
            <List.Item
              title="Haptic Feedback"
              description="Vibrate on connection events"
              right={() => (
                <Switch
                  value={settings.hapticFeedback}
                  onValueChange={(value) => updateSetting('hapticFeedback', value)}
                  color={colors.primary}
                />
              )}
            />
          </Card.Content>
        </Card>
        
        {/* Model Selection Card */}
        <Card style={styles.card}>
          <Card.Content>
            <Title>AI Model Selection</Title>
            <Text style={styles.sectionSubtitle}>
              Choose the processing model based on your device's performance
            </Text>
            
            <RadioButton.Group
              onValueChange={(value) => 
                updateSetting('modelType', value as 'rnnoise' | 'deepfilternet' | 'demucs')
              }
              value={settings.modelType}
            >
              {modelOptions.map((option) => (
                <RadioButton.Item
                  key={option.value}
                  label={option.label}
                  value={option.value}
                  color={colors.primary}
                  style={styles.radioItem}
                />
              ))}
            </RadioButton.Group>
          </Card.Content>
        </Card>
        
        {/* UI Settings Card */}
        <Card style={styles.card}>
          <Card.Content>
            <Title>UI Settings</Title>
            
            {/* Theme Selection */}
            <View style={styles.sectionHeader}>
              <Text>Theme</Text>
            </View>
            <RadioButton.Group
              onValueChange={(value) => 
                updateSetting('theme', value as 'light' | 'dark' | 'system')
              }
              value={settings.theme}
            >
              <RadioButton.Item
                label="Light"
                value="light"
                color={colors.primary}
                style={styles.radioItem}
              />
              <RadioButton.Item
                label="Dark"
                value="dark"
                color={colors.primary}
                style={styles.radioItem}
              />
              <RadioButton.Item
                label="System Default"
                value="system"
                color={colors.primary}
                style={styles.radioItem}
              />
            </RadioButton.Group>
          </Card.Content>
        </Card>
        
        {/* Debug Settings Card */}
        <Card style={styles.card}>
          <Card.Content>
            <Title>Advanced</Title>
            
            {/* Debug Mode */}
            <List.Item
              title="Debug Mode"
              description="Show additional technical information"
              right={() => (
                <Switch
                  value={settings.debugMode}
                  onValueChange={(value) => updateSetting('debugMode', value)}
                  color={colors.primary}
                />
              )}
            />
            
            <Divider style={styles.divider} />
            
            {/* Reset Button */}
            <Button 
              mode="outlined" 
              onPress={handleResetSettings}
              style={styles.resetButton}
              color={colors.error}
            >
              Reset All Settings
            </Button>
          </Card.Content>
        </Card>
      </ScrollView>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.background,
  },
  scrollContent: {
    padding: 16,
    paddingBottom: 32,
  },
  card: {
    marginBottom: 16,
    elevation: 2,
    borderRadius: 8,
  },
  sliderContainer: {
    marginVertical: 16,
  },
  sliderHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  slider: {
    width: '100%',
    height: 40,
  },
  sliderLabels: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingHorizontal: 4,
  },
  sliderLabel: {
    fontSize: 12,
    color: colors.textLight,
  },
  divider: {
    marginVertical: 8,
  },
  sectionHeader: {
    marginTop: 16,
    marginBottom: 8,
  },
  sectionSubtitle: {
    fontSize: 12,
    color: colors.textLight,
    marginTop: 4,
  },
  radioItem: {
    paddingVertical: 4,
  },
  resetButton: {
    marginTop: 16,
    borderColor: colors.error,
  },
});

export default SettingsScreen;