# Contributing

感谢你愿意改进 Mac Time。

## 开发流程

1. Fork 或 clone 仓库。
2. 用 Xcode 打开 `Mac Time.xcodeproj`。
3. 修改前先确认项目能正常构建。
4. 提交 PR 时说明变更动机、主要改动和验证方式。

## 代码风格

- 优先沿用现有 SwiftUI、AppKit 和 ViewModel 结构。
- 保持改动聚焦，避免在一个 PR 中混合无关重构。
- 核心时间合并、数据存储和追踪逻辑应尽量补测试。
- 不提交本地 Xcode 状态、DerivedData、数据库或系统生成文件。

## 隐私

Mac Time 处理的是用户本机 App 使用记录。新增功能时请避免上传或外发这些数据；如果确实需要网络能力，应先在 issue/PR 中明确说明原因、范围和用户控制方式。

