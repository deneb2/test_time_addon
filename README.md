# Modem Monitor & SMS Add-On

This Home Assistant add-on monitors a GSM/cellular modem for events and provides SMS sending capability through MQTT.
The add-on is designed to integrate modem functionality (missed call detection, SMS sending) with Home Assistant.

## Features

- **Modem Event Monitoring**: Detects missed calls from connected GSM modem and publishes to MQTT
- **SMS Sending**: Send SMS messages via MQTT commands from Home Assistant automations
- **Status Feedback**: Publishes SMS delivery status back to MQTT
- **Serial Port Management**: Intelligent locking to prevent conflicts between monitoring and sending
- Easy to configure through the Home Assistant GUI

## Installation Instructions

To install the Time Logger add-on in Home Assistant OS (HAOS), follow these steps:

1. **Add the Repository**:
   - Go to the **Settings** section of Home Assistant.
   - Click on **Add-ons**.
   - Select **Add-on Store** from the menu.
   - Click on the three-dot menu in the top right corner and choose **Repositories**.
   - Add the repository URL where your add-on resides (the URL to your `repository.yaml`).

2. **Install the Add-On**:
   - Find **Time Logger Add-On** in your add-on store.
   - Click on it and then click on the **Install** button.

3. **Configure the Add-On**:
   After installation, navigate to the **Configuration** tab. Set the following options:
   - `mqtt_host`: The hostname of your MQTT broker (default is `localhost`).
   - `mqtt_port`: The port of your MQTT broker (default is `1883`).
   - `mqtt_user`: Your MQTT username.
   - `mqtt_pass`: Your MQTT password.
   - `mqtt_topic`: The base topic for modem events (default is `home/time_logger`).
   - `serial_port`: The serial port where your GSM modem is connected (default is `/dev/ttyUSB2`).
   - Click **Save**.

4. **Start the Add-On**:
   - Go to the **Info** tab and click on **Start** to run the add-on.

## MQTT Topics

The add-on uses the following MQTT topics (assuming `mqtt_topic` is set to `home/time_logger`):

- **Subscribe Topics** (add-on listens to these):
  - `home/time_logger/send_sms` - Send SMS commands to the modem

- **Publish Topics** (add-on publishes to these):
  - `home/time_logger` - Modem events (missed calls, etc.)
  - `home/time_logger/sms_status` - SMS delivery status feedback

## Sending SMS from Home Assistant

### Method 1: Direct MQTT Publish

Use the `mqtt.publish` service in your automations:

```yaml
alias: "Send SMS Alert"
description: "Send SMS when motion detected"
triggers:
  - trigger: state
    entity_id: binary_sensor.motion_detector
    to: "on"
conditions: []
actions:
  - action: mqtt.publish
    data:
      topic: "home/time_logger/send_sms"
      payload: >
        {
          "number": "+1234567890",
          "message": "Motion detected at {{ now().strftime('%H:%M:%S') }}!"
        }
mode: single
```

### Method 2: Create a Notify Service (Recommended)

Add to your `configuration.yaml`:

```yaml
notify:
  - name: sms_modem
    platform: mqtt
    command_topic: "home/time_logger/send_sms"
    payload: '{"number": "{{ target }}", "message": "{{ message }}"}'
```

Then use it in automations:

```yaml
alias: "Door Open SMS Alert"
description: "Send SMS when front door opens"
triggers:
  - trigger: state
    entity_id: binary_sensor.front_door
    to: "on"
conditions: []
actions:
  - action: notify.sms_modem
    data:
      target: "+1234567890"
      message: "Front door opened at {{ now().strftime('%H:%M') }}"
mode: single
```

## Automation Examples

### Example 1: Missed Call Notification

Receive Home Assistant notification when someone calls the modem:

```yaml
alias: "Notify on Missed Call"
description: "Get notification when modem receives a call"
triggers:
  - trigger: mqtt
    topic: home/time_logger
    enabled: true
conditions: []
actions:
  - action: notify.notify
    data:
      message: "{{ trigger.payload }}"
      title: "Modem Alert"
mode: single
```

### Example 2: Temperature Alert via SMS

Send SMS when temperature exceeds threshold:

