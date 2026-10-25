# Capella audit 20261024T125511Z-cb94c9e3

Generated 2026-10-25T05:52:49.835654+00:00 (all raw times UTC).

## 实际覆盖范围

Cases={'PASS': 174, 'SKIPPED': 112, 'NO_RESOURCES': 2}; allocated=174; nodes=['c10', 'c100', 'c102', 'c104', 'c105', 'c112', 'c126', 'c129', 'c131', 'c136', 'c15', 'c153', 'c155', 'c156', 'c16', 'c19', 'c20', 'c22', 'c28', 'c31', 'c34', 'c35', 'c44', 'c46', 'c5', 'c51', 'c61', 'c65', 'c73', 'c75', 'c84', 'c95', 'c96']; kinds={'fs': 19, 'smoke': 2, 'train': 149, 'io': 1, 'pipeline': 3}.
完整日志包不等于所有计划测试通过；排队超时、提交前拒绝和未执行配置均保持未验证。
单卡与四卡环境分别判断；单卡通过足以继续每卡进程数和 worker 测试。
完整覆盖和节点缺项见 coverage.json；实际请求、分配与阶段见 results.csv。

## 已证实原因

以下只证明对应测试的失败事件，底层根因需结合对照和服务端日志。
无已证实失败原因；未执行不等于通过。

## 相关线索

