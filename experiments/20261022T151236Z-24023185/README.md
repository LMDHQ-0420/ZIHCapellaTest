# 实验结论：20261022T151236Z-24023185

结论：本次已经复现 cat 路径/挂载不可用，并定位到测试工具的一项 DataLoader 临时路径错误；没有观察到普遍的“每卡进程多就无法训练”。单卡小合成模型的 12 进程短测通过，但四卡完整持续流程尚未验证，不能推断真实项目或所有高并发负载都稳定。

## 证据范围与统计

- 实际运行：2026-10-22 15:12:36 ～ 2026-10-23 03:19:13 UTC；北京时间 10 月 22 日 23:12:36 ～ 10 月 23 日 11:19:13，约 12 小时 6 分 36 秒。
- 源码版本 `dfefda2532bab859ff861461250ca0f75ada27e9`，脚本 SHA-256 `c8bfe87216d086affadf0dc03d56f343beef9009696f9d1cf827810ae114aaa1`，与上传包内脚本及 config 一致。
- 152 个实验配置：138 PASS、12 已分配后失败、2 排队超时未获得资源。包含三个四元素数组，所以有 161 条父/数组元素记录；629 条 accounting 行还包括 batch、extern 和 step，不能混为 629 个独立实验。
- 实际占用约 9.2683 GPU 小时；按请求时限累计预留上界 53.1333 GPU 小时（原预算 64）。全轮观测到的 GPU 并发峰值为 4。排队也计入整轮耗时。
- 只分析本独立工具的作业。没有读取其他项目、环境、历史训练或正在运行任务，不能用本结果比较其他项目的实际行为。
- 上传的旧版包保存 HOME 原日志和部分 cat 有界摘录，没有完整收集 cat 原始目录。下文保留证据边界；新版导出补齐完整 cat 日志。

机器可读附件：

- `original-config.json`：原始配置；`original-results.csv`：全部 629 条父/数组/step 的原始资源、状态与时间记录。
- `reviewed-cases.json`：152 个实验的原始请求、父/数组元素时间线、实分资源、batch 结果、可用的逐进程退出码及复核分类。
- `long-measurements.json`：六组一小时 launcher/子进程原始结果及从采样重新计算的指标。
- `selected-evidence.json`：失败提交命令、关键异常、挂载/硬件证据；摘录显式标记，并附原始文件哈希。
- `provenance.json`：上传包的大小、SHA-256、源码及统计来源。原压缩包未放入 Git。

可用 Python 3.9+ 对照原包复算到另一个独立目录（不执行包内脚本、不提交作业）：

```bash
python3 experiments/20261022T151236Z-24023185/reproduce_review.py \
  /你保存的绝对路径/20261022T151236Z-24023185.tar.gz --out /tmp/capella-reviewed-copy
```

## 已证实原因

### 1. c59 的两次作业里 cat 挂载不可见

`4451600`、`4451615` 均在 c59 分配 4 GPU / 56 CPU / 700G 后运行约 3 秒，失败码 `72:0`。batch 首条标记及 step 已启动，step 中 HOME 写入、读取、校验和删除正常；`namei` 显示 `/data/cat/ws` 不存在，mountinfo 中没有 `/data/cat`，路径落到本地根 XFS `/dev/nvme0n1p2`。这是该作业视角下的挂载不可见证据，底层原因需要 ZIH 的服务端记录。

两次 `scontrol` 已有 `Licenses=cat,horse,narwhal,walrus`，且 `LicensesAlloc` 含 `cat:1`；不是“没有写 -L cat 所以没有许可”。batch 和 step 都记录 `mnt:[4026531841]`，本次没有观察到二者挂载命名空间分离。

对应四卡独占 base 的第二次重复 `4451688` 在 c116 通过，cat 显示为 Weka 挂载。c59 稍后的 `4452070` 又通过 S 模型每卡 12 进程 MPS 训练。因此不能把 c59 定义为永久坏节点，也不能将独占或 `--ntasks-per-node` 单独认定为原因。

### 2. c23 的四次完整流程在启动训练子进程前访问 cat 失败

`4453471`、`4453484`、`4453487`、`4453491` 都在 c23，已分配 4 GPU / 56 CPU / 700G，约 11～13 秒退出。launcher 枚举到了四张 GPU 的 UUID，随后创建本轮 cat 子目录时遇到 ENOENT/`PermissionError: /data/cat/ws`。四份 `child-exits.json` 均为空，训练子进程没有启动。

