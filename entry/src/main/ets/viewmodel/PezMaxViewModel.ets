import { AssetCredentialStore } from '../data/AssetCredentialStore';
import { preferences } from '@kit.ArkData';
import { PezMaxApiService } from '../service/PezMaxApiService';
import {
  PezMaxBookmark,
  PezMaxBookmarkPage,
  PezMaxCaptcha,
  PezMaxFile,
  PezMaxFilePage,
  PezMaxRegisterDraft,
  PezMaxSecurityDraft,
  PezMaxSessionState,
  PezMaxUploadRank,
  PezMaxUser
} from '../model/PezMaxModels';

const TOKEN_ALIAS: string = 'pezmax_session_token';
const USER_ALIAS: string = 'pezmax_session_user';
const SESSION_ALIAS: string = 'pezmax_session_snapshot_v2';
const SESSION_PREFERENCE_PREFIX: string = 'persistent_';

interface PersistedSession {
  token: string;
  user: PezMaxUser;
}

export class PezMaxViewModel {
  readonly state: PezMaxSessionState = {
    baseUrl: '', token: '', user: undefined, bookmarks: [], files: [], favoriteFiles: [], downloadFiles: [], fileTree: [],
    uploadRank: [],
    bookmarkTotal: 0, fileTotal: 0, favoriteTotal: 0, downloadTotal: 0,
    stats: { favoriteCount: 0, downloadCount: 0, uploadCount: 0 }, authLoading: false, loading: false,
    message: '', errorMessage: ''
  };
  private readonly api: PezMaxApiService = new PezMaxApiService();
  private readonly credentials: AssetCredentialStore;
  private sessionPreferences: preferences.Preferences | undefined = undefined;
  private legacyPreferences: preferences.Preferences | undefined = undefined;

  constructor(credentials: AssetCredentialStore) {
    this.credentials = credentials;
  }

  setSessionPreferences(store: preferences.Preferences, legacyStore?: preferences.Preferences): void {
    this.sessionPreferences = store;
    this.legacyPreferences = legacyStore;
  }

  private preferenceCredential(alias: string): string {
    try {
      const key: string = `${SESSION_PREFERENCE_PREFIX}${alias}`;
      const value: string = String(this.sessionPreferences?.getSync(key, '') ?? '');
      if (value.length > 0) return value;
      return String(this.legacyPreferences?.getSync(key, '') ?? '');
    } catch (_) {
      return '';
    }
  }

  private cachedUser(value: string): PezMaxUser | undefined {
    if (value.length === 0) return undefined;
    try {
      const item: Record<string, Object> = JSON.parse(value) as Record<string, Object>;
      const userId: number = Number(item['userId'] ?? 0);
      const userName: string = String(item['userName'] ?? '');
      if (userName.length === 0) return undefined;
      return {
        userId,
        userName,
        nickName: String(item['nickName'] ?? ''),
        avatar: String(item['avatar'] ?? '')
      };
    } catch (_) {
      return undefined;
    }
  }

  private cachedSession(value: string): PersistedSession | undefined {
    if (value.length === 0) return undefined;
    try {
      const item: Record<string, Object> = JSON.parse(value) as Record<string, Object>;
      const token: string = String(item['token'] ?? '');
      const user: PezMaxUser | undefined = this.cachedUser(JSON.stringify(item['user'] ?? {}));
      if (token.length === 0 || user === undefined) return undefined;
      return { token, user };
    } catch (_) {
      return undefined;
    }
  }

  private async savePreferenceSession(token: string, user: PezMaxUser): Promise<boolean> {
    if (this.sessionPreferences === undefined) return false;
    const snapshot: string = JSON.stringify({ token, user });
    try {
      this.sessionPreferences.putSync(`${SESSION_PREFERENCE_PREFIX}${SESSION_ALIAS}`, snapshot);
      this.sessionPreferences.putSync(`${SESSION_PREFERENCE_PREFIX}${TOKEN_ALIAS}`, token);
      this.sessionPreferences.putSync(`${SESSION_PREFERENCE_PREFIX}${USER_ALIAS}`, JSON.stringify(user));
      await this.sessionPreferences.flush();
      return String(this.sessionPreferences.getSync(`${SESSION_PREFERENCE_PREFIX}${SESSION_ALIAS}`, '')) === snapshot;
    } catch (_) {
      return false;
    }
  }

