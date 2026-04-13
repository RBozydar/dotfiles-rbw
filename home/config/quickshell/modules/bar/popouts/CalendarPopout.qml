import QtQuick
import qs

Item {
    id: root

    required property var clock

    readonly property var currentDate: root.clock ? root.clock.date : new Date()
    readonly property var weekdayNames: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    readonly property int visibleMonth: currentDate.getMonth()
    readonly property int visibleYear: currentDate.getFullYear()
    readonly property int todayDay: currentDate.getDate()
    readonly property int leadingOffset: {
        const firstDay = new Date(root.visibleYear, root.visibleMonth, 1).getDay();
        return (firstDay + 6) % 7;
    }
    readonly property int daysInMonth: new Date(root.visibleYear, root.visibleMonth + 1, 0).getDate()
    readonly property int daysInPreviousMonth: new Date(root.visibleYear, root.visibleMonth, 0).getDate()
    readonly property var calendarCells: root.buildCalendarCells()

    implicitWidth: 330
    implicitHeight: calendarColumn.implicitHeight

    function buildCalendarCells(): var {
        const cells = [];

        for (let index = 0; index < 42; index += 1) {
            const dayIndex = index - root.leadingOffset + 1;
            let day = dayIndex;
            let inCurrentMonth = true;

            if (dayIndex <= 0) {
                day = root.daysInPreviousMonth + dayIndex;
                inCurrentMonth = false;
            } else if (dayIndex > root.daysInMonth) {
                day = dayIndex - root.daysInMonth;
                inCurrentMonth = false;
            }

            cells.push({
                day: day,
                inCurrentMonth: inCurrentMonth,
                isToday: inCurrentMonth && day === root.todayDay
            });
        }

        return cells;
    }

    Column {
        id: calendarColumn

        width: root.implicitWidth
        spacing: 12

        Text {
            text: Qt.formatDateTime(root.currentDate, "MMMM yyyy")
            color: Theme.text
            font.family: Theme.fontSans
            font.pixelSize: 22
            font.weight: Font.DemiBold
        }

        Text {
            text: Qt.formatDateTime(root.currentDate, "dddd, yyyy-MM-dd")
            color: Theme.textMuted
            font.family: Theme.fontSans
            font.pixelSize: 13
        }

        Row {
            width: parent.width
            spacing: 6

            Repeater {
                model: root.weekdayNames

                Text {
                    width: 42
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: Theme.textMuted
                    font.family: Theme.fontSans
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
            }
        }

        Grid {
            columns: 7
            columnSpacing: 6
            rowSpacing: 6

            Repeater {
                model: root.calendarCells

                Rectangle {
                    required property var modelData

                    width: 42
                    height: 36
                    radius: 12
                    color: modelData.isToday ? Theme.accent : (modelData.inCurrentMonth ? Theme.chip : "transparent")
                    border.width: modelData.inCurrentMonth && !modelData.isToday ? 1 : 0
                    border.color: Theme.border
                    opacity: modelData.inCurrentMonth ? 1 : 0.42

                    Text {
                        anchors.centerIn: parent
                        text: parent.modelData.day
                        color: parent.modelData.isToday ? Theme.panelSolid : Theme.text
                        font.family: Theme.fontMono
                        font.pixelSize: 13
                        font.weight: parent.modelData.isToday ? Font.Black : Font.DemiBold
                    }
                }
            }
        }
    }
}