这些作业没有采集当次 cat mountinfo/findmnt，故只能证实路径不可用；不能断言它们与 c59 的底层挂载故障完全相同。最终 `79:0` 是工具完整流程失败的返回码，不是 GPU OOM 的证明。

### 3. 六组 workers=2 失败源于工具的 AF_UNIX 路径长度

六组 S/M/L workers=2 日志均出现 `OSError: AF_UNIX path too long`，继而在约 220 秒预热屏障等待后由 launcher 超时收尾。旧脚本把 TMPDIR 放在深层 cat 路径，例如 `.../processes/p5-S-tune-workers2-r1/4452091_0/g0-p0/tmp`；该例完整目录约 102 字节，加上 Python multiprocessing 的 `pymp-…/listener-…` 后约 134 字节，超过 AF_UNIX 路径限制。

这是测试脚本错误，不能证明服务器不支持 DataLoader workers，也不能用这六组数据比较 worker 吞吐或归因为主机内存不足。新版使用每进程独立的短 `/tmp/ca-*`，本地真实 multiprocessing Unix listener 回归通过；集群 workers 修复效果仍需下一轮确认。

### 全部未通过实验的分类

|实验|作业|节点|UTC 开始|秒|原始结果|复核类别|
|---|---|---|---|---:|---|---|
|p3-g4-exclusive-base-r1|4451600|c59|2026-10-22T16:01:29|3|FAILED 72:0|CAT_MOUNT_NOT_VISIBLE|
|p3-g4-exclusive-ntpn-r1|4451615|c59|2026-10-22T16:01:49|3|FAILED 72:0|CAT_MOUNT_NOT_VISIBLE|
|p5-S-tune-workers2-r1|4452091|c141|2026-10-22T17:52:29|232|FAILED 78:0|IPC_TEMP_PATH_TOO_LONG|
|p5-S-tune-workers2-r2|4452095|c141|2026-10-22T17:56:27|231|FAILED 78:0|IPC_TEMP_PATH_TOO_LONG|
|p5-M-tune-workers2-r1|4452687|c5|2026-10-22T20:57:41|231|FAILED 78:0|IPC_TEMP_PATH_TOO_LONG|
|p5-M-tune-workers2-r2|4452695|c5|2026-10-22T21:01:46|231|FAILED 78:0|IPC_TEMP_PATH_TOO_LONG|
|p5-L-tune-workers2-r1|4453031|c5|2026-10-23T00:04:04|231|FAILED 78:0|IPC_TEMP_PATH_TOO_LONG|
|p5-L-tune-workers2-r2|4453037|c5|2026-10-23T00:08:15|230|FAILED 78:0|IPC_TEMP_PATH_TOO_LONG|
|p6-S-stable-pipeline|4453305|None assigned|None|0|CANCELLED by 2197964 0:0|NO_RESOURCES|
|p6-S-throughput-pipeline|4453381|None assigned|None|0|CANCELLED by 2197964 0:0|NO_RESOURCES|
|p6-M-stable-pipeline|4453471|c23|2026-10-23T03:17:24|13|FAILED 79:0|CAT_PATH_UNUSABLE|
|p6-M-throughput-pipeline|4453484|c23|2026-10-23T03:17:47|11|FAILED 79:0|CAT_PATH_UNUSABLE|
|p6-L-stable-pipeline|4453487|c23|2026-10-23T03:18:25|12|FAILED 79:0|CAT_PATH_UNUSABLE|
|p6-L-throughput-pipeline|4453491|c23|2026-10-23T03:18:47|12|FAILED 79:0|CAT_PATH_UNUSABLE|

两条 `NO_RESOURCES` 为 `4453305`、`4453381`，PENDING/Resources，未发生分配或训练。队列预测 StartTime 不能当作真实开始；实际 sacct Start 未设置，工具在 30 分钟后取消。它们不计为运行失败。

## 相关线索：高并发与资源使用

### 已覆盖的并发范围

