import { common, wantConstant } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { request } from '@kit.BasicServicesKit';
import { fileUri } from '@kit.CoreFileKit';
import { HdsNavDestination, HdsNavigation } from '@kit.UIDesignKit';
import { AppStore, PEZMAX_API_BASE_URL } from '../common/AppStore';
import { compatibleImmersiveMaterial } from '../common/CompatibleMaterial';
import { SystemBarAppearance } from '../common/SystemBarAppearance';
import { THEME_TOKENS } from '../common/ThemeTokens';
import {
  PezMaxBookmark,
  PezMaxCaptcha,
  PezMaxFile,
  PezMaxFileNode,
  PezMaxRegisterDraft,
  PezMaxSecurityDraft,
  PezMaxUploadRank
} from '../model/PezMaxModels';
import { MaterialLevel } from '../model/ShellModels';

interface AppearanceOption {
  value: string;
  label: string;
}

interface ChangelogEntry {
  version: string;
  date: string;
  items: string[];
}

interface PrivacyEntry {
  title: string;
  content: string;
}

enum ResourceMode {
  All = 'all',
  Favorites = 'favorites',
  Downloads = 'downloads'
}

const COLOR_MODE_OPTIONS: AppearanceOption[] = [
  { value: 'system', label: '跟随系统' },
  { value: 'light', label: '浅色' },
  { value: 'dark', label: '深色' }
];

const ACCENT_OPTIONS: AppearanceOption[] = [
  { value: '#3559D8', label: '星河蓝' },
  { value: '#16805E', label: '森林绿' },
  { value: '#A54619', label: '暖橙' },
  { value: '#007D8A', label: '湖青' },
  { value: '#B23A6F', label: '莓红' },
  { value: '#6D48A8', label: '鸢尾紫' }
];

const MATERIAL_OPTIONS: AppearanceOption[] = [
  { value: MaterialLevel.Off, label: '关闭' },
  { value: MaterialLevel.Exquisite, label: '强' },
  { value: MaterialLevel.Gentle, label: '均衡（默认）' },
  { value: MaterialLevel.Smooth, label: '弱' },
  { value: MaterialLevel.Adaptive, label: '系统自适应' }
];

const CHANGELOG_ENTRIES: ChangelogEntry[] = [
  {
    version: '1.0.3',
    date: '2026-08-09',
    items: ['所有主页面与短列表固定从顶部开始布局，收藏、下载等内容数量变化不再改变框体基线。',
      '底部导航切换改为即时响应，远端刷新延后到页面首帧完成后执行。',
      '更新日志与隐私政策底部弹层加入 ArkUI 原生沉浸光感材质。',
      '新增用户资料缓存，覆盖部署和应用重启时直接恢复登录界面。']
  },
  {
    version: '1.0.2',
    date: '2026-08-09',
    items: ['完善浅色、深色和跟随系统模式，框体、列表、输入框及文字统一使用主题资源。',
      '新增应用信息、更新日志与 PezMax 隐私政策，并移除爱发电入口。',
      '主页面标题固定于左上角，设置主题色选项增加纵向间距。']
  },
  {
    version: '1.0.1',
    date: '2026-08-09',
    items: ['资料页改为桌面端风格的文件夹目录，并支持收藏、下载记录和分页。',
      '支持通过系统下载服务获取资料，并交由 HarmonyOS 系统查看器打开。',
      '补齐注册、书签管理、收藏切换及会话持久化。']
  },
  {
    version: '1.0.0',
    date: '2026-08-09',
    items: ['适配 HarmonyOS 原生 ArkUI 与沉浸光感材质', '支持 PezMax 账户登录、注册与会话持久化',
      '支持资料目录、收藏、下载记录、书签与系统文件查看器', '补齐浅色、深色与跟随系统外观模式']
  }
];

const PRIVACY_ENTRIES: PrivacyEntry[] = [
  {
    title: '账户与会话',
    content: '账号和密码仅用于向 PezMax 服务端完成身份验证。应用不会保存明文密码；登录令牌保存在系统安全凭据及应用私有本地存储中，用于保持登录状态。'
  },
  {
    title: '资料与使用记录',
    content: '资料目录、收藏、下载记录和书签由 PezMax 服务端按账户提供。应用仅在展示与操作这些功能时请求必要数据，不会上传相册图片。'
  },
  {
    title: '文件打开',
    content: '打开资料时，文件会下载到应用缓存目录，并交由系统或用户选择的兼容查看器处理。第三方查看器对文件的处理受其自身隐私政策约束。'
  },
  {
    title: '网络与服务',
    content: '应用连接 PezMax 远端服务以完成登录、资料、收藏、下载记录和书签功能。网络请求仅携带完成相应功能所需的信息。'
  },
  {
    title: '数据控制',
    content: '退出登录会移除本机保存的登录令牌并清空本地会话数据。服务端账户及业务数据的删除或更正，请联系 PezMax 项目维护者。'
  }
];

function currentUserName(): string {
  const user = AppStore.pezMaxViewModel.state.user;
  return user === undefined ? '' : (user.nickName || user.userName);
}

function absoluteUrl(value: string): string {
  const url: string = value.trim();
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  if (url.startsWith('/')) return `${PEZMAX_API_BASE_URL}${url}`;
  return url.length > 0 ? `https://${url}` : '';
}

@Component
export struct PezMaxHomeView {
  @State private userName: string = '';
  @State private bookmarkCount: number = 0;
  @State private fileCount: number = 0;
  @State private favoriteCount: number = 0;
  @State private downloadCount: number = 0;
  @State private uploadCount: number = 0;
  @State private loading: boolean = false;
  @State private errorMessage: string = '';
  @StorageLink('layout_page_padding') private pagePadding: number = THEME_TOKENS.pagePadding;
  @StorageLink('pezmax_active_tab') @Watch('onTabChanged') private activeTab: number = 0;
  @StorageLink('pezmax_session_revision') @Watch('onSessionChanged') private sessionRevision: number = 0;
  @StorageLink('appearance_accent_color') private accentColor: string = '#3559D8';
  private refreshing: boolean = false;
  private lastRefreshAt: number = 0;

  aboutToAppear(): void {
    this.sync();
    if (this.activeTab === 0) void this.refresh(false);
  }

  private onTabChanged(): void {
    this.sync();
    if (this.activeTab === 0) {
      setTimeout((): void => { if (this.activeTab === 0) void this.refresh(false); }, 100);
    }
  }

  private onSessionChanged(): void {
    this.sync();
    if (this.activeTab === 0 && this.userName.length > 0) void this.refresh(true);
  }

  private sync(): void {
    const state = AppStore.pezMaxViewModel.state;
    this.userName = currentUserName();
    this.bookmarkCount = state.bookmarkTotal;
    this.fileCount = state.fileTotal;
    this.favoriteCount = state.stats.favoriteCount;
    this.downloadCount = state.stats.downloadCount;
    this.uploadCount = state.stats.uploadCount;
    this.loading = this.refreshing;
    this.errorMessage = state.errorMessage;
  }

  private async refresh(force: boolean): Promise<void> {
    this.sync();
    if (this.userName.length === 0 || this.refreshing) return;
    if (!force && Date.now() - this.lastRefreshAt < 30000) return;
    this.refreshing = true;
    this.loading = true;
    try {
      await Promise.all([
        AppStore.pezMaxViewModel.loadProfileStats(),
        AppStore.pezMaxViewModel.loadBookmarks(),
        AppStore.pezMaxViewModel.loadFiles()
      ]);
      this.lastRefreshAt = Date.now();
    } finally {
      this.refreshing = false;
      this.sync();
    }
  }

  @Builder
  private metric(icon: Resource, label: string, value: string): void {
    Row({ space: 12 }) {
      Stack({ alignContent: Alignment.Center }) {
        Column().width(36).height(36).backgroundColor(this.accentColor).borderRadius(18).opacity(0.12);
        Image(icon).width(19).height(19).fillColor(this.accentColor);
      }.width(40).height(40);
      Column({ space: 2 }) {
        Text(value).fontSize(24).fontWeight(FontWeight.Bold).fontColor(THEME_TOKENS.primaryText);
        Text(label).fontSize(12).fontColor(THEME_TOKENS.secondaryText).maxLines(1);
      }.alignItems(HorizontalAlign.Start).layoutWeight(1);
    }
    .height(84).padding({ left: 14, right: 14 }).width('100%')
    .backgroundColor(Color.Transparent).borderRadius(18)
    .attributeModifier(compatibleImmersiveMaterial(this.accentColor, true));
  }

  build() {
    Column() {
      Column({ space: 5 }) {
        Text('PezMax').fontSize(24).fontWeight(FontWeight.Bold).fontColor(THEME_TOKENS.primaryText);
        Text(this.userName.length > 0 ? `你好，${this.userName}` : '欢迎使用 PezMax')
          .fontSize(14).fontColor(THEME_TOKENS.secondaryText);
      }
      .alignItems(HorizontalAlign.Start).width('100%')
      .padding({ left: this.pagePadding, right: this.pagePadding, top: 10, bottom: 18 });
      Scroll() {
        Column({ space: 16 }) {
        Column({ space: 12 }) {
          Row() {
            Column({ space: 4 }) {
              Text(this.userName.length > 0 ? '内容工作台' : '开始使用 PezMax')
                .fontSize(20).fontWeight(FontWeight.Bold).fontColor(THEME_TOKENS.primaryText);
              Text(this.userName.length > 0 ? '资料、收藏和贡献一目了然' : '登录后同步资料、书签与个人数据')
                .fontSize(13).fontColor(THEME_TOKENS.secondaryText);
            }.alignItems(HorizontalAlign.Start).layoutWeight(1);
            if (this.userName.length > 0) {
              Column({ space: 2 }) {
                Text(`${this.uploadCount}`).fontSize(28).fontWeight(FontWeight.Bold).fontColor(this.accentColor);
                Text('上传贡献').fontSize(11).fontColor(THEME_TOKENS.secondaryText);
              }.alignItems(HorizontalAlign.End);
            }
          }.width('100%');
          if (this.userName.length > 0) {
            Progress({ value: this.uploadCount,
              total: Math.max(1, this.favoriteCount + this.downloadCount + this.uploadCount), type: ProgressType.Linear })
              .color(this.accentColor).backgroundColor('#1A7F8CFF').height(6).width('100%');
          }
        }
        .alignItems(HorizontalAlign.Start).width('100%').padding(18)
        .backgroundColor(Color.Transparent).borderRadius(18)
        .attributeModifier(compatibleImmersiveMaterial(this.accentColor, true));
        if (this.userName.length === 0) {
          Column({ space: 8 }) {
            Text('尚未登录').fontSize(18).fontWeight(FontWeight.Medium)
              .fontColor(THEME_TOKENS.primaryText).width('100%');
            Text('请前往“我的”完成登录后使用资料与书签功能。')
              .fontSize(14).fontColor(THEME_TOKENS.secondaryText).width('100%');
          }.alignItems(HorizontalAlign.Start).padding(16).backgroundColor(Color.Transparent).borderRadius(18)
            .attributeModifier(compatibleImmersiveMaterial(this.accentColor, true)).width('100%');
        } else {
          Text('数据概览').fontSize(14).fontColor(THEME_TOKENS.secondaryText).width('100%');
          Grid() {
            GridItem() { this.metric($r('app.media.nav_bookmark'), '书签', `${this.bookmarkCount}`); }
            GridItem() { this.metric($r('app.media.resource_file'), '资料', `${this.fileCount}`); }
            GridItem() { this.metric($r('app.media.nav_profile'), '收藏', `${this.favoriteCount}`); }
            GridItem() { this.metric($r('app.media.nav_resources'), '下载', `${this.downloadCount}`); }
          }
          .columnsTemplate('1fr 1fr').columnsGap(10).rowsGap(10).width('100%').height(178);
        }
        if (this.loading) LoadingProgress().width(32).height(32);
        if (this.errorMessage.length > 0) Text(this.errorMessage).fontSize(13).fontColor(THEME_TOKENS.danger).width('100%');
        }
        .constraintSize({ minHeight: '100%' })
        .justifyContent(FlexAlign.Start).alignItems(HorizontalAlign.Start)
        .padding({ left: this.pagePadding, right: this.pagePadding, bottom: THEME_TOKENS.contentBottomInset })
        .width('100%');
      }
      .layoutWeight(1).width('100%').scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true });
    }
    .width('100%').height('100%');
  }
}

@Component
export struct PezMaxResourcesView {
  @State private keyword: string = '';
  @State private files: PezMaxFile[] = [];
  @State private favoriteFiles: PezMaxFile[] = [];
  @State private treeNodes: PezMaxFileNode[] = [];
  @State private folderPath: PezMaxFileNode[] = [];
  @State private folderPageStack: number[] = [];
  @State private userName: string = '';
  @State private mode: ResourceMode = ResourceMode.All;
  @State private loading: boolean = false;
  @State private errorMessage: string = '';
  @State private page: number = 1;
  @State private total: number = 0;
  @State private contentOpacity: number = 1;
  @State private contentOffset: number = 0;
  @State private openingFileId: number = 0;
  @StorageLink('layout_page_padding') private pagePadding: number = THEME_TOKENS.pagePadding;
  @StorageLink('pezmax_active_tab') @Watch('onTabChanged') private activeTab: number = 0;
  @StorageLink('pezmax_session_revision') @Watch('onSessionChanged') private sessionRevision: number = 0;
  @StorageLink('pezmax_resource_folder_depth') private resourceFolderDepth: number = 0;
  @StorageLink('pezmax_resource_back_revision') @Watch('onResourceBackRequested') private resourceBackRevision: number = 0;
  @StorageLink('appearance_accent_color') private accentColor: string = '#3559D8';
  private readonly pageSize: number = 8;
  private refreshing: boolean = false;
  private lastRefreshAt: number = 0;

