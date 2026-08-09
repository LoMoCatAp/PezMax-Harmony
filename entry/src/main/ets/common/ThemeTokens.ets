export interface ThemeTokenSet {
  pagePadding: number;
  cardRadius: number;
  compactWidth: number;
  tabletWidth: number;
  contentMaxWidth: number;
  pageBackground: ResourceColor;
  surface: ResourceColor;
  surfaceOutline: ResourceColor;
  primary: ResourceColor;
  primaryText: ResourceColor;
  secondaryText: ResourceColor;
  danger: ResourceColor;
  success: ResourceColor;
  warning: ResourceColor;
  touchTarget: number;
  fieldGap: number;
  safeAreaPadding: number;
  floatingBarInset: number;
  barBottomDistance: number;
  contentBottomInset: number;
  keyboardPadding: number;
  subpageContentTop: number;
  chineseTextSpacing: number;
  minimumContrast: number;
  minButtonWidth: number;
  maxChineseLines: number;
  bottomSafeInset: number;
  feedbackDuration: number;
}

function isDarkAppearance(): boolean {
  const mode: string = String(AppStorage.get('appearance_color_mode') ?? 'system');
  if (mode === 'dark') return true;
  if (mode === 'light') return false;
  return String(AppStorage.get('system_color_mode') ?? 'light') === 'dark';
}

function appearanceColor(light: string, dark: string): ResourceColor {
  return isDarkAppearance() ? dark : light;
}

export const THEME_TOKENS: ThemeTokenSet = {
  pagePadding: 16,
  cardRadius: 18,
  compactWidth: 600,
  tabletWidth: 900,
  contentMaxWidth: 920,
  get pageBackground(): ResourceColor { return appearanceColor('#F7F8FC', '#10131A'); },
  get surface(): ResourceColor { return appearanceColor('#FFFFFF', '#1B2029'); },
  get surfaceOutline(): ResourceColor { return appearanceColor('#DDE2EC', '#343B48'); },
  get primary(): ResourceColor { return appearanceColor('#3559D8', '#9CB2FF'); },
  get primaryText(): ResourceColor { return appearanceColor('#172033', '#F1F4FA'); },
  get secondaryText(): ResourceColor { return appearanceColor('#667085', '#B1BACB'); },
  get danger(): ResourceColor { return appearanceColor('#C62828', '#FFB4AB'); },
  get success(): ResourceColor { return appearanceColor('#18794E', '#75D9AA'); },
  get warning(): ResourceColor { return appearanceColor('#946200', '#FFD166'); },
  touchTarget: 48,
  fieldGap: 10,
  safeAreaPadding: 16,
  floatingBarInset: 64,
  barBottomDistance: 0,
  contentBottomInset: 84,
  keyboardPadding: 24,
  // Shared destination inset. Padding keeps nested List and Toggle updates
  // from inheriting a transform-based visual offset.
  subpageContentTop: 14,
  chineseTextSpacing: 4,
  minimumContrast: 4.5,
  minButtonWidth: 88,
  maxChineseLines: 3,
  bottomSafeInset: 0,
  feedbackDuration: 1800
};

export function pagePaddingFor(width: number): number {
  if (width >= THEME_TOKENS.tabletWidth) return 24;
  if (width >= THEME_TOKENS.compactWidth) return 20;
  return THEME_TOKENS.pagePadding;
}

export function contentWidthFor(width: number): string {
  return width >= THEME_TOKENS.tabletWidth ? `${THEME_TOKENS.contentMaxWidth}vp` : '100%';
}
