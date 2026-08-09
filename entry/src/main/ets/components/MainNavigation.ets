import { NavigationIntent, NavigationSource, ShellTab } from '../model/ShellModels';
import { THEME_TOKENS } from '../common/ThemeTokens';

@Component
export struct MainNavigation {
  @Prop selectedTab: ShellTab = ShellTab.Chat;
  @StorageLink('appearance_accent_color') private appearanceAccentColor: string = '#3559D8';
  @StorageLink('appearance_color_mode') private colorMode: string = 'system';
  @StorageLink('system_color_mode') private systemColorMode: string = 'light';
  onSelect: (intent: NavigationIntent) => void = (_intent: NavigationIntent): void => {};

  @Builder
  private tabButton(label: string, tab: ShellTab, icon: Resource): void {
    Column({ space: 2 }) {
      Image(icon).width(20).height(20)
        .fillColor(this.selectedTab === tab ? this.appearanceAccentColor : THEME_TOKENS.secondaryText);
      Text(label).fontSize(12)
        .fontColor(this.selectedTab === tab ? this.appearanceAccentColor : THEME_TOKENS.secondaryText);
    }
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .onClick((): void => {
      this.onSelect({ target: tab, source: NavigationSource.FallbackNavigation, requestId: Date.now() });
    })
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 })
    .height(56).layoutWeight(1).backgroundColor('#00000000');
  }

  build() {
    Row({ space: 4 }) {
      this.tabButton('首页', ShellTab.Chat, $r('app.media.nav_home'));
      this.tabButton('资料', ShellTab.History, $r('app.media.nav_resources'));
      this.tabButton('书签', ShellTab.Providers, $r('app.media.nav_bookmark'));
      this.tabButton('我的', ShellTab.My, $r('app.media.nav_profile'));
    }
    .width('calc(100% - 24vp)').height(60)
    .margin({ left: 12, right: 12, bottom: 8 })
    .padding({ left: 8, right: 8, top: 2, bottom: 2 })
    .borderRadius(24)
    .backgroundColor(THEME_TOKENS.surface)
    .border({ width: 1, color: THEME_TOKENS.surfaceOutline });
  }
}
