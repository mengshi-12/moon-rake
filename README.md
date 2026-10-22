# moon-rake

多边际、有界权重校准扩展，构建在 [`qjgqjg/moon-causal@0.2.5`](https://github.com/qjgqjg/moon-causal) 之上。输入每行的分类、基础权重和绝对上下界，以及多个分类维度的目标总量；输出按 ID 排序的权重、逐轮最大误差、全部边际残差、总权重和有效样本量。纯 MoonBit，不读文件、不连数据库、不使用随机源，结果只取决于输入。

这是实际依赖上游 API 的扩展，不是另起一个同名基础权重库：单分组基线调用 `rake_integer_cells`，统计诊断调用 `effective_sample_size`，加权均值调用 `hajek_mean`。新增责任是多列分类、逐行绝对界限、跨维完整残差复核、外部权重独立审查和显式未收敛状态。能力比较见 [SOURCES.md](SOURCES.md)，依赖署名见 [THIRD-PARTY.md](THIRD-PARTY.md)。

## 三种工作流

1. **样本校准**：分析员输入四行样本、F/M = 60/40 与 N/S = 50/50 的总体边际，得到 30、30、20、20 的权重；对观测值 10、20、30、40 求加权均值，得到 23，并可逐条审查四个组的残差。
2. **汇总表配平**：数据工程师输入 2×3 交叉表的初始单元格权重、行目标 40/60、列目标 20/30/50，得到 8、12、20、12、18、30；结构零与上下界逐项核查，不用统一缩放冒充多维约束。
3. **权重回归审查**：数据管理员已有四个权重，总体边际改为 F/M = 50/50 后用 `evaluate` 独立复算全部残差，得到最大误差 0.2 并判为不通过；调用 `fit` 重新校准后再次复核通过。审查函数接受外部权重，不需要先相信任何一方的收敛标志。

示例另外展示：上游无界基线给出 7.5/2.5 并违反上界，有界投影给出 4/6 且通过；联合不相容的边际在 5 轮预算后返回 `IterationLimit`，而不是伪装成收敛。

第三种工作流另有独立示例 `examples/audit`：一张从表格粘来的 2×3 权重，`evaluate` 判为 region/south 与 band/high 两条边际不达标（最大误差 0.075），重新 `fit` 后 1 轮收敛，六行权重为 15、15、20、15、15、20。

## 运行

编译工具链 `moonc >= 0.10.14`。本地验证用 `moon 0.1.20260920` / `moonc v0.10.14+7d59c7e`（wasm、wasm-gc、js 三目标），CI 用安装脚本取到的当时最新稳定版 `moonc v0.10.17`（四目标全部通过，含 native）。首次解析已声明的 Apache-2.0 依赖需要联网，缓存后计算过程不联网。JS 目标需要 Node.js；Native 目标需要可用的 C 工具链——Windows 上需要 UCRT/MSVC（`rand_s` 在 MSVCRT 下不存在，只带 LLVM-MinGW/MSVCRT 的机器会在工具链自带的 `env.c` 处报未声明）。

已发布到 Mooncakes：`moon add mengshi-12/moon-rake`（0.1.0，MIT）。作为依赖使用时在 `moon.pkg` 里声明：

```moonbit
import {
  "mengshi-12/moon-rake" @rake,
}
```

从源码工作的完整命令：

```powershell
moon update
moon check --deny-warn --target all
moon build --target all
moon test --deny-warn --target all
moon run examples/demo --target wasm --deny-warn
moon run examples/audit --target wasm --deny-warn
moon fmt --check
moon info
```

两个示例都在 `examples/` 下，可换 `--target wasm-gc` 或 `js`；每个示例在三个目标上的 stdout 逐字一致，真实输出保存在 [docs/demo-output.txt](docs/demo-output.txt) 与 [docs/audit-output.txt](docs/audit-output.txt)。`demo` 走完三种工作流；`audit` 只做审查——把一张粘贴来的权重表当作外部输入，先 `evaluate` 判否，再 `fit` 重算。若 `moon` 不在 PATH，把工具链的 `bin` 目录加入当前进程 PATH 并设置 `MOON_HOME` 指向工具链根目录。

`moon fmt --check` 在 0.10.14 上通过。0.10.17 的格式化器把同一类型的规范拼写改为 `Int32`、可选参数改为 `options~`，直接跑 `moon fmt` 会改写源码但仍可编译；本仓库保留 0.10.14 也接受的 `Int`／`options?` 拼写，因此 CI 不把格式化差异当门禁，只把 check、build、test、接口漂移和示例作为门禁。

## API

```moonbit
let problem : @rake.Problem = {
  rows: [
    { id: "a", cells: ["all"], base_weight: 3.0, lower: 1.0, upper: 4.0 },
    { id: "b", cells: ["all"], base_weight: 1.0, lower: 1.0, upper: 20.0 },
  ],
  margins: [{ name: "population", targets: [{ category: "all", total: 10.0 }] }],
}
let result = @rake.fit(problem).unwrap()
// result.weights: [{id:"a",weight:4}, {id:"b",weight:6}]
let audit = @rake.evaluate(problem, [4.0, 6.0]).unwrap()
assert_true(audit.passes)
```

导入包为 `"mengshi-12/moon-rake" @rake`；完整可编译调用见 `examples/demo`，签名见 [pkg.generated.mbti](pkg.generated.mbti)。

| API | 责任 |
| --- | --- |
| `fit(problem, options?)` | 逐维逐类别执行有界乘法投影，完整扫轮后复核所有边际 |
| `evaluate(problem, weights, tolerance?)` | 审查任意权重；输入顺序与 `problem.rows` 一致，不是按 ID 排序后的顺序 |
| `oneway_baseline(problem)` | 实际调用上游单分组 raking，并重新审查其输出的边际与边界 |
| `weighted_mean(values, weights)` | 严格校验后归一化权重尺度，调用上游 Hájek 均值 |
| `default_options()` | 默认 100 轮、容差 `1e-8` |
| 结果 `to_json()` | 导出 Double 权重、状态、逐组残差与诊断，JSON 字符串正常转义 |

`fit` 的权重按 ID 的 UTF-16 字典序输出；`cells` 始终按输入 `margins` 的顺序解释。更改维度顺序可能改变迭代轨迹和最终可行解，本版本不承诺顺序无关的最优解。输入不会被修改，调用方也不应在执行期间并发修改输入。

`oneway_baseline` 未通过本库复核时状态为 `BaselineRejected`，与本库拟合耗尽预算的 `IterationLimit` 分开，两者都不表示数学不可行。

## 数值语义与边界

- 每轮沿各边际逐组调整：用标量二分求 `sum(clamp(alpha * current, lower, upper)) = target`，夹紧上下界的同时把剩余总量重新分配。组内求解最多 96 次扩展区间、128 次二分，不做取整。
- 每轮结束才计算 `abs(actual-target)/max(1,target)`；所有组不超过容差且无边界违规时才标记 `Converged`。默认容差 `1e-8`，可选 `1e-10..1e-3`；初值已满足时迭代数为 0。
- **`IterationLimit` 只表示未在预算内达到目标，不能当作联合不可行的证明。** 局部组目标超出上下界之和、无正支撑、维度总量不一致会直接拒绝；这些局部检查不构成完整线性可行性求解。
- 非零可调行要求 `1e-12 <= lower <= base_weight <= upper <= 1e12`；结构零必须三项全为 0。正基础权重不会被自动压成零；要删除记录，调用方应先确定结构零，而不是依赖隐藏的数值地板。
- 目标非负且不超过 `1e12`，每维至少一个目标，维度总量须在容差内一致且为正。空类别名、未知类别、重复目标或行 ID、NaN、Infinity、错误行宽全部拒绝，不静默截断输入。
- 上限为 5,000 行、8 个边际维度、256 个目标类别、1,000 轮。每维类别必须覆盖全部输入行；未出现的零目标类别可以接受。
- ESS 为 `(sum w)^2 / sum(w^2)`；调用上游前按最大权重归一化，避免外部极小权重平方下溢。均值同样归一化权重尺度，values 的绝对值限 `1e12`。
- 结果只满足明示的校准条件：不证明总体代表性、缺失机制可忽略、因果识别成立、方差无偏或统计显著，也不输出整数人数或隐私保证。

## 测试与交付状态

22 项具名测试覆盖手算双边际解、非均匀 2×2 表的独立 odds-ratio 解、176 组二元边界解析解、真实上游互操作、联合不相容约束耗尽预算、结构零、外部权重顺序、输入不可变性、NaN/Infinity、极小权重尺度、尺寸上限、容差边界、重复校准零迭代与全部显式错误分支。

CI 配置覆盖四目标的 check、build、test、生成接口无漂移（比较前把 0.10.17 的 `Int32` 归一为 `Int`）和四个目标上的两个示例（`.github/workflows/ci.yml`）。配置存在不等于线上运行通过；最新一次 GitHub Actions 结果以仓库 Actions 页面为准。

已发布到 Mooncakes：`mengshi-12/moon-rake` 0.1.0，`build_status` 为 `success`；`moon add` 后在独立工程里编译并运行通过。未报名任何赛事。`申报书.md` 与 `LOCAL_VALIDATION.md` 属于本地材料，被 `.gitignore` 排除，不在仓库内容中。

MIT（本项目）；Apache-2.0（上游依赖，许可全文见 `licenses/`）。
