import QtQuick
import "../../config"
import "../../services"

StatItem {
    visible: BatteryService.present
    width: visible ? implicitWidth : 0
    icon: BatteryService.icon()
    value: Math.round(BatteryService.percent) + "%"
    iconColor: BatteryService.low ? Theme.bad : BatteryService.charging ? Theme.good : Theme.barTextDim
}
