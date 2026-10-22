# 来源、扩展关系与有限查重

日期：2026-10-20 完成检索与实现记录，2026-10-22 在本机重新解析依赖 0.2.5 并复跑检查，结论未变。只用于本地选题与实现记录，不保证全网唯一或独立报名获批。

## 检索范围

读取 [Mooncakes modules API](https://mooncakes.io/api/v0/modules)，当次 3,156 条，检索 `raking, iterative proportional fitting, survey, calibration weights, post-stratification, contingency`，并补查 causal/calibration 邻居。相关元数据保存为 `docs/registry-neighbors.json`。

成功的 GitHub 仓库/README 搜索：`language:MoonBit raking in:readme`、`moonbit "iterative proportional" in:readme`、`moonbit "post-stratification" in:readme`、`moonbit "边际校准" in:readme` 各返回 0；`moonbit "survey weighting" in:readme` 返回 `qjgqjg/moon-causal` 1 项，以上响应均 `incomplete_results=false`。补查 `moonbit "rake" in:readme` 返回 21 项，主要是综合清单/语言统计项目；本次仅看这些条目的仓库元数据，不据此声称全部与 raking 无关。

检索只覆盖公开元数据和有限 README；不是 GitHub 全量代码搜索，也未覆盖未索引、私有、未发布作品和全部社区讨论。本次实际检查的上游源码才是能力比较的主要证据。

## 真实上游与新增价值

上游：[qjgqjg/moon-causal](https://github.com/qjgqjg/moon-causal)，Apache-2.0，未归档，观测 pushed_at=2026-08-24T09:43:15Z。核读 README、根 mbti、`survey_causal_advanced.mbt`、`calibration_advanced.mbt`；安装并阅读注册表版本 `qjgqjg/moon-causal@0.2.5` 的公开接口和 `validation.mbt`。

| 层面 | 上游实际覆盖 | 本项目范围与验证 |
| --- | --- | --- |
| survey weighting | `rake_integer_cells(keys, weights, target_totals, iterations)` 按一个整数 key 分组缩放；另有单总量 calibration、post-stratification 等 | **不另起一个同名基础权重库**。声明并实际导入上游，提供 `oneway_baseline` 直接调用该函数，测试宽松边界下两者一致；新增多列分类、各维目标、严格输入验证与跨维完整残差复核 |
| 权重约束 | 所核读单 key raking 不接收逐行上下界参数 | 新增每行绝对界限，标量二分求解夹紧后的乘法投影，处理边界与剩余总量；例中无界 7.5/2.5 被本库审查拒绝，有界结果 4/6 通过。176 组二元解析解核对结果 |
| 结果判定 | 上游返回自己的 `CalibrationResult` 和收敛字段 | 适配器不直接采用该字段作为本库结论；按最终权重重新计算全部边际与上下界。多维约束局部可满足但联合冲突时，按预算返回 `IterationLimit`，不伪造数学不可行结论 |
| 数值统计 | 上游已有 ESS 和 Hájek 加权均值 | 真实调用 `effective_sample_size`、`hajek_mean`；新增严格形状/非有限值检查与调用前权重尺度归一化，不主张发明 ESS 或均值 |

这是下游功能扩展与实际 API 互操作，未向上游发送消息或 PR，未声称获得上游认可。新增工程责任由上述 API、具体反例与测试体现；独立目录或更方便的调用不是申报价值的唯一理由。是否适合作为独立新项目仍待官方判断，不能把真实依赖视为自动过审。

## 需求、输入输出与边界

1. 调查分析：样本行、基础权重和多个总体边际输入，输出受约束权重、ESS 和经形状检查的均值。没有推导因果效应或无偏方差。
2. 交叉表调整：将汇总表单元格当作行，输入多个分类目标和结构零/上下界，得到近似实数表及逐边际残差。没有输出虚假的整数人数。
3. 审查现有权重：调用方提供旧权重与新总体目标，`evaluate` 独立复核偏差与界限，`fit` 可重新调整；不需要信任某个上游或本库之前的成功标志。

上述责任与同机 `moon-mrp` 的 BOM/整数库存递推、`moon-usage` 的用量计价不同，无共享核心代码、测试或业务模型。当前实现有明确输入上限与浮点容差，不声称通用凸优化最优性、完整联合可行性判定或统计代表性。

## 通用方法、来源与许可

迭代比例拟合和 raking 为既有方法，背景参考 [Iterative proportional fitting](https://en.wikipedia.org/wiki/Iterative_proportional_fitting)；本次未逐项复核该页面当前正文，不把方法归为原创。代码按本项目显式定义的有界逐组投影语义独立实现，没有复制上游源码、测试或真实样本。

本项目新代码 MIT；上游依赖保持 Apache-2.0。本次实际安装和验证版本为 0.2.5，依赖声明见 `moon.mod`，后续升级需重新核查；授权文本随项目保存在 `licenses/`，署名与使用关系见 `THIRD-PARTY.md`。`.mooncakes` 缓存排除在未来 Git 范围之外，不将依赖源码冒充本项目代码量。

## 本轮放弃的候选

- 三方合并、重试/熔断、组合测试分别找到直接相邻实现，未作为最终项目开发。
- 隐私门禁方向在 GitHub 找到 [MoonSentinel](https://github.com/STW135-2026/moonsentinel)，README 已明确 k-匿名与 l-diversity，因此放弃。
- 关系规范化候选最初按名称/描述检索未定位到完整对手；补充 `language:MoonBit BCNF in:readme` 和 `"minimal cover"` 检索，找到 [LuoYunxin1/moonnormal](https://github.com/LuoYunxin1/moonnormal)，其 README、mbti 覆盖闭包/键/分解/审计。已将候选留在本地 `contest-submission/candidates/unselected-moon-relations-20261020`，**不计入本次两个项目，不建议重复独立申报**。这个发现证明不能只凭早期零命中结论宣称唯一。

## 赛事与交付状态

使用本机 `moonbit-contest-projects` 技能（`SKILL.md`）的流程。该技能的规则摘要不是本次在线验证的最新官方全文；历史微信链接的月份/标题与摘要已知有不一致，当月报名额度、日期和材料要求需向官方确认。这里只完成本地开发与源码交付，不代报名或宣称已过初审。

源码托管在 GitHub（`mengshi-12/moon-rake`），申报书与本地验证记录不入库、不随源码压缩包分发。CI 仅为配置，是否在线运行以仓库 Actions 页面为准；Mooncakes 发布尚未执行。申报书由本人理解并核对改写，不以生成内容冒充人工撰写。
