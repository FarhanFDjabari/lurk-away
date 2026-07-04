import CoreAudio

/// Reads and writes CoreAudio output-device state: the virtual main volume, the mute flag,
/// and the system default output device. Used to blast the alarm on the built-in speakers
/// and to enforce an audible floor while locked.
enum SystemVolume {
    // kAudioHardwareServiceDeviceProperty_VirtualMainVolume ('vmvc') — not surfaced to Swift.
    private static let virtualMainVolumeSelector = AudioObjectPropertySelector(0x766D_7663)

    private static let system = AudioObjectID(kAudioObjectSystemObject)

    static func volumeAddress() -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: virtualMainVolumeSelector,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    static func muteAddress() -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    // MARK: Default output device

    static func defaultOutputDevice() -> AudioDeviceID? {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(system, &address, 0, nil, &size, &deviceID)
        return status == noErr ? deviceID : nil
    }

    static func setDefaultOutputDevice(_ id: AudioDeviceID) {
        var deviceID = id
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let size = UInt32(MemoryLayout<AudioDeviceID>.size)
        AudioObjectSetPropertyData(system, &address, 0, nil, size, &deviceID)
    }

    /// The internal speakers, so the alarm can't be silenced by routing to headphones/AirPlay.
    static func builtInOutputDevice() -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(0)
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr else { return nil }
        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        guard count > 0 else { return nil }
        var devices = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &devices) == noErr else { return nil }

        for device in devices where hasOutputStreams(device) && transportType(device) == kAudioDeviceTransportTypeBuiltIn {
            return device
        }
        return nil
    }

    private static func hasOutputStreams(_ device: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(0)
        guard AudioObjectGetPropertyDataSize(device, &address, 0, nil, &size) == noErr else { return false }
        return size > 0
    }

    private static func transportType(_ device: AudioDeviceID) -> UInt32 {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var transport = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        AudioObjectGetPropertyData(device, &address, 0, nil, &size, &transport)
        return transport
    }

    // MARK: Volume

    static func volume(of device: AudioDeviceID) -> Float? {
        var address = volumeAddress()
        guard AudioObjectHasProperty(device, &address) else { return nil }
        var volume = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &volume)
        return status == noErr ? volume : nil
    }

    static func setVolume(_ value: Float, of device: AudioDeviceID) {
        var address = volumeAddress()
        var settable = DarwinBoolean(false)
        guard AudioObjectIsPropertySettable(device, &address, &settable) == noErr, settable.boolValue else { return }
        var volume = Float32(max(0, min(1, value)))
        let size = UInt32(MemoryLayout<Float32>.size)
        AudioObjectSetPropertyData(device, &address, 0, nil, size, &volume)
    }

    // MARK: Mute

    static func isMuted(of device: AudioDeviceID) -> Bool? {
        var address = muteAddress()
        guard AudioObjectHasProperty(device, &address) else { return nil }
        var muted = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &muted)
        return status == noErr ? (muted != 0) : nil
    }

    static func setMuted(_ muted: Bool, of device: AudioDeviceID) {
        var address = muteAddress()
        var settable = DarwinBoolean(false)
        guard AudioObjectIsPropertySettable(device, &address, &settable) == noErr, settable.boolValue else { return }
        var value = UInt32(muted ? 1 : 0)
        let size = UInt32(MemoryLayout<UInt32>.size)
        AudioObjectSetPropertyData(device, &address, 0, nil, size, &value)
    }
}
