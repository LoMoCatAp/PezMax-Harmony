import { DividerMode, HdsAnimationMode, HdsTabs, HdsTabsController, hdsMaterial } from '@kit.UIDesignKit';
import { supportsHdsImmersiveMaterial } from '../common/CompatibleMaterial';
import { MainNavigation } from '../components/MainNavigation';
import { MaterialLevel, NavigationIntent, NavigationSource, ShellTab } from '../model/ShellModels';
import {
  PezMaxBookmarksView,
  PezMaxHomeView,
  PezMaxProfileView,
  PezMaxResourcesView
} from './PezMaxView';

@Component
export struct MainShellView {
  @State private selectedTab: ShellTab = ShellTab.Chat;
  @State private officialMaterial: boolean = true;
  @StorageLink('appearance_accent_color') private accentColor: string = '#3559D8';
  @StorageLink('appearance_color_mode') private colorMode: string = 'system';
  @StorageLink('system_color_mode') private systemColorMode: string = 'light';
  @StorageLink('appearance_material_level') private materialLevel: string = MaterialLevel.Gentle;
  @StorageLink('pezmax_settings_open') @Watch('onSettingsVisibilityChanged') private settingsOpen: boolean = false;
  @StorageLink('pezmax_navigation_target') private navigationTarget: number = 0;
  @StorageLink('pezmax_navigation_revision') @Watch('onNavigationRequested') private navigationRevision: number = 0;
  private tabsController: HdsTabsController | undefined = undefined;

  aboutToAppear(): void {
    if (supportsHdsImmersiveMaterial()) {
      try {
        this.tabsController = new HdsTabsController();
        this.officialMaterial = true;
      } catch (_) {
        this.tabsController = undefined;
        this.officialMaterial = false;
      }
    } else {
      this.officialMaterial = false;
    }
    this.publishSelectedTab(this.selectedTab);
  }

  private publishSelectedTab(tab: ShellTab): void {
    AppStorage.setOrCreate('pezmax_active_tab', tab as number);
    AppStorage.set('pezmax_active_tab', tab as number);
  }

  private navigate(intent: NavigationIntent): void {
    this.selectedTab = intent.target;
    this.publishSelectedTab(intent.target);
    if (this.officialMaterial && this.tabsController !== undefined) this.tabsController.changeIndex(intent.target);
  }

  private selectTab(index: number): void {
    this.selectedTab = index as ShellTab;
    this.publishSelectedTab(this.selectedTab);
  }

  private onSettingsVisibilityChanged(): void {
    if (!this.officialMaterial || this.tabsController === undefined) return;
    if (this.settingsOpen) this.tabsController.applyHideAnimation(HdsAnimationMode.SCROLL_ANIMATION);
    else this.tabsController.applyShowAnimation(HdsAnimationMode.SCROLL_ANIMATION);
  }

  private onNavigationRequested(): void {
    if (this.navigationRevision <= 0 || this.navigationTarget < 0 || this.navigationTarget > 3) return;
    this.navigate({ target: this.navigationTarget as ShellTab, source: NavigationSource.System,
      requestId: this.navigationRevision });
  }

  private hdsMaterialLevel(): hdsMaterial.MaterialLevel {
    if (this.materialLevel === MaterialLevel.Exquisite) return hdsMaterial.MaterialLevel.EXQUISITE;
    if (this.materialLevel === MaterialLevel.Smooth) return hdsMaterial.MaterialLevel.SMOOTH;
    if (this.materialLevel === MaterialLevel.Adaptive) return hdsMaterial.MaterialLevel.ADAPTIVE;
    return hdsMaterial.MaterialLevel.GENTLE;
  }

  private pageBackground(): ResourceColor {
    const dark: boolean = this.colorMode === 'dark' ||
      (this.colorMode === 'system' && this.systemColorMode === 'dark');
    return dark ? '#10131A' : '#F7F8FC';
  }

  @Builder
  private tabLabel(label: string, tab: ShellTab): void {
    Column({ space: 2 }) {
      if (tab === ShellTab.Chat) {
        Image($r('app.media.nav_home')).width(20).height(20)
          .fillColor(this.selectedTab === tab ? this.accentColor : $r('app.color.text_secondary'));
      } else if (tab === ShellTab.History) {
        Image($r('app.media.nav_resources')).width(20).height(20)
          .fillColor(this.selectedTab === tab ? this.accentColor : $r('app.color.text_secondary'));
      } else if (tab === ShellTab.Providers) {
        Image($r('app.media.nav_bookmark')).width(20).height(20)
          .fillColor(this.selectedTab === tab ? this.accentColor : $r('app.color.text_secondary'));
      } else {
        Image($r('app.media.nav_profile')).width(20).height(20)
          .fillColor(this.selectedTab === tab ? this.accentColor : $r('app.color.text_secondary'));
      }
      Text(label).fontSize(12)
        .fontColor(this.selectedTab === tab ? this.accentColor : $r('app.color.text_secondary'));
    }
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .width('100%').height(52)
    .backgroundColor('#00000000');
  }

  @Builder
  private hdsContent(controller: HdsTabsController): void {
    HdsTabs({ controller }) {
      TabContent() { PezMaxHomeView() }.tabBar(this.tabLabel('首页', ShellTab.Chat));
      TabContent() { PezMaxResourcesView() }.tabBar(this.tabLabel('资料', ShellTab.History));
      TabContent() { PezMaxBookmarksView() }.tabBar(this.tabLabel('书签', ShellTab.Providers));
      TabContent() { PezMaxProfileView() }.tabBar(this.tabLabel('我的', ShellTab.My));
    }
    .barOverlap(true)
    .animationDuration(0)
    .vertical(false)
    .barPosition(BarPosition.End)
    .divider({ mode: DividerMode.NONE })
    .barFloatingStyle({
      barBottomMargin: 4,
      adaptToHandedness: true,
      lightColor: this.accentColor,
      systemMaterialEffect: {
        materialType: hdsMaterial.MaterialType.IMMERSIVE,
        materialLevel: this.hdsMaterialLevel()
      }
    })
    .onChange((index: number): void => { this.selectTab(index); })
    .backgroundColor(this.pageBackground())
    .width('100%').height('100%');
  }

  build() {
    Column() {
      if (this.officialMaterial && this.tabsController !== undefined) {
        this.hdsContent(this.tabsController);
      } else {
        Column() {
          if (this.selectedTab === ShellTab.Chat) {
            PezMaxHomeView();
          } else if (this.selectedTab === ShellTab.History) {
            PezMaxResourcesView();
          } else if (this.selectedTab === ShellTab.Providers) {
            PezMaxBookmarksView();
          } else {
            PezMaxProfileView();
          }
        }.layoutWeight(1).width('100%');
        if (!this.settingsOpen) {
          MainNavigation({
            selectedTab: this.selectedTab,
            onSelect: (intent: NavigationIntent): void => { this.navigate(intent); }
          });
        }
      }
    }
    .width('100%').height('100%')
    .backgroundColor(this.pageBackground());
  }
}
