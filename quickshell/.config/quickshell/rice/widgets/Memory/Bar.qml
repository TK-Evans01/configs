import QtQuick
import "../../core"
import "../../config"
import "../../services" as Svc

Widget {
    label: Svc.Memory.percent + "% \uf538"
    labelColor: Theme.fg0
}
