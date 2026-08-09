import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { AssetCredentialStore } from '../data/AssetCredentialStore';
import { PezMaxViewModel } from '../viewmodel/PezMaxViewModel';

export const PEZMAX_API_BASE_URL: string = 'http://154.8.139.48:8080';

export class AppStore {
  static readonly credentials: AssetCredentialStore = new AssetCredentialStore();
  static readonly pezMaxViewModel: PezMaxViewModel = new PezMaxViewModel(AppStore.credentials);
  static initialized: boolean = false;
  private static appPreferences: preferences.Preferences | undefined = undefined;
  private static sessionPreferences: preferences.Preferences | undefined = undefined;

  static initializePreferences(context: common.UIAbilityContext): void {
    if (AppStore.appPreferences === undefined) {
      AppStore.appPreferences = preferences.getPreferencesSync(context, { name: 'pezmax_app' });
    }
    if (AppStore.sessionPreferences === undefined) {
      AppStore.sessionPreferences = preferences.getPreferencesSync(context, { name: 'pezmax_session' });
    }
    AppStore.pezMaxViewModel.setSessionPreferences(AppStore.sessionPreferences, AppStore.appPreferences);
  }

  static prepare(context: common.UIAbilityContext): void {
    AppStore.initializePreferences(context);
    AppStore.pezMaxViewModel.restoreCached(PEZMAX_API_BASE_URL);
  }

  static readAppearance(key: string, fallback: string): string {
    if (AppStore.appPreferences === undefined) return fallback;
    return AppStore.appPreferences.getSync(key, fallback) as string;
  }

  static saveAppearance(key: string, value: string): void {
    AppStore.appPreferences?.putSync(key, value);
    AppStore.appPreferences?.flushSync();
  }

  static async initialize(context: common.UIAbilityContext): Promise<void> {
    if (AppStore.initialized) return;
    AppStore.initializePreferences(context);
    await AppStore.pezMaxViewModel.restore(PEZMAX_API_BASE_URL);
    AppStore.initialized = true;
  }
}
