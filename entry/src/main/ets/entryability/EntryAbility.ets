import { UIAbility, Configuration, ConfigurationConstant } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { AppStore } from '../common/AppStore';
import { SystemBarAppearance } from '../common/SystemBarAppearance';
export default class EntryAbility extends UIAbility {
  onWindowStageCreate(stage: window.WindowStage): void {
    try {
      // Preferences must be obtained from the Ability context before page construction.
      AppStore.prepare(this.context);
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
      const systemMode: string = this.systemColorMode();
      AppStorage.setOrCreate('system_color_mode', systemMode);
      AppStorage.set('system_color_mode', systemMode);
      SystemBarAppearance.bind(mainWindow, AppStore.readAppearance('color_mode', 'system'), systemMode);
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
    const isDark: boolean = newConfig.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    const systemMode: string = isDark ? 'dark' : 'light';
    AppStorage.setOrCreate('system_color_mode', systemMode);
    AppStorage.set('system_color_mode', systemMode);
    SystemBarAppearance.updateSystemMode(systemMode);
  }

  private systemColorMode(): string {
    return this.context.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ? 'dark' : 'light';
  }

  onWindowStageDestroy(): void {}
}
