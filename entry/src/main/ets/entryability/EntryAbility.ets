import { UIAbility, Configuration, ConfigurationConstant } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { AppStore } from '../common/AppStore';
import { SystemBarAppearance } from '../common/SystemBarAppearance';
export default class EntryAbility extends UIAbility {
  onWindowStageCreate(stage: window.WindowStage): void {
    try {
      // Preferences must be obtained from the Ability context before page construction.
      AppStore.prepare(this.context);
      // Appearance is local state. Restore it before Index is built rather than waiting
      // for the asynchronous account/session restore to complete.
      const systemMode: string = this.systemColorMode();
      const appearanceMode: string = AppStore.readAppearance('color_mode', 'system');
      AppStorage.setOrCreate('system_color_mode', systemMode);
      AppStorage.set('system_color_mode', systemMode);
      AppStorage.setOrCreate('appearance_color_mode', appearanceMode);
      AppStorage.set('appearance_color_mode', appearanceMode);
      AppStorage.setOrCreate('appearance_accent_color', AppStore.readAppearance('accent_color', '#3559D8'));
      AppStorage.set('appearance_accent_color', AppStore.readAppearance('accent_color', '#3559D8'));
      AppStorage.setOrCreate('appearance_material_level', AppStore.readAppearance('material_level', 'GENTLE'));
      AppStorage.set('appearance_material_level', AppStore.readAppearance('material_level', 'GENTLE'));
      this.applyColorMode(appearanceMode);
    } catch (_) {}
    stage.loadContent('pages/Index', (error: Error): void => {
      if (error) return;
      void this.initializeStore(stage);
    });
  }

  private async initializeStore(stage: window.WindowStage): Promise<void> {
    try {
      await AppStore.initialize(this.context);
      const mainWindow: window.Window = await stage.getMainWindow();
      const systemMode: string = String(AppStorage.get('system_color_mode') ?? this.systemColorMode());
      const appearanceMode: string = AppStore.readAppearance('color_mode', 'system');
      this.applyColorMode(appearanceMode);
      SystemBarAppearance.bind(mainWindow, appearanceMode, systemMode);
    } catch (_) {
      // The first page remains usable even when credential restoration fails.
    } finally {
      AppStorage.setOrCreate('pezmax_store_ready', true);
      AppStorage.set('pezmax_store_ready', true);
      const revision: number = Date.now();
      AppStorage.setOrCreate('pezmax_session_revision', revision);
      AppStorage.set('pezmax_session_revision', revision);
    }
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    const selectedMode: string = String(AppStorage.get('appearance_color_mode') ?? 'system');
    // setColorMode() reports the application override here as well. It is not the
    // device mode, so only record configuration changes while following the system.
    if (selectedMode !== 'system') return;
    const isDark: boolean = newConfig.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    const systemMode: string = isDark ? 'dark' : 'light';
    AppStorage.setOrCreate('system_color_mode', systemMode);
    AppStorage.set('system_color_mode', systemMode);
    const revision: number = Number(AppStorage.get('appearance_revision') ?? 0) + 1;
    AppStorage.setOrCreate('appearance_revision', revision);
    AppStorage.set('appearance_revision', revision);
    SystemBarAppearance.updateSystemMode(systemMode);
  }

  private systemColorMode(): string {
    return this.context.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ? 'dark' : 'light';
  }

  private applyColorMode(mode: string): void {
    try {
      if (mode === 'dark') this.context.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
      else if (mode === 'light') this.context.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
      else this.context.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (_) {}
  }

  onWindowStageDestroy(): void {}
}
