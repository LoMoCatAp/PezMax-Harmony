import { http } from '@kit.NetworkKit';
import {
  PezMaxBookmark,
  PezMaxBookmarkPage,
  PezMaxCaptcha,
  PezMaxFile,
  PezMaxFileNode,
  PezMaxFilePage,
  PezMaxProfileStats,
  PezMaxRegisterDraft,
  PezMaxSecurityDraft,
  PezMaxUploadRank,
  PezMaxUser
} from '../model/PezMaxModels';

const PEZMAX_API_BASE_URL: string = 'http://154.8.139.48:8080';

interface ApiResponse {
  status: number;
  payload: Record<string, Object>;
}

export class PezMaxApiService {
  private token: string = '';

  configure(_baseUrl: string, token: string): void {
    this.token = token;
  }

  private async request(path: string, method: http.RequestMethod, body: string = '', authenticated: boolean = false): Promise<ApiResponse> {
    const request: http.HttpRequest = http.createHttp();
    const headers: Record<string, string> = { 'Accept': 'application/json' };
    if (body.length > 0) headers['Content-Type'] = 'application/json';
    if (authenticated && this.token.length > 0) headers['Authorization'] = `Bearer ${this.token}`;
    try {
      const response: http.HttpResponse = await request.request(`${PEZMAX_API_BASE_URL}${path}`, {
        method,
        header: headers,
        extraData: body.length > 0 ? body : undefined,
        connectTimeout: 15000,
        readTimeout: 15000
      });
      const raw: Object | string | undefined = response.result;
      let payload: Record<string, Object> = {};
      if (typeof raw === 'string' && raw.length > 0) payload = JSON.parse(raw) as Record<string, Object>;
      else if (raw !== undefined && typeof raw === 'object') payload = raw as Record<string, Object>;
      return { status: response.responseCode, payload };
    } finally {
      request.destroy();
    }
  }

  private message(payload: Record<string, Object>, fallback: string): string {
    const message: string = String(payload['msg'] ?? payload['message'] ?? '').trim();
    return message.length > 0 ? message : fallback;
  }

  private data(payload: Record<string, Object>): Record<string, Object> {
    const value: Object | undefined = payload['data'];
    return value !== undefined && typeof value === 'object' ? value as Record<string, Object> : payload;
  }

  private ensureSuccess(response: ApiResponse, fallback: string): void {
    if (response.status < 200 || response.status >= 300 || Number(response.payload['code'] ?? 200) !== 200) {
      throw new Error(this.message(response.payload, fallback));
    }
  }

  private file(entry: Object): PezMaxFile {
    const item: Record<string, Object> = entry as Record<string, Object>;
    return {
      fileId: Number(item['fileId'] ?? 0), fileName: String(item['fileName'] ?? ''), fileUrl: String(item['fileUrl'] ?? ''),
      fileSize: Number(item['fileSize'] ?? 0), fileFormat: String(item['fileFormat'] ?? ''), fileYear: Number(item['fileYear'] ?? 0),
      fileType: Number(item['fileType'] ?? 0), fileSchool: String(item['fileSchool'] ?? ''), fileSubject: String(item['fileSubject'] ?? '')
    };
  }

  private fileNode(entry: Object): PezMaxFileNode {
    const item: Record<string, Object> = entry as Record<string, Object>;
    const rawFile: Object | undefined = item['fileInfo'];
    const rawChildren: Object[] = (item['children'] as Object[] | undefined) ?? [];
    return {
      id: String(item['id'] ?? ''),
      label: String(item['label'] ?? ''),
      type: String(item['type'] ?? 'folder'),
      fileInfo: rawFile !== undefined && rawFile !== null ? this.file(rawFile) : undefined,
      children: rawChildren.map((child: Object): PezMaxFileNode => this.fileNode(child))
    };
  }

