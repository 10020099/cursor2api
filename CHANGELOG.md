# Changelog

## v2.5.2 (2026-03-11)

### 🗜️ 移除上下文智能压缩 (Reverted)

移除上一版本引入的“智能压缩替裁剪”功能。
- **原因**：Claude Code等Agent非常依赖完整的工具调用历史（尤其是 `Read` 和 `Bash` 的具体输出）来决定下一步行动。将 `Action output` 压缩为 `[30000 chars...]` 以及将历史命令压缩为 `[System Note...]` 会导致大模型“失忆”，进而在多轮对话中陷入死循环、产生幻觉，甚至复读 `[Called Bash...]` 等错误格式。
- **替代方案**：通过新增的 `isTruncated` 自动检测并返回 `stop_reason: "max_tokens"`，已经能有效解决需要频繁点“继续”按钮的问题，因此粗暴的历史压缩不再被需要。

### ⚠️ 截断无缝续写 (Internal Auto-Continue)

- **Proxy-Side 无缝拼接**：彻底解决大文件编辑（如 `Write` 工具写了几万字）时被 API 截断，导致 JSON 解析失败、变为普通文本从而丢失工具调用的致命问题！
- **自动检测与请求**：当模型输出触发截断（如代码块/XML未闭合），Proxy 将在 **底层直接自动重试续写**，无需任何额外交互。
- **防止工具调用退化为文本**：由于 Anthropic API 会在不同消息间打断工具调用块，造成 Claude Code 将 `{"tool": "Write", ...}` 降级为屏幕上的纯文本并崩溃停顿（Crunched 几分钟）。现在，Proxy 会内部拼接 2-4 次请求，始终将一个完整未截断的 JSON 动作一次性抛给 Claude Code，极大提高了多轮复杂任务的成功率！

### 🔧 工具参数容错 (tool-fixer)

- **移除隐式重命名 `file_path` 为 `path` 行动**：修复 Claude Code 2.1.71 中 `Read` 工具因为必需参数 `file_path` 被强制丢弃而陷入请求验证失败死循环的问题。
- **新增第四层正则兜底**：当模型生成的 JSON 工具调用包含未转义双引号（如代码内容参数）导致标准解析和控制字符修复均失败时，使用正则提取 `tool` 名称和 `parameters` 字段
- 解决 `SyntaxError: Expected ',' or '}'` at position 5384 等长参数解析崩溃问题

### 🛡️ 拒绝 Fallback 优化

- 工具模式下拒绝时返回极短文本 `"Let me proceed with the task."`，避免 Claude Code 误判为任务完成

---

## v2.5.0 (2026-03-10)

- OpenAI Responses API (`/v1/responses`) 支持 Cursor IDE Agent 模式
- 跨协议防御对齐（Anthropic + OpenAI handler 共享拒绝检测和重试逻辑）
- 统一图片预处理管道（OCR/Vision API）
