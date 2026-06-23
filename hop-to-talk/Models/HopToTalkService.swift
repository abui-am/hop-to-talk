import Foundation
import WiFiAware

nonisolated let hopTalkServiceName = "_hop-talk._udp"

extension WAPublishableService {
    static var hopTalkService: WAPublishableService? {
        allServices[hopTalkServiceName]
    }
}

extension WASubscribableService {
    static var hopTalkService: WASubscribableService? {
        allServices[hopTalkServiceName]
    }
}

enum WiFiAwareSupport {
    static var isAvailable: Bool {
        WACapabilities.supportedFeatures.contains(.wifiAware)
    }
}
