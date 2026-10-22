# Capella 独立测试

脚本自带合成数据和 S/M/L 三种 CNN，为每轮新建 cat workspace、Python 虚拟环境及 Slurm 作业。只采集、使用和管理本轮文件、进程及分配的 GPU/CPU/内存；不读取其他项目、历史作业或现有训练环境，也不操作其他计算任务。

## 如何运行

将 `capella_audit.sh` 放到 Capella 登录节点的 HOME 目录，以 `chwu350f` 登录后执行：

```bash
bash "$HOME/capella_audit.sh" start
```

脚本自动申请专用 cat workspace，通过 `ws_allocate` 创建，保留 3 天；自动在本轮目录创建独立 venv，并从官方源安装固定版本 PyTorch 2.5.1 / CUDA 12.4。需要系统 `/usr/bin/python3`（3.9～3.12，含 venv）、Slurm、workspace 工具及登录节点可访问下载源。不需要项目路径、容器、数据集或适配器。环境安装失败会保存错误，并跳过 GPU 训练。

启动后打印 `RUN_DIR`、`CAT_DIR` 和日志位置，控制器后台运行。默认 account=`swtest`、partition=`capella`；最多同时使用 **4 GPU**，单项排队上限 **30 分钟**，单项运行上限 **75 分钟**，整轮预算 **36 小时 / 64 GPU 小时请求上界**。预算内不能完成的测试会标为未验证。

如需调整预算，先生成并编辑配置，再启动：

```bash
bash "$HOME/capella_audit.sh" init-config "$HOME/capella-test-config.json"
# 编辑配置中的预算或 stages（默认 [1,2,3,4,5,6]）。
bash "$HOME/capella_audit.sh" start --config "$HOME/capella-test-config.json"
```

使用打印的真实路径查看、恢复或停止本轮：

```bash
RUN_DIR="$HOME/capella-audit/替换为运行编号"
tail -n 40 "$RUN_DIR/controller.log"
bash "$RUN_DIR/capella_audit.sh" status "$RUN_DIR"
bash "$RUN_DIR/capella_audit.sh" resume "$RUN_DIR"  # 控制器意外退出后恢复
bash "$RUN_DIR/capella_audit.sh" stop "$RUN_DIR"    # 只取消本工具登记且核实归属的作业
```

## 测试什么

1. 站点分区、许可和资源限制；不查询其他作业。
2. 最小启动重复三次；HOME/cat 读写、工作目录、日志路径、默认/显式许可、batch/srun、数组并发 1/2/4。
3. 1/2/4 GPU、CPU/内存配额、独占与非独占、任务参数及提交方式对照。
4. 独立环境的 CUDA 初始化、物理 GPU UUID 绑定、单卡及四卡短训练。
5. 自带模型每卡 1/2/3/4，逐档通过后测试 8/12 进程；单独对照 MPS、线程和 DataLoader workers，并对候选至少持续测试一小时。
6. 独立文件、原子替换、带锁 JSONL、重复启动/跳过/锁；合成数据准备、训练、验证、checkpoint 恢复和汇总流程。

采集本轮请求/实际资源、分层时间线、每个子进程退出码，以及 GPU、CPU、主机内存和吞吐。最小启动或文件系统测试未通过时，停止后续训练。**结论只适用于本工具的合成负载。**

## 输出在哪里

- **HOME：** `$HOME/capella-audit/<运行编号>/`，保存配置、准确提交命令、作业日志、采样、`results.json`、`results.csv`、`REPORT.md`、候选模板和支持取证草稿。
- **cat：** 启动时打印的 `CAT_DIR`，保存本轮数据、缓存、I/O 文件和 checkpoint；为专用新 workspace，默认 3 天到期。
- **诊断包：** `$HOME/capella-audit/<运行编号>.tar.gz`，自动打包日志和结果，不包含 venv、缓存及模型权重。

断开 SSH 后结果保留。无需手工逐项提交；本地交付没有向 Capella 提交作业。
