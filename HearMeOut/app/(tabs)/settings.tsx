import { useState } from 'react';
import { ScrollView, StyleSheet, Switch, Text, View } from 'react-native';

export default function SettingsScreen() {
  const [noiseReduction, setNoiseReduction] = useState(true);
  const [voiceEnhancement, setVoiceEnhancement] = useState(true);
  const [autoAdjust, setAutoAdjust] = useState(false);

  return (
    <ScrollView style={styles.container}>
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Audio Enhancement</Text>
        
        <View style={styles.setting}>
          <View style={styles.settingInfo}>
            <Text style={styles.settingTitle}>Noise Reduction</Text>
            <Text style={styles.settingDescription}>Reduce background noise and distractions</Text>
          </View>
          <Switch
            value={noiseReduction}
            onValueChange={setNoiseReduction}
            trackColor={{ false: '#767577', true: '#81c784' }}
            thumbColor={noiseReduction ? '#4caf50' : '#f4f3f4'}
          />
        </View>

        <View style={styles.setting}>
          <View style={styles.settingInfo}>
            <Text style={styles.settingTitle}>Voice Enhancement</Text>
            <Text style={styles.settingDescription}>Enhance speech clarity and volume</Text>
          </View>
          <Switch
            value={voiceEnhancement}
            onValueChange={setVoiceEnhancement}
            trackColor={{ false: '#767577', true: '#81c784' }}
            thumbColor={voiceEnhancement ? '#4caf50' : '#f4f3f4'}
          />
        </View>

        <View style={styles.setting}>
          <View style={styles.settingInfo}>
            <Text style={styles.settingTitle}>Auto-Adjust</Text>
            <Text style={styles.settingDescription}>Automatically adjust settings based on environment</Text>
          </View>
          <Switch
            value={autoAdjust}
            onValueChange={setAutoAdjust}
            trackColor={{ false: '#767577', true: '#81c784' }}
            thumbColor={autoAdjust ? '#4caf50' : '#f4f3f4'}
          />
        </View>
      </View>

      <View style={styles.section}>
        <Text style={styles.sectionTitle}>About</Text>
        <Text style={styles.version}>HearMeOut v1.0.0</Text>
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#fff',
  },
  section: {
    padding: 16,
    borderBottomWidth: 1,
    borderBottomColor: '#eee',
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    marginBottom: 16,
    color: '#2e7d32',
  },
  setting: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 20,
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
    color: '#666',
  },
  version: {
    fontSize: 14,
    color: '#666',
    fontStyle: 'italic',
  },
}); 