  aboutToAppear(): void {
    this.sync();
    this.publishFolderDepth();
  }

  private onResourceBackRequested(): void {
    if (this.mode === ResourceMode.All && this.folderPath.length > 0) this.leaveFolder();
  }

  private publishFolderDepth(): void {
    const depth: number = this.activeTab === 1 && this.mode === ResourceMode.All ? this.folderPath.length : 0;
    this.resourceFolderDepth = depth;
    AppStorage.set('pezmax_resource_folder_depth', depth);
  }

  private onTabChanged(): void {
    this.sync();
    this.publishFolderDepth();
    if (this.activeTab === 1) {
      setTimeout((): void => { if (this.activeTab === 1) void this.refresh(false); }, 100);
    }
  }

  private onSessionChanged(): void {
    this.sync();
    if (this.activeTab === 1 && this.userName.length > 0) void this.refresh(true);
  }

  private sync(): void {
    const state = AppStore.pezMaxViewModel.state;
    this.userName = currentUserName();
    this.favoriteFiles = state.favoriteFiles;
    this.treeNodes = state.fileTree;
    if (this.mode === ResourceMode.Favorites) {
      this.files = state.favoriteFiles;
      this.total = state.favoriteTotal;
    } else if (this.mode === ResourceMode.Downloads) {
      this.files = state.downloadFiles;
      this.total = state.downloadTotal;
    } else {
      this.files = state.files;
      this.total = this.filteredFolderNodes().length;
    }
    this.loading = this.refreshing || state.loading;
    this.errorMessage = state.errorMessage;
  }

  private selectMode(mode: ResourceMode): void {
    if (this.mode === mode) return;
    this.mode = mode;
    this.publishFolderDepth();
    this.keyword = '';
    this.page = 1;
    this.contentOpacity = 0.35;
    this.contentOffset = 8;
    this.sync();
    animateTo({ duration: 160, curve: Curve.EaseOut }, (): void => {
      this.contentOpacity = 1;
      this.contentOffset = 0;
    });
    void this.refresh(true);
  }

  private async refresh(force: boolean): Promise<void> {
    this.sync();
    if (this.userName.length === 0 || this.refreshing) return;
    if (!force && Date.now() - this.lastRefreshAt < 30000) return;
    this.refreshing = true;
    this.loading = true;
    try {
      if (this.mode === ResourceMode.Favorites) {
        await AppStore.pezMaxViewModel.loadFavoriteFiles(this.page, this.pageSize);
      } else if (this.mode === ResourceMode.Downloads) {
        await AppStore.pezMaxViewModel.loadDownloadFiles(this.page, this.pageSize);
      } else {
        await AppStore.pezMaxViewModel.loadFileTree();
        if (AppStore.pezMaxViewModel.state.favoriteFiles.length === 0) {
          await AppStore.pezMaxViewModel.loadFavoriteFiles();
        }
      }
      this.lastRefreshAt = Date.now();
    } finally {
      this.refreshing = false;
      this.sync();
    }
  }

  private currentFolderNodes(): PezMaxFileNode[] {
    if (this.folderPath.length === 0) return this.treeNodes;
    return this.folderPath[this.folderPath.length - 1].children;
  }

  private filteredFolderNodes(): PezMaxFileNode[] {
    const nodes: PezMaxFileNode[] = this.currentFolderNodes();
    const query: string = this.keyword.trim().toLowerCase();
    if (query.length === 0) return nodes;
    return nodes.filter((node: PezMaxFileNode): boolean => node.label.toLowerCase().includes(query));
  }

  private visibleFolderNodes(): PezMaxFileNode[] {
    const nodes: PezMaxFileNode[] = this.filteredFolderNodes();
    const start: number = (this.page - 1) * this.pageSize;
    return nodes.slice(start, start + this.pageSize);
  }

  private enterFolder(node: PezMaxFileNode): void {
    this.folderPageStack = [...this.folderPageStack, this.page];
    this.folderPath = [...this.folderPath, node];
    this.publishFolderDepth();
    this.keyword = '';
    this.page = 1;
    this.total = node.children.length;
    this.animateContent();
  }

  private leaveFolder(): void {
    if (this.folderPath.length === 0) return;
    const restoredPage: number = this.folderPageStack[this.folderPageStack.length - 1] ?? 1;
    this.folderPath = this.folderPath.slice(0, this.folderPath.length - 1);
    this.folderPageStack = this.folderPageStack.slice(0, this.folderPageStack.length - 1);
    this.publishFolderDepth();
    this.keyword = '';
    this.page = Math.min(restoredPage, Math.max(1, Math.ceil(this.currentFolderNodes().length / this.pageSize)));
    this.total = this.currentFolderNodes().length;
    this.animateContent(-8);
  }

  private jumpToFolder(index: number): void {
    const targetDepth: number = index + 1;
    if (targetDepth === this.folderPath.length) return;
    const restoredPage: number = this.folderPageStack[targetDepth] ?? 1;
    this.folderPath = targetDepth === 0 ? [] : this.folderPath.slice(0, targetDepth);
    this.folderPageStack = this.folderPageStack.slice(0, targetDepth);
    this.publishFolderDepth();
    this.keyword = '';
    this.page = Math.min(restoredPage, Math.max(1, Math.ceil(this.currentFolderNodes().length / this.pageSize)));
    this.total = this.currentFolderNodes().length;
    this.animateContent(-8);
  }

  private animateContent(offset: number = 8): void {
    this.contentOpacity = 0.35;
    this.contentOffset = offset;
    animateTo({ duration: 160, curve: Curve.EaseOut }, (): void => {
      this.contentOpacity = 1;
      this.contentOffset = 0;
    });
  }

  private isFavorite(fileId: number): boolean {
    return this.favoriteFiles.find((item: PezMaxFile): boolean => item.fileId === fileId) !== undefined;
  }

  private fileExtension(item: PezMaxFile): string {
    const format: string = item.fileFormat.trim().toLowerCase().replace('.', '');
    if (format.length > 0 && format.length <= 8) return format;
    const parts: string[] = item.fileName.split('.');
    return parts.length > 1 ? parts[parts.length - 1].toLowerCase() : 'bin';
  }

  private mimeType(item: PezMaxFile): string {
    const extension: string = this.fileExtension(item);
    if (extension === 'pdf') return 'application/pdf';
    if (extension === 'doc') return 'application/msword';
    if (extension === 'docx') return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    if (extension === 'ppt') return 'application/vnd.ms-powerpoint';
    if (extension === 'pptx') return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    if (extension === 'xls') return 'application/vnd.ms-excel';
    if (extension === 'xlsx') return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    if (extension === 'txt' || extension === 'md') return 'text/plain';
    return 'application/octet-stream';
  }

  private waitForDownload(task: request.DownloadTask): Promise<void> {
    return new Promise<void>((resolve: () => void, reject: (reason: Error) => void): void => {
      task.on('complete', (): void => { resolve(); });
      task.on('fail', (code: number): void => { reject(new Error(`文件下载失败（${code}）`)); });
    });
  }

  private async openFile(item: PezMaxFile): Promise<void> {
    if (this.openingFileId !== 0) return;
    const token: string = AppStore.pezMaxViewModel.state.token;
    if (token.length === 0) {
      this.errorMessage = '登录状态已失效，请重新登录';
      return;
    }
    this.openingFileId = item.fileId;
    this.errorMessage = '';
    try {
      const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      const extension: string = this.fileExtension(item);
      const localPath: string = `${context.cacheDir}/pezmax-${item.fileId}-${Date.now()}.${extension}`;
      const task: request.DownloadTask = await request.downloadFile(context, {
        url: `${PEZMAX_API_BASE_URL}/datum/download/file?fileId=${item.fileId}`,
        header: { 'Authorization': `Bearer ${token}` },
        filePath: localPath,
        title: item.fileName,
        enableMetered: true
      });
      await this.waitForDownload(task);
      const uri: string = fileUri.getUriFromPath(localPath);
      await context.startAbility({
        action: 'ohos.want.action.viewData',
        uri,
        type: this.mimeType(item),
        flags: wantConstant.Flags.FLAG_AUTH_READ_URI_PERMISSION
      });
      await AppStore.pezMaxViewModel.loadProfileStats();
    } catch (error) {
      this.errorMessage = error instanceof Error ? error.message : '无法使用系统查看器打开该文件';
      promptAction.showToast({ message: this.errorMessage });
    } finally {
      this.openingFileId = 0;
    }
  }

  private async toggleFavorite(item: PezMaxFile): Promise<void> {
    const wasFavorite: boolean = this.isFavorite(item.fileId);
    const success: boolean = this.isFavorite(item.fileId)
      ? await AppStore.pezMaxViewModel.removeFavorite(item.fileId)
      : await AppStore.pezMaxViewModel.addFavorite(item.fileId);
    this.sync();
    if (success) promptAction.showToast({ message: wasFavorite ? '已移除收藏' : '已收藏' });
  }

  private async removeDownload(item: PezMaxFile): Promise<void> {
    const success: boolean = await AppStore.pezMaxViewModel.removeDownload(item.fileId);
    this.sync();
    if (success) promptAction.showToast({ message: '下载记录已移除' });
  }

