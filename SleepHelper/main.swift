import Foundation

/// Privileged LaunchDaemon: the only thing in LurkAway that runs as root.
/// Accepts XPC connections from the LurkAway app and toggles `pmset disablesleep`
/// so the siren can sound with the lid closed while armed. Every path that could
/// leave sleep disabled is backstopped so the setting always reverts.

let machServiceName = "com.lurkaway.sleepd"

/// Only the LurkAway app, signed by our Developer ID team, may connect.
private let clientRequirement =
    "identifier \"dev.djabari.LurkAway\" and anchor apple generic and "
    + "certificate leaf[subject.OU] = \"X7XMQ8S452\""

final class ListenerDelegate: NSObject, NSXPCListenerDelegate {
    let controller = SleepController()

    func listener(_ listener: NSXPCListener,
                  shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.setCodeSigningRequirement(clientRequirement)
        connection.exportedInterface = NSXPCInterface(with: SleepControlProtocol.self)
        connection.exportedObject = controller
        connection.invalidationHandler = { [controller] in controller.clientDisconnected() }
        connection.interruptionHandler = { [controller] in controller.clientDisconnected() }
        connection.resume()
        return true
    }
}

// Clear any stale override left by an unclean shutdown before accepting work.
SleepController.revertOnLaunch()

let delegate = ListenerDelegate()
let listener = NSXPCListener(machServiceName: machServiceName)
listener.delegate = delegate
listener.resume()

RunLoop.main.run()