- S/M/L × 每卡 1、2、3、4、8、12 进程 × MPS 关/开 × 2 次重复，共 72 组短测全部通过；threads=1、workers=0，数据、batch=64、fp32 固定。实际训练重叠和物理 UUID 由 launcher/子进程记录验证。
- 六组单卡一小时候选全部通过；不是用 90 秒短测外推一小时。
- 四 GPU 环境短测 `4451753` 在 c33 通过，四个独立物理 UUID、4 个训练进程、共同训练约 20 秒。它只证明当次每卡一个小训练的绑定/启动，不代表四卡高并发一小时已通过。
- 数组限制 1、2、4 的实际峰值分别达到 1、2、4，不只是写了 `%4`。四个独立单卡作业及一个四卡轻探针也通过；它们没有承载相同的正式训练，不能据此给出训练吞吐排名。
- threads=2 的六组短调优通过；workers=2 的六组受脚本路径错误影响，没有有效性能结论。
- HOME/cat 并发 I/O 检验通过：每个文件系统 800 条唯一记录，无重复、缺失和非法 JSON；每个子进程退出码与重复启动 SKIP/运行锁单独核验。

### 一小时实测总吞吐

吞吐使用 `launcher.total_items / launcher.wall_seconds`，包括该 launcher 的进程启动与训练尾部验证/保存开销；不包含排队及此前设备枚举。CPU 100% 表示约一个逻辑 CPU。RAM 为所采有效 cgroup 的 peak，不是整台节点的使用量。实际分配均为 1 GPU、14 CPU、180G。

|模型/用途|进程/卡|MPS|线程/worker|作业 / 节点|总 samples/s|RAM peak GiB|CPU 平均核数|GPU 内存采样峰值|分配 GPU 小时|
|---|---:|---|---|---|---:|---:|---:|---:|---:|
|S/稳定|1|关|1/0|4452103 / c141|44,030.8|0.739|1.00|0.89%|1.0036|
|S/吞吐候选|12|开|1/0|4452201 / c141|372,680.1|8.759|11.56|10.69%|1.0072|
|M/稳定|1|关|1/0|4452704 / c78|34,124.4|1.211|1.00|0.95%|1.0069|
|M/吞吐候选|4|开|1/0|4452785 / c78|99,276.2|3.055|3.94|3.84%|1.0039|
|L/稳定|1|关|1/0|4453048 / c5|22,415.6|0.782|1.00|1.09%|1.0039|
|L/吞吐候选|3|开|2/0|4453151 / c116|38,516.3|2.894|5.76|3.32%|1.0047|

S/M 吞吐候选相对本轮单进程基线约为 8.46× / 2.91×；L 约 1.72×。L 两组节点不同且线程数也不同，不能归因于 MPS 一个因素。所有候选都是本轮已测组合中的选择，不是全局最优。每 GPU 小时完成量可由 `long-measurements.json` 中 total_items / allocation.gpu_hours 计算；CPU、功耗和各子进程速度亦保留，不能只比较单任务速度。

### 实际硬件及限制

四卡短测 `4451753/c33` 的实际信息：NVIDIA H100，nvidia-smi 每卡 `95830 MiB`，驱动 `580.159.04`、功率上限 `700 W`；PyTorch 可见容量为 `99949674496 bytes`（约 93.085 GiB）。两个工具的容量值分别保留，未推定差异原因。四个 UUID 均独立、每子进程只见一张分配卡并匹配其物理 UUID。

四卡 allocation 的 CPU affinity 为 56，cgroup memory.max 为 `751619276800 bytes`（700 GiB）。`cpu.max="max 100000"`，此处 CPU 边界来自实际 affinity/cpuset，不能误写成 CFS quota=56。单卡持续测试为 14 CPU、180 GiB cgroup 限制。

S/M/L 单进程 PyTorch reserved 峰值仅约 88/142/276 MiB。即使 12 个进程，这仍是远低于 H100 容量的合成负载；GPU 进程上下文、驱动和 MPS 开销并不等于 Torch allocator 峰值。六组一小时未记录 oom_kill 增长，无 Slurm OUT_OF_MEMORY 或明确 CUDA OOM。采样可能漏过尖峰；本次不能代表显存紧张或大型真实模型。

## 尚未验证与可采用的配置

