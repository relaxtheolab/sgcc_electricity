# MQTT Discovery 使用指南

## 概述

本项目现在支持两种方式将数据推送到 Home Assistant：

1. **REST API 方式**（默认）：通过 Home Assistant REST API 推送传感器数据
2. **MQTT Discovery 方式**（推荐）：通过 MQTT Discovery 协议自动创建实体

## MQTT Discovery 优势

✅ **无需手动配置 template**：自动在 Home Assistant 中发现并创建实体
✅ **实体命名保持一致**：与现有 REST API 版本相同的命名方式，无需修改卡片
✅ **配置更简单**：只需配置 MQTT Broker 地址，无需 HASS_TOKEN
✅ **资源开销更小**：MQTT 协议更轻量，适合低频数据更新
✅ **状态保持**：MQTT retain 消息确保 HA 重启后数据不丢失

## 配置方法

### 1. 确认 Home Assistant MQTT 集成

在 Home Assistant 中启用 MQTT 集成（Settings → Devices & Services → Add Integration → MQTT）

### 2. 配置环境变量

编辑 `.env` 文件，配置 MQTT 相关参数：

```env
# 方式一：使用 MQTT Discovery（推荐）
MQTT_HOST=192.168.1.100        # MQTT Broker 地址
MQTT_PORT=1883                 # MQTT 端口（默认 1883）
MQTT_USERNAME=your_username    # MQTT 用户名（可选）
MQTT_PASSWORD=your_password    # MQTT 密码（可选）

# 可选配置（通常使用默认值即可）
MQTT_CLIENT_ID=ha_sgcc_electricity
MQTT_TOPIC_PREFIX=homeassistant
MQTT_DEVICE_ID=ha_sgcc_electricity
MQTT_DEVICE_NAME=国家电网电费数据

# 方式二：使用 REST API（保持向后兼容）
# 如果配置了 HASS_URL 和 HASS_TOKEN，会优先使用 REST API
HASS_URL=http://homeassistant:8123/
HASS_TOKEN=your_long_lived_token
```

### 3. 优先级说明

程序会按照以下优先级选择推送方式：

1. 如果配置了 `MQTT_HOST`，使用 MQTT Discovery 方式
2. 否则使用 REST API 方式（需要 `HASS_URL` 和 `HASS_TOKEN`）

### 4. Home Assistant Add-on 配置

在 Add-on 配置中添加 MQTT 相关配置：

```yaml
mqtt_host: "192.168.1.100"
mqtt_port: 1883
mqtt_username: ""
mqtt_password: ""
mqtt_client_id: "ha_sgcc_electricity"
mqtt_topic_prefix: "homeassistant"
mqtt_device_id: "ha_sgcc_electricity"
mqtt_device_name: "国家电网电费数据"
```

## 实体命名

MQTT Discovery 版本保持与 REST API 版本相同的实体命名：

| 实体 | 说明 |
|------|------|
| `sensor.electricity_charge_balance_xxxx` | 电费余额（元） |
| `sensor.last_electricity_usage_xxxx` | 最近一天用电量（kWh） |
| `sensor.yearly_electricity_usage_xxxx` | 今年总用电量（kWh） |
| `sensor.yearly_electricity_charge_xxxx` | 今年总电费（元） |
| `sensor.month_electricity_usage_xxxx` | 最近一个月用电量（kWh） |
| `sensor.month_electricity_charge_xxxx` | 上月总电费（元） |
| `sensor.month_valley_usage_xxxx` | 当月谷时用电量（kWh，**需启用数据库**） |
| `sensor.month_flat_usage_xxxx` | 当月平时用电量（kWh，**需启用数据库**） |
| `sensor.month_peak_usage_xxxx` | 当月峰时用电量（kWh，**需启用数据库**） |
| `sensor.month_tip_usage_xxxx` | 当月尖时用电量（kWh，**需启用数据库**） |
| `sensor.prepay_balance_xxxx` | 预付费余额/应交金额（元） |
| `sensor.step_used_step1_xxxx` | 阶梯一阶已用电量（kWh，住宅用户） |
| `sensor.step_remain_step1_xxxx` | 阶梯一阶剩余电量（kWh，住宅用户） |
| `sensor.step_used_step2_xxxx` | 阶梯二阶已用电量（kWh，住宅用户） |
| `sensor.step_remain_step2_xxxx` | 阶梯二阶剩余电量（kWh，住宅用户） |
| `sensor.step_used_step3_xxxx` | 阶梯三阶已用电量（kWh，住宅用户） |
| `sensor.step_total_usage_xxxx` | 阶梯累计用电量（kWh，住宅用户） |
| `sensor.step_stage_xxxx` | 阶梯当前阶段（1/2/3，住宅用户） |

