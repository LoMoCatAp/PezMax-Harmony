export interface PezMaxBookmark {
  id: number;
  url: string;
  title: string;
  description: string;
  coverImage: string;
  subject: string;
  resourceType: string;
  collection: string;
  userId: number;
}

export interface PezMaxFile {
  fileId: number;
  fileName: string;
  fileUrl: string;
  fileSize: number;
  fileFormat: string;
  fileYear: number;
  fileType: number;
  fileSchool: string;
  fileSubject: string;
}

export interface PezMaxFileNode {
  id: string;
  label: string;
  type: string;
  fileInfo: PezMaxFile | undefined;
  children: PezMaxFileNode[];
}

export interface PezMaxFilePage {
  rows: PezMaxFile[];
  total: number;
}

export interface PezMaxBookmarkPage {
  rows: PezMaxBookmark[];
  total: number;
}

export interface PezMaxRegisterDraft {
  username: string;
  password: string;
  confirmPassword: string;
  securityQuestionOne: string;
  securityAnswerOne: string;
  securityQuestionTwo: string;
  securityAnswerTwo: string;
  securityQuestionThree: string;
  securityAnswerThree: string;
  code: string;
  uuid: string;
}

export interface PezMaxUser {
  userId: number;
  userName: string;
  nickName: string;
  avatar: string;
}

export interface PezMaxCaptcha {
  enabled: boolean;
  uuid: string;
  image: string;
}

export interface PezMaxProfileStats {
  favoriteCount: number;
  downloadCount: number;
  uploadCount: number;
}

export interface PezMaxUploadRank {
  userId: number;
  userName: string;
  avatar: string;
  count: number;
}

export interface PezMaxSecurityDraft {
  securityQuestionOne: string;
  securityAnswerOne: string;
  securityQuestionTwo: string;
  securityAnswerTwo: string;
  securityQuestionThree: string;
  securityAnswerThree: string;
}

export interface PezMaxSessionState {
  baseUrl: string;
  token: string;
  user: PezMaxUser | undefined;
  bookmarks: PezMaxBookmark[];
  files: PezMaxFile[];
  favoriteFiles: PezMaxFile[];
  downloadFiles: PezMaxFile[];
  fileTree: PezMaxFileNode[];
  uploadRank: PezMaxUploadRank[];
  bookmarkTotal: number;
  fileTotal: number;
  favoriteTotal: number;
  downloadTotal: number;
  stats: PezMaxProfileStats;
  authLoading: boolean;
  loading: boolean;
  message: string;
  errorMessage: string;
}

export interface PezMaxLoginDraft {
  baseUrl: string;
  username: string;
  password: string;
}
