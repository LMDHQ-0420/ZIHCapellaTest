# Capella 独立测试

自带合成数据、S/M/L 三种 CNN，每轮新建 cat workspace、venv 和作业。只使用、采集和管理本轮文件、进程与分配资源。实验记录：[第一轮](experiments/20261022T151236Z-24023185/README.md)、[第二轮及门控修复](experiments/20261023T154308Z-4364ef9b/README.md)。第二轮只实际运行四个实验，未进行高并发测试；新版已解除四卡排队对单卡测试的阻断。

## 运行

在 Capella 登录节点执行（账号 `chwu350f`）：

```bash
cd "$HOME/ZIHCapellaTest"
git pull --ff-only
bash ./capella_audit.sh start
```

启动后打印 `RUN_DIR`、`CAT_DIR` 和控制器日志路径，后台运行，SSH 断开后保留。脚本自行提交测试作业。需要系统 `/usr/bin/python3`（3.9～3.12，含 venv）、Slurm、`ws_allocate` 和官方下载源访问；只在本轮 venv 安装固定的 PyTorch 2.5.1 / cu124。

默认 `swtest` / `capella`，同时最多 **4 GPU**，排队上限 **30 分钟**（定向节点、四卡环境探针 **5 分钟**），单项运行上限 **75 分钟**，整轮 **36 小时 / 80 GPU 小时申请上界**。新 workspace 保留 **3 天**，请在到期前导出。未获得资源、站点拒绝或预算不足均保留为未验证。

```bash
RUN_DIR="$HOME/capella-audit/替换为启动打印的运行编号"
tail -n 40 "$RUN_DIR/controller.log"
bash "$RUN_DIR/capella_audit.sh" status "$RUN_DIR"
bash "$RUN_DIR/capella_audit.sh" resume "$RUN_DIR"  # 仅在控制器已退出时恢复
bash "$RUN_DIR/capella_audit.sh" stop "$RUN_DIR"    # 只停止本轮登记并核实归属的作业
```

调整节点数量、节点名、模型或预算时，先生成配置并编辑，再启动一个新轮次。默认 `profile="followup"`、`node_samples=6`、`paired_nodes=["c59","c23"]`；实际可分配性决定覆盖范围。原版全面矩阵可选 `profile="full"`。新版修复须 start 新轮次；勿覆盖旧轮次的保存源码，已结束的轮次 resume 不会补跑。

```bash
bash ./capella_audit.sh init-config "$HOME/capella-test-config.json"
# 编辑 JSON；其余默认值可保留。
bash ./capella_audit.sh start --config "$HOME/capella-test-config.json"
```

## 本轮测试什么

- 争取覆盖六个节点：c59、c23 加本轮自动分配成功的节点及抽样替补；最多八个诊断候选。支持 `mixed-` 标记，读取公共节点 TRES；同节点首次资源准入失败后跳过余下重复等待，缺项明确为未验证。
- 每节点重复两轮，比较默认许可、显式 `cat`、显式全部文件系统许可、预先访问目录、cat 工作目录/HOME 符号链接入口、cat 日志路径及 `--ntasks-per-node=1`。batch/step 都记录目录读写、挂载源/类型、权限和命名空间；失败十秒后再检查，保留首次失败。参数顺序交替，记录节点和时间。使用站点支持的文件系统访问方式，不执行管理员挂载或重挂载。
- 资源允许时至多三个节点做四卡资源/独占、任务参数及 direct/srun 对照；每次分配重新核验实际 CPU、RAM、GPU 型号、显存和物理 UUID。
- 分开比较 **1/2/4 个 Slurm 作业**、**每卡 1/2/3/4/8/12 个进程**、**1/2 线程与 0/1/2 个 DataLoader workers**，独立对照 MPS。作业数对照统一每 GPU 175G 主机内存，使四个单卡与一个四卡的总请求同为 700G。修复后的每进程 IPC 临时目录使用短且唯一的 `/tmp/ca-*`。
- 单卡环境通过后先测 S 模型 workers=0/1/2 的 30 秒短回归。四卡环境独立记结果，未获四卡不会阻断单卡测试，流程末尾最多复查一次。训练先用本轮节点本地目录隔离 cat 因素；S/M/L 短测、候选单卡一小时验证、固定每进程 1/4 GiB CUDA 张量的显存压力组；随后四卡短测及本地/cat 各一小时完整流程。逐档检查显存/主机内存至少 20%、CPU 平均至少 10% 的余量，失败或证据不足停止升级。
- 独立文件、原子替换、加锁 JSONL、重复启动/跳过/运行锁；完整流程包含合成数据准备、训练、验证、checkpoint 保存/加载和汇总。

