import CoreAudio
import os

/// While locked, keeps sound audible: routes output to the built-in speakers, unmutes, and
/// enforces a minimum volume so the alarm can't be silenced. Restores the prior output
/// device, volume, and mute state when the device is unlocked.
@MainActor
final class LockAudioGuard {
    private let minVolume: Float = 0.10

    private var device: AudioDeviceID?
    private var savedDevice: AudioDeviceID?
    private var savedVolume: Float?
    private var savedMute: Bool?

    private var volumeAddress = SystemVolume.volumeAddress()
    private var muteAddress = SystemVolume.muteAddress()
    private var volumeListener: AudioObjectPropertyListenerBlock?
    private var muteListener: AudioObjectPropertyListenerBlock?

    func begin() {
        guard device == nil else { return }

        let current = SystemVolume.defaultOutputDevice()
        savedDevice = current
        if let current {
            savedVolume = SystemVolume.volume(of: current)
            savedMute = SystemVolume.isMuted(of: current)
        }

        let builtIn = SystemVolume.builtInOutputDevice()
        if let builtIn, builtIn != current {
            SystemVolume.setDefaultOutputDevice(builtIn)
        }

        guard let target = builtIn ?? current else { return }
        device = target

        SystemVolume.setMuted(false, of: target)
        enforceFloor(on: target)
        installListeners(on: target)
        log.notice("Lock audio guard active — output forced to built-in, unmuted, floor \(Int(self.minVolume * 100))%")
    }

    func end() {
        if let device { removeListeners(on: device) }
        if let saved = savedDevice {
            SystemVolume.setDefaultOutputDevice(saved)
            if let savedVolume { SystemVolume.setVolume(savedVolume, of: saved) }
            if let savedMute { SystemVolume.setMuted(savedMute, of: saved) }
        }
        device = nil
        savedDevice = nil
        savedVolume = nil
        savedMute = nil
        log.notice("Lock audio guard released — prior audio state restored")
    }

    private func enforceFloor(on device: AudioDeviceID) {
        if SystemVolume.isMuted(of: device) == true {
            SystemVolume.setMuted(false, of: device)
        }
        if let volume = SystemVolume.volume(of: device), volume < minVolume {
            SystemVolume.setVolume(minVolume, of: device)
        }
    }

    private func installListeners(on device: AudioDeviceID) {
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            MainActor.assumeIsolated {
                guard let self, let device = self.device else { return }
                self.enforceFloor(on: device)
            }
        }
        volumeListener = block
        muteListener = block
        AudioObjectAddPropertyListenerBlock(device, &volumeAddress, DispatchQueue.main, block)
        AudioObjectAddPropertyListenerBlock(device, &muteAddress, DispatchQueue.main, block)
    }

    private func removeListeners(on device: AudioDeviceID) {
        if let volumeListener {
            AudioObjectRemovePropertyListenerBlock(device, &volumeAddress, DispatchQueue.main, volumeListener)
        }
        if let muteListener {
            AudioObjectRemovePropertyListenerBlock(device, &muteAddress, DispatchQueue.main, muteListener)
        }
        volumeListener = nil
        muteListener = nil
    }
}
