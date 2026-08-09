import { MainShellView } from '../views/MainShellView';
import { THEME_TOKENS, pagePaddingFor } from '../common/ThemeTokens';
import { AppStore } from '../common/AppStore';

@Entry
@Component
struct Index {
  @State private windowWidth: number = THEME_TOKENS.compactWidth;
  @StorageLink('appearance_color_mode') private appearanceColorMode: string = 'system';
  @StorageLink('appearance_accent_color') private appearanceAccentColor: string = '#3559D8';
  @StorageLink('system_color_mode') private systemColorMode: string = 'light';
  @StorageLink('pezmax_store_ready') @Watch('onStoreReady') private storeReady: boolean = false;
  @StorageLink('pezmax_settings_open') private settingsOpen: boolean = false;
  @StorageLink('pezmax_active_tab') private activeTab: number = 0;
  @StorageLink('pezmax_resource_folder_depth') private resourceFolderDepth: number = 0;
  @StorageLink('pezmax_resource_back_revision') private resourceBackRevision: number = 0;

  aboutToAppear(): void {
    AppStorage.setOrCreate('appearance_color_mode', 'system');
    AppStorage.setOrCreate('appearance_accent_color', '#3559D8');
    AppStorage.setOrCreate('appearance_material_level', 'GENTLE');
    AppStorage.setOrCreate('system_color_mode', 'light');
    AppStorage.setOrCreate('appearance_revision', 0);
    AppStorage.setOrCreate('pezmax_active_tab', 0);
    AppStorage.setOrCreate('pezmax_navigation_target', 0);
    AppStorage.setOrCreate('pezmax_navigation_revision', 0);
    AppStorage.setOrCreate('pezmax_session_revision', 0);
    AppStorage.setOrCreate('pezmax_store_ready', false);
    AppStorage.setOrCreate('pezmax_settings_open', false);
    AppStorage.setOrCreate('pezmax_resource_folder_depth', 0);
    AppStorage.setOrCreate('pezmax_resource_back_revision', 0);
    AppStorage.setOrCreate('layout_window_width', this.windowWidth);
    this.publishPagePadding(this.windowWidth);
  }

  private onStoreReady(): void {
    if (!this.storeReady) return;
    const mode: string = AppStore.readAppearance('color_mode', 'system');
    const accent: string = AppStore.readAppearance('accent_color', '#3559D8');
    const material: string = AppStore.readAppearance('material_level', 'GENTLE');
    AppStorage.set('appearance_color_mode', mode);
    AppStorage.set('appearance_accent_color', accent);
    AppStorage.set('appearance_material_level', material);
  }

  private pageBackground(): ResourceColor {
    const dark: boolean = this.appearanceColorMode === 'dark' ||
      (this.appearanceColorMode === 'system' && this.systemColorMode === 'dark');
    return dark ? '#10131A' : '#F7F8FC';
  }

  onBackPress(): boolean {
    if (this.resourceFolderDepth > 0) {
      this.resourceBackRevision += 1;
      AppStorage.set('pezmax_resource_back_revision', this.resourceBackRevision);
      return true;
    }
    return false;
  }

  private publishPagePadding(width: number): void {
    const padding: number = pagePaddingFor(width);
    AppStorage.setOrCreate('layout_window_width', width);
    AppStorage.set('layout_window_width', width);
    AppStorage.setOrCreate('layout_page_padding', padding);
    AppStorage.set('layout_page_padding', padding);
  }

  build() {
    Column() {
      MainShellView().layoutWeight(1);
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.pageBackground())
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .onAreaChange((_oldArea: Area, newArea: Area): void => {
      const nextWidth: number = Number(newArea.width);
      if (nextWidth > 0) {
        this.windowWidth = nextWidth;
        this.publishPagePadding(nextWidth);
      }
    });
  }
}
