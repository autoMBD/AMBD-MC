# PMSM 控制框架

完整启动、参数、模型接口与验证流程统一维护在
[项目手册](../../docs/manual/pmsm.md)，
也可阅读[在线手册](https://autombd.github.io/AMBD-MC/manual/pmsm/)。

从仓库根目录初始化 MATLAB：

```matlab
info = ambd_mc("setup","pmsm");
```

保留 `info` 以维持字典连接；普通启动保留已有标定。
首次运行见[快速开始](../../docs/manual/getting-started.md)，
目标代码与 PIL 见[HSP 指南](../../docs/hardware/hsp-s32k344.md)。
