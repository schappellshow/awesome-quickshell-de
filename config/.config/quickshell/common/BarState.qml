pragma Singleton
import QtQuick
import Quickshell

// Transient bar-UI state shared between the bar and IPC (not persisted).
Singleton {
    id: root

    property bool calendarOpen: false

    function toggleCalendar() {
        calendarOpen = !calendarOpen;
    }
}
