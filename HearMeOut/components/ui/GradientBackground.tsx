import { Colors } from '@/constants/Colors';
import { useColorScheme } from '@/hooks/useColorScheme';
import { LinearGradient } from 'expo-linear-gradient';
import React, { ReactNode } from 'react';
import { StyleSheet, ViewStyle } from 'react-native';

interface GradientBackgroundProps {
  children: ReactNode;
  variant?: 'default' | 'primary' | 'secondary';
  style?: ViewStyle;
}

export const GradientBackground: React.FC<GradientBackgroundProps> = ({
  children,
  variant = 'default',
  style,
}) => {
  const colorScheme = useColorScheme();
  const colors = Colors[colorScheme ?? 'light'];
  
  const getGradientColors = () => {
    switch (variant) {
      case 'primary':
        return colorScheme === 'dark'
          ? ['#0D1B24', '#162733']
          : ['#F8FBFD', '#EDF4F7'];
      case 'secondary':
        return colorScheme === 'dark'
          ? ['#162733', '#0D1B24']
          : ['#E8F5F3', '#F8FBFD'];
      default:
        return colorScheme === 'dark'
          ? [colors.background, colors.subtle]
          : [colors.background, colors.subtle];
    }
  };
  
  return (
    <LinearGradient
      colors={getGradientColors()}
      style={[styles.gradient, style]}
      start={{ x: 0, y: 0 }}
      end={{ x: 1, y: 1 }}
    >
      {children}
    </LinearGradient>
  );
};

const styles = StyleSheet.create({
  gradient: {
    flex: 1,
  },
}); 