- 挂载失败究竟由 slurmd/prolog、Weka 客户端、命名空间或其他站点状态导致，需要管理员按作业 ID、UTC 时间、节点查服务端日志。已有许可证并不保证挂载成功。
- 历史 `FAILED 0:53` 且没有 batch 首条标记的启动问题，本轮没有复现。已进入 batch/step 的 cat 失败不能直接等同于历史故障。
- 原版 `event()` 参数重名应用错误不是本轮这 12 组失败的原因；正常 SKIP 不是崩溃。
- 单次 HOME 成功不能证明所有作业中的 cat 正常；c59 后来成功也不能否定此前失败。节点/时间/独占状态存在混杂，尚无证据独立归因于 ntasks-per-node、exclusive 或某张 GPU。
- 四卡完整持续流程：两组未获得资源、四组在训练子进程之前失败，尚无成功证据。真实项目、容器/cleanenv、实际大模型、数据加载与输出目录竞争未在这个独立工具中测试。
- 暂可用的合成负载稳定配置：单卡 14 CPU / 180G，n=1、MPS 关、threads=1、workers=0；吞吐候选：S n=12/MPS 开/1/0，M n=4/开/1/0，L n=3/开/2/0。这些只获得单卡一小时证据；不要直接当作四卡或真实项目推荐。请求内存明显大于该合成负载实际需要，但没有做缩减配额后的独立长测，因此不下调已验证模板的资源。
- 运行时限建议按真实预期时长设置；本轮一小时候选请求约 65 分钟。七天排队影响没有做受控对照。完整请求、实际等待与资源见 CSV，不以少数节点/队列样本预测今后等待时间。

## 下一轮如何缩小原因

新版 v3 默认 followup；不复用本轮目录、作业、环境或数据，c59/c23 只是需要复测的节点名。

1. 自动分配最小探针，再覆盖六个可分配节点；每节点把默认/显式 cat/全部文件系统许可、目录预访问、cat cwd/HOME 符号链接入口/log、ntasks-per-node 分别和基线比较。每次记录 batch 与 step 的挂载和读写；失败后十秒复查但不抹去失败。新节点异常再按预算配对。只使用站点支持的访问方式，不手工挂载文件系统。
2. 所有训练分配在 batch 和实际 payload 中检查 cat。cat 路径失败的训练直接在该层分类；节点本地训练保持独立，可继续验证 GPU/CPU，避免把 cat 故障计成高并发训练故障。
3. 修复短 TMPDIR，重测 worker/线程；分开比较 Slurm 作业数、每卡进程数和 DataLoader 线程。保持模型/数据/batch 不变，分别记录 UUID、实际重叠、逐进程退出、总吞吐与 CPU/RAM。
4. 新增固定每进程 1/4 GiB 已写入 CUDA 张量的显存压力对照，逐档上升并留余量；此对照也不能替代真正的大模型。
5. 先短测四卡，再对候选做本地/cat 各至少一小时的完整流程。预算、排队、采样或余量不满足则明确标未验证。新的完整导出同时保存 HOME/cat 所有日志、校验清单及缺失状态。

## 提供 ZIH 支持的事实（草稿，未发送）

收件人：`hpc-support@tu-dresden.de`。优先查询 c59 的 `4451600/4451615`（UTC 2026-10-22 16:01:29～16:01:52）和 c23 的 `4453471/4453484/4453487/4453491`（UTC 2026-10-23 03:17:24～03:18:59）。前者 license 已分配而 `/data/cat` 未挂载、HOME 正常；后者 license 已分配但 `/data/cat/ws` 不可用、训练进程未启动。请检查当时 slurmd/prolog/Weka 挂载及命名空间日志；底层原因未定。

原始提交命令与参数保存在 `selected-evidence.json` 的 `jobs/<case>/submission.json` 项中，作业时间和父/batch/extern/step 在 `original-results.csv`；最小复现由新版单 GPU/单 CPU/1G、/tmp cwd、绝对 HOME 日志探针生成，完整命令写入下一轮每个 `submission.json`。不盲目重提交旧目录，也不以退出码替代根因。

官方依据：[文件系统许可与排查](https://compendium.hpc.tu-dresden.de/data_lifecycle/working/)、[GPU 作业参数警告与示例](https://compendium.hpc.tu-dresden.de/jobs_and_resources/slurm_examples_with_gpu/)、[Capella 硬件](https://compendium.hpc.tu-dresden.de/jobs_and_resources/capella/)、[资源限制](https://compendium.hpc.tu-dresden.de/jobs_and_resources/slurm_limits/)。硬件和配额结论以本轮分配证据为准。
