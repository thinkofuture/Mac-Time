# Mac Time

[下载 App](https://github.com/thinkofuture/Mac-Time/releases/latest/download/Mac-Time.app.zip)
[查看 Releases](https://github.com/thinkofuture/Mac-Time/releases)

Mac Time 是一个 macOS 菜单栏时间记录工具，用来追踪当前正在使用的前台 App，并把一天的使用记录显示成时间线。

> 下载链接会指向 GitHub 最新 Release 中名为 `Mac-Time.app.zip` 的资源文件。下载后解压，并将 `Mac Time.app` 拖入“应用程序”文件夹即可使用。

## 功能

- 自动记录前台 App 的使用时段
- 通过菜单栏图标打开或隐藏主窗口
- 按日期浏览时间线
- 查看、编辑和删除单条记录
- 为不同 App 设置时间线颜色
- 使用本地 SQLite 数据库保存记录

## 要求

- macOS 26.0 或更高版本
- Xcode 26 或更高版本
- Swift Package Manager

> 当前工程的 deployment target 是 macOS 26.0。若你希望支持更早版本，可以在 Xcode 中调低 `MACOSX_DEPLOYMENT_TARGET` 后重新验证。

## 构建

1. 克隆仓库。
2. 用 Xcode 打开 `Mac Time.xcodeproj`。
3. 等待 Swift Package Manager 解析依赖。
4. 选择 `Mac Time` scheme，然后运行。

命令行构建：

```sh
xcodebuild -project "Mac Time.xcodeproj" -scheme "Mac Time" -configuration Debug build
```

## 数据和隐私

Mac Time 只在本机记录前台 App 的名称、bundle identifier、开始时间、结束时间和持续时间。数据默认保存在：

```text
~/Library/Application Support/MacTime/records.db
```

项目不会上传、同步或发送这些记录。

## 依赖

- [SQLite.swift](https://github.com/stephencelis/SQLite.swift)

## 贡献

欢迎 issue 和 pull request。提交前请先确保项目可以在 Xcode 中正常构建，并尽量为核心逻辑补充测试。

## 许可证

本项目使用 MIT License。详见 [LICENSE](LICENSE)。