  private async removePreferenceSession(): Promise<void> {
    if (this.sessionPreferences === undefined) return;
    try {
      this.sessionPreferences.deleteSync(`${SESSION_PREFERENCE_PREFIX}${TOKEN_ALIAS}`);
      this.sessionPreferences.deleteSync(`${SESSION_PREFERENCE_PREFIX}${USER_ALIAS}`);
      this.sessionPreferences.deleteSync(`${SESSION_PREFERENCE_PREFIX}${SESSION_ALIAS}`);
      await this.sessionPreferences.flush();
    } catch (_) {}
  }

  private async saveSession(token: string, user: PezMaxUser): Promise<void> {
    const preferenceSaved: boolean = await this.savePreferenceSession(token, user);
    let assetSaved: boolean = false;
    try {
      await this.credentials.update(TOKEN_ALIAS, token);
      await this.credentials.update(USER_ALIAS, JSON.stringify(user));
      assetSaved = true;
    } catch (_) {}
    if (!preferenceSaved && !assetSaved) throw new Error('无法保存登录状态，请重试');
  }

  restoreCached(baseUrl: string): boolean {
    this.state.baseUrl = baseUrl;
    const snapshot: PersistedSession | undefined = this.cachedSession(this.preferenceCredential(SESSION_ALIAS));
    this.state.token = snapshot?.token ?? this.preferenceCredential(TOKEN_ALIAS);
    const cachedUserValue: string = snapshot === undefined ?
      this.preferenceCredential(USER_ALIAS) : JSON.stringify(snapshot.user);
    this.state.user = this.state.token.length > 0 ? this.cachedUser(cachedUserValue) : undefined;
    this.api.configure(baseUrl, this.state.token);
    return this.state.token.length > 0 && this.state.user !== undefined;
  }

  async restore(baseUrl: string): Promise<void> {
    if (this.restoreCached(baseUrl)) {
      await this.saveSession(this.state.token, this.state.user as PezMaxUser);
      return;
    }
    let cachedUserValue: string = '';
    if (this.state.token.length === 0) {
      try {
        this.state.token = await this.credentials.get(TOKEN_ALIAS) ?? '';
      } catch (_) {}
    }
    if (cachedUserValue.length === 0) {
      try {
        cachedUserValue = await this.credentials.get(USER_ALIAS) ?? '';
      } catch (_) {}
    }
    this.api.configure(baseUrl, this.state.token);
    if (this.state.token.length === 0) return;
    this.state.user = this.cachedUser(cachedUserValue);
    if (this.state.user !== undefined) {
      await this.saveSession(this.state.token, this.state.user);
      return;
    }
    try {
      this.state.user = await this.api.currentUser();
      await this.saveSession(this.state.token, this.state.user);
    } catch (_) {
      // Keep the token for the next retry. A deployment restart must not
      // destroy a valid session because the server is briefly unavailable.
    }
  }

  async captcha(): Promise<PezMaxCaptcha> {
    return this.api.captcha();
  }

  async register(draft: PezMaxRegisterDraft): Promise<boolean> {
    this.state.authLoading = true;
    this.state.errorMessage = '';
    this.state.message = '';
    try {
      await this.api.register(draft);
      this.state.message = '注册成功，请使用新账号登录';
      return true;
    } catch (error) {
      this.state.errorMessage = error instanceof Error ? error.message : '注册失败，请检查填写内容';
      return false;
    } finally {
      this.state.authLoading = false;
    }
  }