```yaml
alias: "High Temperature SMS Alert"
description: "Send SMS when temperature is too high"
triggers:
  - trigger: numeric_state
    entity_id: sensor.living_room_temperature
    above: 30
conditions: []
actions:
  - action: mqtt.publish
    data:
      topic: "home/time_logger/send_sms"
      payload: >
        {
          "number": "+1234567890",
          "message": "⚠️ Temperature alert! Living room: {{ states('sensor.living_room_temperature') }}°C at {{ now().strftime('%H:%M') }}"
        }
mode: single
```

### Example 3: Alarm System Integration

Send SMS to multiple recipients when alarm is triggered:

```yaml
alias: "Alarm Triggered - SMS Alert"
description: "Send SMS to emergency contacts when alarm triggers"
triggers:
  - trigger: state
    entity_id: alarm_control_panel.home_alarm
    to: "triggered"
conditions: []
actions:
  - action: mqtt.publish
    data:
      topic: "home/time_logger/send_sms"
      payload: >
        {
          "number": "+1234567890",
          "message": "🚨 ALARM TRIGGERED at {{ now().strftime('%Y-%m-%d %H:%M:%S') }}! Check cameras immediately."
        }
  - action: mqtt.publish
    data:
      topic: "home/time_logger/send_sms"
      payload: >
        {
          "number": "+0987654321",
          "message": "🚨 ALARM TRIGGERED at {{ now().strftime('%Y-%m-%d %H:%M:%S') }}! Check cameras immediately."
        }
mode: single
```

### Example 4: Daily Status Report

Send daily SMS with home status:

```yaml
alias: "Daily SMS Status Report"
description: "Send daily home status via SMS"
triggers:
  - trigger: time
    at: "08:00:00"
conditions: []
actions:
  - action: mqtt.publish
    data:
      topic: "home/time_logger/send_sms"
      payload: >
        {
          "number": "+1234567890",
          "message": "Good morning! Home status: Temp {{ states('sensor.temperature') }}°C, All systems OK"
        }
mode: single
```

### Example 5: Power Outage Alert

Alert via SMS when power outage is detected:

```yaml
alias: "Power Outage SMS Alert"
description: "Send SMS when main power fails"
triggers:
  - trigger: state
    entity_id: binary_sensor.power_status
    to: "off"
conditions: []
actions:
  - action: mqtt.publish
    data:
      topic: "home/time_logger/send_sms"
      payload: >
        {
          "number": "+1234567890",
          "message": "⚡ Power outage detected at {{ now().strftime('%H:%M') }}! Running on backup."
        }
mode: single
```

### Example 6: Monitor SMS Delivery Status

Track SMS delivery status:

```yaml
alias: "SMS Delivery Status Monitor"
description: "Log SMS delivery status"
triggers:
  - trigger: mqtt
    topic: home/time_logger/sms_status
conditions: []
actions:
  - action: notify.persistent_notification
    data:
      message: >
        SMS Status: {{ trigger.payload_json.status }}
        To: {{ trigger.payload_json.number }}
        Time: {{ trigger.payload_json.timestamp }}
      title: "SMS Delivery Update"
mode: queued
```

## Troubleshooting

### SMS Not Sending

1. Check the add-on logs for error messages
2. Verify your modem is connected and shows up as `/dev/ttyUSBx`
3. Ensure the serial port in configuration matches your modem
4. Test modem connectivity: `gammu --device /dev/ttyUSB2 --connection at identify`
5. Check MQTT broker connection

### Modem Not Detected

1. Check USB connection
2. Verify device appears in `/dev/` directory
3. Install `usb-modeswitch` if needed
4. Check add-on has proper device permissions

### Conflicts with Other Add-ons

This add-on uses a polling pattern to prevent conflicts when accessing the serial port. If you experience issues:
1. Don't run multiple add-ons that access the same serial port simultaneously
2. Check add-on logs for Gammu errors or serial port access issues
3. Verify only one process is accessing the serial port at a time

## Technical Details

- **Modem Communication**: Uses `socat` for event monitoring and `gammu` for SMS sending
- **Polling Pattern**: Checks for SMS to send (~priority) then polls modem every ~10 seconds
- **Queue System**: File-based queue at `/tmp/sms_queue` for reliable SMS handling
- **No Conflicts**: Sequential access - only one operation touches serial port at a time
- **SMS Format**: JSON payload with `number` and `message` fields
- **Status Feedback**: Publishes success/failure status to MQTT after each SMS attempt
- **Modem Buffering**: Modem buffers missed call notifications, delivered when polled