  @Builder
  private modeButton(label: string, mode: ResourceMode): void {
    Button(label)
      .fontColor(this.mode === mode ? this.accentColor : THEME_TOKENS.secondaryText)
      .backgroundColor(Color.Transparent)
      .border({ width: this.mode === mode ? 1.5 : 0, color: this.accentColor })
      .attributeModifier(compatibleImmersiveMaterial(this.accentColor))
      .height(40).layoutWeight(1).borderRadius(20)
      .onClick((): void => { this.selectMode(mode); })
      .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.98 });
  }

  @Builder
  private folderNode(node: PezMaxFileNode): void {
    Row({ space: 12 }) {
      Image($r('app.media.resource_folder')).width(24).height(24).fillColor(this.accentColor);
      Column({ space: 3 }) {
        Text(node.label).fontSize(16).fontWeight(FontWeight.Medium).maxLines(2)
          .fontColor(THEME_TOKENS.primaryText)
          .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%');
        Text(`${node.children.length} 项`).fontSize(12).fontColor(THEME_TOKENS.secondaryText).width('100%');
      }.alignItems(HorizontalAlign.Start).layoutWeight(1);
      Image($r('app.media.nav_back')).width(18).height(18).fillColor(THEME_TOKENS.secondaryText)
        .rotate({ angle: 180 });
    }
    .width('100%').height(68).padding({ left: 14, right: 14, top: 10, bottom: 10 })
    .backgroundColor(Color.Transparent).borderRadius(16)
    .attributeModifier(compatibleImmersiveMaterial(this.accentColor, true))
    .onClick((): void => { this.enterFolder(node); })
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.985 });
  }

  @Builder
  private fileNode(node: PezMaxFileNode): void {
    if (node.fileInfo !== undefined) {
      this.resourceCard(node.fileInfo);
    }
  }

  @Builder
  private resourceCard(item: PezMaxFile): void {
    Column({ space: 8 }) {
      Row({ space: 10 }) {
        Image($r('app.media.resource_file')).width(24).height(24).fillColor(this.accentColor);
        Text(item.fileName.length > 0 ? item.fileName : '未命名资料')
          .fontSize(17).fontWeight(FontWeight.Medium).maxLines(2)
          .fontColor(THEME_TOKENS.primaryText)
          .textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1);
      }.width('100%');
      Text([item.fileSubject, item.fileSchool, item.fileYear > 0 ? `${item.fileYear}` : '', item.fileFormat]
        .filter((value: string): boolean => value.length > 0).join(' · '))
        .fontSize(13).fontColor(THEME_TOKENS.secondaryText).width('100%');
      Row({ space: 8 }) {
        Button(this.openingFileId === item.fileId ? '正在打开' : '打开').height(36).width(96)
          .enabled(this.openingFileId === 0).fontColor(this.accentColor).backgroundColor(Color.Transparent)
          .attributeModifier(compatibleImmersiveMaterial(this.accentColor)).onClick((): void => { void this.openFile(item); })
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 });
        if (this.mode === ResourceMode.Downloads) {
          Button('移除记录').height(36).fontColor(THEME_TOKENS.danger).backgroundColor(Color.Transparent)
            .attributeModifier(compatibleImmersiveMaterial(this.accentColor)).onClick((): void => { void this.removeDownload(item); })
            .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 });
        } else {
          Button(this.isFavorite(item.fileId) ? '取消收藏' : '收藏').height(36)
            .fontColor(this.isFavorite(item.fileId) ? THEME_TOKENS.danger : this.accentColor)
            .backgroundColor(Color.Transparent).attributeModifier(compatibleImmersiveMaterial(this.accentColor))
            .onClick((): void => { void this.toggleFavorite(item); })
            .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 });
        }
      }.width('100%');
    }
    .alignItems(HorizontalAlign.Start).padding(16).width('100%')
    .backgroundColor(Color.Transparent).borderRadius(18)
    .attributeModifier(compatibleImmersiveMaterial(this.accentColor, true));
  }

  private pageCount(): number {
    return Math.max(1, Math.ceil(this.total / this.pageSize));
  }

  private changePage(nextPage: number): void {
    if (nextPage < 1 || nextPage > this.pageCount() || nextPage === this.page) return;
    const offset: number = nextPage > this.page ? 8 : -8;
    this.page = nextPage;
    this.animateContent(offset);
    if (this.mode !== ResourceMode.All) void this.refresh(true);
  }

  @Builder
  private pagination(): void {
    if (this.total > this.pageSize) {
      Row({ space: 12 }) {
        Button({ type: ButtonType.Circle }) {
          Image($r('app.media.nav_back')).width(18).height(18).fillColor(this.accentColor);
        }
          .width(40).height(40).backgroundColor(Color.Transparent)
          .attributeModifier(compatibleImmersiveMaterial(this.accentColor)).enabled(this.page > 1)
          .onClick((): void => { this.changePage(this.page - 1); })
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 });
        Text(`${this.page} / ${this.pageCount()}`).fontSize(14).fontColor(THEME_TOKENS.secondaryText)
          .textAlign(TextAlign.Center).width(72);
        Button({ type: ButtonType.Circle }) {
          Image($r('app.media.nav_back')).width(18).height(18).fillColor(this.accentColor).rotate({ angle: 180 });
        }
          .width(40).height(40).backgroundColor(Color.Transparent)
          .attributeModifier(compatibleImmersiveMaterial(this.accentColor)).enabled(this.page < this.pageCount())
          .onClick((): void => { this.changePage(this.page + 1); })
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 });
      }.width('100%').justifyContent(FlexAlign.Center).padding({ top: 8, bottom: 4 });
    }
  }

  @Builder
  private breadcrumbs(): void {
    Scroll() {
      Row({ space: 4 }) {
        Button('全部资料').height(34).fontSize(13).fontColor(this.folderPath.length === 0 ? this.accentColor : THEME_TOKENS.secondaryText)
          .backgroundColor(Color.Transparent).attributeModifier(compatibleImmersiveMaterial(this.accentColor)).borderRadius(17)
          .onClick((): void => { this.jumpToFolder(-1); }).clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.98 });
        ForEach(this.folderPath, (node: PezMaxFileNode, index: number): void => {
          Text('/').fontColor(THEME_TOKENS.secondaryText);
          Button(node.label).height(34).fontSize(13)
            .fontColor(index === this.folderPath.length - 1 ? this.accentColor : THEME_TOKENS.secondaryText)
            .backgroundColor(Color.Transparent).attributeModifier(compatibleImmersiveMaterial(this.accentColor)).borderRadius(17)
            .onClick((): void => { this.jumpToFolder(index); }).clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.98 });
        }, (node: PezMaxFileNode): string => node.id);
      }.height(38);
    }.width('100%').height(38).scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off);
  }

  @Builder
  private resourcesPage(): void {
    Column() {
      Column({ space: 5 }) {
        Text('资料').fontSize(24).fontWeight(FontWeight.Bold).fontColor(THEME_TOKENS.primaryText);
        Text('浏览、收藏与管理下载记录').fontSize(14).fontColor(THEME_TOKENS.secondaryText);
      }
      .alignItems(HorizontalAlign.Start).width('100%')
      .padding({ left: this.pagePadding, right: this.pagePadding, top: 10, bottom: 18 });
      Scroll() {
        Column({ space: 12 }) {
        if (this.userName.length === 0) {
          Text('请先在“我的”页面登录').fontSize(15).fontColor(THEME_TOKENS.secondaryText)
            .width('100%').textAlign(TextAlign.Center).padding(32);
        } else {
          Row({ space: 4 }) {
            this.modeButton('全部', ResourceMode.All);
            this.modeButton('收藏', ResourceMode.Favorites);
            this.modeButton('下载', ResourceMode.Downloads);
          }.padding(4).width('100%').backgroundColor(Color.Transparent).borderRadius(22)
            .attributeModifier(compatibleImmersiveMaterial(this.accentColor));
          if (this.mode === ResourceMode.All) this.breadcrumbs();
          Row({ space: 8 }) {
            if (this.mode === ResourceMode.All && this.folderPath.length > 0) {
              Button({ type: ButtonType.Circle }) {
                Image($r('app.media.nav_back')).width(18).height(18).fillColor(this.accentColor);
              }.width(44).height(44).backgroundColor(Color.Transparent).attributeModifier(compatibleImmersiveMaterial(this.accentColor))
                .onClick((): void => { this.leaveFolder(); }).clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 });
            }
            TextInput({ text: this.keyword, placeholder: this.mode === ResourceMode.All ? '筛选当前文件夹' : '搜索资料名称' })
              .onChange((value: string): void => {
                this.keyword = value;
                this.page = 1;
                if (this.mode === ResourceMode.All) this.total = this.filteredFolderNodes().length;
              })
              .fontColor(THEME_TOKENS.primaryText).placeholderColor(THEME_TOKENS.secondaryText)
              .onSubmit((): void => { if (this.mode !== ResourceMode.All) void this.refresh(true); }).layoutWeight(1);
            if (this.mode !== ResourceMode.All) {
              Button('搜索').height(THEME_TOKENS.touchTarget).fontColor(this.accentColor).backgroundColor(Color.Transparent)
                .attributeModifier(compatibleImmersiveMaterial(this.accentColor)).onClick((): void => { this.page = 1; void this.refresh(true); })
                .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 });
            }
          }.width('100%');
          if (this.loading && ((this.mode === ResourceMode.All && this.treeNodes.length === 0) ||
            (this.mode !== ResourceMode.All && this.files.length === 0))) {
            Column() {
              LoadingProgress().width(32).height(32);
            }
            .layoutWeight(1).width('100%')
            .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center);
          } else {
            if (this.errorMessage.length > 0) Text(this.errorMessage).fontSize(13).fontColor(THEME_TOKENS.danger).width('100%');
            Column({ space: 10 }) {
              if (this.mode === ResourceMode.All) {
                if (this.visibleFolderNodes().length === 0) {
                  Text('当前文件夹暂无内容').fontSize(15).fontColor(THEME_TOKENS.secondaryText)
                    .width('100%').textAlign(TextAlign.Center).padding(32);
                }
                ForEach(this.visibleFolderNodes(), (node: PezMaxFileNode): void => {
                  if (node.type === 'folder') this.folderNode(node);
                  else this.fileNode(node);
                }, (node: PezMaxFileNode): string => node.id);
              } else {
                if (this.files.length === 0) {
                  Text(this.mode === ResourceMode.Favorites ? '暂无收藏' : '暂无下载记录')
                    .fontSize(15).fontColor(THEME_TOKENS.secondaryText).width('100%').textAlign(TextAlign.Center).padding(32);
                }
                ForEach(this.files, (item: PezMaxFile): void => { this.resourceCard(item); },
                  (item: PezMaxFile): string => `${item.fileId}`);
              }
            }.width('100%').opacity(this.contentOpacity).translate({ x: this.contentOffset });
            this.pagination();
          }
        }
        }
        .constraintSize({ minHeight: '100%' })
        .justifyContent(FlexAlign.Start).alignItems(HorizontalAlign.Start)
        .padding({ left: this.pagePadding, right: this.pagePadding, bottom: THEME_TOKENS.contentBottomInset })
        .width('100%');
      }
      .layoutWeight(1).width('100%').scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true });
    }
    .width('100%').height('100%');
  }

  build() {
    Column() { this.resourcesPage(); }.width('100%').height('100%');
  }
}

@Component
export struct PezMaxBookmarksView {
  @State private keyword: string = '';
  @State private bookmarks: PezMaxBookmark[] = [];
  @State private userName: string = '';
  @State private loading: boolean = false;
  @State private errorMessage: string = '';
  @State private showCreate: boolean = false;
  @State private draftTitle: string = '';
  @State private draftUrl: string = '';
  @State private draftDescription: string = '';
  @State private draftSubject: string = '';
  @State private draftCollection: string = '';
  @State private page: number = 1;
  @State private total: number = 0;
  @State private contentOpacity: number = 1;
  @State private contentOffset: number = 0;
  @StorageLink('layout_page_padding') private pagePadding: number = THEME_TOKENS.pagePadding;
  @StorageLink('pezmax_active_tab') @Watch('onTabChanged') private activeTab: number = 0;
  @StorageLink('pezmax_session_revision') @Watch('onSessionChanged') private sessionRevision: number = 0;
  @StorageLink('appearance_accent_color') private accentColor: string = '#3559D8';
  private readonly pageSize: number = 8;
  private refreshing: boolean = false;
  private lastRefreshAt: number = 0;

  aboutToAppear(): void { this.sync(); }

  private onTabChanged(): void {
    this.sync();
    if (this.activeTab === 2) {
      setTimeout((): void => { if (this.activeTab === 2) void this.refresh(false); }, 100);
    }
  }

  private onSessionChanged(): void {
    this.sync();
    if (this.activeTab === 2 && this.userName.length > 0) void this.refresh(true);
  }

  private sync(): void {
    const state = AppStore.pezMaxViewModel.state;
    this.userName = currentUserName();
    this.bookmarks = state.bookmarks;
    this.total = state.bookmarkTotal;
    this.loading = this.refreshing || state.loading;
    this.errorMessage = state.errorMessage;
  }

  private async refresh(force: boolean): Promise<void> {
    this.sync();
    if (this.userName.length === 0 || this.refreshing) return;
    if (!force && Date.now() - this.lastRefreshAt < 30000) return;
    this.refreshing = true;
    this.loading = true;
    try {
      await AppStore.pezMaxViewModel.loadBookmarks(this.keyword, this.page, this.pageSize);
      this.lastRefreshAt = Date.now();
    } finally {
      this.refreshing = false;
      this.sync();
    }
  }

  private openBookmark(item: PezMaxBookmark): void {
    const url: string = absoluteUrl(item.url);
    if (url.length === 0) {
      this.errorMessage = '该书签没有可用地址';
      return;
    }
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    void context.startAbility({ action: 'ohos.want.action.viewData', uri: url });
  }

  private async confirmDelete(item: PezMaxBookmark): Promise<void> {
    const result: promptAction.ShowDialogSuccessResponse = await promptAction.showDialog({
      title: '删除书签',
      message: `确定删除“${item.title || item.url}”吗？`,
      buttons: [{ text: '取消', color: '#667085' }, { text: '删除', color: '#C62828' }]
    });
    if (result.index !== 1) return;
    await AppStore.pezMaxViewModel.deleteBookmark(item.id);
    this.sync();
    if (this.bookmarks.length === 0 && this.page > 1) {
      this.page -= 1;
      await this.refresh(true);
    }
  }

  private async createBookmark(): Promise<void> {
    if (this.draftTitle.trim().length === 0 || this.draftUrl.trim().length === 0) {
      this.errorMessage = '标题和链接不能为空';
      return;
    }
    const success: boolean = await AppStore.pezMaxViewModel.createBookmark({
      id: 0, title: this.draftTitle.trim(), url: this.draftUrl.trim(), description: this.draftDescription.trim(),
      subject: this.draftSubject.trim(), collection: this.draftCollection.trim(), resourceType: '', coverImage: '', userId: 0
    });
    this.sync();
    if (!success) return;
    this.draftTitle = '';
    this.draftUrl = '';
    this.draftDescription = '';
    this.draftSubject = '';
    this.draftCollection = '';
    this.showCreate = false;
    this.page = 1;
    await this.refresh(true);
    promptAction.showToast({ message: '书签已创建' });
  }

  private pageCount(): number {
    return Math.max(1, Math.ceil(this.total / this.pageSize));
  }

  private changePage(nextPage: number): void {
    if (nextPage < 1 || nextPage > this.pageCount() || nextPage === this.page) return;
    const offset: number = nextPage > this.page ? 8 : -8;
    this.page = nextPage;
    this.contentOpacity = 0.35;
    this.contentOffset = offset;
    animateTo({ duration: 160, curve: Curve.EaseOut }, (): void => {
      this.contentOpacity = 1;
      this.contentOffset = 0;
    });
    void this.refresh(true);
  }

