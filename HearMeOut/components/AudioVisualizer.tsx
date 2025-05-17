import { Colors } from '@/constants/Colors';
import { VisualizationData } from '@/hooks/useAudioVisualization';
import { useColorScheme } from '@/hooks/useColorScheme';
import React, { useEffect, useRef } from 'react';
import { Animated, StyleSheet, View, ViewStyle } from 'react-native';

interface AudioVisualizerProps {
  data: VisualizationData;
  isActive: boolean;
  style?: ViewStyle;
  barStyle?: ViewStyle;
  barWidth?: number;
  barSpacing?: number;
  primaryColor?: string;
  secondaryColor?: string;
  mirror?: boolean;
}

export const AudioVisualizer: React.FC<AudioVisualizerProps> = ({
  data,
  isActive,
  style,
  barStyle,
  barWidth = 3,
  barSpacing = 2,
  primaryColor,
  secondaryColor,
  mirror = true
}) => {
  const colorScheme = useColorScheme();
  const colors = Colors[colorScheme ?? 'light'];
  
  // Use provided colors or defaults
  const barColor = primaryColor || colors.tint;
  const altColor = secondaryColor || colors.accent;
  
  // Animation value for the entire visualizer
  const bounceAnim = useRef(new Animated.Value(0)).current;
  
  // Start bounce animation when active
  useEffect(() => {
    let animationLoop: Animated.CompositeAnimation | null = null;
    
    if (isActive) {
      animationLoop = Animated.loop(
        Animated.sequence([
          Animated.timing(bounceAnim, {
            toValue: 1,
            duration: 800,
            useNativeDriver: true,
          }),
          Animated.timing(bounceAnim, {
            toValue: 0,
            duration: 800,
            useNativeDriver: true,
          }),
        ])
      );
      animationLoop.start();
    } else {
      bounceAnim.setValue(0);
    }
    
    return () => {
      if (animationLoop) {
        animationLoop.stop();
      }
    };
  }, [isActive, bounceAnim]);
  
  // Scale animation for the container
  const containerScale = bounceAnim.interpolate({
    inputRange: [0, 1],
    outputRange: [1, 1.02]
  });
  
  // Base styles for visualization bars
  const getBarStyle = (value: number, index: number) => {
    // Calculate color based on height and position
    const heightPercent = value; // 0-1 range
    const colorInterpolation = heightPercent;
    
    // Create different patterns based on position
    const isCenter = index > data.bars.length * 0.4 && index < data.bars.length * 0.6;
    const isSide = index < data.bars.length * 0.2 || index > data.bars.length * 0.8;
    
    // Apply different color and animation patterns
    const backgroundColor = isCenter 
      ? barColor 
      : isSide 
        ? barColor 
        : mixColors(barColor, altColor, colorInterpolation);
    
    return {
      width: barWidth,
      height: `${value * 100}%`,
      backgroundColor,
      marginHorizontal: barSpacing / 2,
      borderRadius: barWidth / 2,
    };
  };
  
  // Helper to mix colors based on a ratio
  const mixColors = (color1: string, color2: string, ratio: number) => {
    // Simple color mixing for demo purposes
    return ratio > 0.5 ? color1 : color2;
  };
  
  return (
    <Animated.View 
      style={[
        styles.container, 
        { transform: [{ scale: containerScale }] },
        style
      ]}
    >
      <View style={styles.visualizer}>
        {data.bars.map((value, index) => (
          <View
            key={`bar-${index}`}
            style={[
              styles.barContainer,
              { height: mirror ? '50%' : '100%' }
            ]}
          >
            <Animated.View
              style={[
                styles.bar,
                getBarStyle(value, index),
                barStyle
              ]}
            />
            
            {/* Mirrored bar if enabled */}
            {mirror && (
              <Animated.View
                style={[
                  styles.bar,
                  getBarStyle(value * 0.7, index), // slightly shorter
                  styles.mirroredBar,
                  barStyle
                ]}
              />
            )}
          </View>
        ))}
      </View>
    </Animated.View>
  );
};

const styles = StyleSheet.create({
  container: {
    width: '100%',
    height: '100%',
    justifyContent: 'center',
    alignItems: 'center',
    overflow: 'hidden',
  },
  visualizer: {
    width: '100%',
    height: '100%',
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
  },
  barContainer: {
    justifyContent: 'flex-end',
    alignItems: 'center',
  },
  bar: {
    width: 3,
    backgroundColor: '#26C6AD',
  },
  mirroredBar: {
    transform: [{ scaleY: -1 }],
    opacity: 0.5,
  },
}); 