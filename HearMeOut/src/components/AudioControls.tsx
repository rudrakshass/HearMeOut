import React, { useState, useEffect } from 'react';
import { View, StyleSheet, Animated } from 'react-native';
import { Button, Text, IconButton } from 'react-native-paper';
import { colors } from '../constants/colors';

interface AudioControlsProps {
  isActive: boolean;
  audioLevel: number;
  outputLevel: number;
  onToggle: () => void;
  noiseReductionLevel: number;
  speechEnhancementLevel: number;
}

const AudioControls: React.FC<AudioControlsProps> = ({
  isActive,
  audioLevel,
  outputLevel,
  onToggle,
  noiseReductionLevel,
  speechEnhancementLevel,
}) => {
  // Animation values for audio level meters
  const [inputLevelAnim] = useState(new Animated.Value(0));
  const [outputLevelAnim] = useState(new Animated.Value(0));
  
  // Update animations when levels change
  useEffect(() => {
    Animated.timing(inputLevelAnim, {
      toValue: audioLevel / 100,
      duration: 200,
      useNativeDriver: false,
    }).start();
    
    Animated.timing(outputLevelAnim, {
      toValue: outputLevel / 100,
      duration: 200,
      useNativeDriver: false,
    }).start();
  }, [audioLevel, outputLevel, inputLevelAnim, outputLevelAnim]);
  
  // Calculate reduction percentage
  const reductionPercentage = 
    audioLevel === 0 ? 0 : Math.round((1 - (outputLevel / audioLevel)) * 100);
  
  return (
    <View style={styles.container}>
      {/* Audio Meters */}
      <View style={styles.metersContainer}>
        {/* Input Level Meter */}
        <View style={styles.meterColumn}>
          <Text style={styles.meterLabel}>Input</Text>
          <View style={styles.meter}>
            <Animated.View 
              style={[
                styles.meterFill, 
                {
                  height: inputLevelAnim.interpolate({
                    inputRange: [0, 1],
                    outputRange: ['0%', '100%'],
                  }),
                  backgroundColor: inputLevelAnim.interpolate({
                    inputRange: [0, 0.5, 0.8, 1],
                    outputRange: [colors.primary, colors.primary, colors.warning, colors.error],
                  }),
                }
              ]} 
            />
          </View>
          <Text style={styles.meterValue}>{Math.round(audioLevel)}%</Text>
        </View>
        
        {/* Processing Indicator */}
        <View style={styles.processingIndicator}>
          {isActive ? (
            <View style={styles.processingActive}>
              <IconButton
                icon="arrow-right"
                size={20}
                iconColor={colors.surface}
                style={styles.processingIcon}
              />
            </View>
          ) : (
            <View style={styles.processingInactive}>
              <IconButton
                icon="arrow-right"
                size={20}
                iconColor={colors.textLight}
                style={styles.processingIcon}
              />
            </View>
          )}
        </View>
        
        {/* Output Level Meter */}
        <View style={styles.meterColumn}>
          <Text style={styles.meterLabel}>Output</Text>
          <View style={styles.meter}>
            <Animated.View 
              style={[
                styles.meterFill, 
                {
                  height: outputLevelAnim.interpolate({
                    inputRange: [0, 1],
                    outputRange: ['0%', '100%'],
                  }),
                  backgroundColor: outputLevelAnim.interpolate({
                    inputRange: [0, 0.6, 0.9],
                    outputRange: [colors.secondary, colors.secondary, colors.warning],
                  }),
                }
              ]} 
            />
          </View>
          <Text style={styles.meterValue}>{Math.round(outputLevel)}%</Text>
        </View>
      </View>
      
      {/* Noise Reduction Stats */}
      {isActive && (
        <View style={styles.statsContainer}>
          <Text style={styles.statsLabel}>Noise Reduction:</Text>
          <Text style={styles.statsValue}>{reductionPercentage}%</Text>
        </View>
      )}
      
      {/* Control Button */}
      <Button
        mode={isActive ? "outlined" : "contained"}
        onPress={onToggle}
        style={[
          styles.controlButton,
          isActive ? styles.stopButton : styles.startButton
        ]}
        contentStyle={styles.buttonContent}
        labelStyle={styles.buttonLabel}
        icon={isActive ? "stop" : "play"}
      >
        {isActive ? "Stop Processing" : "Start Processing"}
      </Button>
      
      {/* Processing Settings Info */}
      <View style={styles.settingsInfo}>
        <View style={styles.settingItem}>
          <Text style={styles.settingLabel}>Noise Reduction:</Text>
          <Text style={styles.settingValue}>{noiseReductionLevel}%</Text>
        </View>
        <View style={styles.settingItem}>
          <Text style={styles.settingLabel}>Speech Enhancement:</Text>
          <Text style={styles.settingValue}>{speechEnhancementLevel}%</Text>
        </View>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    marginTop: 16,
  },
  metersContainer: {
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    height: 150,
    marginBottom: 16,
  },
  meterColumn: {
    alignItems: 'center',
    width: 50,
  },
  meterLabel: {
    fontSize: 12,
    marginBottom: 4,
    color: colors.textLight,
  },
  meter: {
    height: 100,
    width: 15,
    backgroundColor: colors.divider,
    borderRadius: 8,
    overflow: 'hidden',
    justifyContent: 'flex-end',
  },
  meterFill: {
    width: '100%',
    backgroundColor: colors.primary,
    position: 'absolute',
    bottom: 0,
    borderRadius: 8,
  },
  meterValue: {
    fontSize: 12,
    marginTop: 4,
    color: colors.text,
  },
  processingIndicator: {
    width: 40,
    alignItems: 'center',
    justifyContent: 'center',
  },
  processingActive: {
    backgroundColor: colors.primary,
    borderRadius: 20,
    width: 40,
    height: 40,
    justifyContent: 'center',
    alignItems: 'center',
  },
  processingInactive: {
    backgroundColor: colors.disabled,
    borderRadius: 20,
    width: 40,
    height: 40,
    justifyContent: 'center',
    alignItems: 'center',
  },
  processingIcon: {
    margin: 0,
  },
  statsContainer: {
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 16,
  },
  statsLabel: {
    fontSize: 14,
    color: colors.textLight,
    marginRight: 8,
  },
  statsValue: {
    fontSize: 16,
    fontWeight: '600',
    color: colors.primary,
  },
  controlButton: {
    marginVertical: 16,
    borderRadius: 24,
    elevation: 2,
  },
  buttonContent: {
    height: 48,
  },
  buttonLabel: {
    fontSize: 16,
    fontWeight: '500',
  },
  startButton: {
    backgroundColor: colors.primary,
  },
  stopButton: {
    borderColor: colors.primary,
    borderWidth: 2,
  },
  settingsInfo: {
    marginTop: 8,
  },
  settingItem: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 4,
  },
  settingLabel: {
    color: colors.textLight,
  },
  settingValue: {
    fontWeight: '500',
  },
});

export default AudioControls;