  @Builder
  private pagination(): void {
    if (this.total > this.pageSize) {
      Row({ space: 12 }) {
        Button({ type: ButtonType.Circle }) {
          Image($r('app.media.nav_back')).width(18).height(18).fillColor(this.accentColor);
        }.width(40).height(40).backgroundColor(Color.Transparent).attributeModifier(compatibleImmersiveMaterial(this.accentColor))
          .enabled(this.page > 1).onClick((): void => { this.changePage(this.page - 1); })
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 });
        Text(`${this.page} / ${this.pageCount()}`).fontSize(14).fontColor(THEME_TOKENS.secondaryText)
          .textAlign(TextAlign.Center).width(72);
        Button({ type: ButtonType.Circle }) {
          Image($r('app.media.nav_back')).width(18).height(18).fillColor(this.accentColor).rotate({ angle: 180 });
        }.width(40).height(40).backgroundColor(Color.Transparent).attributeModifier(compatibleImmersiveMaterial(this.accentColor))
          .enabled(this.page < this.pageCount()).onClick((): void => { this.changePage(this.page + 1); })
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 });
      }.width('100%').justifyContent(FlexAlign.Center).padding({ top: 8, bottom: 4 });
    }
  }

  @Builder
  private bookmarkCard(item: PezMaxBookmark): void {
    Column({ space: 8 }) {
      Text(item.title.length > 0 ? item.title : item.url).fontSize(17).fontWeight(FontWeight.Medium)
        .fontColor(THEME_TOKENS.primaryText)
        .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%');
      Text(item.url).fontSize(13).fontColor(this.accentColor).maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%');
      if (item.description.length > 0) {
        Text(item.description).fontSize(14).fontColor(THEME_TOKENS.secondaryText)
          .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%');
      }
      if (item.subject.length > 0 || item.collection.length > 0) {
        Text([item.subject, item.collection].filter((value: string): boolean => value.length > 0).join(' · '))
          .fontSize(12).fontColor(THEME_TOKENS.secondaryText).width('100%');
      }
      Row({ space: 8 }) {
        Button('打开').height(36).fontColor(this.accentColor).backgroundColor(Color.Transparent)
          .attributeModifier(compatibleImmersiveMaterial(this.accentColor)).onClick((): void => { this.openBookmark(item); })
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 });
        Button('删除').height(36).fontColor(THEME_TOKENS.danger).backgroundColor(Color.Transparent)
          .attributeModifier(compatibleImmersiveMaterial(this.accentColor)).onClick((): void => { void this.confirmDelete(item); })
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 });
      }.width('100%');
    }
    .alignItems(HorizontalAlign.Start).padding(16).width('100%')
    .backgroundColor(Color.Transparent).borderRadius(18)
    .attributeModifier(compatibleImmersiveMaterial(this.accentColor, true));
  }

  build() {
    Column() {
      Row() {
        Column({ space: 5 }) {
          Text('书签').fontSize(24).fontWeight(FontWeight.Bold).fontColor(THEME_TOKENS.primaryText);
          Text('收藏与整理常用链接').fontSize(14).fontColor(THEME_TOKENS.secondaryText);
        }.alignItems(HorizontalAlign.Start).layoutWeight(1);
        if (this.userName.length > 0) {
          Button(this.showCreate ? '取消' : '新增').height(THEME_TOKENS.touchTarget)
            .fontColor(this.accentColor).backgroundColor(Color.Transparent)
            .attributeModifier(compatibleImmersiveMaterial(this.accentColor))
            .onClick((): void => { this.showCreate = !this.showCreate; })
            .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 });
        }
      }
      .width('100%')
      .padding({ left: this.pagePadding, right: this.pagePadding, top: 10, bottom: 18 });
      Scroll() {
        Column({ space: 12 }) {
        if (this.userName.length === 0) {
          Text('请先在“我的”页面登录').fontSize(15).fontColor(THEME_TOKENS.secondaryText)
            .width('100%').textAlign(TextAlign.Center).padding(32);
        } else {
          if (this.showCreate) {
            Column({ space: 10 }) {
              Text('新增书签').fontSize(18).fontWeight(FontWeight.Medium)
                .fontColor(THEME_TOKENS.primaryText).width('100%');
              TextInput({ text: this.draftTitle, placeholder: '标题' }).fontColor(THEME_TOKENS.primaryText)
                .placeholderColor(THEME_TOKENS.secondaryText).onChange((value: string): void => { this.draftTitle = value; });
              TextInput({ text: this.draftUrl, placeholder: '链接地址' }).fontColor(THEME_TOKENS.primaryText)
                .placeholderColor(THEME_TOKENS.secondaryText).onChange((value: string): void => { this.draftUrl = value; });
              TextArea({ text: this.draftDescription, placeholder: '描述（可选）' })
                .fontColor(THEME_TOKENS.primaryText).placeholderColor(THEME_TOKENS.secondaryText)
                .onChange((value: string): void => { this.draftDescription = value; }).height(80);
              TextInput({ text: this.draftSubject, placeholder: '学科（可选）' }).fontColor(THEME_TOKENS.primaryText)
                .placeholderColor(THEME_TOKENS.secondaryText).onChange((value: string): void => { this.draftSubject = value; });
              TextInput({ text: this.draftCollection, placeholder: '分类（可选）' }).fontColor(THEME_TOKENS.primaryText)
                .placeholderColor(THEME_TOKENS.secondaryText).onChange((value: string): void => { this.draftCollection = value; });
              Button('保存书签').enabled(!this.loading).width('100%').fontColor(this.accentColor)
                .backgroundColor(Color.Transparent).attributeModifier(compatibleImmersiveMaterial(this.accentColor))
                .onClick((): void => { void this.createBookmark(); })
                .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 });
            }.alignItems(HorizontalAlign.Start).width('100%').padding(16)
              .backgroundColor(Color.Transparent).borderRadius(18)
              .attributeModifier(compatibleImmersiveMaterial(this.accentColor, true));
          }
          Row({ space: 8 }) {
            TextInput({ text: this.keyword, placeholder: '搜索书签标题' })
              .fontColor(THEME_TOKENS.primaryText).placeholderColor(THEME_TOKENS.secondaryText)
              .onChange((value: string): void => { this.keyword = value; this.page = 1; })
              .onSubmit((): void => { void this.refresh(true); }).layoutWeight(1);
            Button('搜索').height(THEME_TOKENS.touchTarget).fontColor(this.accentColor).backgroundColor(Color.Transparent)
              .attributeModifier(compatibleImmersiveMaterial(this.accentColor)).onClick((): void => { this.page = 1; void this.refresh(true); })
              .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 });
          }.width('100%');
          if (this.loading && this.bookmarks.length === 0) LoadingProgress().width(32).height(32);
          if (this.errorMessage.length > 0) Text(this.errorMessage).fontSize(13).fontColor(THEME_TOKENS.danger).width('100%');
          if (!this.loading && this.bookmarks.length === 0) {
            Text('暂无书签').fontSize(15).fontColor(THEME_TOKENS.secondaryText).width('100%').textAlign(TextAlign.Center).padding(32);
          }
          Column({ space: 10 }) {
            ForEach(this.bookmarks, (item: PezMaxBookmark): void => { this.bookmarkCard(item); },
              (item: PezMaxBookmark): string => `${item.id}`);
          }.width('100%').opacity(this.contentOpacity).translate({ x: this.contentOffset });
          this.pagination();
        }
        }
        .constraintSize({ minHeight: '100%' })
        .justifyContent(FlexAlign.Start).alignItems(HorizontalAlign.Start)
        .padding({ left: this.pagePadding, right: this.pagePadding, bottom: THEME_TOKENS.contentBottomInset })
        .width('100%');
      }
      .layoutWeight(1).width('100%').scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true });
    }
    .width('100%').height('100%');
  }
}

@Component
export struct PezMaxProfileView {
  @State private username: string = '';
  @State private password: string = '';
  @State private confirmPassword: string = '';
  @State private registerMode: boolean = false;
  @State private registerStep: number = 1;
  @State private securityQuestionOne: string = '';
  @State private securityAnswerOne: string = '';
  @State private securityQuestionTwo: string = '';
  @State private securityAnswerTwo: string = '';
  @State private securityQuestionThree: string = '';
  @State private securityAnswerThree: string = '';
  @State private acceptedDisclaimer: boolean = false;
  @State private captchaCode: string = '';
  @State private captchaUuid: string = '';
  @State private captchaImage: string = '';
  @State private captchaEnabled: boolean = false;
  @State private userName: string = '';
  @State private avatar: string = '';
  @State private loading: boolean = false;
  @State private errorMessage: string = '';
  @State private message: string = '';
  @State private uploadRank: PezMaxUploadRank[] = [];
  @State private rankLoading: boolean = false;
  @State private rankError: string = '';
  @State private currentUserId: number = 0;
  @State private accountUserName: string = '';
  @State private accountQuestionOne: string = '';
  @State private accountAnswerOne: string = '';
  @State private accountQuestionTwo: string = '';
  @State private accountAnswerTwo: string = '';
  @State private accountQuestionThree: string = '';
  @State private accountAnswerThree: string = '';
  @State private securityVerificationPassword: string = '';
  @State private oldPassword: string = '';
  @State private newPassword: string = '';
  @State private confirmNewPassword: string = '';
  @State private accountLoading: boolean = false;
  @State private accountMessage: string = '';
  @State private accountError: string = '';
  @State private subpage: string = 'profile';
  @State private showAboutSheet: boolean = false;
  @State private aboutSheetKind: number = 0;
  @State private expandedChangelogVersion: string = '1.0.3';
  @State private changelogContentEntered: boolean = false;
  @StorageLink('pezmax_settings_open') private settingsOpen: boolean = false;
  @StorageLink('layout_page_padding') private pagePadding: number = THEME_TOKENS.pagePadding;
  @StorageLink('layout_window_width') private windowWidth: number = THEME_TOKENS.compactWidth;
  @StorageLink('pezmax_store_ready') @Watch('onStoreReady') private storeReady: boolean = false;
  @StorageLink('pezmax_active_tab') @Watch('onTabChanged') private activeTab: number = 0;
  @StorageLink('pezmax_session_revision') @Watch('sync') private sessionRevision: number = 0;
  @StorageLink('appearance_color_mode') private colorMode: string = 'system';
  @StorageLink('system_color_mode') private systemColorMode: string = 'light';
  @StorageLink('appearance_accent_color') private accentColor: string = '#3559D8';
  @StorageLink('appearance_material_level') private materialLevel: string = MaterialLevel.Gentle;
  private pageStack: NavPathStack = new NavPathStack();
  private rankRefreshing: boolean = false;
  private lastRankRefreshAt: number = 0;

  aboutToAppear(): void {
    this.sync();
    if (this.userName.length === 0 && this.storeReady) void this.refreshCaptcha();
    if (this.userName.length > 0) void this.refreshUploadRank(false);
  }

  private onStoreReady(): void {
    this.sync();
    if (this.storeReady && this.userName.length === 0) void this.refreshCaptcha();
  }

  private onTabChanged(): void {
    if (this.activeTab !== 3) return;
    this.sync();
    if (this.userName.length === 0 && this.captchaUuid.length === 0) {
      setTimeout((): void => {
        if (this.activeTab === 3 && this.userName.length === 0 && this.captchaUuid.length === 0) {
          void this.refreshCaptcha();
        }
      }, 100);
    }
    if (this.userName.length > 0) void this.refreshUploadRank(false);
  }

  private sync(): void {
    const state = AppStore.pezMaxViewModel.state;
    this.userName = currentUserName();
    this.loading = state.authLoading;
    this.errorMessage = state.errorMessage;
    this.message = state.message;
    this.uploadRank = state.uploadRank;
    this.currentUserId = state.user?.userId ?? 0;
    this.avatar = state.user?.avatar ?? '';
  }

  private async refreshUploadRank(force: boolean): Promise<void> {
    if (this.userName.length === 0 || this.rankRefreshing) return;
    if (!force && Date.now() - this.lastRankRefreshAt < 60000 && this.uploadRank.length > 0) return;
    this.rankRefreshing = true;
    this.rankLoading = true;
    this.rankError = '';
    try {
      await AppStore.pezMaxViewModel.loadUploadRank();
      this.lastRankRefreshAt = Date.now();
    } catch (error) {
      this.rankError = error instanceof Error ? error.message : '获取上传排行榜失败';
    } finally {
      this.rankRefreshing = false;
      this.rankLoading = false;
      this.sync();
    }
  }

  private publishSessionChange(): void {
    const revision: number = Date.now();
    AppStorage.setOrCreate('pezmax_session_revision', revision);
    AppStorage.set('pezmax_session_revision', revision);
  }

  private publishSubpage(page: string, open: boolean): void {
    animateTo({ duration: 180, curve: Curve.EaseOut }, (): void => {
      this.subpage = open ? page : 'profile';
      this.settingsOpen = open;
      AppStorage.setOrCreate('pezmax_settings_open', open);
      AppStorage.set('pezmax_settings_open', open);
    });
  }

  private openSubpage(page: string): void {
    if (this.settingsOpen && this.subpage === page) return;
    if (page === 'account') {
      this.prepareAccountEditor();
      void this.loadAccountSecurity();
    }
    this.publishSubpage(page, true);
    this.pageStack.pushPathByName(page, false);
  }

  private prepareAccountEditor(): void {
    this.accountUserName = this.userName;
    this.accountQuestionOne = '';
    this.accountQuestionTwo = '';
    this.accountQuestionThree = '';
    this.accountAnswerOne = '';
    this.accountAnswerTwo = '';
    this.accountAnswerThree = '';
    this.securityVerificationPassword = '';
    this.oldPassword = '';
    this.newPassword = '';
    this.confirmNewPassword = '';
    this.accountMessage = '';
    this.accountError = '';
  }