  async login(username: string, password: string, code: string, uuid: string): Promise<boolean> {
    this.state.authLoading = true;
    this.state.errorMessage = '';
    this.state.message = '';
    try {
      const token: string = await this.api.login(username.trim(), password, code.trim(), uuid);
      this.state.token = token;
      this.api.configure(this.state.baseUrl, token);
      this.state.user = await this.api.currentUser();
      await this.saveSession(token, this.state.user);
      this.state.message = '登录成功';
      return true;
    } catch (error) {
      this.state.token = '';
      this.state.user = undefined;
      this.api.configure(this.state.baseUrl, '');
      this.state.errorMessage = error instanceof Error ? error.message : '登录失败，请检查账号、密码和验证码';
      return false;
    } finally {
      this.state.authLoading = false;
    }
  }

  async logout(): Promise<void> {
    this.state.token = '';
    this.state.user = undefined;
    this.state.bookmarks = [];
    this.state.files = [];
    this.state.favoriteFiles = [];
    this.state.downloadFiles = [];
    this.state.fileTree = [];
    this.state.uploadRank = [];
    this.state.bookmarkTotal = 0;
    this.state.fileTotal = 0;
    this.state.favoriteTotal = 0;
    this.state.downloadTotal = 0;
    this.state.stats = { favoriteCount: 0, downloadCount: 0, uploadCount: 0 };
    this.state.message = '';
    this.state.errorMessage = '';
    this.api.configure(this.state.baseUrl, '');
    try {
      await this.credentials.remove(TOKEN_ALIAS);
    } catch (_) {}
    try {
      await this.credentials.remove(USER_ALIAS);
    } catch (_) {}
    await this.removePreferenceSession();
  }

  async loadBookmarks(keyword: string = '', page: number = 1, pageSize: number = 8): Promise<void> {
    this.state.loading = true;
    this.state.errorMessage = '';
    try {
      const result: PezMaxBookmarkPage = await this.api.bookmarks(keyword, page, pageSize);
      this.state.bookmarks = result.rows;
      this.state.bookmarkTotal = result.total;
    } catch (error) {
      this.state.errorMessage = error instanceof Error ? error.message : '无法获取书签';
    } finally {
      this.state.loading = false;
    }
  }

  async createBookmark(bookmark: PezMaxBookmark): Promise<boolean> {
    this.state.loading = true;
    this.state.errorMessage = '';
    try {
      await this.api.createBookmark(bookmark);
      this.state.message = '书签已创建';
      const result: PezMaxBookmarkPage = await this.api.bookmarks();
      this.state.bookmarks = result.rows;
      this.state.bookmarkTotal = result.total;
      return true;
    } catch (error) {
      this.state.errorMessage = error instanceof Error ? error.message : '新增书签失败';
      return false;
    } finally {
      this.state.loading = false;
    }
  }

  async loadFiles(keyword: string = '', page: number = 1, pageSize: number = 8): Promise<void> {
    this.state.loading = true;
    this.state.errorMessage = '';
    try {
      const result: PezMaxFilePage = await this.api.files(keyword, page, pageSize);
      this.state.files = result.rows;
      this.state.fileTotal = result.total;
    } catch (error) {
      this.state.errorMessage = error instanceof Error ? error.message : '获取资料失败';
    } finally {
      this.state.loading = false;
    }
  }

  async loadFileTree(): Promise<void> {
    this.state.loading = true;
    this.state.errorMessage = '';
    try {
      this.state.fileTree = await this.api.fileTree();
    } catch (error) {
      this.state.errorMessage = error instanceof Error ? error.message : '获取资料目录失败';
    } finally {
      this.state.loading = false;
    }
  }

  async loadFavoriteFiles(page: number = 1, pageSize: number = 8): Promise<void> {
    if (this.state.user === undefined) return;
    this.state.loading = true;
    this.state.errorMessage = '';
    try {
      const result: PezMaxFilePage = await this.api.favoriteFiles(this.state.user.userId, page, pageSize);
      this.state.favoriteFiles = result.rows;
      this.state.favoriteTotal = result.total;
    } catch (error) {
      this.state.errorMessage = error instanceof Error ? error.message : '获取收藏失败';
    } finally {
      this.state.loading = false;
    }
  }

