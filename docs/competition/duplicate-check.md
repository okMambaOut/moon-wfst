# MoonWFST 语义查重与选题复核

- 首次选择：2026-10-13；接手续查：2026-10-14。
- 截止：2026-10-30 24:00，仅按 Skill 固定记录，不重新打开赛事章程。
- 复核决定：保留已获参赛者确认的 MoonWFST；不足是工程完成度，不是重选理由。
- 有限结论：**在已记录检索范围内未发现成熟直接替代。** 不声称穷尽所有仓库、分支、未发布模块或不同词汇的实现。

## 1. 三个不同问题域的候选

| 排序／决定 | 候选、基础数据和流程 | 至少三类复用方 | 核心语义证据 |
|---|---|---|---|
| 1，保留 | 加权有限状态转导机：输入／输出标签、弧与终止权重、半环；构图→组合／变换→路径查询与聚合 | 语音候选格、语言形态工具、OCR 后处理、编译与搜索工具 | loci 的业务 Mealy 机、certified 的键值 trie/FST、正则匹配、通用路径库相邻，但下面核实的接口没有形成相同带权关系模型和工作流 |
| 2，淘汰 | 可编程熵编码：频率／CDF→rANS／tANS／算术码→解码 | 存储、传输、压缩工具 | `Juwan-Hwang/moon-certified@0.1.1` 的 `compression/ans/ans.mbt` 已有频率表、rANS/tANS 压缩与解压；`arithmetic_coding.mbt` 有字节编解码。已检查归一化／重整化源码及空输入、全字节、偏斜分布、往返测试片段。仅改模型输入不足以区分主线 |
| 3，淘汰 | 离散小波变换：向量／图像→多分辨率系数→重建 | 图像压缩、信号分析、科学计算 | `hwlxmm/dsp@0.1.0` 的 `src/signal/wavelet.mbt` 有 Haar 正逆与 db4 正变换；`signal_advanced_test.mbt` 有 8 点往返。`walkzzz/image@0.5.0` 的 `haar_wavelet.mbt` 有 1D/2D 正逆及去噪，测试有系数、往返、阈值。已有直接主功能 |

三个方向都有跨域价值；后两个淘汰原因是已存在的核心能力，不是包名。前轮还有 ODE、Unicode 排序、QP、HMM、RDF 规范化、多边形布尔运算的淘汰线索；本轮未重新全面审查，不将这些线索包装为新的充分结论。

## 2. 选中方向及已实现边界

独立 MoonBit 实现，不是 OpenFst/RustFST 完整移植、词典包、识别器外壳或界面。提供显式 epsilon、半环、验证构图与快照、投影／反转、epsilon-free 组合、并／连接、支持图成员判断、修剪／拓扑排序、最短接受路径、DAG k-best 和前向／后向／总权重聚合。

三例分别完成：识别候选格与词法图组合得到 `cat`（代价 6）；形态候选得到 `go+PAST`（代价 1）；六格合成 OCR 候选与格式约束得到 `NB0158`（代价 6）。它们是源码构造的例子，不是实际识别精度测量。三类调用者复用同一数据模型，而不是三套硬编码产品。

不包含 epsilon-filtered 组合、epsilon closure、确定化、最小化、OpenFst 文件兼容、模型训练或视觉推理。组合要求兼容半环且乘法可交换；聚合可保持非交换乘法顺序。`accepts_pair` 是非零弧／终止的支持图存在性，不等于抵消或饱和后的聚合权重非零。具体约束见 `docs/design/semantics.md`。

## 3. 相邻项目 README、API、源码与测试