  private clearAccountFeedback(): void {
    this.accountError = '';
    this.accountMessage = '';
  }

  private showAccountError(message: string): void {
    this.accountMessage = '';
    this.accountError = message;
    promptAction.showToast({ message });
  }

  private showAccountSuccess(message: string): void {
    this.accountError = '';
    this.accountMessage = message;
    promptAction.showToast({ message });
  }

  private async loadAccountSecurity(): Promise<void> {
    this.accountLoading = true;
    try {
      const questions: string[] = await AppStore.pezMaxViewModel.securityQuestions();
      this.accountQuestionOne = questions[0] ?? '';
      this.accountQuestionTwo = questions[1] ?? '';
      this.accountQuestionThree = questions[2] ?? '';
    } catch (error) {
      this.accountError = error instanceof Error ? error.message : '获取密保问题失败';
    } finally {
      this.accountLoading = false;
    }
  }

  private async saveAccountUserName(): Promise<void> {
    const value: string = this.accountUserName.trim();
    if (value.length < 2 || value.length > 20) {
      this.showAccountError('用户名长度必须为 2-20 位');
      return;
    }
    this.accountLoading = true;
    this.clearAccountFeedback();
    try {
      await AppStore.pezMaxViewModel.updateUserName(value);
      this.sync();
      this.publishSessionChange();
      this.showAccountSuccess('用户名已更新');
    } catch (error) {
      this.showAccountError(error instanceof Error ? error.message : '修改用户名失败');
    } finally {
      this.accountLoading = false;
    }
  }

  private async saveAccountSecurity(): Promise<void> {
    const draft: PezMaxSecurityDraft = {
      securityQuestionOne: this.accountQuestionOne.trim(), securityAnswerOne: this.accountAnswerOne.trim(),
      securityQuestionTwo: this.accountQuestionTwo.trim(), securityAnswerTwo: this.accountAnswerTwo.trim(),
      securityQuestionThree: this.accountQuestionThree.trim(), securityAnswerThree: this.accountAnswerThree.trim()
    };
    if (draft.securityQuestionOne.length === 0 || draft.securityAnswerOne.length === 0 ||
      draft.securityQuestionTwo.length === 0 || draft.securityAnswerTwo.length === 0 ||
      draft.securityQuestionThree.length === 0 || draft.securityAnswerThree.length === 0) {
      this.showAccountError('请完整填写三组密保问题和答案');
      return;
    }
    if (this.securityVerificationPassword.length === 0) {
      this.showAccountError('请输入当前登录密码以验证身份');
      return;
    }
    this.accountLoading = true;
    this.clearAccountFeedback();
    try {
      await AppStore.pezMaxViewModel.verifyPassword(this.securityVerificationPassword);
      await AppStore.pezMaxViewModel.updateSecurity(draft);
      this.securityVerificationPassword = '';
      this.accountAnswerOne = '';
      this.accountAnswerTwo = '';
      this.accountAnswerThree = '';
      this.showAccountSuccess('密保问题已更新');
    } catch (error) {
      this.showAccountError(error instanceof Error ? error.message : '修改密保失败');
    } finally {
      this.accountLoading = false;
    }
  }

  private async saveAccountPassword(): Promise<void> {
    const validLength: boolean = this.newPassword.length >= 5 && this.newPassword.length <= 20;
    const hasNumber: boolean = new RegExp('[0-9]').test(this.newPassword);
    const hasLetter: boolean = new RegExp('[A-Za-z]').test(this.newPassword);
    const hasSymbol: boolean = new RegExp('[!-/:-@\\[-`{-~]').test(this.newPassword);
    if (this.oldPassword.length === 0) {
      this.showAccountError('请输入当前密码');
      return;
    }
    if (!validLength || !hasNumber || !hasLetter || !hasSymbol) {
      this.showAccountError('新密码需为 5-20 位，并同时包含数字、字母与符号');
      return;
    }
    if (this.newPassword !== this.confirmNewPassword) {
      this.showAccountError('两次输入的新密码不一致');
      return;
    }
    this.accountLoading = true;
    this.clearAccountFeedback();
    try {
      await AppStore.pezMaxViewModel.updatePassword(this.oldPassword, this.newPassword);
      this.oldPassword = '';
      this.newPassword = '';
      this.confirmNewPassword = '';
      this.showAccountSuccess('登录密码已更新');
    } catch (error) {
      this.showAccountError(error instanceof Error ? error.message : '修改密码失败');
    } finally {
      this.accountLoading = false;
    }
  }

  private normalizedAvatar(value: string): string {
    const avatar: string = value.trim();
    if (avatar.length === 0 || avatar === 'null' || avatar === 'default.png') return '';
    if (avatar.startsWith('http://') || avatar.startsWith('https://') || avatar.startsWith('data:')) return avatar;
    return avatar.startsWith('/') ? `${PEZMAX_API_BASE_URL}${avatar}` : `${PEZMAX_API_BASE_URL}/${avatar}`;
  }

  private closeSubpage(): void {
    if (!this.settingsOpen) return;
    this.pageStack.pop();
    this.publishSubpage('profile', false);
  }

  private onSubpageHidden(page: string): void {
    if (!this.settingsOpen || this.subpage !== page) return;
    this.publishSubpage('profile', false);
  }

  private openChangelog(): void {
    this.expandedChangelogVersion = CHANGELOG_ENTRIES[0].version;
    this.changelogContentEntered = false;
    this.aboutSheetKind = 1;
    this.showAboutSheet = true;
    setTimeout((): void => { this.changelogContentEntered = true; }, 80);
  }

  private openPrivacyPolicy(): void {
    this.aboutSheetKind = 2;
    this.showAboutSheet = true;
  }

  private labels(options: AppearanceOption[]): string[] {
    return options.map((option: AppearanceOption): string => option.label);
  }

  private selectOptions(options: AppearanceOption[]): SelectOption[] {
    return this.labels(options).map((label: string): SelectOption => ({ value: label }));
  }

  private optionIndex(options: AppearanceOption[], value: string): number {
    const index: number = options.findIndex((option: AppearanceOption): boolean => option.value === value);
    return index < 0 ? 0 : index;
  }

  private selectColorMode(index: number): void {
    const option: AppearanceOption | undefined = COLOR_MODE_OPTIONS[index];
    if (option === undefined) return;
    animateTo({ duration: 220, curve: Curve.EaseOut }, (): void => {
      this.colorMode = option.value;
      AppStorage.set('appearance_color_mode', option.value);
    });
    AppStore.saveAppearance('color_mode', option.value);
    SystemBarAppearance.apply(option.value);
  }

  private selectAccent(option: AppearanceOption): void {
    animateTo({ duration: 240, curve: Curve.EaseOut }, (): void => {
      this.accentColor = option.value;
      AppStorage.set('appearance_accent_color', option.value);
    });
    AppStore.saveAppearance('accent_color', option.value);
  }

  private selectMaterial(index: number): void {
    const option: AppearanceOption | undefined = MATERIAL_OPTIONS[index];
    if (option === undefined) return;
    this.materialLevel = option.value;
    AppStore.saveAppearance('material_level', option.value);
    AppStorage.set('appearance_material_level', option.value);
  }

  private async refreshCaptcha(): Promise<void> {
    try {
      const captcha: PezMaxCaptcha = await AppStore.pezMaxViewModel.captcha();
      this.captchaEnabled = captcha.enabled;
      this.captchaUuid = captcha.uuid;
      this.captchaImage = captcha.image;
      this.captchaCode = '';
    } catch (error) {
      this.errorMessage = error instanceof Error ? error.message : '获取验证码失败';
    }
  }

  private async login(): Promise<void> {
    if (this.username.trim().length === 0 || this.password.length === 0) {
      this.errorMessage = '请输入账号和密码';
      return;
    }
    if (this.captchaEnabled && (this.captchaCode.trim().length === 0 || this.captchaUuid.length === 0)) {
      this.errorMessage = '请输入验证码';
      return;
    }
    const success: boolean = await AppStore.pezMaxViewModel.login(this.username, this.password, this.captchaCode, this.captchaUuid);
    this.sync();
    if (success) {
      this.password = '';
      this.captchaCode = '';
      this.publishSessionChange();
      void this.refreshUploadRank(true);
      promptAction.showToast({ message: '登录成功' });
    } else {
      await this.refreshCaptcha();
    }
  }

  private switchAuthMode(registerMode: boolean): void {
    if (this.registerMode === registerMode) return;
    animateTo({ duration: 170, curve: Curve.EaseOut }, (): void => {
      this.registerMode = registerMode;
      this.registerStep = 1;
      this.errorMessage = '';
      this.message = '';
    });
    void this.refreshCaptcha();
  }

  private nextRegisterStep(): void {
    const account: string = this.username.trim();
    if (account.length < 2 || account.length > 20) {
      this.errorMessage = '账号长度必须为 2-20 位';
      return;
    }
    if (this.password.length < 5 || this.password.length > 15) {
      this.errorMessage = '密码长度必须为 5-15 位';
      return;
    }
    const usesPrintableCharacters: boolean = new RegExp('^[\\x21-\\x7E]+$').test(this.password);
    const hasNumber: boolean = new RegExp('[0-9]').test(this.password);
    const hasLetter: boolean = new RegExp('[A-Za-z]').test(this.password);
    const hasSymbol: boolean = new RegExp('[!-/:-@\\[-`{-~]').test(this.password);
    if (!usesPrintableCharacters || !hasNumber || !hasLetter || !hasSymbol) {
      this.errorMessage = '密码需同时包含数字、字母与符号';
      return;
    }
    if (this.password !== this.confirmPassword) {
      this.errorMessage = '两次输入的密码不一致';
      return;
    }
    this.errorMessage = '';
    animateTo({ duration: 170, curve: Curve.EaseOut }, (): void => { this.registerStep = 2; });
  }

  private async register(): Promise<void> {
    if ([this.securityQuestionOne, this.securityAnswerOne, this.securityQuestionTwo, this.securityAnswerTwo,
      this.securityQuestionThree, this.securityAnswerThree].some((value: string): boolean => value.trim().length === 0)) {
      this.errorMessage = '请完整填写三组密保问题和答案';
      return;
    }
    if (!this.acceptedDisclaimer) {
      this.errorMessage = '请先同意用户注册及免责声明';
      return;
    }
    if (this.captchaEnabled && (this.captchaCode.trim().length === 0 || this.captchaUuid.length === 0)) {
      this.errorMessage = '请输入验证码';
      return;
    }
    const draft: PezMaxRegisterDraft = {
      username: this.username,
      password: this.password,
      confirmPassword: this.confirmPassword,
      securityQuestionOne: this.securityQuestionOne,
      securityAnswerOne: this.securityAnswerOne,
      securityQuestionTwo: this.securityQuestionTwo,
      securityAnswerTwo: this.securityAnswerTwo,
      securityQuestionThree: this.securityQuestionThree,
      securityAnswerThree: this.securityAnswerThree,
      code: this.captchaCode,
      uuid: this.captchaUuid
    };
    const success: boolean = await AppStore.pezMaxViewModel.register(draft);
    this.sync();
    if (success) {
      this.password = '';
      this.confirmPassword = '';
      this.captchaCode = '';
      this.acceptedDisclaimer = false;
      this.registerStep = 1;
      this.registerMode = false;
      promptAction.showToast({ message: '注册成功，请登录' });
    }
    await this.refreshCaptcha();
  }

  private async logout(): Promise<void> {
    await AppStore.pezMaxViewModel.logout();
    this.sync();
    this.publishSessionChange();
    await this.refreshCaptcha();
  }

  private rankColor(index: number): ResourceColor {
    if (index === 0) return '#D89B20';
    if (index === 1) return '#738197';
    if (index === 2) return '#B66C43';
    return this.accentColor;
  }

  private rankInitial(item: PezMaxUploadRank): string {
    const name: string = item.userName.trim();
    return name.length > 0 ? name.slice(0, 1).toUpperCase() : '?';
  }

