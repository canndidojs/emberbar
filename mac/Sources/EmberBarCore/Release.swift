import Foundation

/// A parsed release the app may point the user to. The app only ever opens `url` in the browser;
/// it never downloads or runs anything.
public struct ReleaseInfo: Equatable {
    public let version: String
    public let url: URL
}

public enum ReleaseParser {
    public static let tagPrefix = "mac-v"
    static let allowedURLPrefix = "https://github.com/canndidojs/emberbar/releases/"

    /// Newest non-draft, non-prerelease release whose tag is `mac-vX.Y.Z` and whose page is on our repo.
    public static func latest(from data: Data) -> ReleaseInfo? {
        guard let list = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else { return nil }
        var best: ReleaseInfo?
        for item in list {
            guard item["draft"] as? Bool != true, item["prerelease"] as? Bool != true,
                  let tag = item["tag_name"] as? String, tag.hasPrefix(tagPrefix),
                  let html = item["html_url"] as? String, html.hasPrefix(allowedURLPrefix), !html.contains(".."),
                  let url = URL(string: html), url.scheme == "https", url.host == "github.com"
            else { continue }
            let version = String(tag.dropFirst(tagPrefix.count))
            guard parts(version) != nil else { continue }
            if best == nil || isNewer(version, than: best!.version) { best = ReleaseInfo(version: version, url: url) }
        }
        return best
    }

    /// Strict `X.Y.Z` (digits only). Anything else is ignored.
    static func parts(_ v: String) -> [Int]? {
        let p = v.split(separator: ".", omittingEmptySubsequences: false)
        guard p.count == 3 else { return nil }
        let nums = p.compactMap { s -> Int? in
            guard !s.isEmpty, s.count <= 6, s.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
            return Int(s)
        }
        return nums.count == 3 ? nums : nil
    }

    public static func isNewer(_ a: String, than b: String) -> Bool {
        guard let x = parts(a), let y = parts(b) else { return false }
        return x.lexicographicallyPrecedes(y) ? false : x != y
    }
}
