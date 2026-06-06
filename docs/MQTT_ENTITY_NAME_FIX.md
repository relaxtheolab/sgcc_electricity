# MQTT 实体命名问题修复指南

## 问题现象

日志显示正确的英文实体名称：
```
sensor.month_electricity_usage_1372
sensor.yearly_electricity_usage_1372
sensor.yearly_electricity_charge_1372
```

但 Home Assistant 中出现了拼音命名的实体：
```
sensor.fan_dian_dong_che_1372_dang_yue_feng_shi_yong_dian_liang
```

## 问题原因

MQTT Discovery 协议中，如果 `object_id` 没有正确设置或被 HA 忽略，HA 会根据中文的 `name` 字段自动生成拼音实体名称。

可能的原因：
1. **旧版本遗留配置**：旧版代码可能发送了错误的配置，这些配置作为 retain 消息保留在 MQTT broker 中
2. **HA 缓存**：Home Assistant 已经创建了拼音命名的实体，即使新配置正确也不会自动更名

## 解决方案

### 方法一：使用清理脚本（推荐）

我已经创建了清理脚本 `scripts/cleanup_mqtt_entities.py`，它会：
- 清除所有 MQTT retain 消息
- 重置 Discovery 配置

**使用步骤：**

1. 停止当前运行的服务
2. 运行清理脚本：
   ```bash
   cd scripts
   python cleanup_mqtt_entities.py
   ```
3. 在 Home Assistant 中手动删除拼音命名的实体：
   - 设置 → 设备与服务 → 实体
   - 搜索 `fan_dian_dong_che` 或你的用户ID后4位
   - 选中并删除这些实体
4. 重启本服务，让它重新发送正确的配置
5. HA 会自动创建正确的英文命名实体

### 方法二：手动清理

如果无法运行脚本，可以手动操作：

1. **在 Home Assistant 中删除拼音实体**：
   - 设置 → 设备与服务 → 实体
   - 搜索拼音命名的实体并删除

2. **清除 MQTT Broker 的 retain 消息**：
   使用 MQTT 客户端（如 MQTT Explorer）连接到你的 broker，删除所有 `homeassistant/sensor/` 下的 retain 消息

3. **重启服务**：
   ```bash
   docker restart sgcc_electricity
   ```

### 方法三：删除设备重新发现

1. 在 Home Assistant 中：
   - 设置 → 设备与服务 → MQTT → 设备
   - 找到 "国家电网电费" 设备
   - 删除整个设备（会同时删除所有关联实体）
2. 重启本服务
3. HA 会重新发现设备和实体

## 验证修复

修复后，在 Home Assistant 的实体列表中应该看到：
- `sensor.month_electricity_usage_1372` （当月用电量）
- `sensor.month_electricity_charge_1372` （当月电费）
- `sensor.yearly_electricity_usage_1372` （年度用电量）
- 等等...

实体名称与日志中显示的一致。

## 预防措施

当前代码已包含清理逻辑（`mqtt_discovery.py` 第 66-104 行），会在连接时自动清理旧版本的错误配置。首次运行修复后，后续不会再出现此问题。