  @Builder
  private uploadRankPanel(): void {
    Column({ space: 0 }) {
      Row({ space: 10 }) {
        Column({ space: 3 }) {
          Text('上传排行榜').fontSize(18).fontWeight(FontWeight.Medium).fontColor(THEME_TOKENS.primaryText);
          Text('按已通过审核的上传数量排名').fontSize(12).fontColor(THEME_TOKENS.secondaryText);
        }.alignItems(HorizontalAlign.Start).layoutWeight(1);
        Button('刷新').height(38).fontColor(this.accentColor).backgroundColor(Color.Transparent)
          .attributeModifier(compatibleImmersiveMaterial(this.accentColor))
          .enabled(!this.rankLoading).onClick((): void => { void this.refreshUploadRank(true); })
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 });
      }.width('100%').padding({ left: 16, right: 12, top: 14, bottom: 12 });
      if (this.rankLoading && this.uploadRank.length === 0) {
        LoadingProgress().width(28).height(28).margin({ top: 18, bottom: 22 });
      } else if (this.rankError.length > 0 && this.uploadRank.length === 0) {
        Text(this.rankError).fontSize(13).fontColor(THEME_TOKENS.danger)
          .width('100%').textAlign(TextAlign.Center).padding({ top: 18, bottom: 22 });
      } else if (this.uploadRank.length === 0) {
        Text('暂无排行榜数据').fontSize(13).fontColor(THEME_TOKENS.secondaryText)
          .width('100%').textAlign(TextAlign.Center).padding({ top: 18, bottom: 22 });
      } else {
        Column({ space: 0 }) {
          ForEach(this.uploadRank, (item: PezMaxUploadRank, index: number): void => {
            if (index > 0) Divider().margin({ left: 58, right: 14 });
            Row({ space: 10 }) {
              Text(`${index + 1}`).fontSize(14).fontWeight(FontWeight.Bold).fontColor(this.rankColor(index))
                .width(24).textAlign(TextAlign.Center);
              Stack({ alignContent: Alignment.Center }) {
                Column().width(34).height(34).backgroundColor(this.rankColor(index)).borderRadius(17).opacity(0.16);
                Text(this.rankInitial(item)).fontSize(14).fontWeight(FontWeight.Medium).fontColor(this.rankColor(index));
                if (this.normalizedAvatar(item.avatar).length > 0) {
                  Image(this.normalizedAvatar(item.avatar)).width(34).height(34).borderRadius(17)
                    .objectFit(ImageFit.Cover);
                }
              }.width(36).height(36);
              Column({ space: 2 }) {
                Text(item.userName.length > 0 ? item.userName : `用户 ${item.userId}`)
                  .fontSize(15).fontWeight(item.userId === this.currentUserId ? FontWeight.Bold : FontWeight.Medium)
                  .fontColor(THEME_TOKENS.primaryText).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis });
                Text(item.userId === this.currentUserId ? '我的排名' : 'PezMax 用户')
                  .fontSize(11).fontColor(THEME_TOKENS.secondaryText);
              }.alignItems(HorizontalAlign.Start).layoutWeight(1);
              Text(`${item.count}`).fontSize(17).fontWeight(FontWeight.Bold).fontColor(this.rankColor(index));
              Text('份').fontSize(11).fontColor(THEME_TOKENS.secondaryText);
            }
            .width('100%').height(58).padding({ left: 12, right: 16 })
            .backgroundColor(item.userId === this.currentUserId ? '#103559D8' : Color.Transparent);
          }, (item: PezMaxUploadRank): string => `${item.userId}`);
        }.width('100%');
      }
    }
    .alignItems(HorizontalAlign.Center).width('100%').backgroundColor(Color.Transparent).borderRadius(18)
    .attributeModifier(compatibleImmersiveMaterial(this.accentColor, true));
  }

  @Builder
  private settingsEntry(): void {
    Row({ space: 12 }) {
      Image($r('app.media.my_settings')).width(22).height(22).fillColor(this.accentColor);
      Column({ space: 3 }) {
        Text('设置').fontSize(17).fontWeight(FontWeight.Medium).fontColor(THEME_TOKENS.primaryText);
        Text('外观与沉浸光感').fontSize(13).fontColor(THEME_TOKENS.secondaryText);
      }.alignItems(HorizontalAlign.Start).layoutWeight(1);
      Text('›').fontSize(26).fontColor(THEME_TOKENS.secondaryText);
    }
    .width('100%').padding(16).backgroundColor(Color.Transparent).borderRadius(18)
    .attributeModifier(compatibleImmersiveMaterial(this.accentColor, true))
    .onClick((): void => { this.openSubpage('settings'); })
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.985 });
  }

  @Builder
  private aboutEntry(): void {
    Row({ space: 12 }) {
      Image($r('app.media.my_about')).width(22).height(22).fillColor(this.accentColor);
      Column({ space: 3 }) {
        Text('关于').fontSize(17).fontWeight(FontWeight.Medium).fontColor(THEME_TOKENS.primaryText);
        Text('应用信息、更新日志与隐私政策').fontSize(13).fontColor(THEME_TOKENS.secondaryText);
      }.alignItems(HorizontalAlign.Start).layoutWeight(1);
      Text('›').fontSize(26).fontColor(THEME_TOKENS.secondaryText);
    }
    .width('100%').padding(16).backgroundColor(Color.Transparent).borderRadius(18)
    .attributeModifier(compatibleImmersiveMaterial(this.accentColor, true))
    .onClick((): void => { this.openSubpage('about'); })
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.985 });
  }

  @Builder
  private accentPicker(): void {
    Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
      ForEach(ACCENT_OPTIONS, (option: AppearanceOption): void => {
        Row({ space: 8 }) {
          Stack({ alignContent: Alignment.Center }) {
            Column().width(22).height(22).backgroundColor(option.value).borderRadius(11);
            if (this.accentColor === option.value) Column().width(8).height(8).backgroundColor(Color.White).borderRadius(4);
          }.width(28).height(32);
          Text(option.label).fontSize(14).fontColor(THEME_TOKENS.primaryText).maxLines(1);
        }
        .width('48%').height(52).padding({ left: 8, right: 8 }).margin({ top: 4, bottom: 4 })
        .border({ width: this.accentColor === option.value ? 1 : 0, color: option.value })
        .borderRadius(18).backgroundColor(Color.Transparent)
        .attributeModifier(compatibleImmersiveMaterial(option.value))
        .onClick((): void => { this.selectAccent(option); })
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.985 });
      }, (option: AppearanceOption): string => option.value);
    }.width('100%');
  }

  @Builder
  private subpageHeader(title: string): void {
    Row({ space: 10 }) {
      Button({ type: ButtonType.Circle }) {
        Image($r('app.media.nav_back')).width(20).height(20).fillColor(this.accentColor);
      }
        .width(40).height(40).backgroundColor(Color.Transparent)
        .attributeModifier(compatibleImmersiveMaterial(this.accentColor, false, true))
        .onClick((): void => { this.closeSubpage(); })
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 });
      Text(title).fontSize(24).fontWeight(FontWeight.Bold).fontColor(THEME_TOKENS.primaryText);
    }
    .width('100%').height(48)
    .padding({ left: this.subpageHorizontalPadding(), right: this.subpageHorizontalPadding() });
  }

  private subpageHorizontalPadding(): number {
    if (this.windowWidth < THEME_TOKENS.tabletWidth) return this.pagePadding;
    return Math.max(this.pagePadding, (this.windowWidth - 720) / 2);
  }

  private subpageTopPadding(): number {
    return this.windowWidth >= THEME_TOKENS.tabletWidth ? 12 : 8;
  }

  private subpageBackground(): ResourceColor {
    const dark: boolean = this.colorMode === 'dark' ||
      (this.colorMode === 'system' && this.systemColorMode === 'dark');
    return dark ? '#10131A' : '#F7F8FC';
  }

  @Builder
  private subpageFrame(title: string, page: string): void {
    HdsNavDestination() {
      Column() {
        this.subpageHeader(title);
        Column() {
          if (page === 'about') this.aboutContent();
          else if (page === 'account') this.accountContent();
          else this.settingsContent();
        }
        .padding({ top: 4 })
        .layoutWeight(1).width('100%');
      }
      .width('100%').height('100%')
      .backgroundColor(this.subpageBackground());
    }
    .hideTitleBar(true)
    .hideBackButton(true)
    .onBackPressed((): boolean => false)
    .onHidden((): void => { this.onSubpageHidden(page); })
    .backgroundColor(this.subpageBackground())
    .width('100%').height('100%');
  }

  @Builder
  private settingsPage(): void {
    this.subpageFrame('设置', 'settings');
  }

  @Builder
  private settingsContent(): void {
    Scroll() {
      Column({ space: 14 }) {
        Text('外观').fontSize(14).fontColor(THEME_TOKENS.secondaryText).width('100%');
        Column({ space: 0 }) {
          Row({ space: 12 }) {
            Image($r('app.media.setting_display')).width(20).height(20).fillColor(this.accentColor);
            Text('显示模式').fontSize(17).fontWeight(FontWeight.Medium)
              .fontColor(THEME_TOKENS.primaryText).layoutWeight(1);
            Select(this.selectOptions(COLOR_MODE_OPTIONS))
              .selected(this.optionIndex(COLOR_MODE_OPTIONS, this.colorMode))
              .value(this.labels(COLOR_MODE_OPTIONS)[this.optionIndex(COLOR_MODE_OPTIONS, this.colorMode)])
              .onSelect((index: number): void => { this.selectColorMode(index); });
          }.width('100%').padding(16);
          Divider().margin({ left: 16, right: 16 });
          Column({ space: 10 }) {
            Row({ space: 12 }) {
              Image($r('app.media.setting_theme')).width(20).height(20).fillColor(this.accentColor);
              Text('主题色').fontSize(17).fontWeight(FontWeight.Medium).fontColor(THEME_TOKENS.primaryText);
            }.width('100%');
            this.accentPicker();
          }.alignItems(HorizontalAlign.Start).width('100%').padding(16);
        }.width('100%').backgroundColor(Color.Transparent).borderRadius(18)
          .attributeModifier(compatibleImmersiveMaterial(this.accentColor, true));
        Text('沉浸光感').fontSize(14).fontColor(THEME_TOKENS.secondaryText).width('100%').margin({ top: 8 });
        Row({ space: 12 }) {
          Image($r('app.media.setting_material')).width(20).height(20).fillColor(this.accentColor);
          Text('档位').fontSize(17).fontWeight(FontWeight.Medium)
            .fontColor(THEME_TOKENS.primaryText).layoutWeight(1);
          Select(this.selectOptions(MATERIAL_OPTIONS))
            .selected(this.optionIndex(MATERIAL_OPTIONS, this.materialLevel))
            .value(this.labels(MATERIAL_OPTIONS)[this.optionIndex(MATERIAL_OPTIONS, this.materialLevel)])
            .onSelect((index: number): void => { this.selectMaterial(index); });
        }.width('100%').padding(16).backgroundColor(Color.Transparent).borderRadius(18)
          .attributeModifier(compatibleImmersiveMaterial(this.accentColor, true));
      }
      .constraintSize({ minHeight: '100%' })
      .justifyContent(FlexAlign.Start).alignItems(HorizontalAlign.Start)
      .padding({ left: this.subpageHorizontalPadding(), right: this.subpageHorizontalPadding(),
        top: this.subpageTopPadding(), bottom: 32 }).width('100%');
    }
    .layoutWeight(1).width('100%').scrollBar(BarState.Off)
    .backgroundColor(this.subpageBackground())
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true });
  }

  @Builder
  private aboutPage(): void {
    this.subpageFrame('关于', 'about');
  }

  @Builder
  private accountPage(): void {
    this.subpageFrame('账号设置', 'account');
  }

  @Builder
  private accountContent(): void {
    Scroll() {
      Column({ space: 14 }) {
        if (this.accountMessage.length > 0) {
          Text(this.accountMessage).fontSize(14).fontColor(THEME_TOKENS.success).width('100%').padding(12)
            .backgroundColor(Color.Transparent).borderRadius(14)
            .attributeModifier(compatibleImmersiveMaterial(this.accentColor, true));
        }
        if (this.accountError.length > 0) {
          Text(this.accountError).fontSize(14).fontColor(THEME_TOKENS.danger).width('100%').padding(12)
            .backgroundColor(Color.Transparent).borderRadius(14)
            .attributeModifier(compatibleImmersiveMaterial(this.accentColor, true));
        }
        Text('用户名').fontSize(14).fontColor(THEME_TOKENS.secondaryText).width('100%');
        Column({ space: 12 }) {
          TextInput({ text: this.accountUserName, placeholder: '用户名（2-20 位）' })
            .fontColor(THEME_TOKENS.primaryText).placeholderColor(THEME_TOKENS.secondaryText)
            .onChange((value: string): void => { this.accountUserName = value; this.clearAccountFeedback(); }).width('100%');
          Button(this.accountLoading ? '正在保存' : '保存用户名').enabled(!this.accountLoading)
            .height(THEME_TOKENS.touchTarget).width('100%').fontColor(this.accentColor).backgroundColor(Color.Transparent)
            .attributeModifier(compatibleImmersiveMaterial(this.accentColor))
            .onClick((): void => { void this.saveAccountUserName(); })
            .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 });
        }.alignItems(HorizontalAlign.Start).width('100%').padding(16).backgroundColor(Color.Transparent).borderRadius(18)
          .attributeModifier(compatibleImmersiveMaterial(this.accentColor, true));

        Text('密保问题').fontSize(14).fontColor(THEME_TOKENS.secondaryText).width('100%').margin({ top: 8 });
        Column({ space: 12 }) {
          TextInput({ text: this.securityVerificationPassword, placeholder: '当前登录密码（用于身份校验）' }).type(InputType.Password)
            .fontColor(THEME_TOKENS.primaryText).placeholderColor(THEME_TOKENS.secondaryText)
            .onChange((value: string): void => { this.securityVerificationPassword = value; this.clearAccountFeedback(); }).width('100%');
          TextInput({ text: this.accountQuestionOne, placeholder: '密保问题一' })
            .fontColor(THEME_TOKENS.primaryText).placeholderColor(THEME_TOKENS.secondaryText)
            .onChange((value: string): void => { this.accountQuestionOne = value; this.clearAccountFeedback(); }).width('100%');
          TextInput({ text: this.accountAnswerOne, placeholder: '新答案一' }).type(InputType.Password)
            .fontColor(THEME_TOKENS.primaryText).placeholderColor(THEME_TOKENS.secondaryText)
            .onChange((value: string): void => { this.accountAnswerOne = value; this.clearAccountFeedback(); }).width('100%');
          Divider();
          TextInput({ text: this.accountQuestionTwo, placeholder: '密保问题二' })
            .fontColor(THEME_TOKENS.primaryText).placeholderColor(THEME_TOKENS.secondaryText)
            .onChange((value: string): void => { this.accountQuestionTwo = value; this.clearAccountFeedback(); }).width('100%');
          TextInput({ text: this.accountAnswerTwo, placeholder: '新答案二' }).type(InputType.Password)
            .fontColor(THEME_TOKENS.primaryText).placeholderColor(THEME_TOKENS.secondaryText)
            .onChange((value: string): void => { this.accountAnswerTwo = value; this.clearAccountFeedback(); }).width('100%');
          Divider();
          TextInput({ text: this.accountQuestionThree, placeholder: '密保问题三' })
            .fontColor(THEME_TOKENS.primaryText).placeholderColor(THEME_TOKENS.secondaryText)
            .onChange((value: string): void => { this.accountQuestionThree = value; this.clearAccountFeedback(); }).width('100%');
          TextInput({ text: this.accountAnswerThree, placeholder: '新答案三' }).type(InputType.Password)
            .fontColor(THEME_TOKENS.primaryText).placeholderColor(THEME_TOKENS.secondaryText)
            .onChange((value: string): void => { this.accountAnswerThree = value; this.clearAccountFeedback(); }).width('100%');
          Button(this.accountLoading ? '正在保存' : '保存密保问题').enabled(!this.accountLoading)
            .height(THEME_TOKENS.touchTarget).width('100%').fontColor(this.accentColor).backgroundColor(Color.Transparent)
            .attributeModifier(compatibleImmersiveMaterial(this.accentColor))
            .onClick((): void => { void this.saveAccountSecurity(); })
            .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 });
        }.alignItems(HorizontalAlign.Start).width('100%').padding(16).backgroundColor(Color.Transparent).borderRadius(18)
          .attributeModifier(compatibleImmersiveMaterial(this.accentColor, true));

        Text('登录密码').fontSize(14).fontColor(THEME_TOKENS.secondaryText).width('100%').margin({ top: 8 });
        Column({ space: 12 }) {
          TextInput({ text: this.oldPassword, placeholder: '当前密码' }).type(InputType.Password)
            .fontColor(THEME_TOKENS.primaryText).placeholderColor(THEME_TOKENS.secondaryText)
            .onChange((value: string): void => { this.oldPassword = value; this.clearAccountFeedback(); }).width('100%');
          TextInput({ text: this.newPassword, placeholder: '新密码（5-20 位，数字+字母+符号）' }).type(InputType.Password)
            .fontColor(THEME_TOKENS.primaryText).placeholderColor(THEME_TOKENS.secondaryText)
            .onChange((value: string): void => { this.newPassword = value; this.clearAccountFeedback(); }).width('100%');
          TextInput({ text: this.confirmNewPassword, placeholder: '确认新密码' }).type(InputType.Password)
            .fontColor(THEME_TOKENS.primaryText).placeholderColor(THEME_TOKENS.secondaryText)
            .onChange((value: string): void => { this.confirmNewPassword = value; this.clearAccountFeedback(); }).width('100%');
          Button(this.accountLoading ? '正在保存' : '更新登录密码').enabled(!this.accountLoading)
            .height(THEME_TOKENS.touchTarget).width('100%').fontColor(this.accentColor).backgroundColor(Color.Transparent)
            .attributeModifier(compatibleImmersiveMaterial(this.accentColor))
            .onClick((): void => { void this.saveAccountPassword(); })
            .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 });
        }.alignItems(HorizontalAlign.Start).width('100%').padding(16).backgroundColor(Color.Transparent).borderRadius(18)
          .attributeModifier(compatibleImmersiveMaterial(this.accentColor, true));
      }
      .constraintSize({ minHeight: '100%' }).justifyContent(FlexAlign.Start).alignItems(HorizontalAlign.Start)
      .padding({ left: this.subpageHorizontalPadding(), right: this.subpageHorizontalPadding(),
        top: this.subpageTopPadding(), bottom: 32 }).width('100%');
    }
    .layoutWeight(1).width('100%').scrollBar(BarState.Off)
    .backgroundColor(this.subpageBackground())
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true });
  }

  @Builder
  private aboutContent(): void {
    Scroll() {
      Column({ space: 14 }) {
          Text('应用信息').fontSize(14).fontColor(THEME_TOKENS.secondaryText).width('100%');
          Column({ space: 6 }) {
            Text('PezMax').fontSize(22).fontWeight(FontWeight.Bold)
              .fontColor(THEME_TOKENS.primaryText).width('100%');
            Text('HarmonyOS 原生客户端').fontSize(14).fontColor(THEME_TOKENS.secondaryText).width('100%');
            Text('版本 1.0.3').fontSize(14).fontColor(THEME_TOKENS.secondaryText).width('100%');
          }
          .alignItems(HorizontalAlign.Start).width('100%').padding(16)
          .backgroundColor(Color.Transparent).borderRadius(18)
          .attributeModifier(compatibleImmersiveMaterial(this.accentColor, true));
          Text('文档').fontSize(14).fontColor(THEME_TOKENS.secondaryText).width('100%').margin({ top: 8 });
          Row({ space: 12 }) {
            Image($r('app.media.nav_history')).width(20).height(20).fillColor(this.accentColor);
            Column({ space: 3 }) {
              Text('更新日志').fontSize(17).fontWeight(FontWeight.Medium).fontColor(THEME_TOKENS.primaryText);
              Text('查看版本功能变化').fontSize(13).fontColor(THEME_TOKENS.secondaryText);
            }.alignItems(HorizontalAlign.Start).layoutWeight(1);
            Text('›').fontSize(26).fontColor(THEME_TOKENS.secondaryText);
          }
          .width('100%').padding(16).backgroundColor(Color.Transparent).borderRadius(18)
          .attributeModifier(compatibleImmersiveMaterial(this.accentColor, true))
          .onClick((): void => { this.openChangelog(); })
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.985 });
          Row({ space: 12 }) {
            Image($r('app.media.my_about')).width(20).height(20).fillColor(this.accentColor);
            Column({ space: 3 }) {
              Text('隐私政策').fontSize(17).fontWeight(FontWeight.Medium).fontColor(THEME_TOKENS.primaryText);
              Text('账户、资料、文件与网络说明').fontSize(13).fontColor(THEME_TOKENS.secondaryText);
            }.alignItems(HorizontalAlign.Start).layoutWeight(1);
            Text('›').fontSize(26).fontColor(THEME_TOKENS.secondaryText);
          }
          .width('100%').padding(16).backgroundColor(Color.Transparent).borderRadius(18)
          .attributeModifier(compatibleImmersiveMaterial(this.accentColor, true))
          .onClick((): void => { this.openPrivacyPolicy(); })
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.985 });
      }
      .constraintSize({ minHeight: '100%' })
      .justifyContent(FlexAlign.Start).alignItems(HorizontalAlign.Start)
      .padding({ left: this.subpageHorizontalPadding(), right: this.subpageHorizontalPadding(),
        top: this.subpageTopPadding(), bottom: 32 }).width('100%');
    }
    .layoutWeight(1).width('100%').scrollBar(BarState.Off)
    .backgroundColor(this.subpageBackground())
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true });
  }

  @Builder
  private subpageDestination(name: string): void {
    if (name === 'about') this.aboutPage();
    else if (name === 'account') this.accountPage();
    else this.settingsPage();
  }

  @Builder
  private changelogSheet(): void {
    Column({ space: 14 }) {
      Text('').width(36).height(4).borderRadius(2).backgroundColor(THEME_TOKENS.secondaryText).opacity(0.32);
      Row({ space: 12 }) {
        Stack() {
          Image($r('app.media.icon_background')).width(52).height(52).objectFit(ImageFit.Cover);
          Image($r('app.media.pezmax_app_icon')).width(52).height(52).objectFit(ImageFit.Cover);
        }.width(52).height(52).borderRadius(16).clip(true).backgroundColor(Color.White);
        Column({ space: 4 }) {
          Text('PezMax').fontSize(20).fontWeight(FontWeight.Bold).fontColor(THEME_TOKENS.primaryText);
          Text(`当前版本 v${CHANGELOG_ENTRIES[0].version}`)
            .fontSize(13).fontColor(THEME_TOKENS.secondaryText);
        }.alignItems(HorizontalAlign.Start).layoutWeight(1);
      }
      .width('100%').margin({ top: 48 }).padding(14)
      .backgroundColor(Color.Transparent).borderRadius(20)
      .attributeModifier(compatibleImmersiveMaterial(this.accentColor, true));
      Column({ space: 12 }) {
        Text('更新日志').fontSize(16).fontWeight(FontWeight.Medium)
          .fontColor(THEME_TOKENS.primaryText).width('100%');
        Scroll() {
          Column({ space: 10 }) {
            ForEach(CHANGELOG_ENTRIES, (entry: ChangelogEntry): void => {
              Column({ space: 0 }) {
                Row({ space: 10 }) {
                  Column({ space: 3 }) {
                    Text(`v${entry.version}`).fontSize(17).fontWeight(FontWeight.Medium)
                      .fontColor(THEME_TOKENS.primaryText);
                    Text(entry.date).fontSize(12).fontColor(THEME_TOKENS.secondaryText);
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1);
                  Image($r('app.media.changelog_arrow')).width(20).height(20)
                    .fillColor(THEME_TOKENS.secondaryText)
                    .rotate({ angle: this.expandedChangelogVersion === entry.version ? 180 : 0 })
                    .animation({ duration: 180, curve: Curve.EaseOut });
                }
                .width('100%').padding({ left: 16, right: 16, top: 14, bottom: 14 })
                .onClick((): void => {
                  this.expandedChangelogVersion = this.expandedChangelogVersion === entry.version ? '' : entry.version;
                })
                .clickEffect({ level: ClickEffectLevel.MIDDLE, scale: 0.97 });
                if (this.expandedChangelogVersion === entry.version) {
                  Column({ space: 8 }) {
                    Divider().margin({ bottom: 12 });
                    ForEach(entry.items, (item: string): void => {
                      Text(`• ${item}`).fontSize(14).lineHeight(21)
                        .fontColor(THEME_TOKENS.secondaryText).width('100%');
                    }, (item: string): string => item);
                  }
                  .alignItems(HorizontalAlign.Start).width('100%')
                  .padding({ left: 16, right: 16, bottom: 16 })
                  .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: -8 })))
                  .animation({ duration: 180, curve: Curve.EaseOut });
                }
              }
              .width('100%').backgroundColor(Color.Transparent).borderRadius(18)
              .attributeModifier(compatibleImmersiveMaterial(this.accentColor, true));
            }, (entry: ChangelogEntry): string => entry.version);
          }.width('100%');
        }
        .width('100%').height(350).scrollBar(BarState.Auto)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true });
      }
      .width('100%')
      .opacity(this.changelogContentEntered ? 1 : 0)
      .translate({ y: this.changelogContentEntered ? 0 : 24 })
      .scale({ x: this.changelogContentEntered ? 1 : 0.97, y: this.changelogContentEntered ? 1 : 0.97 })
      .animation({ duration: 420, curve: Curve.Friction });
    }
    .width('100%').padding({ left: 20, right: 20, top: 8, bottom: 20 });
  }

  @Builder
  private privacySheet(): void {
    Column({ space: 14 }) {
      Text('').width(36).height(4).borderRadius(2).backgroundColor(THEME_TOKENS.secondaryText).opacity(0.32);
      Scroll() {
        Column({ space: 16 }) {
          Column({ space: 6 }) {
            Text('隐私政策').fontSize(20).fontWeight(FontWeight.Bold)
              .fontColor(THEME_TOKENS.primaryText).width('100%');
            Text('生效日期：2026 年 8 月 9 日').fontSize(13)
              .fontColor(THEME_TOKENS.secondaryText).width('100%');
          }.alignItems(HorizontalAlign.Start).width('100%');
          Divider();
          ForEach(PRIVACY_ENTRIES, (entry: PrivacyEntry): void => {
            Column({ space: 8 }) {
              Text(entry.title).fontSize(16).fontWeight(FontWeight.Medium)
                .fontColor(THEME_TOKENS.primaryText).width('100%');
              Text(entry.content).fontSize(15).lineHeight(22)
                .fontColor(THEME_TOKENS.primaryText).width('100%');
            }.alignItems(HorizontalAlign.Start).width('100%');
          }, (entry: PrivacyEntry): string => entry.title);
        }
        .alignItems(HorizontalAlign.Start).width('100%').padding(18)
        .backgroundColor(Color.Transparent).borderRadius(22)
        .attributeModifier(compatibleImmersiveMaterial(this.accentColor, true));
      }
      .width('100%').height(400).scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true });
    }
    .width('100%').padding({ left: 20, right: 20, top: 44, bottom: 20 });
  }

  @Builder
  private aboutSheet(): void {
    if (this.aboutSheetKind === 1) this.changelogSheet();
    else this.privacySheet();
  }

  @Builder
  private authSwitcher(): void {
    Row({ space: 4 }) {
      Button('登录').layoutWeight(1).height(40).borderRadius(20)
        .fontColor(!this.registerMode ? this.accentColor : THEME_TOKENS.secondaryText)
        .backgroundColor(Color.Transparent)
        .border({ width: !this.registerMode ? 1.5 : 0, color: this.accentColor })
        .attributeModifier(compatibleImmersiveMaterial(this.accentColor))
        .onClick((): void => { this.switchAuthMode(false); })
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.98 });
      Button('注册').layoutWeight(1).height(40).borderRadius(20)
        .fontColor(this.registerMode ? this.accentColor : THEME_TOKENS.secondaryText)
        .backgroundColor(Color.Transparent)
        .border({ width: this.registerMode ? 1.5 : 0, color: this.accentColor })
        .attributeModifier(compatibleImmersiveMaterial(this.accentColor))
        .onClick((): void => { this.switchAuthMode(true); })
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.98 });
    }.padding(4).width('100%').borderRadius(22).backgroundColor(Color.Transparent)
      .attributeModifier(compatibleImmersiveMaterial(this.accentColor));
  }

  @Builder
  private captchaField(): void {
    if (this.captchaEnabled) {
      Row({ space: 10 }) {
        TextInput({ text: this.captchaCode, placeholder: '验证码' })
          .fontColor(THEME_TOKENS.primaryText).placeholderColor(THEME_TOKENS.secondaryText)
          .onChange((value: string): void => { this.captchaCode = value; }).layoutWeight(1);
        Image(this.captchaImage).width(112).height(44).objectFit(ImageFit.Contain)
          .borderRadius(8).onClick((): void => { void this.refreshCaptcha(); });
      }.width('100%').height(48);
    }
  }

  @Builder
  private loginForm(): void {
    Column({ space: 12 }) {
      TextInput({ text: this.username, placeholder: '账号' })
        .fontColor(THEME_TOKENS.primaryText).placeholderColor(THEME_TOKENS.secondaryText)
        .onChange((value: string): void => { this.username = value; }).width('100%');
      TextInput({ text: this.password, placeholder: '密码' }).type(InputType.Password)
        .fontColor(THEME_TOKENS.primaryText).placeholderColor(THEME_TOKENS.secondaryText)
        .onChange((value: string): void => { this.password = value; }).width('100%');
      this.captchaField();
      Button(this.loading ? '正在登录' : '登录').enabled(!this.loading).width('100%').height(THEME_TOKENS.touchTarget)
        .fontColor(this.accentColor).backgroundColor(Color.Transparent)
        .attributeModifier(compatibleImmersiveMaterial(this.accentColor))
        .onClick((): void => { void this.login(); })
        .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 });
    }.width('100%').transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ x: -8 })))
      .animation({ duration: 160, curve: Curve.EaseOut });
  }

  @Builder
  private registerForm(): void {
    Column({ space: 12 }) {
      Row() {
        Text(this.registerStep === 1 ? '账号信息' : '密保与验证').fontSize(17).fontWeight(FontWeight.Medium)
          .fontColor(THEME_TOKENS.primaryText).layoutWeight(1);
        Text(`${this.registerStep} / 2`).fontSize(13).fontColor(THEME_TOKENS.secondaryText);
      }.width('100%');
      if (this.registerStep === 1) {
        Text('请勿使用学号或手机号作为账号').fontSize(13).fontColor(THEME_TOKENS.secondaryText).width('100%');
        TextInput({ text: this.username, placeholder: '账号（2-20 位）' })
          .fontColor(THEME_TOKENS.primaryText).placeholderColor(THEME_TOKENS.secondaryText)
          .onChange((value: string): void => { this.username = value; }).width('100%');
        TextInput({ text: this.password, placeholder: '密码（5-15 位，数字+字母+符号）' }).type(InputType.Password)
          .fontColor(THEME_TOKENS.primaryText).placeholderColor(THEME_TOKENS.secondaryText)
          .onChange((value: string): void => { this.password = value; }).width('100%');
        TextInput({ text: this.confirmPassword, placeholder: '确认密码' }).type(InputType.Password)
          .fontColor(THEME_TOKENS.primaryText).placeholderColor(THEME_TOKENS.secondaryText)
          .onChange((value: string): void => { this.confirmPassword = value; }).width('100%');
        Button('下一步').width('100%').height(THEME_TOKENS.touchTarget).fontColor(this.accentColor)
          .backgroundColor(Color.Transparent).attributeModifier(compatibleImmersiveMaterial(this.accentColor))
          .onClick((): void => { this.nextRegisterStep(); })
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 });
      } else {
        Text('密保问题用于找回密码，请填写仅自己知道的答案').fontSize(13)
          .fontColor(THEME_TOKENS.secondaryText).width('100%');
        Column({ space: 8 }) {
          TextInput({ text: this.securityQuestionOne, placeholder: '密保问题一' })
            .fontColor(THEME_TOKENS.primaryText).placeholderColor(THEME_TOKENS.secondaryText)
            .onChange((value: string): void => { this.securityQuestionOne = value; });
          TextInput({ text: this.securityAnswerOne, placeholder: '密保答案一' })
            .fontColor(THEME_TOKENS.primaryText).placeholderColor(THEME_TOKENS.secondaryText)
            .onChange((value: string): void => { this.securityAnswerOne = value; });
        }.width('100%').padding(12).borderRadius(16).backgroundColor(Color.Transparent)
          .attributeModifier(compatibleImmersiveMaterial(this.accentColor, true));
        Column({ space: 8 }) {
          TextInput({ text: this.securityQuestionTwo, placeholder: '密保问题二' })
            .fontColor(THEME_TOKENS.primaryText).placeholderColor(THEME_TOKENS.secondaryText)
            .onChange((value: string): void => { this.securityQuestionTwo = value; });
          TextInput({ text: this.securityAnswerTwo, placeholder: '密保答案二' })
            .fontColor(THEME_TOKENS.primaryText).placeholderColor(THEME_TOKENS.secondaryText)
            .onChange((value: string): void => { this.securityAnswerTwo = value; });
        }.width('100%').padding(12).borderRadius(16).backgroundColor(Color.Transparent)
          .attributeModifier(compatibleImmersiveMaterial(this.accentColor, true));
        Column({ space: 8 }) {
          TextInput({ text: this.securityQuestionThree, placeholder: '密保问题三' })
            .fontColor(THEME_TOKENS.primaryText).placeholderColor(THEME_TOKENS.secondaryText)
            .onChange((value: string): void => { this.securityQuestionThree = value; });
          TextInput({ text: this.securityAnswerThree, placeholder: '密保答案三' })
            .fontColor(THEME_TOKENS.primaryText).placeholderColor(THEME_TOKENS.secondaryText)
            .onChange((value: string): void => { this.securityAnswerThree = value; });
        }.width('100%').padding(12).borderRadius(16).backgroundColor(Color.Transparent)
          .attributeModifier(compatibleImmersiveMaterial(this.accentColor, true));
        this.captchaField();
        Row({ space: 8 }) {
          Checkbox({ name: 'registerDisclaimer', group: 'register' }).select(this.acceptedDisclaimer)
            .selectedColor(this.accentColor).onChange((selected: boolean): void => { this.acceptedDisclaimer = selected; });
          Text('我已阅读并同意用户注册及免责声明').fontSize(13).fontColor(THEME_TOKENS.secondaryText).layoutWeight(1);
        }.width('100%');
        Row({ space: 10 }) {
          Button('上一步').layoutWeight(1).height(THEME_TOKENS.touchTarget).fontColor(this.accentColor)
            .backgroundColor(Color.Transparent).attributeModifier(compatibleImmersiveMaterial(this.accentColor))
            .onClick((): void => { animateTo({ duration: 160, curve: Curve.EaseOut }, (): void => { this.registerStep = 1; }); })
            .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 });
          Button(this.loading ? '正在注册' : '完成注册').enabled(!this.loading).layoutWeight(1)
            .height(THEME_TOKENS.touchTarget).fontColor(this.accentColor).backgroundColor(Color.Transparent)
            .attributeModifier(compatibleImmersiveMaterial(this.accentColor)).onClick((): void => { void this.register(); })
            .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 });
        }.width('100%');
      }
    }.width('100%').padding(14).borderRadius(18).backgroundColor(Color.Transparent)
      .attributeModifier(compatibleImmersiveMaterial(this.accentColor, true))
      .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ x: 8 })))
      .animation({ duration: 170, curve: Curve.EaseOut });
  }

  @Builder
  private profilePage(): void {
    Column() {
      Column({ space: 5 }) {
        Text('我的').fontSize(24).fontWeight(FontWeight.Bold).fontColor(THEME_TOKENS.primaryText);
        Text(this.userName.length > 0 ? '管理 PezMax 账户' : this.registerMode ? '创建 PezMax 账户' : '登录 PezMax 账户')
          .fontSize(14).fontColor(THEME_TOKENS.secondaryText);
      }
      .alignItems(HorizontalAlign.Start).width('100%')
      .padding({ left: this.pagePadding, right: this.pagePadding, top: 10, bottom: 18 });
      Scroll() {
        Column({ space: 14 }) {
        if (this.userName.length === 0) {
          Column({ space: 14 }) {
            this.authSwitcher();
            if (this.registerMode) this.registerForm();
            else this.loginForm();
            if (this.message.length > 0) Text(this.message).fontSize(13).fontColor(THEME_TOKENS.success).width('100%');
            if (this.errorMessage.length > 0) Text(this.errorMessage).fontSize(13).fontColor(THEME_TOKENS.danger).width('100%');
          }.alignItems(HorizontalAlign.Start).width('100%');
        } else {
          Row({ space: 12 }) {
            Stack({ alignContent: Alignment.Center }) {
              Column().width(44).height(44).backgroundColor(this.accentColor).borderRadius(22).opacity(0.16);
              Text(this.userName.slice(0, 1).toUpperCase()).fontSize(18).fontWeight(FontWeight.Medium)
                .fontColor(this.accentColor);
              if (this.normalizedAvatar(this.avatar).length > 0) {
                Image(this.normalizedAvatar(this.avatar)).width(44).height(44).borderRadius(22).objectFit(ImageFit.Cover);
              }
            }.width(46).height(46);
            Column({ space: 4 }) {
              Text(this.userName).fontSize(22).fontWeight(FontWeight.Bold)
                .fontColor(THEME_TOKENS.primaryText).width('100%');
              Text('已连接 PezMax · 点击管理账号').fontSize(13).fontColor(THEME_TOKENS.secondaryText).width('100%');
            }.alignItems(HorizontalAlign.Start).layoutWeight(1);
            Text('›').fontSize(26).fontColor(THEME_TOKENS.secondaryText);
          }
          .alignItems(VerticalAlign.Center).padding(16).backgroundColor(Color.Transparent).borderRadius(18)
          .attributeModifier(compatibleImmersiveMaterial(this.accentColor, true)).width('100%')
          .onClick((): void => { this.openSubpage('account'); })
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.985 });
          if (this.message.length > 0) Text(this.message).fontSize(13).fontColor(THEME_TOKENS.success).width('100%');
          if (this.errorMessage.length > 0) Text(this.errorMessage).fontSize(13).fontColor(THEME_TOKENS.danger).width('100%');
        }
        if (this.userName.length > 0) this.uploadRankPanel();
        Column({ space: 10 }) {
          this.settingsEntry();
          this.aboutEntry();
        }.width('100%').margin({ top: 10 });
        if (this.userName.length > 0) {
          Button('退出登录').fontColor(THEME_TOKENS.danger).width('100%').backgroundColor(Color.Transparent)
            .attributeModifier(compatibleImmersiveMaterial(this.accentColor)).onClick((): void => { void this.logout(); })
            .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 });
        }
        }
        .constraintSize({ minHeight: '100%' })
        .justifyContent(FlexAlign.Start).alignItems(HorizontalAlign.Start)
        .padding({ left: this.pagePadding, right: this.pagePadding, bottom: THEME_TOKENS.contentBottomInset })
        .width('100%');
      }
      .layoutWeight(1).width('100%').scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true });
    }
    .width('100%').height('100%');
  }

  build() {
    HdsNavigation(this.pageStack) {
      Column() { this.profilePage(); }.width('100%').height('100%');
    }
    .mode(NavigationMode.Stack)
    .hideTitleBar(true)
    .hideToolBar(true)
    .navDestination(this.subpageDestination)
    .width('100%').height('100%')
    .bindSheet($$this.showAboutSheet, this.aboutSheet(), {
      detents: [SheetSize.FIT_CONTENT],
      preferType: SheetType.BOTTOM,
      showClose: true,
      dragBar: false,
      scrollSizeMode: ScrollSizeMode.CONTINUOUS,
      onWillDismiss: (): void => {
        this.changelogContentEntered = false;
        this.showAboutSheet = false;
        this.aboutSheetKind = 0;
      }
    });
  }
}