|实验|结果|最后到达层|节点|作业|
|---|---|---|---|---|
|f2-auto-baseline-r1|PASS|exit|c104|4461972|
|f2-auto-baseline-r2|PASS|exit|c104|4461974|
|f2-auto-baseline-r3|PASS|exit|c104|4461976|
|f2-c59-default-r1|SKIPPED||||
|f2-c59-cat-r1|SKIPPED||||
|f2-c59-all-r1|SKIPPED||||
|f2-c59-touch-r1|SKIPPED||||
|f2-c59-cat-cwd-r1|SKIPPED||||
|f2-c59-alias-cwd-r1|SKIPPED||||
|f2-c59-cat-log-r1|SKIPPED||||
|f2-c59-ntpn-r1|SKIPPED||||
|f2-c59-ntpn-r2|SKIPPED||||
|f2-c59-cat-log-r2|SKIPPED||||
|f2-c59-alias-cwd-r2|SKIPPED||||
|f2-c59-cat-cwd-r2|SKIPPED||||
|f2-c59-touch-r2|SKIPPED||||
|f2-c59-all-r2|SKIPPED||||
|f2-c59-cat-r2|SKIPPED||||
|f2-c59-default-r2|SKIPPED||||
|f2-c23-default-r1|SKIPPED||||
|f2-c23-cat-r1|SKIPPED||||
|f2-c23-all-r1|SKIPPED||||
|f2-c23-touch-r1|SKIPPED||||
|f2-c23-cat-cwd-r1|SKIPPED||||
|f2-c23-alias-cwd-r1|SKIPPED||||
|f2-c23-cat-log-r1|SKIPPED||||
|f2-c23-ntpn-r1|SKIPPED||||
|f2-c23-ntpn-r2|SKIPPED||||
|f2-c23-cat-log-r2|SKIPPED||||
|f2-c23-alias-cwd-r2|SKIPPED||||
|f2-c23-cat-cwd-r2|SKIPPED||||
|f2-c23-touch-r2|SKIPPED||||
|f2-c23-all-r2|SKIPPED||||
|f2-c23-cat-r2|SKIPPED||||
|f2-c23-default-r2|SKIPPED||||
|f2-c104-default-r1|PASS|exit|c104|4461978|
|f2-c104-cat-r1|PASS|exit|c104|4461980|
|f2-c104-all-r1|PASS|exit|c104|4461983|
|f2-c104-touch-r1|PASS|exit|c104|4461986|
|f2-c104-cat-cwd-r1|PASS|exit|c104|4461992|
|f2-c104-alias-cwd-r1|PASS|exit|c104|4461996|
|f2-c104-cat-log-r1|PASS|exit|c104|4461998|
|f2-c104-ntpn-r1|PASS|exit|c104|4462000|
|f2-c104-ntpn-r2|PASS|exit|c104|4462002|
|f2-c104-cat-log-r2|PASS|exit|c104|4462004|
|f2-c104-alias-cwd-r2|PASS|exit|c104|4462006|
|f2-c104-cat-cwd-r2|PASS|exit|c104|4462074|
|f2-c104-touch-r2|PASS|exit|c104|4462077|
|f2-c104-all-r2|PASS|exit|c104|4462098|
|f2-c104-cat-r2|PASS|exit|c104|4462101|
|f2-c104-default-r2|PASS|exit|c104|4462105|
|f2-c34-default-r1|SKIPPED||||
|f2-c34-cat-r1|SKIPPED||||
|f2-c34-all-r1|SKIPPED||||
|f2-c34-touch-r1|SKIPPED||||
|f2-c34-cat-cwd-r1|SKIPPED||||
|f2-c34-alias-cwd-r1|SKIPPED||||
|f2-c34-cat-log-r1|SKIPPED||||
|f2-c34-ntpn-r1|SKIPPED||||
|f2-c34-ntpn-r2|SKIPPED||||
|f2-c34-cat-log-r2|SKIPPED||||
|f2-c34-alias-cwd-r2|SKIPPED||||
|f2-c34-cat-cwd-r2|SKIPPED||||
|f2-c34-touch-r2|SKIPPED||||
|f2-c34-all-r2|SKIPPED||||
|f2-c34-cat-r2|SKIPPED||||
|f2-c34-default-r2|SKIPPED||||
|f2-c5-default-r1|SKIPPED||||
|f2-c5-cat-r1|SKIPPED||||
|f2-c5-all-r1|SKIPPED||||
|f2-c5-touch-r1|SKIPPED||||
|f2-c5-cat-cwd-r1|SKIPPED||||
|f2-c5-alias-cwd-r1|SKIPPED||||
|f2-c5-cat-log-r1|SKIPPED||||
|f2-c5-ntpn-r1|SKIPPED||||
|f2-c5-ntpn-r2|SKIPPED||||
|f2-c5-cat-log-r2|SKIPPED||||
|f2-c5-alias-cwd-r2|SKIPPED||||
|f2-c5-cat-cwd-r2|SKIPPED||||
|f2-c5-touch-r2|SKIPPED||||
|f2-c5-all-r2|SKIPPED||||
|f2-c5-cat-r2|SKIPPED||||
|f2-c5-default-r2|SKIPPED||||
|f2-c134-default-r1|SKIPPED||||
|f2-c134-cat-r1|SKIPPED||||
|f2-c134-all-r1|SKIPPED||||
|f2-c134-touch-r1|SKIPPED||||
|f2-c134-cat-cwd-r1|SKIPPED||||
|f2-c134-alias-cwd-r1|SKIPPED||||
|f2-c134-cat-log-r1|SKIPPED||||
|f2-c134-ntpn-r1|SKIPPED||||
|f2-c134-ntpn-r2|SKIPPED||||
|f2-c134-cat-log-r2|SKIPPED||||
|f2-c134-alias-cwd-r2|SKIPPED||||
|f2-c134-cat-cwd-r2|SKIPPED||||
|f2-c134-touch-r2|SKIPPED||||
|f2-c134-all-r2|SKIPPED||||
|f2-c134-cat-r2|SKIPPED||||
|f2-c134-default-r2|SKIPPED||||
|f2-c130-default-r1|SKIPPED||||
|f2-c130-cat-r1|SKIPPED||||
|f2-c130-all-r1|SKIPPED||||
|f2-c130-touch-r1|SKIPPED||||
|f2-c130-cat-cwd-r1|SKIPPED||||
|f2-c130-alias-cwd-r1|SKIPPED||||
|f2-c130-cat-log-r1|SKIPPED||||
|f2-c130-ntpn-r1|SKIPPED||||
|f2-c130-ntpn-r2|SKIPPED||||
|f2-c130-cat-log-r2|SKIPPED||||
|f2-c130-alias-cwd-r2|SKIPPED||||
|f2-c130-cat-cwd-r2|SKIPPED||||
|f2-c130-touch-r2|SKIPPED||||
|f2-c130-all-r2|SKIPPED||||
|f2-c130-cat-r2|SKIPPED||||
|f2-c130-default-r2|SKIPPED||||
|f2-c81-default-r1|SKIPPED||||
|f2-c81-cat-r1|SKIPPED||||
|f2-c81-all-r1|SKIPPED||||
|f2-c81-touch-r1|SKIPPED||||
|f2-c81-cat-cwd-r1|SKIPPED||||
|f2-c81-alias-cwd-r1|SKIPPED||||
|f2-c81-cat-log-r1|SKIPPED||||
|f2-c81-ntpn-r1|SKIPPED||||
|f2-c81-ntpn-r2|SKIPPED||||
|f2-c81-cat-log-r2|SKIPPED||||
|f2-c81-alias-cwd-r2|SKIPPED||||
|f2-c81-cat-cwd-r2|SKIPPED||||
|f2-c81-touch-r2|SKIPPED||||
|f2-c81-all-r2|SKIPPED||||
|f2-c81-cat-r2|SKIPPED||||
|f2-c81-default-r2|SKIPPED||||
|p4-own-1gpu|PASS|exit|c44|4462127|
|p4-own-4gpu|PASS|exit|c105|4462138|
|f4-workers0-r1|PASS|exit|c156|4462214|
|f4-workers0-r2|PASS|exit|c156|4462224|
|f4-workers1-r1|PASS|exit|c156|4462229|
|f4-workers1-r2|PASS|exit|c156|4462233|
|f4-workers2-r1|PASS|exit|c20|4462245|
|f4-workers2-r2|PASS|exit|c20|4462254|
|f5-jobs1-r1-0|PASS|exit|c105|4462259|
|f5-jobs2-r1-0|PASS|exit|c105|4462268|
|f5-jobs2-r1-1|PASS|exit|c10|4462270|
|f5-jobs4-r1-0|PASS|exit|c105|4462282|
|f5-jobs4-r1-1|PASS|exit|c153|4462284|
|f5-jobs4-r1-2|PASS|exit|c10|4462286|
|f5-jobs4-r1-3|PASS|exit|c100|4462288|
|f5-one-four-r1|PASS|exit|c105|4462294|
|f5-jobs1-r2-0|PASS|exit|c20|4462310|
|f5-jobs2-r2-0|PASS|exit|c20|4462318|
|f5-jobs2-r2-1|PASS|exit|c104|4462320|
|f5-jobs4-r2-0|PASS|exit|c20|4462329|
|f5-jobs4-r2-1|PASS|exit|c20|4462331|
|f5-jobs4-r2-2|PASS|exit|c104|4462333|
|f5-jobs4-r2-3|PASS|exit|c104|4462335|
|f5-one-four-r2|PASS|exit|c105|4462341|
|p5-S-n1-off-r1|PASS|exit|c20|4462391|
|p5-S-n1-off-r2|PASS|exit|c84|4462398|
|p5-S-n1-on-r1|PASS|exit|c84|4462418|
|p5-S-n1-on-r2|PASS|exit|c84|4462421|
|p5-S-n2-off-r1|PASS|exit|c84|4462433|
|p5-S-n2-off-r2|PASS|exit|c84|4462447|
|p5-S-n2-on-r1|PASS|exit|c84|4462451|
|p5-S-n2-on-r2|PASS|exit|c84|4462457|
|p5-S-n3-off-r1|PASS|exit|c84|4462460|
|p5-S-n3-off-r2|PASS|exit|c84|4462465|
|p5-S-n3-on-r1|PASS|exit|c20|4462468|
|p5-S-n3-on-r2|PASS|exit|c20|4462471|
|p5-S-n4-off-r1|PASS|exit|c20|4462473|
|p5-S-n4-off-r2|PASS|exit|c20|4462475|
|p5-S-n4-on-r1|PASS|exit|c20|4462482|
|p5-S-n4-on-r2|PASS|exit|c20|4462506|
|p5-S-n8-off-r1|PASS|exit|c20|4462511|
|p5-S-n8-off-r2|PASS|exit|c20|4462516|
|p5-S-n8-on-r1|PASS|exit|c20|4462518|
|p5-S-n8-on-r2|PASS|exit|c20|4462521|
|p5-S-n12-off-r1|PASS|exit|c20|4462543|
|p5-S-n12-off-r2|PASS|exit|c20|4462546|
|p5-S-n12-on-r1|PASS|exit|c20|4462552|
|p5-S-n12-on-r2|PASS|exit|c20|4462555|
|p5-S-tune-threads2-r1|PASS|exit|c20|4462558|
|p5-S-tune-threads2-r2|PASS|exit|c10|4462562|
|p5-S-tune-workers1-r1|PASS|exit|c10|4462612|
|p5-S-tune-workers1-r2|PASS|exit|c10|4462616|
|p5-S-tune-workers2-r1|PASS|exit|c104|4462618|
|p5-S-tune-workers2-r2|PASS|exit|c46|4462624|
|p5-S-stable-long|PASS|exit|c104|4462630|
|p5-S-throughput-long|PASS|exit|c104|4462818|
|p5-M-n1-off-r1|PASS|exit|c104|4462892|
|p5-M-n1-off-r2|PASS|exit|c104|4462894|
|p5-M-n1-on-r1|PASS|exit|c20|4462910|
|p5-M-n1-on-r2|PASS|exit|c20|4462915|
|p5-M-n2-off-r1|PASS|exit|c20|4462919|
|p5-M-n2-off-r2|PASS|exit|c20|4462922|
|p5-M-n2-on-r1|PASS|exit|c16|4462928|
|p5-M-n2-on-r2|PASS|exit|c104|4462933|
|p5-M-n3-off-r1|PASS|exit|c104|4462939|
|p5-M-n3-off-r2|PASS|exit|c104|4462949|
|p5-M-n3-on-r1|PASS|exit|c104|4462956|
|p5-M-n3-on-r2|PASS|exit|c20|4462959|
|p5-M-n4-off-r1|PASS|exit|c28|4462965|
|p5-M-n4-off-r2|PASS|exit|c28|4462979|
|p5-M-n4-on-r1|PASS|exit|c95|4462994|
|p5-M-n4-on-r2|PASS|exit|c95|4463010|
|p5-M-n8-off-r1|PASS|exit|c155|4463023|
|p5-M-n8-off-r2|PASS|exit|c155|4463036|
|p5-M-n8-on-r1|PASS|exit|c73|4463051|
|p5-M-n8-on-r2|PASS|exit|c84|4463064|
|p5-M-n12-off-r1|PASS|exit|c20|4463085|
|p5-M-n12-off-r2|PASS|exit|c16|4463095|
|p5-M-n12-on-r1|PASS|exit|c16|4463110|
|p5-M-n12-on-r2|PASS|exit|c155|4463126|
|p5-M-tune-threads2-r1|PASS|exit|c155|4463133|
|p5-M-tune-threads2-r2|PASS|exit|c35|4463143|
|p5-M-tune-workers1-r1|PASS|exit|c35|4463151|
|p5-M-tune-workers1-r2|PASS|exit|c51|4463160|
|p5-M-tune-workers2-r1|PASS|exit|c102|4463171|
|p5-M-tune-workers2-r2|PASS|exit|c102|4463189|
|p5-M-stable-long|PASS|exit|c75|4463205|
|p5-M-throughput-long|PASS|exit|c75|4463566|
|p5-L-n1-off-r1|PASS|exit|c20|4463857|
|p5-L-n1-off-r2|PASS|exit|c20|4463860|
|p5-L-n1-on-r1|PASS|exit|c20|4463868|
|p5-L-n1-on-r2|PASS|exit|c20|4463874|
|p5-L-n2-off-r1|PASS|exit|c20|4463877|
|p5-L-n2-off-r2|PASS|exit|c104|4463888|
|p5-L-n2-on-r1|PASS|exit|c104|4463892|
|p5-L-n2-on-r2|PASS|exit|c31|4463895|
|p5-L-n3-off-r1|PASS|exit|c16|4463902|
|p5-L-n3-off-r2|PASS|exit|c16|4463907|
|p5-L-n3-on-r1|PASS|exit|c16|4463910|
|p5-L-n3-on-r2|PASS|exit|c61|4463917|
|p5-L-n4-off-r1|PASS|exit|c61|4463952|
|p5-L-n4-off-r2|PASS|exit|c61|4463959|
|p5-L-n4-on-r1|PASS|exit|c61|4463966|
|p5-L-n4-on-r2|PASS|exit|c61|4463973|
|p5-L-n8-off-r1|PASS|exit|c61|4463976|
|p5-L-n8-off-r2|PASS|exit|c126|4464008|
|p5-L-n8-on-r1|PASS|exit|c153|4464011|
|p5-L-n8-on-r2|PASS|exit|c96|4464018|
|p5-L-n12-off-r1|PASS|exit|c16|4464025|
|p5-L-n12-off-r2|PASS|exit|c19|4464028|
|p5-L-n12-on-r1|PASS|exit|c19|4464032|
|p5-L-n12-on-r2|PASS|exit|c19|4464035|
|p5-L-tune-threads2-r1|PASS|exit|c153|4464045|
|p5-L-tune-threads2-r2|PASS|exit|c136|4464047|
|p5-L-tune-workers1-r1|PASS|exit|c136|4464050|
|p5-L-tune-workers1-r2|PASS|exit|c16|4464053|
|p5-L-tune-workers2-r1|PASS|exit|c22|4464057|
|p5-L-tune-workers2-r2|PASS|exit|c28|4464084|
|p5-L-stable-long|PASS|exit|c5|4464086|
|p5-L-throughput-long|PASS|exit|c5|4464134|
|f5-ballast1024-n1-r1|PASS|exit|c15|4464184|
|f5-ballast1024-n1-r2|PASS|exit|c112|4464186|
|f5-ballast1024-n2-r1|PASS|exit|c100|4464194|
|f5-ballast1024-n2-r2|PASS|exit|c15|4464198|
|f5-ballast1024-n3-r1|PASS|exit|c15|4464207|
|f5-ballast1024-n3-r2|PASS|exit|c15|4464210|
|f5-ballast1024-n4-r1|PASS|exit|c15|4464224|
|f5-ballast1024-n4-r2|PASS|exit|c96|4464226|
|f5-ballast1024-n8-r1|PASS|exit|c15|4464236|
|f5-ballast1024-n8-r2|PASS|exit|c15|4464238|
|f5-ballast1024-n12-r1|PASS|exit|c15|4464243|
|f5-ballast1024-n12-r2|PASS|exit|c15|4464250|
|f5-ballast4096-n1-r1|PASS|exit|c15|4464257|
|f5-ballast4096-n1-r2|PASS|exit|c15|4464263|
|f5-ballast4096-n2-r1|PASS|exit|c131|4464269|
|f5-ballast4096-n2-r2|PASS|exit|c131|4464274|
|f5-ballast4096-n3-r1|PASS|exit|c34|4464276|
|f5-ballast4096-n3-r2|PASS|exit|c100|4464279|
|f5-ballast4096-n4-r1|PASS|exit|c100|4464281|
|f5-ballast4096-n4-r2|PASS|exit|c100|4464283|
|f5-ballast4096-n8-r1|PASS|exit|c100|4464288|
|f5-ballast4096-n8-r2|PASS|exit|c100|4464300|
|f5-ballast4096-n12-r1|PASS|exit|c15|4464308|
|f5-ballast4096-n12-r2|PASS|exit|c15|4464315|
|p6-io|PASS|exit|c65|4464327|
|f6-S-four-n1-r1|PASS|exit|c15|4464331|
|f6-S-four-n1-r2|PASS|exit|c15|4464464|
|f6-S-four-n12-r1|NO_RESOURCES|queue|None assigned|4464470|
|f6-S-four-n12-r2|PASS|exit|c15|4464548|
|f6-S-local-pipeline|PASS|exit|c15|4464619|
|f6-S-cat-pipeline|NO_RESOURCES|queue|None assigned|4464707|
|f6-L-four-n1-r1|PASS|exit|c100|4464737|
|f6-L-four-n1-r2|PASS|exit|c100|4464787|
|f6-L-four-n4-r1|PASS|exit|c100|4464792|
|f6-L-four-n4-r2|PASS|exit|c129|4464800|
|f6-L-local-pipeline|PASS|exit|c129|4464805|
|f6-L-cat-pipeline|PASS|exit|c129|4464854|