  async captcha(): Promise<PezMaxCaptcha> {
    const response: ApiResponse = await this.request('/datum/user/captchaImage', http.RequestMethod.GET);
    this.ensureSuccess(response, '获取验证码失败');
    const value: Record<string, Object> = this.data(response.payload);
    const enabled: boolean = value['captchaEnabled'] === true;
    return {
      enabled,
      uuid: String(value['uuid'] ?? ''),
      image: enabled ? `data:image/jpeg;base64,${String(value['img'] ?? '')}` : ''
    };
  }

  async login(username: string, password: string, code: string, uuid: string): Promise<string> {
    const response: ApiResponse = await this.request('/datum/user/login', http.RequestMethod.POST,
      JSON.stringify({ username, password, code, uuid }));
    this.ensureSuccess(response, `登录失败（HTTP ${response.status}）`);
    const token: string = String(this.data(response.payload)['token'] ?? '').trim();
    if (token.length === 0) throw new Error(this.message(response.payload, '登录响应中没有令牌'));
    return token;
  }

  async register(draft: PezMaxRegisterDraft): Promise<void> {
    const response: ApiResponse = await this.request('/datum/user/register', http.RequestMethod.POST,
      JSON.stringify({
        username: draft.username.trim(),
        password: draft.password,
        confirmPassword: draft.confirmPassword,
        securityQuestionOne: draft.securityQuestionOne.trim(),
        securityAnswerOne: draft.securityAnswerOne.trim(),
        securityQuestionTwo: draft.securityQuestionTwo.trim(),
        securityAnswerTwo: draft.securityAnswerTwo.trim(),
        securityQuestionThree: draft.securityQuestionThree.trim(),
        securityAnswerThree: draft.securityAnswerThree.trim(),
        code: draft.code.trim(),
        uuid: draft.uuid,
        avatar: ''
      }));
    this.ensureSuccess(response, `注册失败（HTTP ${response.status}）`);
  }

  async currentUser(): Promise<PezMaxUser> {
    const response: ApiResponse = await this.request('/datum/user/getInfo', http.RequestMethod.GET, '', true);
    this.ensureSuccess(response, `获取用户信息失败（HTTP ${response.status}）`);
    const raw: Record<string, Object> = (this.data(response.payload)['user'] as Record<string, Object> | undefined) ?? {};
    const user: PezMaxUser = {
      userId: Number(raw['userId'] ?? 0),
      userName: String(raw['userName'] ?? raw['username'] ?? ''),
      nickName: String(raw['nickName'] ?? raw['nickname'] ?? raw['userName'] ?? ''),
      avatar: String(raw['avatar'] ?? '')
    };
    if (user.userId === 0 && user.userName.length === 0) throw new Error('未获取到用户信息');
    return user;
  }

  async bookmarks(keyword: string = '', page: number = 1, pageSize: number = 8): Promise<PezMaxBookmarkPage> {
    let suffix: string = `?pageNum=${page}&pageSize=${pageSize}`;
    if (keyword.trim().length > 0) suffix += `&title=${encodeURIComponent(keyword.trim())}`;
    const response: ApiResponse = await this.request(`/datum/bookmark/list${suffix}`, http.RequestMethod.GET, '', true);
    this.ensureSuccess(response, `获取书签失败（HTTP ${response.status}）`);
    const rows: Object[] = (response.payload['rows'] as Object[] | undefined) ?? [];
    const bookmarks: PezMaxBookmark[] = rows.map((entry: Object): PezMaxBookmark => {
      const item: Record<string, Object> = entry as Record<string, Object>;
      return {
        id: Number(item['id'] ?? 0), url: String(item['url'] ?? ''), title: String(item['title'] ?? ''),
        description: String(item['description'] ?? ''), coverImage: String(item['coverImage'] ?? ''),
        subject: String(item['subject'] ?? ''), resourceType: String(item['resourceType'] ?? ''),
        collection: String(item['collection'] ?? ''), userId: Number(item['userId'] ?? 0)
      };
    });
    return { rows: bookmarks, total: Number(response.payload['total'] ?? bookmarks.length) };
  }

