# TODO - 功能增强

参考 [renxiaoyaoo/ha-95598](https://github.com/renxiaoyaoo/ha-95598) 项目，以下是国网 95598 网站能直接查询到但我们尚未实现的数据。

---

## 1. 每日分时电量（谷/平/峰/尖）

**优先级：高** | **来源：国网直接查询**

### 原理

国网 95598 的「日用电量」页面（tab-second），每行数据除了日总用电量 `dayElePq`，还包含 4 个分时字段：

| Vue 字段 | 含义 | 对应中文 |
|----------|------|---------|
| `thisVPq` | 谷电量 | 低谷用电 |
| `thisNPq` | 平电量 | 平用电 |
| `thisPPq` | 峰电量 | 峰用电 |
| `thisTPq` | 尖电量 | 尖用电 |

这些数据存储在 Vue 组件的 `sevenEleList` / `new_sevenEleList` 数组中，每个元素是一天的数据。

### 获取方式

**方式一（推荐）：Vue 状态注入**
```javascript
// 扫描页面所有 DOM 元素的 __vue__ 属性
// 从 Vue 实例中读取 sevenEleList / new_sevenEleList
// 每条记录包含: day, dayElePq, thisVPq, thisNPq, thisPPq, thisTPq
```

**方式二（Fallback）：DOM 展开行**
```
1. 点击日用电量 tab
2. 找到表格行的展开图标 (el-table__expand-icon)
3. 点击展开后，读取展开行中的谷/平/峰/尖用电量
   XPath: .//p[.//text()[contains(.,'谷用电')]]//span[contains(@class,'num')]
```

### 实现要点

- 新增 `scripts/fetchers/vue_state.py`：注入 JS 脚本读取 Vue 状态
- 修改 `_get_yesterday_usage`：同时返回分时数据
- 新增 `_get_recent_daily_usage_breakdown`：获取最近 N 天逐天分时电量
- 新增 HA 传感器实体：`sensor.last_valley_electricity_usage_xxxx` 等

---

## 2. 月度分时电量（从电费账单明细获取）

**优先级：中** | **来源：国网直接查询**

### 原理

国网 95598 有一个「电费账单」页面（URL 不同于用电量页面），展示每月的账单详情。进入某个月的账单明细后，可以获取到该月的谷/平/峰/尖电量。

页面地址：`/osgweb/electricityBill`（需要在 const.py 中添加）

### 获取方式

**Vue 状态读取：**
```javascript
// 账单明细页的 Vue 实例中包含 pvQtyList 数组
// pvQtyList[0] 包含: valQty(谷), flatQty(平), peakQty(峰), sharpQty(尖)
```

**DOM 读取（Fallback）：**
```xpath
// 账单明细页的分时电量 DOM
//div[contains(@class,'wrap_pvQtyJm')]//div[contains(@class,'top_item')]
// 每个分时段包含 name 标签（如"低谷"）和数值
```

### 流程

```
1. 打开电费账单页面
2. 选择年份
3. 展开所有月份（点击"查看更多"）
4. 逐月点击进入账单明细
5. 读取该月的谷/平/峰/尖电量
6. 返回账单列表，继续下一个月
```

### 实现要点

- 新增 `ELECTRIC_BILL_SUMMARY_URL` 常量
- 新增 `_sync_monthly_bill_tou` 方法
- 更新数据库 monthly 表增加 valley/flat/peak/tip 字段

---

## 3. Vue 状态注入获取数据（替代 DOM 解析）

**优先级：高** | **影响：全局优化**

### 原理

ha-95598 项目最核心的创新是：不通过解析 DOM 元素来获取数据，而是直接读取 Vue 组件实例的内部状态。

国网 95598 前端是 Vue.js 应用，所有数据都绑定在 Vue 实例上。通过注入 JS 脚本遍历 DOM 元素的 `__vue__` 属性，可以直接拿到结构化的 JSON 数据，比 XPath 解析 DOM 更稳定、更完整。

### 核心脚本

```javascript
// 遍历页面所有元素，查找 Vue 实例
Array.from(document.querySelectorAll('*'))
  .map(el => {
    const vm = el.__vue__;
    if (!vm) return null;
    // 从 Vue 实例中提取指定 key 的数据
    return { /* 结构化数据 */ };
  })
  .filter(Boolean);
```

### 可获取的所有 Vue 字段

| Vue Key | 页面 | 含义 |
|---------|------|------|
| `mixinGetYuEdata` | 余额页 | 余额信息（sumMoney, prepayBal, estiAmt, historyOwe, penalty, totalPq） |
| `consInfoobj` / `consInfo` | 余额页 | 用户信息 |
| `powerData` | 用电量页 | 年度汇总（dataInfo.totalEleNum, totalEleCost） |
| `mothEleList` / `mothData` | 用电量页 | 月度用电列表（month, monthEleNum, monthEleCost） |
| `sevenEleList` / `new_sevenEleList` | 用电量页 | 日用电列表（含分时 thisVPq/NPq/PPq/TPq） |
| `tariffC` | 用电量页 | 最近总用电 |
| `start` / `end` | 用电量页 | 日期范围 |
| `billNumberList` / `BillList` | 账单页 | 月度账单列表 |
| `billList` | 账单明细页 | 账单详情（含 pvQtyList 分时数据） |
| `prcGroupList` | 账单明细页 | 电费分段明细 |

### 实现要点

- 新增 `scripts/fetchers/vue_state.py`
- 在现有数据获取方法中增加 Vue 状态读取作为首选方案，DOM 解析作为 fallback
- 这种方式更稳定，因为国网网站前端更新频繁，DOM 结构易变，但 Vue 数据字段相对稳定

---

## 4. 电费余额增强信息

**优先级：低** | **来源：国网直接查询**

### 原理

当前项目只获取了余额数字，但国网余额页的 Vue 状态 `mixinGetYuEdata` 实际包含更多字段：

| 字段 | 含义 |
|------|------|
| `amtTime` | 余额更新时间 |
| `sumMoney` | 总余额 |
| `prepayBal` | 预付费余额 |
| `estiAmt` | 预估金额 |
| `historyOwe` | 历史欠费 |
| `penalty` | 违约金 |
| `totalPq` | 总用电量 |
| `consNo` | 用户编号 |

### 实现要点

- 可将这些额外字段存入 HA 传感器属性中
- 作为现有 `_get_electric_balance` 的增强

---

## 5. 断点续传机制

**优先级：低** | **来源：ha-95598 设计**

### 原理

ha-95598 实现了一套进度追踪系统，将每个用户的当前抓取进度（balance → yearly → monthly → daily → tou → persist → billing → complete）保存到缓存中。如果中途中断，下次运行时跳过已完成的阶段。

### 实现要点

- 进度存储在 `ha_95598_cache.json` 中
- 每个阶段完成后更新进度
- 下次运行时检查进度，跳过已完成阶段