## 尚未验证

无 batch 首条标记只能定位到 batch 正文之前，不能区分 chdir、日志打开、prolog 或服务端故障。
默认 license 自动包含全部文件系统；license 与挂载可见性分别核对。SKIP 不等于崩溃。
全部结果仅适用于本工具自带的合成模型和数据；未运行的对照保持未知。
MaxRSS 可能只在 step 有值，空值不是零；cgroup 与采样也可能遗漏峰值。

## 推荐配置

只输出重复短测、至少一小时持续测试且保留配置余量的候选。吞吐最高指已测试配置中的结果。
- 单卡 S/stable: n=1, MPS=False, threads=1, workers=0; short throughput=44952.356 items/s; GPU peak fraction=0.009; host=0.004; long_pass=True
  一小时实测（含启动开销的总吞吐、采样和余量）：{"case": "p5-S-stable-long", "model": "S", "n": 1, "mps": false, "threads": 1, "workers": 0, "seconds": 3600, "throughput": 43367.729200827176, "gpu_fraction": 0.008942919753730565, "host_fraction": 0.004621526930067274, "samples": 721, "safe": true, "host_oom_observed": false, "requested_gpu_hours": 1.0833333333333333, "gpus": 1, "storage": "local", "ballast_mib": 0, "nodes": ["c104"], "workload": {"model_id": "cnn-8x2-v1", "data_id": "random512x3x32x32-seed20261022-v1", "batch_size": 64, "precision": "fp32"}, "observed_gpu_hours": 1.0047222222222223, "queue_seconds": 14.0, "items_per_gpu_hour": 155609433.67431572, "mean_cpu_percent": 99.62072716443603, "cpu_fraction": 0.07115766226031145, "affinity_cpus": 14, "effective_cpu_capacity": 14, "max_threads": 6, "max_rss_sum_kib": 1214192, "mean_gpu_utilization": 24.615811373092928, "mean_gpu_power_watts": 143.2014979195561, "child_speeds": [43428.950676998626]}
- 单卡 S/throughput: n=12, MPS=True, threads=1, workers=0; short throughput=416025.980 items/s; GPU peak fraction=0.107; host=0.049; long_pass=True
  一小时实测（含启动开销的总吞吐、采样和余量）：{"case": "p5-S-throughput-long", "model": "S", "n": 12, "mps": true, "threads": 1, "workers": 0, "seconds": 3600, "throughput": 364436.725863419, "gpu_fraction": 0.10692893665866639, "host_fraction": 0.04719367557101779, "samples": 723, "safe": true, "host_oom_observed": false, "requested_gpu_hours": 1.0833333333333333, "gpus": 1, "storage": "local", "ballast_mib": 0, "nodes": ["c104"], "workload": {"model_id": "cnn-8x2-v1", "data_id": "random512x3x32x32-seed20261022-v1", "batch_size": 64, "precision": "fp32"}, "observed_gpu_hours": 1.0069444444444444, "queue_seconds": 1.0, "items_per_gpu_hour": 1308191306.151724, "mean_cpu_percent": 1156.8059942760287, "cpu_fraction": 0.8262899959114491, "affinity_cpus": 14, "effective_cpu_capacity": 14, "max_threads": 50, "max_rss_sum_kib": 13052520, "mean_gpu_utilization": 90.37206085753803, "mean_gpu_power_watts": 302.07788381742733, "child_speeds": [30961.04382327503, 30336.787524105675, 30315.496886467452, 30528.079782540717, 30253.150355358364, 30350.231487906603, 30204.255137719254, 30640.34663558895, 30761.03617392569, 30703.188004366824, 30412.027455531654, 30444.23470165569]}
- 单卡 M/stable: n=1, MPS=False, threads=1, workers=0; short throughput=35166.622 items/s; GPU peak fraction=0.010; host=0.004; long_pass=True
  一小时实测（含启动开销的总吞吐、采样和余量）：{"case": "p5-M-stable-long", "model": "M", "n": 1, "mps": false, "threads": 1, "workers": 0, "seconds": 3600, "throughput": 33183.86833064607, "gpu_fraction": 0.009506417614525723, "host_fraction": 0.006597476535373264, "samples": 721, "safe": true, "host_oom_observed": false, "requested_gpu_hours": 1.0833333333333333, "gpus": 1, "storage": "local", "ballast_mib": 0, "nodes": ["c75"], "workload": {"model_id": "cnn-32x4-v1", "data_id": "random512x3x32x32-seed20261022-v1", "batch_size": 64, "precision": "fp32"}, "observed_gpu_hours": 1.005, "queue_seconds": 11.0, "items_per_gpu_hour": 119119920.39800996, "mean_cpu_percent": 99.83335339089619, "cpu_fraction": 0.07130953813635442, "affinity_cpus": 14, "effective_cpu_capacity": 14, "max_threads": 6, "max_rss_sum_kib": 1146988, "mean_gpu_utilization": 45.3869625520111, "mean_gpu_power_watts": 204.98751733703213, "child_speeds": [33254.30287563653]}
- 单卡 M/throughput: n=8, MPS=True, threads=2, workers=0; short throughput=116209.224 items/s; GPU peak fraction=0.076; host=0.031; long_pass=False
  一小时实测（含启动开销的总吞吐、采样和余量）：{"case": "p5-M-throughput-long", "model": "M", "n": 8, "mps": true, "threads": 2, "workers": 0, "seconds": 3600, "throughput": 116374.01737495314, "gpu_fraction": 0.07606177606177607, "host_fraction": 0.03132612440321181, "samples": 722, "safe": false, "host_oom_observed": false, "requested_gpu_hours": 1.0833333333333333, "gpus": 1, "storage": "local", "ballast_mib": 0, "nodes": ["c75"], "workload": {"model_id": "cnn-32x4-v1", "data_id": "random512x3x32x32-seed20261022-v1", "batch_size": 64, "precision": "fp32"}, "observed_gpu_hours": 1.0055555555555555, "queue_seconds": 9.0, "items_per_gpu_hour": 417825244.640884, "mean_cpu_percent": 1343.5792966643287, "cpu_fraction": 0.9596994976173776, "affinity_cpus": 14, "effective_cpu_capacity": 14, "max_threads": 50, "max_rss_sum_kib": 8635260, "mean_gpu_utilization": 97.70914127423822, "mean_gpu_power_watts": 504.6929916897503, "child_speeds": [14699.126311740096, 14393.735680417361, 14577.6629889474, 14911.069084830882, 14441.469956998812, 14978.711684147955, 14227.53580760793, 14478.00284104106]}
