# PezMax Harmony

<p align="center">
  <img src="https://img.shields.io/badge/HarmonyOS-API%2024-0D8BFF?logo=harmonyos&logoColor=white" alt="HarmonyOS API 24">
  <img src="https://img.shields.io/badge/ArkTS-5.0-0D8BFF" alt="ArkTS">
  <img src="https://img.shields.io/badge/ArkUI-Native-0D8BFF" alt="ArkUI">
  <img src="https://img.shields.io/badge/platform-HarmonyOS-0D8BFF?logo=harmonyos&logoColor=white" alt="HarmonyOS">
</p>

PezMax 的 HarmonyOS 原生客户端。项目使用 ArkTS 和 ArkUI 构建，以 HarmonyOS 沉浸光感材质重现 PezMax 桌面端的资料、书签和账户体验。

本仓库由 [LoMoCatAp](https://github.com/LoMoCatAp) 维护，是 PezMax 团队项目的移动端适配实现，不是 [PezMax](https://github.com/PezMax) 团队的官方发布渠道。

## 当前功能

- 登录、注册和本地安全凭据会话持久化。
- 资料文件夹、收藏、下载记录、分页和系统文件查看器打开。
- 云端书签的浏览、新增、搜索和删除。
- 上传排行榜、账户统计，以及用户名、密保问题、登录密码修改。
- 浅色、深色、跟随系统和主题色设置。
- ArkUI 原生底部导航、子页返回栏、底部弹窗与沉浸光感交互动效。

应用不提供相册图片上传或头像上传入口，避免产生不必要的大请求体。

## 上游项目

- 后端：[PezMax/PezMax-Java](https://github.com/PezMax/PezMax-Java)
- 桌面端参考：[PezMax/PezMax-Desktop](https://github.com/PezMax/PezMax-Desktop)
- 团队主页：[PezMax](https://github.com/PezMax)

HarmonyOS 客户端使用项目内置的 PezMax 服务地址，不提供终端用户编辑服务地址的设置项。服务端可用性、账户权限和资料内容由对应服务端维护者负责。

## 源码运行

1. 安装 DevEco Studio，并在 SDK Manager 中安装 HarmonyOS SDK API 24 或更新版本。
2. 将 `build-profile.example.json5` 复制为本机的 `build-profile.json5`，并填入自己的签名材料；该文件已被 Git 忽略。
3. 使用 DevEco Studio 打开项目根目录，选择 `entry` 模块和已连接设备或模拟器后运行。

也可以在 PowerShell 中构建：

```powershell
$env:DEVECO_SDK_HOME = 'C:\Program Files\Huawei\DevEco Studio\sdk'
node 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.js' --mode module -p product=default -p buildMode=debug assembleHap
```

生成的 HAP 位于 `entry/build/default/outputs/default/`。

## 隐私与数据

- 登录令牌存放在 HarmonyOS 系统安全凭据及应用私有存储中；应用不保存明文密码。
- 资料、收藏、下载记录和书签仅在请求相应功能时与 PezMax 服务端交换必要数据。
- 文件打开时仅暂存于应用缓存目录，并交由 HarmonyOS 系统或用户选择的兼容查看器处理。
- 不读取相册、联系人、位置或通话记录，也不上传图片。

完整说明见 [隐私政策](docs/PRIVACY_POLICY.md)。

## 项目结构

```text
AppScope/                           应用级配置和图标资源
entry/src/main/ets/
  common/                           应用存储、主题和系统能力兼容层
  components/                       可复用 ArkUI 组件
  model/                            领域模型和导航定义
  pages/                            应用入口页
  service/                          PezMax 远端接口适配
  viewmodel/                        页面状态和业务交互
  views/                            主页、资料、书签和我的页面
entry/src/main/resources/           字符串、颜色和主题资源
docs/                               项目文档
```

## 反馈

- 项目仓库：[LoMoCatAp/PezMax-Harmony](https://github.com/LoMoCatAp/PezMax-Harmony)
- 问题反馈：[GitHub Issues](https://github.com/LoMoCatAp/PezMax-Harmony/issues)

## License

See [LICENSE](LICENSE).
