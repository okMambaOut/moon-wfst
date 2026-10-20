# MoonWFST

MoonWFST 是可复用的 MoonBit **加权有限状态转导机（WFST）基础库**。转导机用有限图表示输入与输出之间的关系：每条弧包含输入标签、输出标签及权重，权重由调用者提供的半环解释。本库面向语音候选格处理、形态分析、OCR 后处理、分词及其他有限状态处理流程，提供共享的数据模型和算法；它本身不是识别器，也不包含领域模型。

**版本与范围：**`0.1.2` 修复图拓扑和路径等内部数组可被外部直接修改的问题，并增加边界回归。已实现能力是有明确边界的 WFST 子集，不是 OpenFst 的完整替代。下文示例使用源码中定义的合成图，不是生产数据或性能基准。

## 0.1.2 兼容性说明

构图器与图快照的拓扑数组、接受路径轨迹、修剪映射均改为私有字段。请通过 `transducer_arcs_from`、`transducer_final_weight`、`accepting_path_states`、`accepting_path_steps` 和 `trim_result_state_mapping` 等公开访问器读取。公开函数签名不变；直接读取这些内部数组字段的代码需要迁移。可变权重载荷仍不提供深复制保证。旧版 `0.1.1` 不包含此修复。

## 已实现能力

- 验证构图：密集状态编号、构建时复制的图快照、显式终止权重，以及与空字符串符号不同的 epsilon 标签。
- 权重代数：调用者自定义半环，内置 Boolean 半环和有界非负 tropical 权重。
- 关系变换：输入／输出投影、反转、带权并与连接，以及无 epsilon 的转导机组合。
- 图分析：结构可达性、到终止状态的可达性、接受核心修剪、确定性拓扑顺序、入弧查询和图统计。
- 路径查询：输入／输出 token 对的支持图成员判断、最低成本接受路径，以及 DAG 上有界的 k-best 路径。
- 路径聚合：DAG 上通用半环的前向权重、后向权重和接受路径总权重。
- 明确错误：非法状态、暂不支持的 epsilon 组合、Dijkstra 负权重、DAG 算法遇到环及非法路径数量限制。

## 安装与使用

在已有 MoonBit 模块中安装精确版本：

```powershell
moon add okMambaOut/moon-wfst@0.1.2
```

在使用该库的包目录中，通过 `moon.pkg` 指定导入别名：

```moonbit
import {
  "okMambaOut/moon-wfst" @wfst,
}
```

通过 `@wfst.transducer_builder` 创建构图器，再使用 `add_state`、`set_start`、`set_final`、`add_arc` 和 `build_transducer` 构造关系图。完整的构图、组合、路径排序和结果提取流程见 [语音候选格示例](examples/speech_lattice/main.mbt)。