- 单卡 L/stable: n=1, MPS=False, threads=1, workers=0; short throughput=28413.258 items/s; GPU peak fraction=0.011; host=0.004; long_pass=True
  一小时实测（含启动开销的总吞吐、采样和余量）：{"case": "p5-L-stable-long", "model": "L", "n": 1, "mps": false, "threads": 1, "workers": 0, "seconds": 3600, "throughput": 22576.51577549696, "gpu_fraction": 0.010904727120943336, "host_fraction": 0.0067757288614908855, "samples": 721, "safe": true, "host_oom_observed": false, "requested_gpu_hours": 1.0833333333333333, "gpus": 1, "storage": "local", "ballast_mib": 0, "nodes": ["c5"], "workload": {"model_id": "cnn-64x6-v1", "data_id": "random512x3x32x32-seed20261022-v1", "batch_size": 64, "precision": "fp32"}, "observed_gpu_hours": 1.005, "queue_seconds": 2.0, "items_per_gpu_hour": 81064119.40298508, "mean_cpu_percent": 99.77882844870756, "cpu_fraction": 0.07127059174907682, "affinity_cpus": 14, "effective_cpu_capacity": 14, "max_threads": 6, "max_rss_sum_kib": 1170264, "mean_gpu_utilization": 64.31900138696255, "mean_gpu_power_watts": 287.6909847434116, "child_speeds": [22630.3951206981]}
- 单卡 L/throughput: n=4, MPS=True, threads=1, workers=0; short throughput=39282.328 items/s; GPU peak fraction=0.044; host=0.016; long_pass=True
  一小时实测（含启动开销的总吞吐、采样和余量）：{"case": "p5-L-throughput-long", "model": "L", "n": 4, "mps": true, "threads": 1, "workers": 0, "seconds": 3600, "throughput": 40026.02292706247, "gpu_fraction": 0.044005008869873734, "host_fraction": 0.017812432183159723, "samples": 721, "safe": true, "host_oom_observed": false, "requested_gpu_hours": 1.0833333333333333, "gpus": 1, "storage": "local", "ballast_mib": 0, "nodes": ["c5"], "workload": {"model_id": "cnn-64x6-v1", "data_id": "random512x3x32x32-seed20261022-v1", "batch_size": 64, "precision": "fp32"}, "observed_gpu_hours": 1.0044444444444445, "queue_seconds": 12.0, "items_per_gpu_hour": 143803306.19469026, "mean_cpu_percent": 394.37552338774833, "cpu_fraction": 0.28169680241982026, "affinity_cpus": 14, "effective_cpu_capacity": 14, "max_threads": 18, "max_rss_sum_kib": 4693496, "mean_gpu_utilization": 96.998613037448, "mean_gpu_power_watts": 469.3962413314842, "child_speeds": [10023.247464064818, 10028.524318389178, 10055.087611779005, 10015.999985252507]}

## 四卡与存储对照

{
  "S": {
    "n": 1,
    "short": [
      {
        "case": "f6-S-four-n1-r1",
        "model": "S",
        "n": 1,
        "mps": true,
        "threads": 1,
        "workers": 0,
        "seconds": 90,
        "throughput": 157882.9605004751,
        "gpu_fraction": 0.009652509652509652,
        "host_fraction": 0.004841188703264509,
        "samples": 22,
        "safe": true,
        "host_oom_observed": false,
        "requested_gpu_hours": 0.4666666666666667,
        "gpus": 4,
        "storage": "local",
        "ballast_mib": 0,
        "nodes": [
          "c15"
        ],
        "workload": {
          "model_id": "cnn-8x2-v1",
          "data_id": "random512x3x32x32-seed20261022-v1",
          "batch_size": 64,
          "precision": "fp32"
        },
        "observed_gpu_hours": 0.20222222222222222,
        "queue_seconds": 1371.0,
        "items_per_gpu_hour": 82747463.73626374,
        "mean_cpu_percent": 348.700273140582,
        "cpu_fraction": 0.062267905917961074,
        "affinity_cpus": 56,
        "effective_cpu_capacity": 56,
        "max_threads": 18,
        "max_rss_sum_kib": 4349840,
        "mean_gpu_utilization": 20.40909090909091,
        "mean_gpu_power_watts": 136.385,
        "child_speeds": [
          47069.74340985149,
          46202.032629391404,
          46452.41118168122,
          46200.83085264951
        ]
      },
      {
        "case": "f6-S-four-n1-r2",
        "model": "S",
        "n": 1,
        "mps": true,
        "threads": 1,
        "workers": 0,
        "seconds": 90,
        "throughput": 157167.82973144046,
        "gpu_fraction": 0.009652509652509652,
        "host_fraction": 0.004822033473423549,
        "samples": 22,
        "safe": true,
        "host_oom_observed": false,
        "requested_gpu_hours": 0.4666666666666667,
        "gpus": 4,
        "storage": "local",
        "ballast_mib": 0,
        "nodes": [
          "c15"
        ],
        "workload": {
          "model_id": "cnn-8x2-v1",
          "data_id": "random512x3x32x32-seed20261022-v1",
          "batch_size": 64,
          "precision": "fp32"
        },
        "observed_gpu_hours": 0.1411111111111111,
        "queue_seconds": 11.0,
        "items_per_gpu_hour": 117804245.66929135,
        "mean_cpu_percent": 349.7088036622246,
        "cpu_fraction": 0.06244800065396868,
        "affinity_cpus": 56,
        "effective_cpu_capacity": 56,
        "max_threads": 18,
        "max_rss_sum_kib": 4346624,
        "mean_gpu_utilization": 20.568181818181817,
        "mean_gpu_power_watts": 136.02306818181816,
        "child_speeds": [
          46500.489934421836,
          45927.587739427705,
          47057.702710510115,
          45217.97759560712
        ]
      }
    ],
    "long": {
      "local": {
        "case": "f6-S-local-pipeline",
        "verified": true,
        "measurements": [
          {
            "case": "f6-S-local-pipeline",
            "model": "S",
            "n": 1,
            "mps": true,
            "threads": 1,
            "workers": 0,
            "seconds": 3600,
            "throughput": 173965.35409651668,
            "gpu_fraction": 0.009652509652509652,
            "host_fraction": 0.005205486842564174,
            "samples": 723,
            "safe": true,
            "host_oom_observed": false,
            "requested_gpu_hours": 4.333333333333333,
            "gpus": 4,
            "storage": "local",
            "ballast_mib": 0,
            "nodes": [
              "c15"
            ],
            "workload": {
              "model_id": "cnn-8x2-v1",
              "data_id": "random512x3x32x32-seed20261022-v1",
              "batch_size": 64,
              "precision": "fp32"
            },
            "observed_gpu_hours": 4.042222222222223,
            "queue_seconds": 12.0,
            "items_per_gpu_hour": 155634503.35349092,
            "mean_cpu_percent": 396.61864082789936,
            "cpu_fraction": 0.07082475729069632,
            "affinity_cpus": 56,
            "effective_cpu_capacity": 56,
            "max_threads": 18,
            "max_rss_sum_kib": 4616108,
            "mean_gpu_utilization": 25.51936376210235,
            "mean_gpu_power_watts": 143.46603042876887,
            "child_speeds": [
              44632.2976063626,
              43411.832542438526,
              43261.28932378891,
              43447.12732164238
            ]
          }
        ]
      },
      "cat": {
        "case": "f6-S-cat-pipeline",
        "verified": false,
        "measurements": []
      }
    }
  },
  "L": {
    "n": 4,
    "short": [
      {
        "case": "f6-L-four-n4-r1",
        "model": "L",
        "n": 4,
        "mps": true,
        "threads": 1,
        "workers": 0,
        "seconds": 90,
        "throughput": 126098.16550534102,
        "gpu_fraction": 0.043942397996452054,
        "host_fraction": 0.017182846069335938,
        "samples": 24,
        "safe": true,
        "host_oom_observed": false,
        "requested_gpu_hours": 0.4666666666666667,
        "gpus": 4,
        "storage": "local",
        "ballast_mib": 0,
        "nodes": [
          "c100"
        ],
        "workload": {
          "model_id": "cnn-64x6-v1",
          "data_id": "random512x3x32x32-seed20261022-v1",
          "batch_size": 64,
          "precision": "fp32"
        },
        "observed_gpu_hours": 0.1511111111111111,
        "queue_seconds": 6.0,
        "items_per_gpu_hour": 101703388.23529412,
        "mean_cpu_percent": 1218.4104277247409,
        "cpu_fraction": 0.2175732906651323,
        "affinity_cpus": 56,
        "effective_cpu_capacity": 56,
        "max_threads": 66,
        "max_rss_sum_kib": 17308772,
        "mean_gpu_utilization": 74.79166666666667,
        "mean_gpu_power_watts": 400.2932291666666,
        "child_speeds": [
          10633.633536523252,
          10703.556961776958,
          10719.538800179549,
          10646.614884360355,
          10645.363334577762,
          10725.580416928,
          10673.364614320371,
          10636.639932395034,
          10659.407929483554,
          10779.852813423004,
          10677.170885774933,
          10661.016090641942,
          10633.965788363996,
          10644.956301042943,
          10650.14780260519,
          10661.138334432346
        ]
      },
      {
        "case": "f6-L-four-n4-r2",
        "model": "L",
        "n": 4,
        "mps": true,
        "threads": 1,
        "workers": 0,
        "seconds": 90,
        "throughput": 126315.82883748949,
        "gpu_fraction": 0.043942397996452054,
        "host_fraction": 0.017183974129813057,
        "samples": 24,
        "safe": true,
        "host_oom_observed": false,
        "requested_gpu_hours": 0.4666666666666667,
        "gpus": 4,
        "storage": "local",
        "ballast_mib": 0,
        "nodes": [
          "c129"
        ],
        "workload": {
          "model_id": "cnn-64x6-v1",
          "data_id": "random512x3x32x32-seed20261022-v1",
          "batch_size": 64,
          "precision": "fp32"
        },
        "observed_gpu_hours": 0.25222222222222224,
        "queue_seconds": 73.0,
        "items_per_gpu_hour": 61020983.25991189,
        "mean_cpu_percent": 1214.3479492191916,
        "cpu_fraction": 0.21684784807485563,
        "affinity_cpus": 56,
        "effective_cpu_capacity": 56,
        "max_threads": 66,
        "max_rss_sum_kib": 17305896,
        "mean_gpu_utilization": 74.94791666666667,
        "mean_gpu_power_watts": 407.2126041666666,
        "child_speeds": [
          10655.625964440265,
          10667.01978145826,
          10701.92565842594,
          10691.152695576055,
          10639.271525566553,
          10659.78811004307,
          10725.120646853926,
          10698.624156587708,
          10696.130793249651,
          10717.55217402722,
          10717.392965401727,
          10701.474471680196,
          10697.082119788569,
          10696.258515311767,
          10671.150454722054,
          10666.57292144348
        ]
      }
    ],
    "long": {
      "local": {
        "case": "f6-L-local-pipeline",
        "verified": true,
        "measurements": [
          {
            "case": "f6-L-local-pipeline",
            "model": "L",
            "n": 4,
            "mps": true,
            "threads": 1,
            "workers": 0,
            "seconds": 3600,
            "throughput": 159572.41646507828,
            "gpu_fraction": 0.044025879161014296,
            "host_fraction": 0.01732088361467634,
            "samples": 726,
            "safe": true,
            "host_oom_observed": false,
            "requested_gpu_hours": 4.333333333333333,
            "gpus": 4,
            "storage": "local",
            "ballast_mib": 0,
            "nodes": [
              "c129"
            ],
            "workload": {
              "model_id": "cnn-64x6-v1",
              "data_id": "random512x3x32x32-seed20261022-v1",
              "batch_size": 64,
              "precision": "fp32"
            },
            "observed_gpu_hours": 4.054444444444444,
            "queue_seconds": 3.0,
            "items_per_gpu_hour": 142940800.8769526,
            "mean_cpu_percent": 1573.35058569998,
            "cpu_fraction": 0.2809554617321393,
            "affinity_cpus": 56,
            "effective_cpu_capacity": 56,
            "max_threads": 66,
            "max_rss_sum_kib": 17654660,
            "mean_gpu_utilization": 96.49414600550965,
            "mean_gpu_power_watts": 455.45904269972505,
            "child_speeds": [
              10152.16758997048,
              9944.225221165882,
              10042.744894322557,
              10045.177418105675,
              10152.414013831512,
              10072.220230153098,
              10057.037671048394,
              10019.491953064049,
              10073.053119048112,
              10023.101726294506,
              10094.30573930857,
              10024.811712507848,
              10137.372847788567,
              9999.419951344456,
              10098.602258984583,
              10048.56345724398
            ]
          }
        ]
      },
      "cat": {
        "case": "f6-L-cat-pipeline",
        "verified": true,
        "measurements": [
          {
            "case": "f6-L-cat-pipeline",
            "model": "L",
            "n": 4,
            "mps": true,
            "threads": 1,
            "workers": 0,
            "seconds": 3600,
            "throughput": 159586.613116796,
            "gpu_fraction": 0.044025879161014296,
            "host_fraction": 0.01802146911621094,
            "samples": 726,
            "safe": true,
            "host_oom_observed": false,
            "requested_gpu_hours": 4.333333333333333,
            "gpus": 4,
            "storage": "cat",
            "ballast_mib": 0,
            "nodes": [
              "c129"
            ],
            "workload": {
              "model_id": "cnn-64x6-v1",
              "data_id": "random512x3x32x32-seed20261022-v1",
              "batch_size": 64,
              "precision": "fp32"
            },
            "observed_gpu_hours": 4.055555555555555,
            "queue_seconds": 15.0,
            "items_per_gpu_hour": 142903706.30136988,
            "mean_cpu_percent": 1573.4782268346842,
            "cpu_fraction": 0.2809782547919079,
            "affinity_cpus": 56,
            "effective_cpu_capacity": 56,
            "max_threads": 66,
            "max_rss_sum_kib": 17777724,
            "mean_gpu_utilization": 96.48037190082644,
            "mean_gpu_power_watts": 455.4008849862252,
            "child_speeds": [
              10125.916493257315,
              10084.502536686821,
              10043.11685939702,
              10129.48520384463,
              10103.942528400557,
              10011.388723553035,
              9994.003908468681,
              10050.765662002677,
              10029.397000586921,
              10063.619975368523,
              9974.551552175608,
              10099.244326642138,
              10051.441328965286,
              10140.787523800424,
              10088.02198304394,
              9996.880827806737
            ]
          }
        ]
      }
    }
  }
}

