import SwiftUI
import AppKit

struct Drive: Identifiable {
    let url: URL
    let name: String
    let internalDisk: Bool
    let local: Bool
    let ejectable: Bool
    let total: Int64
    let available: Int64
    var id: String { url.path }
    var canEject: Bool { !internalDisk && (ejectable || !local) && url.path != "/" }
    var kind: String { internalDisk ? "Internal" : (local ? "External / disk image" : "Network") }

    static func read(_ url: URL) -> Drive? {
        // Query keys separately: one unsupported SMB metadata key must not
        // discard a mounted volume or hide its other available properties.
        let name = try? url.resourceValues(forKeys: [.volumeNameKey]).volumeName
        let local = (try? url.resourceValues(forKeys: [.volumeIsLocalKey]).volumeIsLocal) ?? true
        let internalDisk = (try? url.resourceValues(forKeys: [.volumeIsInternalKey]).volumeIsInternal) ?? local
        let ejectable = (try? url.resourceValues(forKeys: [.volumeIsEjectableKey]).volumeIsEjectable) ?? false
        let removable = (try? url.resourceValues(forKeys: [.volumeIsRemovableKey]).volumeIsRemovable) ?? false
        let total = (try? url.resourceValues(forKeys: [.volumeTotalCapacityKey]).volumeTotalCapacity) ?? 0
        let available = (try? url.resourceValues(forKeys: [.volumeAvailableCapacityKey]).volumeAvailableCapacity) ?? 0
        return Drive(url: url, name: name ?? (url.path == "/" ? "Macintosh HD" : url.lastPathComponent),
                     internalDisk: internalDisk, local: local, ejectable: ejectable || removable,
                     total: Int64(total), available: Int64(available))
    }
}

@MainActor
final class DriveStore: ObservableObject {
    @Published var drives: [Drive] = []
    @Published var busy: String?
    @Published var message: String?
    private var observers: [NSObjectProtocol] = []

    init() {
        refresh()
        for name in [NSWorkspace.didMountNotification, NSWorkspace.didUnmountNotification, NSWorkspace.didRenameVolumeNotification] {
            observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            })
        }
    }

    func refresh() {
        var urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: nil, options: [.skipHiddenVolumes]) ?? []
        // The startup volume should remain visible even if enumeration fails.
        urls.append(URL(fileURLWithPath: "/", isDirectory: true))
        // Finder mounts normally live here. Only accept actual volume roots,
        // never arbitrary folders left behind by disconnected devices.
        let candidates = (try? FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: "/Volumes"), includingPropertiesForKeys: [.isVolumeKey], options: [.skipsHiddenFiles])) ?? []
        for candidate in candidates {
            let resolved = candidate.resolvingSymlinksInPath()
            if (try? resolved.resourceValues(forKeys: [.isVolumeKey]).isVolume) == true {
                urls.append(resolved)
            }
        }
        var seen = Set<String>()
        urls = urls.filter { seen.insert($0.standardizedFileURL.path).inserted }
        drives = urls.compactMap(Drive.read).sorted {
            if $0.internalDisk != $1.internalDisk { return !$0.internalDisk }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    func eject(_ drive: Drive) {
        guard busy == nil, let current = Drive.read(drive.url), current.canEject else { return }
        busy = drive.id
        message = nil
        Task {
            let error = await Task.detached(priority: .userInitiated) { () -> String? in
                do {
                    try NSWorkspace.shared.unmountAndEjectDevice(at: drive.url)
                    return nil
                } catch { return error.localizedDescription }
            }.value
            busy = nil
            message = error.map { "Couldn’t eject \(drive.name): \($0) Close files or apps using this drive and try again." } ?? "\(drive.name) was ejected."
            refresh()
        }
    }
}

struct DrivePanel: View {
    @ObservedObject var store: DriveStore
    @AppStorage("showOnlyEjectableDrives") private var showOnlyEjectableDrives = true
    private var visibleDrives: [Drive] {
        store.drives.filter { !showOnlyEjectableDrives || $0.canEject }
    }
    private func bytes(_ n: Int64) -> String { ByteCountFormatter.string(fromByteCount: n, countStyle: .file) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("DriveBar").font(.title2.bold())
                    Text("\(visibleDrives.count) of \(store.drives.count) mounted volumes").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button { store.refresh() } label: { Image(systemName: "arrow.clockwise") }
                    .help("Refresh drives").accessibilityLabel("Refresh drives")
            }
            Divider()
            Toggle("Show only ejectable drives", isOn: $showOnlyEjectableDrives)
                .toggleStyle(.switch).controlSize(.small)
                .help("Hide internal and non-ejectable volumes. Mounted network shares remain visible.")
            if visibleDrives.isEmpty {
                Text(showOnlyEjectableDrives ? "No ejectable drives connected. Turn off the filter to see all mounted volumes." : "No mounted drives found.").foregroundStyle(.secondary).padding(.vertical)
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(visibleDrives) { drive in
                            HStack(spacing: 12) {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: drive.url.path))
                                    .resizable().frame(width: 36, height: 36)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(drive.name).font(.headline).lineLimit(1)
                                    Text(drive.kind).font(.caption).foregroundStyle(.secondary)
                                    if drive.total > 0 {
                                        ProgressView(value: Double(max(0, drive.total - drive.available)), total: Double(drive.total)).tint(.accentColor)
                                        Text("\(bytes(drive.available)) free of \(bytes(drive.total))")
                                            .font(.caption2).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer(minLength: 0)
                                Button { NSWorkspace.shared.open(drive.url) } label: { Image(systemName: "folder") }
                                    .help("Open \(drive.name) in Finder").accessibilityLabel("Open \(drive.name) in Finder")
                                if store.busy == drive.id {
                                    ProgressView().controlSize(.small).frame(width: 28)
                                } else {
                                    Button { store.eject(drive) } label: { Image(systemName: "eject.fill") }
                                        .disabled(!drive.canEject || store.busy != nil)
                                        .help(drive.canEject ? "Eject \(drive.name)" : "Internal or non-ejectable volume")
                                        .accessibilityLabel("Eject \(drive.name)")
                                }
                            }
                            .padding(12).background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }.frame(height: min(420, CGFloat(visibleDrives.count) * 112))
            }
            if let message = store.message {
                Text(message).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            }
            Divider()
            HStack {
                Text("Eject before unplugging.").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }.keyboardShortcut("q")
            }
        }
        .padding(16).frame(width: 420)
        // Publish the panel's ideal height after filtering instead of accepting
        // the previous, taller window's proposed height.
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { store.refresh() }
    }
}

@main
struct DriveBarApp: App {
    @StateObject private var store = DriveStore()
    var body: some Scene {
        MenuBarExtra("DriveBar", systemImage: "externaldrive") {
            DrivePanel(store: store)
        }.menuBarExtraStyle(.window)
            .windowResizability(.contentSize)
    }
}