  async files(keyword: string = '', page: number = 1, pageSize: number = 8): Promise<PezMaxFilePage> {
    let suffix: string = `?pageNum=${page}&pageSize=${pageSize}`;
    if (keyword.trim().length > 0) suffix += `&fileName=${encodeURIComponent(keyword.trim())}`;
    const response: ApiResponse = await this.request(`/datum/file/list${suffix}`, http.RequestMethod.GET, '', true);
    this.ensureSuccess(response, `获取资料失败（HTTP ${response.status}）`);
    const rows: Object[] = (response.payload['rows'] as Object[] | undefined) ?? [];
    const files: PezMaxFile[] = rows.map((entry: Object): PezMaxFile => this.file(entry));
    return { rows: files, total: Number(response.payload['total'] ?? files.length) };
  }

  async fileTree(): Promise<PezMaxFileNode[]> {
    const response: ApiResponse = await this.request('/datum/file/tree', http.RequestMethod.GET, '', true);
    this.ensureSuccess(response, `获取资料目录失败（HTTP ${response.status}）`);
    const rows: Object[] = (response.payload['data'] as Object[] | undefined) ?? [];
    return rows.map((entry: Object): PezMaxFileNode => this.fileNode(entry));
  }

  async favoriteFiles(userId: number, page: number = 1, pageSize: number = 8): Promise<PezMaxFilePage> {
    const response: ApiResponse = await this.request(`/datum/desktop/favorite/list/${userId}?pageNum=${page}&pageSize=${pageSize}`,
      http.RequestMethod.GET, '', true);
    this.ensureSuccess(response, `获取收藏失败（HTTP ${response.status}）`);
    const rows: Object[] = (response.payload['rows'] as Object[] | undefined) ?? [];
    const files: PezMaxFile[] = rows.map((entry: Object): PezMaxFile => this.file(entry));
    return { rows: files, total: Number(response.payload['total'] ?? files.length) };
  }

  async downloadFiles(userId: number, page: number = 1, pageSize: number = 8): Promise<PezMaxFilePage> {
    const response: ApiResponse = await this.request(`/datum/desktop/download/list/${userId}?pageNum=${page}&pageSize=${pageSize}`,
      http.RequestMethod.GET, '', true);
    this.ensureSuccess(response, `获取下载记录失败（HTTP ${response.status}）`);
    const rows: Object[] = (response.payload['rows'] as Object[] | undefined) ?? [];
    const files: PezMaxFile[] = rows.map((entry: Object): PezMaxFile => this.file(entry));
    return { rows: files, total: Number(response.payload['total'] ?? files.length) };
  }

  async profileStats(): Promise<PezMaxProfileStats> {
    const response: ApiResponse = await this.request('/datum/desktop/user/profile/stats', http.RequestMethod.GET, '', true);
    this.ensureSuccess(response, `获取账户统计失败（HTTP ${response.status}）`);
    const value: Record<string, Object> = this.data(response.payload);
    return {
      favoriteCount: Number(value['favoriteCount'] ?? 0),
      downloadCount: Number(value['downloadCount'] ?? 0),
      uploadCount: Number(value['uploadCount'] ?? 0)
    };
  }

  async uploadRank(): Promise<PezMaxUploadRank[]> {
    const response: ApiResponse = await this.request('/datum/user/rank', http.RequestMethod.GET, '', true);
    this.ensureSuccess(response, `获取上传排行榜失败（HTTP ${response.status}）`);
    const rows: Object[] = (response.payload['data'] as Object[] | undefined) ?? [];
    return rows.map((entry: Object): PezMaxUploadRank => {
      const item: Record<string, Object> = entry as Record<string, Object>;
      return {
        userId: Number(item['userId'] ?? 0),
        userName: String(item['userName'] ?? item['username'] ?? item['nickName'] ?? ''),
        avatar: String(item['avatar'] ?? ''),
        count: Number(item['count'] ?? item['uploadCount'] ?? 0)
      };
    });
  }

