import { Colors } from '@/constants/Colors';
import { useColorScheme } from '@/hooks/useColorScheme';
import { Ionicons } from '@expo/vector-icons';
import * as Haptics from 'expo-haptics';
import React from 'react';
import {
    ActivityIndicator,
    Pressable,
    StyleSheet,
    Text,
    TextStyle,
    View,
    ViewStyle
} from 'react-native';

interface ButtonProps {
  onPress: () => void;
  title: string;
  variant?: 'primary' | 'secondary' | 'outline' | 'ghost';
  size?: 'small' | 'medium' | 'large';
  icon?: keyof typeof Ionicons.glyphMap;
  iconPosition?: 'left' | 'right';
  disabled?: boolean;
  loading?: boolean;
  style?: ViewStyle;
  textStyle?: TextStyle;
}

export const Button: React.FC<ButtonProps> = ({
  onPress,
  title,
  variant = 'primary',
  size = 'medium',
  icon,
  iconPosition = 'left',
  disabled = false,
  loading = false,
  style,
  textStyle,
}) => {
  const colorScheme = useColorScheme();
  const colors = Colors[colorScheme ?? 'light'];

  const handlePress = () => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    onPress();
  };

  // Determine button styling based on variant
  const getButtonStyle = () => {
    const baseStyle: ViewStyle = {
      opacity: disabled ? 0.6 : 1,
    };

    switch (variant) {
      case 'primary':
        return {
          ...baseStyle,
          backgroundColor: colors.tint,
        };
      case 'secondary':
        return {
          ...baseStyle,
          backgroundColor: colors.secondary,
        };
      case 'outline':
        return {
          ...baseStyle,
          backgroundColor: 'transparent',
          borderWidth: 1.5,
          borderColor: colors.tint,
        };
      case 'ghost':
        return {
          ...baseStyle,
          backgroundColor: 'transparent',
        };
      default:
        return baseStyle;
    }
  };

  // Determine text color based on variant
  const getTextColor = (): string => {
    switch (variant) {
      case 'primary':
      case 'secondary':
        return '#FFFFFF';
      case 'outline':
      case 'ghost':
        return colors.tint;
      default:
        return colors.text;
    }
  };

  // Determine size styling
  const getSizeStyle = (): ViewStyle => {
    switch (size) {
      case 'small':
        return styles.small;
      case 'large':
        return styles.large;
      default:
        return styles.medium;
    }
  };

  // Determine text size styling
  const getTextSizeStyle = (): TextStyle => {
    switch (size) {
      case 'small':
        return { fontSize: 14 };
      case 'large':
        return { fontSize: 18 };
      default:
        return { fontSize: 16 };
    }
  };

  const buttonStyles = [
    styles.button,
    getSizeStyle(),
    getButtonStyle(),
    style,
  ];

  const textStyles = [
    styles.text,
    getTextSizeStyle(),
    { color: getTextColor() },
    textStyle,
  ];

  const iconSize = size === 'small' ? 16 : size === 'large' ? 24 : 20;
  const iconColor = getTextColor();

  return (
    <Pressable
      onPress={handlePress}
      style={({ pressed }) => [
        buttonStyles,
        pressed && !disabled && styles.pressed,
      ]}
      disabled={disabled || loading}
    >
      <View style={styles.content}>
        {loading ? (
          <ActivityIndicator color={getTextColor()} size="small" />
        ) : (
          <>
            {icon && iconPosition === 'left' && (
              <Ionicons
                name={icon}
                size={iconSize}
                color={iconColor}
                style={styles.iconLeft}
              />
            )}
            <Text style={textStyles}>{title}</Text>
            {icon && iconPosition === 'right' && (
              <Ionicons
                name={icon}
                size={iconSize}
                color={iconColor}
                style={styles.iconRight}
              />
            )}
          </>
        )}
      </View>
    </Pressable>
  );
};

const styles = StyleSheet.create({
  button: {
    borderRadius: 12,
    justifyContent: 'center',
    alignItems: 'center',
  },
  small: {
    paddingVertical: 8,
    paddingHorizontal: 12,
    borderRadius: 8,
  },
  medium: {
    paddingVertical: 12,
    paddingHorizontal: 16,
  },
  large: {
    paddingVertical: 16,
    paddingHorizontal: 24,
  },
  pressed: {
    opacity: 0.8,
    transform: [{ scale: 0.98 }],
  },
  content: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
  },
  text: {
    fontWeight: '600',
    textAlign: 'center',
  },
  iconLeft: {
    marginRight: 8,
  },
  iconRight: {
    marginLeft: 8,
  },
}); 