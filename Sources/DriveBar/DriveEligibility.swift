import Foundation

/// Physical removability and safe unmounting are different capabilities.
/// USB SSDs and some card readers report fixed media but can still be ejected.
enum DriveEligibility {
    static func canEject(path: String, local: Bool, internalDisk: Bool?, removable: Bool) -> Bool {
        let path = URL(fileURLWithPath: path).standardizedFileURL.path
        guard path != "/", path != "/System/Volumes", !path.hasPrefix("/System/Volumes/") else { return false }
        // A built-in SD reader can be on an internal bus while its card is
        // removable. Protect system mounts above, then honor media evidence.
        if removable { return true }
        if internalDisk == true { return false }
        if !local { return true }
        if internalDisk == false { return true }
        // Unknown device location requires positive removable-media evidence.
        return false
    }
}
