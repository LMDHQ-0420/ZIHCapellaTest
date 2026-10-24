# Capella audit 20261023T154308Z-4364ef9b

Generated 2026-10-23T18:01:53.264990+00:00 (all raw times UTC).

## 已证实原因

以下只证明对应测试的失败事件，底层根因需结合对照和服务端日志。
无已证实失败原因；未执行不等于通过。

## 相关线索

|实验|结果|最后到达层|节点|作业|
|---|---|---|---|---|
|f2-auto-baseline-r1|PASS|exit|c153|4456507|
|f2-auto-baseline-r2|PASS|exit|c153|4456512|
|f2-auto-baseline-r3|PASS|exit|c155|4456514|
|f2-c148-default-r1|REJECTED||||
|f2-c148-cat-r1|REJECTED||||
|f2-c148-all-r1|REJECTED||||
|f2-c148-touch-r1|REJECTED||||
|f2-c148-cat-cwd-r1|REJECTED||||
|f2-c148-alias-cwd-r1|REJECTED||||
|f2-c148-cat-log-r1|REJECTED||||
|f2-c148-ntpn-r1|REJECTED||||
|f2-c148-ntpn-r2|REJECTED||||
|f2-c148-cat-log-r2|REJECTED||||
|f2-c148-alias-cwd-r2|REJECTED||||
|f2-c148-cat-cwd-r2|REJECTED||||
|f2-c148-touch-r2|REJECTED||||
|f2-c148-all-r2|REJECTED||||
|f2-c148-cat-r2|REJECTED||||
|f2-c148-default-r2|REJECTED||||
|f2-c113-default-r1|NO_RESOURCES|queue|None assigned|4456538|
|f2-c113-cat-r1|NO_RESOURCES|queue|None assigned|4456563|
|f2-c113-all-r1|NO_RESOURCES|queue|None assigned|4456576|
|f2-c113-touch-r1|NO_RESOURCES|queue|None assigned|4456596|
|f2-c113-cat-cwd-r1|NO_RESOURCES|queue|None assigned|4456612|
|f2-c113-alias-cwd-r1|NO_RESOURCES|queue|None assigned|4456629|
|f2-c113-cat-log-r1|NO_RESOURCES|queue|None assigned|4456655|
|f2-c113-ntpn-r1|NO_RESOURCES|queue|None assigned|4456681|
|f2-c113-ntpn-r2|NO_RESOURCES|queue|None assigned|4456707|
|f2-c113-cat-log-r2|NO_RESOURCES|queue|None assigned|4456777|
|f2-c113-alias-cwd-r2|NO_RESOURCES|queue|None assigned|4456796|
|f2-c113-cat-cwd-r2|NO_RESOURCES|queue|None assigned|4456819|
|f2-c113-touch-r2|NO_RESOURCES|queue|None assigned|4456853|
|f2-c113-all-r2|NO_RESOURCES|queue|None assigned|4456867|
|f2-c113-cat-r2|NO_RESOURCES|queue|None assigned|4456904|
|f2-c113-default-r2|NO_RESOURCES|queue|None assigned|4456931|
|f3-c148-base-r1|REJECTED||||
|f3-c148-ntpn-r1|REJECTED||||
|f3-c148-exclusive-r1|NO_RESOURCES|queue|None assigned|4456962|
|f3-c148-gpt-r1|REJECTED||||
|f3-c148-direct-r1|REJECTED||||
|f3-c148-direct-r2|REJECTED||||
|f3-c148-gpt-r2|REJECTED||||
|f3-c148-exclusive-r2|NO_RESOURCES|queue|None assigned|4456994|
|f3-c148-ntpn-r2|REJECTED||||
|f3-c148-base-r2|REJECTED||||
|p4-own-1gpu|PASS|exit|c68|4457110|
|p4-own-4gpu|NO_RESOURCES|queue|None assigned|4457120|

## 尚未验证

无 batch 首条标记只能定位到 batch 正文之前，不能区分 chdir、日志打开、prolog 或服务端故障。
默认 license 自动包含全部文件系统；license 与挂载可见性分别核对。SKIP 不等于崩溃。
全部结果仅适用于本工具自带的合成模型和数据；未运行的对照保持未知。
MaxRSS 可能只在 step 有值，空值不是零；cgroup 与采样也可能遗漏峰值。

## 推荐配置

只输出重复短测、至少一小时持续测试且保留配置余量的候选。吞吐最高指已测试配置中的结果。
无已验证训练推荐；保持原因未定。

## 四卡与存储对照

{}

## Slurm 作业并发对照

{}

各分配的节点、UUID、存储路径可能不同；跨节点差异不能仅归因于 MPS、许可或 Slurm 参数。
本地临时存储仅用于分离 GPU/CPU 与 cat 因素；本地 checkpoint 随任务清理，验证结果和日志保存在 HOME。
显存压力组只增加固定大小的已写入 CUDA 张量，不能代替真实大模型或所有显存峰值阶段。

完整数据见 results.csv、results.json、training-measurements.json、jobs/ 和 evidence/。
Observed GPU hours=0.0189; reservation upper bound=2.4000.
Actual global GPU overlap=1; configured cap=4.