| 固定版本／检索对象 | 核实的模型、接口、测试 | 重叠和独立项目必要性 |
|---|---|---|
| [zploc/loci@0.1.0](https://mooncakes.io/docs/zploc/loci)，仓库记录 `zpc-sh/loci` | 发布源码 `loci_fsm/README.md`、`transducer.mbt`、`transducer_algebra.mbt`、`transducer_test.mbt`：Mealy `transduce(Self, TransducerInput)`，封闭 Scalar/SubmitWork/Event/Tick/RawBytes 与业务输出；Compose 经桥接函数串接。测试检查状态、事件和输出 | 最接近转导邻居；不是半环加权关系图。扩展封闭业务模型会改变其主抽象。仓库 GET 404，所以采用官方发布包；不据此断言维护停止 |
| [Juwan-Hwang/moon-certified@0.1.1](https://mooncakes.io/docs/Juwan-Hwang/moon-certified) | `containers/fst/fst.mbt`、`fst_test.mbt`：字符串→整数 trie，build/search/keys；空输入、前缀、键覆盖测试 | 键值查找并非双标签、权重关系和转导组合 |
| [walkzzz/re-mbt@0.1.0](https://mooncakes.io/docs/walkzzz/re-mbt) | README、接口、`re/core.mbt`／`compile.mbt`、`core_test.mbt`：AST 编译与匹配、分组／位置返回；exec_opt/execp 成功失败和 pos 测试 | 正则接受／捕获，不是通用带权双标签图；不重建其正则 parser |
| [Suquster/moonbit-pathfinding](https://github.com/Suquster/moonbit-pathfinding)，本轮 main 快照 | README、`src/core/prelude.mbt`、`src/directed/dijkstra.mbt`／`dag_shortest_path.mbt` 及对应测试：节点／邻居回调、`Weight.add/zero/infinity` 和总序。测试含菱形、负边、不可达及同起终点 | 最短路／拓扑确实重叠；核实接口未提供双标签关系、终止权重及任意半环求和。强制总序 Weight 会排除矩阵聚合；独立模型有必要，未声称实现更快或更优 |
| [trkbt10/indexion](https://github.com/trkbt10/indexion)，本轮 main 快照 | README、`src/kgf/parser/parse_preprocess_fst.mbt`、`src/kgf/preprocess/fst.mbt`／`preprocess_wbtest.mbt`：JSON 预处理 FST、字符类、首个匹配转移、Emit/Buf/Flush 动作。测试检查 base64 分类／转换；未找到独立通用加权 FST 测试套件 | 真实字符转导邻居，中心是 KGF 预处理和缓冲动作，不是分支关系、半环或加权组合；扩展跨越原有产品边界 |
| [length-super/moonctl](https://github.com/length-super/moonctl)，本轮 main 快照 | README、根接口、`model.mbt`／`check.mbt`／`oracle_test.mbt`：状态命题、动作边、CTL 固定点／证据，参考测试枚举路径和循环 | 有限状态图相邻，但中心是时序逻辑真假及见证 |
| `lhw153766-ctrl/sparse-linalg@0.1.1` | 仅复核元数据和已有注册表矩阵／分解边界 | 数值底座邻居；前轮“min-plus/tropical”细节本轮未独立核实，不继续作强断言，未排除全部源码 |

官方包源码通过隔离研究模块 `moon add` 下载，只阅读，不拷入生产库或计入规模。本轮检查相邻测试的源码语义，**未执行其测试、未背书质量或穷尽所有子包**。GitHub 内容 API 保存 blob SHA，仓库外证据清单保存 SHA-256 和检索响应；不上传私有材料。

## 4. 永久注册表对照

对照 Skill 的 `references/project-registry.md` 相关指纹，既有 MoonWFST 条目是本项目续作，不再次注册新选题。

- MoonPetri：place／transition／token marking 和发射可达性；不覆盖、删除或借用旧 `moonpetri` 仓库。
- MoonDag：任务工期、CPM、slack、变更影响和重跑计划；本项目不提供这些流程。共有拓扑遍历不作为差异化成果。
- MoonCite：CSL 引用格式化；MoonPhone：电话编号计划。即使 rejected/reserved 也不复用其指纹。
- MoonOT：离散最优传输 coupling／诊断，不是标签路径关系；矩阵测试不实现传输求解。

保留全部历史，账号与发布授权按日期追加；新增邻居标记 external-checked，不宣称项目已完成全平台交付。

## 5. 反向检索与限制

2026-10-14，`moon search --limit 100`：wfst 0；transducer 3；semiring 5；fst 6；loci 2；wavelet 6；ans 80。宽泛命中不都是相邻实现；搜索无分页，未声称全量覆盖。

GitHub 隔离只读 API 仓库检索：`wfst/transducer/semiring language:MoonBit` 各 0；`finite-state language:MoonBit` 1（moonctl）；`OpenFst/RustFST MoonBit` 各 0。反向代码检索 `extension:mbt`：wfst 2（WebP fixture 无关）；transducer 11（发现 indexion 等）；semiring 68（发现路径／代数代码）；`shortest_paths_in_dag`、`forward_weights_in_dag` 各 0。incomplete_results=false 仅描述当次查询，不证明没有遗漏。官方 awesome-moonbit 清单也用于辅助寻找不同命名的实现。

限制：未登录 API 曾限流，后续使用指定账号隔离 API；未遍历所有分支／历史，未执行全部邻居测试；loci 链接仓库不可见，但发布包可核实。源码和测试核验采用核心文件／代表片段，不证明相邻整个项目不含额外功能。数字是当时检索快照，不是优越性证据。结论维持：**在已记录检索范围内未发现成熟直接替代。**

## 6. 许可与参照

[OpenFst](https://github.com/mjansche/openfst)（Apache-2.0）及 [RustFST](https://github.com/GWBM/RustFST)（MIT/Apache-2.0）是跨语言数据模型／语义参照，不是复制实现或完整兼容的上游。实现、测试图和示例独立编写，toolchain core 不 vendoring。许可与 AI 使用说明见仓库根文件。申报书只写已实现能力、可复现数字、参照和边界，不复制搜索流水。