  async securityQuestions(): Promise<string[]> {
    const response: ApiResponse = await this.request('/datum/desktop/user/profile/security',
      http.RequestMethod.GET, '', true);
    this.ensureSuccess(response, `获取密保问题失败（HTTP ${response.status}）`);
    const value: Record<string, Object> = this.data(response.payload);
    const questions: Object[] = (value['questions'] as Object[] | undefined) ?? [];
    if (questions.length > 0) return questions.map((question: Object): string => String(question ?? '').trim());
    return String(value['question'] ?? '').split('|').map((question: string): string => question.trim());
  }

  async updateUserName(userName: string): Promise<void> {
    const response: ApiResponse = await this.request('/datum/desktop/user/profile/username',
      http.RequestMethod.PUT, JSON.stringify({ userName: userName.trim() }), true);
    this.ensureSuccess(response, `修改用户名失败（HTTP ${response.status}）`);
  }

  async verifyPassword(password: string): Promise<void> {
    const response: ApiResponse = await this.request('/datum/desktop/user/profile/password/verify',
      http.RequestMethod.POST, JSON.stringify({ password }), true);
    this.ensureSuccess(response, `密码校验失败（HTTP ${response.status}）`);
  }

  async updateSecurity(draft: PezMaxSecurityDraft): Promise<void> {
    const response: ApiResponse = await this.request('/datum/desktop/user/profile/security',
      http.RequestMethod.PUT, JSON.stringify(draft), true);
    this.ensureSuccess(response, `修改密保失败（HTTP ${response.status}）`);
  }

  async updatePassword(oldPassword: string, newPassword: string): Promise<void> {
    const response: ApiResponse = await this.request('/datum/desktop/user/profile/password',
      http.RequestMethod.PUT, JSON.stringify({ oldPassword, newPassword }), true);
    this.ensureSuccess(response, `修改密码失败（HTTP ${response.status}）`);
  }

  async addFavorite(userId: number, fileId: number): Promise<void> {
    const response: ApiResponse = await this.request('/datum/favorite', http.RequestMethod.POST,
      JSON.stringify({ userId, fileId }), true);
    this.ensureSuccess(response, `收藏失败（HTTP ${response.status}）`);
  }

  async removeFavorite(userId: number, fileId: number): Promise<void> {
    const response: ApiResponse = await this.request(`/datum/desktop/favorite/${userId}/${fileId}`,
      http.RequestMethod.DELETE, '', true);
    this.ensureSuccess(response, `移除收藏失败（HTTP ${response.status}）`);
  }

  async removeDownload(userId: number, fileId: number): Promise<void> {
    const response: ApiResponse = await this.request(`/datum/desktop/download/${userId}/${fileId}`,
      http.RequestMethod.DELETE, '', true);
    this.ensureSuccess(response, `移除下载记录失败（HTTP ${response.status}）`);
  }

  async createBookmark(bookmark: PezMaxBookmark): Promise<void> {
    const response: ApiResponse = await this.request('/datum/bookmark', http.RequestMethod.POST, JSON.stringify({
      url: bookmark.url,
      title: bookmark.title,
      description: bookmark.description,
      subject: bookmark.subject,
      resourceType: bookmark.resourceType,
      collection: bookmark.collection
    }), true);
    this.ensureSuccess(response, `新增书签失败（HTTP ${response.status}）`);
  }

  async deleteBookmark(id: number): Promise<void> {
    const response: ApiResponse = await this.request(`/datum/bookmark/${id}`, http.RequestMethod.DELETE, '', true);
    this.ensureSuccess(response, `删除书签失败（HTTP ${response.status}）`);
  }
}