模块名称为 `okMambaOut/moon-wfst`。版本与公开材料见 [GitHub Release](https://github.com/okMambaOut/moon-wfst/releases/tag/v0.1.2) 和 [MoonCakes 模块页面](https://mooncakes.io/docs/okMambaOut/moon-wfst)。

## 三个可运行示例

安装 MoonBit 工具链后，在仓库根目录执行：

```powershell
moon run --target wasm-gc examples/speech_lattice
moon run --target wasm-gc examples/morphology
moon run --target wasm-gc examples/ocr_constraints
```

| 示例 | 输入与处理流程 | 合成样例的确定结果 |
| --- | --- | --- |
| 语音候选格 | 将识别候选格与词法映射组合，选择最低成本接受路径。 | `cat`，总成本 `6`。 |
| 形态分析 | 为不规则词形 `went` 的多个词素分析排序，提取低成本结果。 | `go+PAST`，成本 `1`。 |
| OCR 格式约束 | 将六格字符候选与格式转导机组合，结合字形混淆成本重新评分。 | `NB0158`，总成本 `6`。 |

这三个程序均位于 [examples](examples)，可直接运行。OCR 示例不处理像素、不调用 OCR 模型、不验证校验码，结果不能解释为真实识别准确率；语音示例也不包含声学推理。

## API 契约与功能边界

- **半环：**调用者提供零元、单位元、候选相加及路径扩展运算。本库不能证明代数规律，也不能自动证明两个半环兼容；并与连接的合成弧使用左操作数的运算。
- **转导机组合：**两侧必须无 epsilon，并使用兼容且**乘法可交换**的半环。当前逐弧配对的权重交错不能视作一般非交换半环上的组合。任一侧出现 epsilon 均返回 `UnsupportedEpsilonComposition`，不隐含 epsilon 过滤器。
- **最短路径：**Dijkstra 检查全部弧权重和终止权重均非负，包括不可达部分。调用者负责保证比较的单调性和代数一致性。
- **k-best：**`shortest_paths_in_dag` 要求整张图无环。对于满足路径排序契约的 DAG，可使用适当的负边权；平行弧保留为不同推导，算法保存显式路径前缀，适用于有界 `k` 和中等规模图。
- **成员判断：**`accepts_pair` 根据调用者提供的零权重判定函数，回答支持图上的成员存在性。它不聚合权重、不返回路径见证，也不等价于“聚合总权重非零”；抵消、零因子或饱和运算可能使二者不同。内存规模与状态数 × 输入位置数 × 输出位置数成正比。
- **前向／后向聚合：**`forward_weights_in_dag`、`backward_weights_in_dag` 和 `total_weight_in_dag` 使用图的半环聚合路径权重，拒绝图中任何位置的环，不推断无限级数闭包。结果依赖调用者提供有效的半环运算。
- **明确不包含：**带 epsilon 过滤的组合、带权 epsilon 闭包／消除、确定化、最小化、OpenFst 二进制导入导出、模型训练、分词策略、图像识别及领域专用校验。

详细的运算顺序、结构行为与权重行为的区别、错误语义见 [语义说明](docs/design/semantics.md)。有限检索范围内的选题比较与相邻项目边界见 [查重记录](docs/competition/duplicate-check.md)。

## 构建与验证

```powershell
moon info
moon fmt --check
moon check --target wasm-gc --deny-warn
moon check --target wasm --deny-warn
moon check --target js --deny-warn
moon check --target native --deny-warn
moon build --target wasm-gc --deny-warn
moon test --target wasm-gc --deny-warn
```

2026-10-20，在本机 Moon `0.1.20261012` 下，wasm-gc、WebAssembly 和 JavaScript 各通过 **56/56 项仓库测试**，各完成严格检查与构建。另在仓库外独立消费者中，以 Python 穷举路径、整数矩阵计算和循环图有限不动点计算作为预期，每个后端通过 **208 项独立验算**；这些测试不是性能或真实识别准确率结论。三个示例在三个本地后端均得到上述结果。

本机 native 严格检查通过，但缺少 MSVC C++ 工具和 Windows SDK，未执行本机 native 构建或测试。[GitHub Actions](https://github.com/okMambaOut/moon-wfst/actions) 工作流对每个发布提交分别执行四目标检查、构建、测试，以及三个 wasm-gc 示例；发布以对应 SHA 的真实运行结果为准，不沿用旧版 CI 证明新版。

根目录基础库包含 **1604 物理行非测试 `.mbt` 实现**，计数包含空行，不包含测试、示例、生成接口或构建输出。这是实现规模与验证事实，不是性能结论。

## 许可证、来源与 AI 使用

本项目采用 Apache-2.0，见 [LICENSE](LICENSE) 和 [NOTICE](NOTICE)。唯一导入的 MoonBit 包是工具链提供的 `moonbitlang/core/debug`，未随项目 vendoring。

OpenFst 和 RustFST 仅用于术语、语义和 API 比较，未引入上游源码或数据。参考来源和范围见 [第三方归属说明](THIRD-PARTY-NOTICES.md)，AI 辅助使用情况见 [AI-USE.md](AI-USE.md)。

## 安全与资源限制

库的输入是内存图，不是网络传输格式；库内没有网络访问、文件系统访问、动态加载或自动解析。处理不可信输入时，调用者必须限制状态数、弧数、token 长度和请求的 `k`。

组合的状态规模可能达到两侧状态集的乘积，当前使用线性搜索查找状态对；Dijkstra 通过线性扫描选择下一状态，未使用堆；成员判断分配密集的状态／位置乘积空间；k-best 会复制路径前缀。这些算法不提供服务级的有界耗时保证，详见 [资源限制](docs/design/resources.md)。

## 项目历史与作者归属

本项目在原有 MoonWFST 成果上继续开发，保留已有历史。最初 23 个提交保留原来的 `yujieMamba` 作者归属，后续接手提交使用参赛者指定的仓库级名称 `okmanba` 和 `okMambaOut` GitHub noreply 邮箱。

仓库所有权与提交作者是不同事实；本项目未改写历史，也不声称两个账号代表同一自然人。