  async loadDownloadFiles(page: number = 1, pageSize: number = 8): Promise<void> {
    if (this.state.user === undefined) return;
    this.state.loading = true;
    this.state.errorMessage = '';
    try {
      const result: PezMaxFilePage = await this.api.downloadFiles(this.state.user.userId, page, pageSize);
      this.state.downloadFiles = result.rows;
      this.state.downloadTotal = result.total;
    } catch (error) {
      this.state.errorMessage = error instanceof Error ? error.message : '获取下载记录失败';
    } finally {
      this.state.loading = false;
    }
  }

  async loadProfileStats(): Promise<void> {
    if (this.state.user === undefined) return;
    try {
      this.state.stats = await this.api.profileStats();
    } catch (_) {}
  }

  async loadUploadRank(): Promise<void> {
    if (this.state.user === undefined) return;
    this.state.uploadRank = await this.api.uploadRank();
  }

  async securityQuestions(): Promise<string[]> {
    if (this.state.user === undefined) return [];
    return this.api.securityQuestions();
  }

  async updateUserName(userName: string): Promise<void> {
    if (this.state.user === undefined) throw new Error('请先登录');
    await this.api.updateUserName(userName);
    this.state.user = await this.api.currentUser();
    await this.saveSession(this.state.token, this.state.user);
  }

  async verifyPassword(password: string): Promise<void> {
    if (this.state.user === undefined) throw new Error('请先登录');
    await this.api.verifyPassword(password);
  }

  async updateSecurity(draft: PezMaxSecurityDraft): Promise<void> {
    if (this.state.user === undefined) throw new Error('请先登录');
    await this.api.updateSecurity(draft);
  }

  async updatePassword(oldPassword: string, newPassword: string): Promise<void> {
    if (this.state.user === undefined) throw new Error('请先登录');
    await this.api.updatePassword(oldPassword, newPassword);
  }

  async addFavorite(fileId: number): Promise<boolean> {
    if (this.state.user === undefined) return false;
    try {
      await this.api.addFavorite(this.state.user.userId, fileId);
      const file: PezMaxFile | undefined = this.state.files.find((item: PezMaxFile): boolean => item.fileId === fileId);
      if (file !== undefined && !this.state.favoriteFiles.some((item: PezMaxFile): boolean => item.fileId === fileId)) {
        this.state.favoriteFiles = [file, ...this.state.favoriteFiles];
        this.state.favoriteTotal += 1;
      }
      await this.loadProfileStats();
      return true;
    } catch (error) {
      this.state.errorMessage = error instanceof Error ? error.message : '收藏失败';
      return false;
    }
  }

  async removeFavorite(fileId: number): Promise<boolean> {
    if (this.state.user === undefined) return false;
    try {
      await this.api.removeFavorite(this.state.user.userId, fileId);
      this.state.favoriteFiles = this.state.favoriteFiles.filter((item: PezMaxFile): boolean => item.fileId !== fileId);
      this.state.favoriteTotal = Math.max(0, this.state.favoriteTotal - 1);
      await this.loadProfileStats();
      return true;
    } catch (error) {
      this.state.errorMessage = error instanceof Error ? error.message : '移除收藏失败';
      return false;
    }
  }

  async removeDownload(fileId: number): Promise<boolean> {
    if (this.state.user === undefined) return false;
    try {
      await this.api.removeDownload(this.state.user.userId, fileId);
      this.state.downloadFiles = this.state.downloadFiles.filter((item: PezMaxFile): boolean => item.fileId !== fileId);
      this.state.downloadTotal = Math.max(0, this.state.downloadTotal - 1);
      await this.loadProfileStats();
      return true;
    } catch (error) {
      this.state.errorMessage = error instanceof Error ? error.message : '移除下载记录失败';
      return false;
    }
  }

  async deleteBookmark(id: number): Promise<boolean> {
    try {
      await this.api.deleteBookmark(id);
      const result: PezMaxBookmarkPage = await this.api.bookmarks();
      this.state.bookmarks = result.rows;
      this.state.bookmarkTotal = result.total;
      return true;
    } catch (error) {
      this.state.errorMessage = error instanceof Error ? error.message : '删除书签失败';
      return false;
    }
  }
}
