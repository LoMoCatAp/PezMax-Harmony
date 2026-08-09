import { CommonModifier, uiMaterial } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';
import { hdsEffect } from '@kit.UIDesignKit';
import { THEME_TOKENS } from './ThemeTokens';

function activeDarkMode(): boolean {
  const mode: string = String(AppStorage.get('appearance_color_mode') ?? 'system');
  if (mode === 'dark') return true;
  if (mode === 'light') return false;
  return String(AppStorage.get('system_color_mode') ?? 'light') === 'dark';
}

export function supportsComponentImmersiveMaterial(): boolean {
  return deviceInfo.sdkApiVersion >= 26;
}

export function supportsHdsImmersiveMaterial(): boolean {
  return deviceInfo.sdkApiVersion >= 23;
}

export class CompatibleMaterialModifier extends CommonModifier {
  private readonly accentColor: string;
  private readonly applyShadow: boolean;
  private readonly transparentBackground: boolean;
  private readonly darkMode: boolean;

  constructor(accentColor: string, applyShadow: boolean = false, transparentBackground: boolean = false) {
    super();
    this.accentColor = accentColor;
    this.applyShadow = applyShadow;
    this.transparentBackground = transparentBackground;
    this.darkMode = activeDarkMode();
  }

  applyNormalAttribute(instance: CommonAttribute): void {
    if (!supportsComponentImmersiveMaterial()) {
      instance.backgroundColor(this.transparentBackground ? Color.Transparent : (this.darkMode ? '#1B2029' : '#FFFFFF'));
      if (supportsHdsImmersiveMaterial()) {
        const effect: VisualEffect = new hdsEffect.HdsEffectBuilder()
          .pressShadow(hdsEffect.PressShadowType.BLEND_GRADIENT)
          .pointLight({
            sourceType: hdsEffect.PointLightSourceType.SOFT,
            illuminatedType: hdsEffect.PointLightIlluminatedType.BORDER_CONTENT,
            options: { color: this.accentColor, intensity: 0.55, height: 24, bloom: 0.12 }
          })
          .buildEffect();
        instance.visualEffect(effect);
      }
      if (this.applyShadow) {
        instance.border({ width: 1, color: this.darkMode ? '#343B48' : '#DDE2EC' });
        instance.shadow({ radius: 10, color: this.darkMode ? '#52000000' : '#14000000', offsetY: 2 });
      }
      return;
    }
    instance.systemMaterial(new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.THIN,
      materialColor: this.applyShadow ? (this.darkMode ? '#1B2029' : '#FFFFFF') : Color.Transparent,
      applyShadow: false,
      interactive: true,
      lightEffect: { color: this.accentColor }
    }));
  }
}

export function compatibleImmersiveMaterial(accentColor: string,
  applyShadow: boolean = false, transparentBackground: boolean = false): CommonModifier {
  return new CompatibleMaterialModifier(accentColor, applyShadow, transparentBackground);
}
