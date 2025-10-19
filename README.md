# Time Logger Add-On

This is an example Home Assistant plugin that sends the current timestamp through MQTT at regular intervals.
The add-on is designed to demonstrate how to create a basic Home Assistant add-on that integrates with MQTT.

## Features

- Periodically publishes the current timestamp to an MQTT topic.
- Easy to configure through the Home Assistant GUI.

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
   - After installation, navigate to the **Configuration** tab.
   - Set the following options:
     - `mqtt_host`: The hostname of your MQTT broker (default is `localhost`, check on mosquitto plug-in info page to see the hostname).
     - `mqtt_user`: Your MQTT username.
     - `mqtt_pass`: Your MQTT password.
   - Click **Save**.

4. **Start the Add-On**:
   - Go to the **Info** tab and click on **Start** to run the add-on.

## Automation Example

You can set up an automation in Home Assistant to receive notifications whenever the timestamp is published. Here’s an example automation configuration:

```yaml
alias: test mqtt
description: ""
triggers:
  - trigger: mqtt
    topic: home/time_logger
    enabled: true
conditions: []
actions:
  - action: notify.notify
    metadata: {}
    data:
      message: "Received timestamp: {{ trigger.payload }}"
      title: test
mode: single

```