其中 `xxxx` 为户号后四位。

## MQTT Discovery 工作原理

1. **发现阶段**：程序首次启动时，会向 MQTT Broker 发送传感器配置消息
   - 配置主题：`homeassistant/sensor/{entity_id}/config`
   - 状态主题：`homeassistant/sensor/{entity_id}/state`

2. **Home Assistant 接收**：HA 的 MQTT 集成会自动发现配置消息并创建实体

3. **状态更新**：后续数据更新时，程序只推送状态值到状态主题

4. **状态保持**：所有消息都设置了 retain 标志，确保 HA 重启后数据不丢失

## 设备识别

每个户号会创建一个独立的设备：

- **设备标识符**：`ha_sgcc_electricity_{user_id}`
- **设备名称**：`户名（户号后四位）` 或 `国家电网电费-{户号后四位}`
- **制造商**：SGCC
- **型号**：国家电网电费数据获取

## 与 REST API 版本的对比

| 对比维度 | REST API | MQTT Discovery |
|---------|---------|---------------|
| **配置复杂度** | ⭐⭐ 需要配置 template | ⭐ 只需配置 MQTT 地址 |
| **实体创建** | 手动配置 template | 自动发现创建 |
| **实体命名** | sensor.xxx_xxxx | sensor.xxx_xxxx（相同） |
| **兼容性** | 所有 HA 版本 | 需要 MQTT 集成 |
| **状态保持** | 需要缓存恢复 | retain 消息自动保持 |
| **网络开销** | HTTP 协议 | 轻量级 MQTT |
| **调试难度** | 可直接测试 API | 需 MQTT 工具 |

## 迁移指南

如果你已经使用 REST API 版本，想迁移到 MQTT Discovery 版本：

1. **备份数据**：备份现有的 HA 配置
2. **配置 MQTT**：在 `.env` 中添加 `MQTT_HOST` 等配置
3. **删除旧实体**：在 HA 中删除通过 REST API 创建的传感器实体
4. **重启服务**：重启 Docker 容器或 Add-on
5. **验证实体**：在 HA 中检查是否自动发现了新的实体
6. **更新卡片**：由于实体命名相同，现有卡片无需修改

## 常见问题

### Q: MQTT 和 REST API 可以同时使用吗？

A: 不可以。程序会优先使用 MQTT（如果配置了 `MQTT_HOST`），否则使用 REST API。

### Q: MQTT 连接失败会怎样？

A: 程序会记录错误日志，但不会退出。下次数据更新时会重新尝试连接。

### Q: 如何确认 MQTT Discovery 是否成功？

A: 在 Home Assistant 中查看是否自动发现了新的传感器实体，或检查日志中的 MQTT 连接状态。

### Q: HA 重启后数据会丢失吗？

A: 不会。MQTT 消息设置了 retain 标志，HA 重启后会自动恢复最后的传感器状态。

### Q: 能否使用外网 MQTT Broker？

A: 可以，但建议使用内网 MQTT Broker 以保证稳定性和安全性。

## 技术实现细节

### MQTT 库

使用 `paho-mqtt==2.1.0` 库进行 MQTT 通信。

### 发现配置格式

```json
{
  "name": "电费余额",
  "unique_id": "sensor.electricity_charge_balance_1234",
  "state_topic": "homeassistant/sensor/sensor.electricity_charge_balance_1234/state",
  "device": {
    "identifiers": ["ha_sgcc_electricity_3200000000001234"],
    "name": "住宅（1234）",
    "model": "国家电网电费数据获取",
    "manufacturer": "SGCC",
    "sw_version": "2.0.0"
  },
  "unit_of_measurement": "CNY",
  "device_class": "monetary",
  "state_class": "total",
  "icon": "mdi:cash"
}
```

### 状态消息格式

```
150.0
```

### 属性消息格式（可选）

```json
{
  "last_reset": "2026-06-06, 21:00:00",
  "amount_due": 0.0
}
```