# 第05轮：风图埠短航 — 设计与实施计划

2026-10-24，基线39c1d6f。沿用已获授权的自主设计与发布流程。

## 设计

第二航灯点亮后，在雨阶码头东侧找新航船人登船，前往风图埠。这里是用低矮石堤、木船棚和帆布风标组成的小港：黄铜、锈红木材和冷青海水形成独立配色。整段无强制战斗、无道具消耗。三座航标在主港任意顺序观察，记录持续保存；静音仍可凭文字和标记完成。

风标说明避开东侧受风礁石；潮尺说明中央浅滩不可通行，南面水道足够深；对灯说明泊位入口位于南侧背风弯。航图台提供「北侧浅滩 / 东侧礁道 / 南侧背风弯」三条明确路线，未记齐线索不能启航。选错留在原地并解释原因，可即时重试；选对抵达独立背风小泊位。与当地制帆人交谈完成故事、领取一次补给、点亮靠泊灯，再乘当地小艇免费回主港。主港船可回雨阶，雨阶原渡船可回醒潮港。

选择方案：扩展现有静态微缩岛屿与确认菜单，复用战斗之外的步行、对话、标记及保存流程。相比开放海面驾驶与风浪模拟，它能把观察线索转化成完整可测的短旅程，同时保持现有掌机RPG节奏。此轮不新增物种、道馆或声乐。

## 接口与分工

- 规则代理：`wind_quest.gd`（class_name WindQuest）与 `game_state.gd`、`test_wind_rules.gd`。旗标 `wind_arrived/wind_wind/wind_tide/wind_light/wind_sailed/wind_rewarded`；默认false；wind进度依赖第二馆，sailed依赖三线索，rewarded依赖sailed。岛屿ID `windchart`；安全点 `(120,0,8)`，泊位点 `(140,0,2)`。保持版本1兼容及事务校验。
- 世界代理：`windchart_world.gd` 与 `world.gd`。主港Rect2(108,-11,24,22)，泊位Rect2(136,-5,8,10)，之间海面不可步行。Windchart世界helper提供 `DOCK/BERTH/BOUNDS/BERTH_BOUNDS/MARKERS`，build/can_walk/sync_progress；world新增windchart、sync_wind_progress，处理摄像机/安全位置/岛屿切换/无随机遇敌。新船入口在雨阶 `(64,0,8.2)`；新helper负责建造与注册，不改旧岛文件。
- 主代理：main/game_ui接入航渡、三线索、路线选择与回港；全中文目录；实际场景旅程、截图、文档、打包发布。共用资源预算，子代理不运行Godot。

规则接口：`travel(state,destination)->bool` 只允许 rainstep↔windchart；`interact(state,role)->Dictionary` 返回speaker/lines/changed/sound；角色 wind_keeper（主港免费回复）、wind_wind/wind_tide/wind_light、wind_chart（提示）、wind_berth（一次结尾与奖励）。`marker_count(state)->int`、`can_sail(state)->bool`、`choose_route(state,route)->Dictionary`，route north/east/south，仅south成功并写position；`return_to_quay(state)->bool` 免费从泊位回主港；`objective(state)->String` 提供当前行动。

## 顺序与验收

- [x] 先在独立验证副本确认缺少新岛/规则/旗标（RED）。
- [x] 并行按非重叠文件实现规则和程序化港口；主代理实现菜单/协调器/本地化。
- [x] 实际从雨阶登船，取消不移动；三个线索六种顺序，缺线索拒绝、两条错路无损重试、正确路线抵泊、一次领奖、免费回港及经雨阶返醒潮港；满队/空物资/静音不阻塞。
- [x] 旧档默认新内容未开启；新进度中途与结尾保存恢复；非法进度事务拒绝；全队倒下读档在当地安全点回复。
- [x] 完整 `sh tools/verify.sh` 已通过10,744项，中英实渲染与独立审查通过；发布结果见status。

所有运行采用隔离项目和用户目录，截图禁用保存。当前玩家实际操作验收不与自动技术验证混同。

## 实施与审查记录

已实现全部路线与返航，规则/双语目录/主场景真实旅程通过。独立审查发现未启航的健康队伍坏档可位于孤立泊位，现以地图同范围Rect2在事务提交前拒绝，3个坏档RED/GREEN用例通过，旧岛位置兼容保留。港口实际渲染后补充两座低船架与卷帆，并给地图加入实际通路/作业区轮廓和更清晰的泊位标签。全程运行于独立源副本及用户目录，未使用真实玩家存档。

下一轮由本聊天续作代理执行第06轮旅伴寄养：24个寄养位、回复点寄存/领回、满队捕捉送寄养、容量和最后一位伙伴保护、旧档与双语回归。此次不提前实施该系统。
