import { DefaultTheme } from 'react-native-paper';

// Color palette designed for users with sensory sensitivity
// Using calm, muted colors with sufficient contrast

export const colors = {
  // Primary colors
  primary: '#4A6FA5', // Muted blue
  primaryLight: '#6B8CB5',
  primaryDark: '#345286',
  
  // Secondary colors
  secondary: '#5D937F', // Muted teal
  secondaryLight: '#7EA999',
  secondaryDark: '#426E5C',
  
  // Accent colors
  accent: '#A57B4A', // Warm muted orange
  accentLight: '#BF9A73',
  accentDark: '#86602D',
  
  // Background colors
  background: '#F9F9F9', // Off-white
  surface: '#FFFFFF',
  card: '#F0F4F8',
  
  // Text colors
  text: '#333333',
  textLight: '#666666',
  textDisabled: '#999999',
  
  // Status colors
  success: '#4CAF50', // Green
  warning: '#FF9800', // Orange
  error: '#E57373', // Light red (less intense than standard red)
  info: '#64B5F6', // Light blue
  
  // UI colors
  divider: '#E0E0E0',
  disabled: '#E0E0E0',
  placeholder: '#BDBDBD',
  
  // Control states
  active: '#4A6FA5',
  inactive: '#BDBDBD',
  
  // Status indicators for connections
  connected: '#66BB6A',
  disconnected: '#E0E0E0',
  processing: '#7986CB',
  
  // Shadows
  shadow: 'rgba(0, 0, 0, 0.1)',
};

// Create a theme for react-native-paper
export const theme = {
  ...DefaultTheme,
  colors: {
    ...DefaultTheme.colors,
    primary: colors.primary,
    accent: colors.accent,
    background: colors.background,
    surface: colors.surface,
    text: colors.text,
    error: colors.error,
    disabled: colors.disabled,
    placeholder: colors.placeholder,
    backdrop: colors.shadow,
  },
  roundness: 8,
  animation: {
    scale: 1.0,
  },
};

// Export specific color combinations for different UI states
export const uiStates = {
  // Processing states
  processing: {
    background: colors.primaryLight,
    text: colors.surface,
    icon: colors.surface,
  },
  
  // Connection states
  connected: {
    background: colors.success,
    text: colors.surface,
    icon: colors.surface,
  },
  disconnected: {
    background: colors.error,
    text: colors.surface,
    icon: colors.surface,
  },
  connecting: {
    background: colors.warning,
    text: colors.text,
    icon: colors.text,
  },
};