## Slurm 作业并发对照

{
  "jobs1-r1": {
    "cases": [
      "f5-jobs1-r1-0"
    ],
    "all_pass": true,
    "total_items": 4214464,
    "allocations": [
      {
        "job": "4462259",
        "start": 1792848363.0,
        "end": 1792848472.0,
        "gpus": 1
      }
    ],
    "training": [
      [
        1792848379.1861367,
        1792848469.187486
      ]
    ],
    "actual_peak_jobs": 1,
    "requested_jobs": 1,
    "common_training_overlap_seconds": 90.00134921073914,
    "aggregate_items_per_wall_second": 38664.807339449544,
    "observed_gpu_hours": 0.03027777777777778,
    "items_per_gpu_hour": 139193306.42201835,
    "concurrency_verified": true,
    "per_case_measurements": [
      {
        "case": "f5-jobs1-r1-0",
        "model": "S",
        "n": 1,
        "mps": false,
        "threads": 1,
        "workers": 0,
        "seconds": 90,
        "throughput": 42933.49570258537,
        "gpu_fraction": 0.008942919753730565,
        "host_fraction": 0.006736864362444197,
        "samples": 20,
        "safe": true,
        "host_oom_observed": false,
        "requested_gpu_hours": 0.11666666666666667,
        "gpus": 1,
        "storage": "local",
        "ballast_mib": 0,
        "nodes": [
          "c105"
        ],
        "workload": {
          "model_id": "cnn-8x2-v1",
          "data_id": "random512x3x32x32-seed20261022-v1",
          "batch_size": 64,
          "precision": "fp32"
        },
        "observed_gpu_hours": 0.03027777777777778,
        "queue_seconds": 10.0,
        "items_per_gpu_hour": 139193306.42201835,
        "mean_cpu_percent": 92.12506107292548,
        "cpu_fraction": 0.06580361505208962,
        "affinity_cpus": 14,
        "effective_cpu_capacity": 14,
        "max_threads": 6,
        "max_rss_sum_kib": 1133884,
        "mean_gpu_utilization": 22.2,
        "mean_gpu_power_watts": 137.925,
        "child_speeds": [
          46826.67540003963
        ]
      }
    ]
  },
  "jobs2-r1": {
    "cases": [
      "f5-jobs2-r1-0",
      "f5-jobs2-r1-1"
    ],
    "all_pass": true,
    "total_items": 7641984,
    "allocations": [
      {
        "job": "4462268",
        "start": 1792848483.0,
        "end": 1792848589.0,
        "gpus": 1
      },
      {
        "job": "4462270",
        "start": 1792848503.0,
        "end": 1792848614.0,
        "gpus": 1
      }
    ],
    "training": [
      [
        1792848493.4567814,
        1792848583.4576437
      ],
      [
        1792848521.665663,
        1792848611.6666317
      ]
    ],
    "actual_peak_jobs": 2,
    "requested_jobs": 2,
    "common_training_overlap_seconds": 61.7919807434082,
    "aggregate_items_per_wall_second": 58335.75572519084,
    "observed_gpu_hours": 0.06027777777777778,
    "items_per_gpu_hour": 126779458.06451613,
    "concurrency_verified": false,
    "per_case_measurements": [
      {
        "case": "f5-jobs2-r1-0",
        "model": "S",
        "n": 1,
        "mps": false,
        "threads": 1,
        "workers": 0,
        "seconds": 90,
        "throughput": 44473.961477829085,
        "gpu_fraction": 0.008942919753730565,
        "host_fraction": 0.00434295654296875,
        "samples": 20,
        "safe": true,
        "host_oom_observed": false,
        "requested_gpu_hours": 0.11666666666666667,
        "gpus": 1,
        "storage": "local",
        "ballast_mib": 0,
        "nodes": [
          "c105"
        ],
        "workload": {
          "model_id": "cnn-8x2-v1",
          "data_id": "random512x3x32x32-seed20261022-v1",
          "batch_size": 64,
          "precision": "fp32"
        },
        "observed_gpu_hours": 0.029444444444444443,
        "queue_seconds": 8.0,
        "items_per_gpu_hour": 143967396.2264151,
        "mean_cpu_percent": 94.08815397489431,
        "cpu_fraction": 0.06720582426778166,
        "affinity_cpus": 14,
        "effective_cpu_capacity": 14,
        "max_threads": 6,
        "max_rss_sum_kib": 1137080,
        "mean_gpu_utilization": 22.35,
        "mean_gpu_power_watts": 137.605,
        "child_speeds": [
          47099.993191972164
        ]
      },
      {
        "case": "f5-jobs2-r1-1",
        "model": "S",
        "n": 1,
        "mps": false,
        "threads": 1,
        "workers": 0,
        "seconds": 90,
        "throughput": 34643.366532002874,
        "gpu_fraction": 0.008942919753730565,
        "host_fraction": 0.006747807094029018,
        "samples": 20,
        "safe": true,
        "host_oom_observed": false,
        "requested_gpu_hours": 0.11666666666666667,
        "gpus": 1,
        "storage": "local",
        "ballast_mib": 0,
        "nodes": [
          "c10"
        ],
        "workload": {
          "model_id": "cnn-8x2-v1",
          "data_id": "random512x3x32x32-seed20261022-v1",
          "batch_size": 64,
          "precision": "fp32"
        },
        "observed_gpu_hours": 0.030833333333333334,
        "queue_seconds": 28.0,
        "items_per_gpu_hour": 110365751.35135135,
        "mean_cpu_percent": 91.62141304133038,
        "cpu_fraction": 0.06544386645809314,
        "affinity_cpus": 14,
        "effective_cpu_capacity": 14,
        "max_threads": 6,
        "max_rss_sum_kib": 1136124,
        "mean_gpu_utilization": 17.95,
        "mean_gpu_power_watts": 141.4335,
        "child_speeds": [
          37810.08141887315
        ]
      }
    ]
  },
  "jobs4-r1": {
    "cases": [
      "f5-jobs4-r1-0",
      "f5-jobs4-r1-1",
      "f5-jobs4-r1-2",
      "f5-jobs4-r1-3"
    ],
    "all_pass": true,
    "total_items": 14730304,
    "allocations": [
      {
        "job": "4462282",
        "start": 1792848623.0,
        "end": 1792848732.0,
        "gpus": 1
      },
      {
        "job": "4462284",
        "start": 1792848623.0,
        "end": 1792848733.0,
        "gpus": 1
      },
      {
        "job": "4462286",
        "start": 1792848623.0,
        "end": 1792848730.0,
        "gpus": 1
      },
      {
        "job": "4462288",
        "start": 1792848623.0,
        "end": 1792848732.0,
        "gpus": 1
      }
    ],
    "training": [
      [
        1792848638.8834372,
        1792848728.8851566
      ],
      [
        1792848641.2389865,
        1792848731.239859
      ],
      [
        1792848634.8077772,
        1792848724.8094406
      ],
      [
        1792848638.4313269,
        1792848728.4327035
      ]
    ],
    "actual_peak_jobs": 4,
    "requested_jobs": 4,
    "common_training_overlap_seconds": 83.57045412063599,
    "aggregate_items_per_wall_second": 133911.85454545455,
    "observed_gpu_hours": 0.12083333333333333,
    "items_per_gpu_hour": 121905964.13793103,
    "concurrency_verified": true,
    "per_case_measurements": [
      {
        "case": "f5-jobs4-r1-0",
        "model": "S",
        "n": 1,
        "mps": false,
        "threads": 1,
        "workers": 0,
        "seconds": 90,
        "throughput": 43570.873267970535,
        "gpu_fraction": 0.008942919753730565,
        "host_fraction": 0.00687652587890625,
        "samples": 20,
        "safe": true,
        "host_oom_observed": false,
        "requested_gpu_hours": 0.11666666666666667,
        "gpus": 1,
        "storage": "local",
        "ballast_mib": 0,
        "nodes": [
          "c105"
        ],
        "workload": {
          "model_id": "cnn-8x2-v1",
          "data_id": "random512x3x32x32-seed20261022-v1",
          "batch_size": 64,
          "precision": "fp32"
        },
        "observed_gpu_hours": 0.03027777777777778,
        "queue_seconds": 6.0,
        "items_per_gpu_hour": 140057834.86238533,
        "mean_cpu_percent": 91.86249037238316,
        "cpu_fraction": 0.06561606455170226,
        "affinity_cpus": 14,
        "effective_cpu_capacity": 14,
        "max_threads": 6,
        "max_rss_sum_kib": 1136300,
        "mean_gpu_utilization": 22.05,
        "mean_gpu_power_watts": 137.5635,
        "child_speeds": [
          47117.32131965433
        ]
      },
      {
        "case": "f5-jobs4-r1-1",
        "model": "S",
        "n": 1,
        "mps": false,
        "threads": 1,
        "workers": 0,
        "seconds": 90,
        "throughput": 29743.682170392418,
        "gpu_fraction": 0.008942919753730565,
        "host_fraction": 0.0067415727887834825,
        "samples": 20,
        "safe": true,
        "host_oom_observed": false,
        "requested_gpu_hours": 0.11666666666666667,
        "gpus": 1,
        "storage": "local",
        "ballast_mib": 0,
        "nodes": [
          "c153"
        ],
        "workload": {
          "model_id": "cnn-8x2-v1",
          "data_id": "random512x3x32x32-seed20261022-v1",
          "batch_size": 64,
          "precision": "fp32"
        },
        "observed_gpu_hours": 0.030555555555555555,
        "queue_seconds": 6.0,
        "items_per_gpu_hour": 96380509.0909091,
        "mean_cpu_percent": 91.80420792095474,
        "cpu_fraction": 0.06557443422925338,
        "affinity_cpus": 14,
        "effective_cpu_capacity": 14,
        "max_threads": 6,
        "max_rss_sum_kib": 1134884,
        "mean_gpu_utilization": 15.9,
        "mean_gpu_power_watts": 134.05400000000003,
        "child_speeds": [
          32721.45987570854
        ]
      },
      {
        "case": "f5-jobs4-r1-2",
        "model": "S",
        "n": 1,
        "mps": false,
        "threads": 1,
        "workers": 0,
        "seconds": 90,
        "throughput": 33551.978427621165,
        "gpu_fraction": 0.008942919753730565,
        "host_fraction": 0.004342912946428572,
        "samples": 20,
        "safe": true,
        "host_oom_observed": false,
        "requested_gpu_hours": 0.11666666666666667,
        "gpus": 1,
        "storage": "local",
        "ballast_mib": 0,
        "nodes": [
          "c10"
        ],
        "workload": {
          "model_id": "cnn-8x2-v1",
          "data_id": "random512x3x32x32-seed20261022-v1",
          "batch_size": 64,
          "precision": "fp32"
        },
        "observed_gpu_hours": 0.029722222222222223,
        "queue_seconds": 6.0,
        "items_per_gpu_hour": 108128657.94392523,
        "mean_cpu_percent": 93.78941073902584,
        "cpu_fraction": 0.06699243624216131,
        "affinity_cpus": 14,
        "effective_cpu_capacity": 14,
        "max_threads": 6,
        "max_rss_sum_kib": 1154008,
        "mean_gpu_utilization": 16.85,
        "mean_gpu_power_watts": 140.363,
        "child_speeds": [
          35708.4943338231
        ]
      },
      {
        "case": "f5-jobs4-r1-3",
        "model": "S",
        "n": 1,
        "mps": false,
        "threads": 1,
        "workers": 0,
        "seconds": 90,
        "throughput": 44429.20293007615,
        "gpu_fraction": 0.008942919753730565,
        "host_fraction": 0.0067333984375,
        "samples": 20,
        "safe": true,
        "host_oom_observed": false,
        "requested_gpu_hours": 0.11666666666666667,
        "gpus": 1,
        "storage": "local",
        "ballast_mib": 0,
        "nodes": [
          "c100"
        ],
        "workload": {
          "model_id": "cnn-8x2-v1",
          "data_id": "random512x3x32x32-seed20261022-v1",
          "batch_size": 64,
          "precision": "fp32"
        },
        "observed_gpu_hours": 0.03027777777777778,
        "queue_seconds": 6.0,
        "items_per_gpu_hour": 143038238.5321101,
        "mean_cpu_percent": 91.72372485204622,
        "cpu_fraction": 0.06551694632289015,
        "affinity_cpus": 14,
        "effective_cpu_capacity": 14,
        "max_threads": 6,
        "max_rss_sum_kib": 1135652,
        "mean_gpu_utilization": 22.65,
        "mean_gpu_power_watts": 138.125,
        "child_speeds": [
          48120.15233510349
        ]
      }
    ]
  },
  "one-four-r1": {
    "cases": [
      "f5-one-four-r1"
    ],
    "all_pass": true,
    "total_items": 16768768,
    "allocations": [
      {
        "job": "4462294",
        "start": 1792848853.0,
        "end": 1792848972.0,
        "gpus": 4
      }
    ],
    "training": [
      [
        1792848878.735134,
        1792848968.7363489
      ],
      [
        1792848878.735081,
        1792848968.7360241
      ],
      [
        1792848878.735116,
        1792848968.735524
      ],
      [
        1792848878.7350707,
        1792848968.7356899
      ]
    ],
    "actual_peak_jobs": 1,
    "requested_jobs": 1,
    "common_training_overlap_seconds": 90.00039005279541,
    "aggregate_items_per_wall_second": 140914.01680672268,
    "observed_gpu_hours": 0.1322222222222222,
    "items_per_gpu_hour": 126822615.12605043,
    "concurrency_verified": true,
    "per_case_measurements": [
      {
        "case": "f5-one-four-r1",
        "model": "S",
        "n": 1,
        "mps": false,
        "threads": 1,
        "workers": 0,
        "seconds": 90,
        "throughput": 162358.98512774435,
        "gpu_fraction": 0.008942919753730565,
        "host_fraction": 0.0047021702357700895,
        "samples": 21,
        "safe": true,
        "host_oom_observed": false,
        "requested_gpu_hours": 0.4666666666666667,
        "gpus": 4,
        "storage": "local",
        "ballast_mib": 0,
        "nodes": [
          "c105"
        ],
        "workload": {
          "model_id": "cnn-8x2-v1",
          "data_id": "random512x3x32x32-seed20261022-v1",
          "batch_size": 64,
          "precision": "fp32"
        },
        "observed_gpu_hours": 0.1322222222222222,
        "queue_seconds": 109.0,
        "items_per_gpu_hour": 126822615.12605043,
        "mean_cpu_percent": 356.2420990876492,
        "cpu_fraction": 0.06361466055136593,
        "affinity_cpus": 56,
        "effective_cpu_capacity": 56,
        "max_threads": 18,
        "max_rss_sum_kib": 4379256,
        "mean_gpu_utilization": 20.928571428571427,
        "mean_gpu_power_watts": 133.72535714285715,
        "child_speeds": [
          45920.090497520665,
          46116.49385384712,
          47506.98360779041,
          46774.43347927409
        ]
      }
    ]
  },
  "jobs1-r2": {
    "cases": [
      "f5-jobs1-r2-0"
    ],
    "all_pass": true,
    "total_items": 4336448,
    "allocations": [
      {
        "job": "4462310",
        "start": 1792849010.0,
        "end": 1792849119.0,
        "gpus": 1
      }
    ],
    "training": [
      [
        1792849023.6868157,
        1792849113.6875052
      ]
    ],
    "actual_peak_jobs": 1,
    "requested_jobs": 1,
    "common_training_overlap_seconds": 90.00068950653076,
    "aggregate_items_per_wall_second": 39783.92660550459,
    "observed_gpu_hours": 0.03027777777777778,
    "items_per_gpu_hour": 143222135.7798165,
    "concurrency_verified": true,
    "per_case_measurements": [
      {
        "case": "f5-jobs1-r2-0",
        "model": "S",
        "n": 1,
        "mps": false,
        "threads": 1,
        "workers": 0,
        "seconds": 90,
        "throughput": 45415.18924631593,
        "gpu_fraction": 0.008942919753730565,
        "host_fraction": 0.004342150006975447,
        "samples": 20,
        "safe": true,
        "host_oom_observed": false,
        "requested_gpu_hours": 0.11666666666666667,
        "gpus": 1,
        "storage": "local",
        "ballast_mib": 0,
        "nodes": [
          "c20"
        ],
        "workload": {
          "model_id": "cnn-8x2-v1",
          "data_id": "random512x3x32x32-seed20261022-v1",
          "batch_size": 64,
          "precision": "fp32"
        },
        "observed_gpu_hours": 0.03027777777777778,
        "queue_seconds": 28.0,
        "items_per_gpu_hour": 143222135.7798165,
        "mean_cpu_percent": 93.4573471602751,
        "cpu_fraction": 0.06675524797162508,
        "affinity_cpus": 14,
        "effective_cpu_capacity": 14,
        "max_threads": 6,
        "max_rss_sum_kib": 1147268,
        "mean_gpu_utilization": 21.25,
        "mean_gpu_power_watts": 145.37949999999998,
        "child_speeds": [
          48182.38585157176
        ]
      }
    ]
  },
  "jobs2-r2": {
    "cases": [
      "f5-jobs2-r2-0",
      "f5-jobs2-r2-1"
    ],
    "all_pass": true,
    "total_items": 8386816,
    "allocations": [
      {
        "job": "4462318",
        "start": 1792849137.0,
        "end": 1792849245.0,
        "gpus": 1
      },
      {
        "job": "4462320",
        "start": 1792849137.0,
        "end": 1792849247.0,
        "gpus": 1
      }
    ],
    "training": [
      [
        1792849150.2082138,
        1792849240.2083244
      ],
      [
        1792849154.859266,
        1792849244.859749
      ]
    ],
    "actual_peak_jobs": 2,
    "requested_jobs": 2,
    "common_training_overlap_seconds": 85.3490583896637,
    "aggregate_items_per_wall_second": 76243.78181818181,
    "observed_gpu_hours": 0.06055555555555556,
    "items_per_gpu_hour": 138497878.89908257,
    "concurrency_verified": true,
    "per_case_measurements": [
      {
        "case": "f5-jobs2-r2-0",
        "model": "S",
        "n": 1,
        "mps": false,
        "threads": 1,
        "workers": 0,
        "seconds": 90,
        "throughput": 43638.790333495876,
        "gpu_fraction": 0.008942919753730565,
        "host_fraction": 0.00434539794921875,
        "samples": 20,
        "safe": true,
        "host_oom_observed": false,
        "requested_gpu_hours": 0.11666666666666667,
        "gpus": 1,
        "storage": "local",
        "ballast_mib": 0,
        "nodes": [
          "c20"
        ],
        "workload": {
          "model_id": "cnn-8x2-v1",
          "data_id": "random512x3x32x32-seed20261022-v1",
          "batch_size": 64,
          "precision": "fp32"
        },
        "observed_gpu_hours": 0.03,
        "queue_seconds": 15.0,
        "items_per_gpu_hour": 138606933.33333334,
        "mean_cpu_percent": 93.9621587675964,
        "cpu_fraction": 0.06711582769114029,
        "affinity_cpus": 14,
        "effective_cpu_capacity": 14,
        "max_threads": 6,
        "max_rss_sum_kib": 1138604,
        "mean_gpu_utilization": 21.05,
        "mean_gpu_power_watts": 145.9525,
        "child_speeds": [
          46202.25374073937
        ]
      },
      {
        "case": "f5-jobs2-r2-1",
        "model": "S",
        "n": 1,
        "mps": false,
        "threads": 1,
        "workers": 0,
        "seconds": 90,
        "throughput": 43070.32403549986,
        "gpu_fraction": 0.008942919753730565,
        "host_fraction": 0.006723894391741071,
        "samples": 20,
        "safe": true,
        "host_oom_observed": false,
        "requested_gpu_hours": 0.11666666666666667,
        "gpus": 1,
        "storage": "local",
        "ballast_mib": 0,
        "nodes": [
          "c104"
        ],
        "workload": {
          "model_id": "cnn-8x2-v1",
          "data_id": "random512x3x32x32-seed20261022-v1",
          "batch_size": 64,
          "precision": "fp32"
        },
        "observed_gpu_hours": 0.030555555555555555,
        "queue_seconds": 15.0,
        "items_per_gpu_hour": 138390807.27272728,
        "mean_cpu_percent": 91.13078159168619,
        "cpu_fraction": 0.06509341542263299,
        "affinity_cpus": 14,
        "effective_cpu_capacity": 14,
        "max_threads": 6,
        "max_rss_sum_kib": 1137848,
        "mean_gpu_utilization": 22.05,
        "mean_gpu_power_watts": 137.63400000000001,
        "child_speeds": [
          46984.280652393354
        ]
      }
    ]
  },
  "jobs4-r2": {
    "cases": [
      "f5-jobs4-r2-0",
      "f5-jobs4-r2-1",
      "f5-jobs4-r2-2",
      "f5-jobs4-r2-3"
    ],
    "all_pass": true,
    "total_items": 17375680,
    "allocations": [
      {
        "job": "4462329",
        "start": 1792849262.0,
        "end": 1792849370.0,
        "gpus": 1
      },
      {
        "job": "4462331",
        "start": 1792849262.0,
        "end": 1792849370.0,
        "gpus": 1
      },
      {
        "job": "4462333",
        "start": 1792849262.0,
        "end": 1792849364.0,
        "gpus": 1
      },
      {
        "job": "4462335",
        "start": 1792849282.0,
        "end": 1792849382.0,
        "gpus": 1
      }
    ],
    "training": [
      [
        1792849275.9178522,
        1792849365.9188058
      ],
      [
        1792849275.9096029,
        1792849365.910987
      ],
      [
        1792849273.0421078,
        1792849363.0424917
      ],
      [
        1792849291.1738598,
        1792849381.1753466
      ]
    ],
    "actual_peak_jobs": 4,
    "requested_jobs": 4,
    "common_training_overlap_seconds": 71.8686318397522,
    "aggregate_items_per_wall_second": 144797.33333333334,
    "observed_gpu_hours": 0.11611111111111111,
    "items_per_gpu_hour": 149647004.784689,
    "concurrency_verified": false,
    "per_case_measurements": [
      {
        "case": "f5-jobs4-r2-0",
        "model": "S",
        "n": 1,
        "mps": false,
        "threads": 1,
        "workers": 0,
        "seconds": 90,
        "throughput": 45453.53759309408,
        "gpu_fraction": 0.008942919753730565,
        "host_fraction": 0.004346749441964286,
        "samples": 20,
        "safe": true,
        "host_oom_observed": false,
        "requested_gpu_hours": 0.11666666666666667,
        "gpus": 1,
        "storage": "local",
        "ballast_mib": 0,
        "nodes": [
          "c20"
        ],
        "workload": {
          "model_id": "cnn-8x2-v1",
          "data_id": "random512x3x32x32-seed20261022-v1",
          "batch_size": 64,
          "precision": "fp32"
        },
        "observed_gpu_hours": 0.03,
        "queue_seconds": 13.0,
        "items_per_gpu_hour": 145597866.6666667,
        "mean_cpu_percent": 93.26106743350644,
        "cpu_fraction": 0.06661504816679031,
        "affinity_cpus": 14,
        "effective_cpu_capacity": 14,
        "max_threads": 6,
        "max_rss_sum_kib": 1138880,
        "mean_gpu_utilization": 22.55,
        "mean_gpu_power_watts": 146.836,
        "child_speeds": [
          48532.10739848293
        ]
      },
      {
        "case": "f5-jobs4-r2-1",
        "model": "S",
        "n": 1,
        "mps": false,
        "threads": 1,
        "workers": 0,
        "seconds": 90,
        "throughput": 44962.0731906849,
        "gpu_fraction": 0.008942919753730565,
        "host_fraction": 0.004342803955078125,
        "samples": 20,
        "safe": true,
        "host_oom_observed": false,
        "requested_gpu_hours": 0.11666666666666667,
        "gpus": 1,
        "storage": "local",
        "ballast_mib": 0,
        "nodes": [
          "c20"
        ],
        "workload": {
          "model_id": "cnn-8x2-v1",
          "data_id": "random512x3x32x32-seed20261022-v1",
          "batch_size": 64,
          "precision": "fp32"
        },
        "observed_gpu_hours": 0.03,
        "queue_seconds": 13.0,
        "items_per_gpu_hour": 144484266.6666667,
        "mean_cpu_percent": 92.93295768390716,
        "cpu_fraction": 0.06638068405993369,
        "affinity_cpus": 14,
        "effective_cpu_capacity": 14,
        "max_threads": 6,
        "max_rss_sum_kib": 1138884,
        "mean_gpu_utilization": 22.6,
        "mean_gpu_power_watts": 138.47549999999998,
        "child_speeds": [
          48160.680917515536
        ]
      },
      {
        "case": "f5-jobs4-r2-2",
        "model": "S",
        "n": 1,
        "mps": false,
        "threads": 1,
        "workers": 0,
        "seconds": 90,
        "throughput": 45541.6280122642,
        "gpu_fraction": 0.008942919753730565,
        "host_fraction": 0.0043724496023995535,
        "samples": 19,
        "safe": true,
        "host_oom_observed": false,
        "requested_gpu_hours": 0.11666666666666667,
        "gpus": 1,
        "storage": "local",
        "ballast_mib": 0,
        "nodes": [
          "c104"
        ],
        "workload": {
          "model_id": "cnn-8x2-v1",
          "data_id": "random512x3x32x32-seed20261022-v1",
          "batch_size": 64,
          "precision": "fp32"
        },
        "observed_gpu_hours": 0.028333333333333332,
        "queue_seconds": 13.0,
        "items_per_gpu_hour": 152201788.23529413,
        "mean_cpu_percent": 94.07588164068079,
        "cpu_fraction": 0.06719705831477199,
        "affinity_cpus": 14,
        "effective_cpu_capacity": 14,
        "max_threads": 6,
        "max_rss_sum_kib": 1144632,
        "mean_gpu_utilization": 23.842105263157894,
        "mean_gpu_power_watts": 137.8136842105263,
        "child_speeds": [
          47915.17278335822
        ]
      },
      {
        "case": "f5-jobs4-r2-3",
        "model": "S",
        "n": 1,
        "mps": false,
        "threads": 1,
        "workers": 0,
        "seconds": 90,
        "throughput": 46017.30501849774,
        "gpu_fraction": 0.008942919753730565,
        "host_fraction": 0.004331338065011161,
        "samples": 19,
        "safe": true,
        "host_oom_observed": false,
        "requested_gpu_hours": 0.11666666666666667,
        "gpus": 1,
        "storage": "local",
        "ballast_mib": 0,
        "nodes": [
          "c104"
        ],
        "workload": {
          "model_id": "cnn-8x2-v1",
          "data_id": "random512x3x32x32-seed20261022-v1",
          "batch_size": 64,
          "precision": "fp32"
        },
        "observed_gpu_hours": 0.027777777777777776,
        "queue_seconds": 33.0,
        "items_per_gpu_hour": 156989952.0,
        "mean_cpu_percent": 93.73989733328705,
        "cpu_fraction": 0.06695706952377646,
        "affinity_cpus": 14,
        "effective_cpu_capacity": 14,
        "max_threads": 6,
        "max_rss_sum_kib": 1135812,
        "mean_gpu_utilization": 24.31578947368421,
        "mean_gpu_power_watts": 135.6536842105263,
        "child_speeds": [
          48452.88817530441
        ]
      }
    ]
  },
  "one-four-r2": {
    "cases": [
      "f5-one-four-r2"
    ],
    "all_pass": true,
    "total_items": 16729984,
    "allocations": [
      {
        "job": "4462341",
        "start": 1792849454.0,
        "end": 1792849574.0,
        "gpus": 4
      }
    ],
    "training": [
      [
        1792849481.1380239,
        1792849571.1391463
      ],
      [
        1792849481.1380117,
        1792849571.1395352
      ],
      [
        1792849481.1380363,
        1792849571.1385846
      ],
      [
        1792849481.1380146,
        1792849571.1392524
      ]
    ],
    "actual_peak_jobs": 1,
    "requested_jobs": 1,
    "common_training_overlap_seconds": 90.00054836273193,
    "aggregate_items_per_wall_second": 139416.53333333333,
    "observed_gpu_hours": 0.13333333333333333,
    "items_per_gpu_hour": 125474880.0,
    "concurrency_verified": true,
    "per_case_measurements": [
      {
        "case": "f5-one-four-r2",
        "model": "S",
        "n": 1,
        "mps": false,
        "threads": 1,
        "workers": 0,
        "seconds": 90,
        "throughput": 162145.8303504754,
        "gpu_fraction": 0.008942919753730565,
        "host_fraction": 0.004704649788992745,
        "samples": 21,
        "safe": true,
        "host_oom_observed": false,
        "requested_gpu_hours": 0.4666666666666667,
        "gpus": 4,
        "storage": "local",
        "ballast_mib": 0,
        "nodes": [
          "c105"
        ],
        "workload": {
          "model_id": "cnn-8x2-v1",
          "data_id": "random512x3x32x32-seed20261022-v1",
          "batch_size": 64,
          "precision": "fp32"
        },
        "observed_gpu_hours": 0.13333333333333333,
        "queue_seconds": 61.0,
        "items_per_gpu_hour": 125474880.0,
        "mean_cpu_percent": 351.06476740795324,
        "cpu_fraction": 0.06269013703713451,
        "affinity_cpus": 56,
        "effective_cpu_capacity": 56,
        "max_threads": 18,
        "max_rss_sum_kib": 4380252,
        "mean_gpu_utilization": 21.071428571428573,
        "mean_gpu_power_watts": 134.83476190476193,
        "child_speeds": [
          47039.41316187656,
          46005.26512443407,
          46251.09522468831,
          46590.64736104274
        ]
      }
    ]
  }
}

各分配的节点、UUID、存储路径可能不同；跨节点差异不能仅归因于 MPS、许可或 Slurm 参数。
本地临时存储仅用于分离 GPU/CPU 与 cat 因素；本地 checkpoint 随任务清理，验证结果和日志保存在 HOME。
显存压力组只增加固定大小的已写入 CUDA 张量，不能代替真实大模型或所有显存峰值阶段。

完整数据见 results.csv、results.json、training-measurements.json、jobs/ 和 evidence/。
Observed GPU hours=23.9311; reservation upper bound=46.1167.
Actual global GPU overlap=4; configured cap=4.