每 5 秒采样，每个子进程单独记退出码，比较实际重叠、总吞吐、GPU 小时及 CPU/RAM 使用。cat 不可用会阻止该次 cat 训练；HOME/启动正常时本地训练仍可验证 GPU 并发。不同节点的性能差异保留为混杂因素。**短测及合成负载结果不能外推到所有真实模型；未执行的配置不会标为通过。**

## 输出及完整导出

HOME 的 `$HOME/capella-audit/<运行编号>/` 保存 `REPORT.md`、`coverage.json`（实际分配及测试覆盖）、`results.json/csv`、`findings.json`、各并发/显存压力结果、配置/源码哈希、准确提交命令、Slurm 日志、采样、每个子进程日志和候选模板。打印的独立 `CAT_DIR` 保存 I/O、训练结果和 checkpoint。节点本地 checkpoint 随任务清理，其验证结果和日志保存在 HOME。

结束时自动生成同级 `<运行编号>.full.tar.gz` 快照及 `.sha256`。**最终收齐控制器末尾日志，请等控制器退出后执行下面的导出**；命令不提交作业、不重新运行测试，也支持上一轮 v2 目录。旧轮次请调用仓库中的新版脚本，勿覆盖旧轮次的源码/config/runtime。

```bash
TOOL="$HOME/ZIHCapellaTest/capella_audit.sh"
RUN_DIR="$HOME/capella-audit/替换为运行编号"

bash "$TOOL" export "$RUN_DIR"
ARCHIVE="${RUN_DIR}.full.tar.gz"

# 校验实际包内的每一个文件，同时检查日志覆盖是否完整。
bash "$TOOL" verify-export "$ARCHIVE"
cat "$RUN_DIR/export-status.json"
ls -lh "$ARCHIVE" "$ARCHIVE.sha256"
```

包内 `<运行编号>/home/` 和 `cat/` 收集本轮全部普通日志/结果文件，**不截取长日志**；`export-manifest.json` 列出每个文件的大小、SHA-256、排除项及缺失来源。默认排除 venv、缓存、符号链接和 `.pt/.pth` 权重。如需连 cat 和 HOME 中的 checkpoint 一起导出：

```bash
bash "$TOOL" export "$RUN_DIR" --include-checkpoints
ARCHIVE="${RUN_DIR}.all.tar.gz"
bash "$TOOL" verify-export "$ARCHIVE"
```

`COMPLETE_LOGS=True`、退出码 0 表示日志来源齐全且校验通过。退出码 2 / `COMPLETE_LOGS=False` 表示已生成可用但有缺失的包（例如 cat 到期或不可访问），原因在 manifest；HOME 摘录无法恢复已经丢失的 cat 原日志。控制器或另一个导出正在运行时会拒绝导出，稍后重试。新版不会覆盖旧版 `<运行编号>.tar.gz`；`.full` 与 `.all` 分别独立保存。

在自己电脑的终端下载（`CAPELLA_SSH` 替换为平时能连接的 SSH 别名/目标；按实际情况使用网关配置）：

```bash
CAPELLA_SSH='chwu350f@替换为SSH目标'
RUN_ID='替换为运行编号'
mkdir -p "$HOME/Downloads/capella-results"
cd "$HOME/Downloads/capella-results"
scp "${CAPELLA_SSH}:capella-audit/${RUN_ID}.full.tar.gz" .
scp "${CAPELLA_SSH}:capella-audit/${RUN_ID}.full.tar.gz.sha256" .

# macOS（Linux 可用 sha256sum -c）：
shasum -a 256 -c "${RUN_ID}.full.tar.gz.sha256"
# 使用本地仓库的脚本再次验证包内所有文件，不需要 Slurm/CUDA：
bash /本地仓库绝对路径/ZIHCapellaTest/capella_audit.sh verify-export "${RUN_ID}.full.tar.gz"
tar -xzf "${RUN_ID}.full.tar.gz"
# 查看：<运行编号>/home/REPORT.md、home/jobs/、home/slurm/、cat/。
```

下载含权重的包时，把上述 `.full.tar.gz` 改为 `.all.tar.gz`。需要交回分析时，同时提供压缩包和 `.sha256`。
