import { Colors } from '@/constants/Colors';
import { useColorScheme } from '@/hooks/useColorScheme';
import React from 'react';
import { StyleSheet, View, ViewProps, ViewStyle } from 'react-native';

interface CardProps extends ViewProps {
  style?: ViewStyle;
  variant?: 'default' | 'elevated' | 'outlined';
}

export const Card: React.FC<CardProps> = ({ 
  children, 
  style,
  variant = 'default', 
  ...props 
}) => {
  const colorScheme = useColorScheme();
  const colors = Colors[colorScheme ?? 'light'];

  const cardStyles = [
    styles.card,
    { backgroundColor: colors.cardBackground },
    variant === 'elevated' && [
      styles.elevated, 
      { 
        shadowColor: colors.shadow,
        backgroundColor: colorScheme === 'dark' ? colors.subtle : colors.background, 
      }
    ],
    variant === 'outlined' && [
      styles.outlined, 
      { borderColor: colors.divider }
    ],
    style,
  ];

  return (
    <View style={cardStyles} {...props}>
      {children}
    </View>
  );
};

const styles = StyleSheet.create({
  card: {
    borderRadius: 16,
    padding: 16,
    marginVertical: 8,
  },
  elevated: {
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.8,
    shadowRadius: 8,
    elevation: 4,
  },
  outlined: {
    borderWidth: 1,
  },
}); 