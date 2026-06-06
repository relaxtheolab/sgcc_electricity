# MQTT 版本测试指南

## 准备工作

### 1. 安装 MQTT Broker（如果还没有）

Home Supervisor 用户通常已经内置了 Mosquitto：

```bash
# 安装 Mosquitto Add-on
ha supervisor addons install core_mosquitto

# 配置 Mosquitto（禁用认证以简化测试）
```

### 2. 启用 Home Assistant MQTT 集成

1. 进入 Home Assistant → Settings → Devices & services
2. 点击 "Add integration"
3. 搜索并添加 "MQTT"
4. 配置连接信息（如果 Mosquitto 在本地，通常使用 `homeassistant.local:1883`）

### 3. 测试 MQTT 连接

使用 MQTT Explorer 或 MQTTX 等工具测试连接：

- Broker: `homeassistant.local` 或你的 MQTT Broker 地址
- Port: `1883`
- Username/Password: 如果有的话

## 配置测试

### Docker Compose 方式

1. 编辑 `.env` 文件：

```env
PHONE_NUMBER=your_phone_number
PASSWORD=your_password

# 配置 MQTT
MQTT_HOST=homeassistant.local
MQTT_PORT=1883
MQTT_USERNAME=your_username    # 如果有认证
MQTT_PASSWORD=your_password    # 如果有认证

# 注释掉 REST API 配置（可选）
# HASS_URL=http://homeassistant:8123/
# HASS_TOKEN=your_token
```

2. 启动服务：

```bash
docker-compose up -d --force-recreate
docker-compose logs -f ha_sgcc_electricity
```

3. 查看日志，确认 MQTT 连接成功：

```
2026-06-06 22:00:00  [INFO] ---- 正在连接 MQTT Broker: homeassistant.local:1883
2026-06-06 22:00:00  [INFO] ---- MQTT 连接成功 (reason_code: 0)
2026-06-06 22:00:00  [INFO] ---- 使用 MQTT Discovery 方式推送数据到: homeassistant.local
```

### Add-on 方式

1. 进入 Home Assistant → Settings → Add-ons → 国家电网电费数据获取
2. 在 Configuration 中添加：

```yaml
mqtt_host: "homeassistant.local"
mqtt_port: 1883
# mqtt_username: "your_username"
# mqtt_password: "your_password"
```

3. 保存配置并重启 Add-on

## 验证实体创建

### 1. 检查 Home Assistant

进入 Home Assistant → Settings → Devices & services，应该会看到新的设备：

- 设备名称：`住宅（1234）` 或 `国家电网电费-1234`
- 制造商：SGCC
- 模型：国家电网电费数据获取

### 2. 检查实体

点击设备进入，应该看到以下实体：

```
sensor.electricity_charge_balance_1234
sensor.last_electricity_usage_1234
sensor.yearly_electricity_usage_1234
sensor.yearly_electricity_charge_1234
sensor.month_electricity_usage_1234
sensor.month_electricity_charge_1234
sensor.month_valley_usage_1234
sensor.month_flat_usage_1234
sensor.month_peak_usage_1234
sensor.month_tip_usage_1234
sensor.prepay_balance_1234
sensor.step_used_step1_1234
sensor.step_remain_step1_1234
sensor.step_used_step2_1234
sensor.step_remain_step2_1234
sensor.step_used_step3_1234
sensor.step_total_usage_1234
sensor.step_stage_1234
```

### 3. 检查实体状态

点击任意实体，确认：
- 状态值正常
- 单位显示正确（CNY 或 kWh）
- 图标正常显示
- 属性（attributes）包含正确的信息

## MQTT 消息验证

### 1. 使用 MQTT Explorer 订阅

订阅主题：`homeassistant/sensor/#`

应该看到以下消息：

#### Discovery 配置消息（retain=true）

