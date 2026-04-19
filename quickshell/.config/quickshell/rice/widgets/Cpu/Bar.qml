import QtQuick
import "../../core"
import "../../config"
import "../../services" as Svc

Widget {
    label: Svc.Cpu.percent + "% \uf2db"
    labelColor: Theme.fg0
}