主题：`homeassistant/sensor/sensor.electricity_charge_balance_1234/config`

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
  "icon": "mdi:cash",
  "object_id": "electricity_charge_balance_1234"
}
```

#### 状态消息（retain=true）

主题：`homeassistant/sensor/sensor.electricity_charge_balance_1234/state`

```
150.0
```

### 2. 测试数据更新

等待数据同步完成后，检查状态消息是否更新：

```bash
# 使用 mosquitto_sub 订阅
mosquitto_sub -h homeassistant.local -t "homeassistant/sensor/sensor.electricity_charge_balance_1234/state" -v
```

应该看到更新后的值。

## 故障排查

### 问题 1：MQTT 连接失败

**症状**：
```
[ERROR] ---- MQTT 客户端初始化失败: [Errno 111] Connection refused
```

**解决方案**：
1. 确认 MQTT Broker 是否运行
2. 确认 MQTT_HOST 和 MQTT_PORT 是否正确
3. 检查防火墙设置
4. 如果使用 Docker，确保网络配置正确

### 问题 2：Home Assistant 未发现实体

**症状**：MQTT 消息已发送，但 HA 中看不到实体

**解决方案**：
1. 确认 MQTT 集成已启用
2. 检查 MQTT 集成的连接状态
3. 查看 Home Assistant 日志，确认是否有 MQTT 相关错误
4. 尝试手动触发 MQTT Discovery：发送 LWT 消息

### 问题 3：实体状态未更新

**症状**：实体已创建，但状态值不更新

**解决方案**：
1. 检查程序日志，确认 MQTT 消息是否发送
2. 使用 MQTT 工具订阅状态主题，确认消息是否到达
3. 检查实体的 "Last updated" 时间
4. 尝试手动刷新实体

### 问题 4：实体命名冲突

**症状**：实体 ID 被修改或添加后缀

**解决方案**：
1. 删除旧的 REST API 实体
2. 重启 Home Assistant
3. 等待 MQTT Discovery 重新创建实体

## 性能测试

### 1. 监控 MQTT 消息流量

使用 MQTT 监控工具查看：
- 消息频率
- 消息大小
- 网络带宽占用

预期：
- 每次同步：约 15 个传感器 × 2 条消息（config + state）= 30 条
- 消息大小：config 约 500 字节，state 约 10 字节
- 每天同步 2 次，总流量约 30 KB/天

### 2. 监控 CPU 和内存使用

```bash
docker stats ha_sgcc_electricity
```

预期：
- CPU 使用：< 5%（空闲时）
- 内存使用：< 200 MB
- 网络使用：< 1 MB/天

## 迁移验证

如果你之前使用 REST API 版本：

1. **备份数据**：导出 HA 配置和实体状态
2. **删除旧实体**：在 HA 中删除所有 sensor.xxx_xxxx 实体
3. **配置 MQTT**：按照上述步骤配置 MQTT
4. **启动服务**：重启 Docker 或 Add-on
5. **验证实体**：检查是否自动创建了新实体
6. **验证数据**：确认数据值与之前一致
7. **验证卡片**：确认现有卡片无需修改即可正常显示

## 回滚到 REST API

如果 MQTT 方式有问题，可以回滚到 REST API：

1. 注释掉 MQTT 配置：

```env
# MQTT_HOST=homeassistant.local
# MQTT_PORT=1883
```

2. 启用 REST API 配置：

```env
HASS_URL=http://homeassistant:8123/
HASS_TOKEN=your_long_lived_token
```

3. 重启服务

4. 手动配置 template（参考 docs/HA_CONFIG.md）

## 测试清单

- [ ] MQTT Broker 运行正常
- [ ] Home Assistant MQTT 集成已启用
- [ ] 程序成功连接到 MQTT Broker
- [ ] Home Assistant 自动发现了新设备
- [ ] 所有实体都已创建
- [ ] 实体状态值正确
- [ ] 实体属性完整
- [ ] 图标显示正常
- [ ] 单位显示正确
- [ ] 数据定时更新正常
- [ ] HA 重启后数据不丢失
- [ ] 多户号场景正常
- [ ] 历史卡片无需修改即可显示