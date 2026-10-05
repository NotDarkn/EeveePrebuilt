import Foundation
import Orion

struct RemoteFlagsGroup: HookGroup {}

private enum Resolve {
    static func bool(_ key: NSString, _ orig: Bool, _ start: UInt64) -> Bool {
        let value = RemoteFlags.shared.resolve(key as String, kind: .bool, orig: orig, since: start)
        return (value as? NSNumber)?.boolValue ?? orig
    }

    static func int(_ key: NSString, _ lower: Int, _ upper: Int, _ orig: Int, _ start: UInt64) -> Int {
        let value = RemoteFlags.shared.resolve(key as String, kind: .int, orig: orig, lower: lower, upper: upper, since: start)
        guard let number = value as? NSNumber else { return orig }
        return min(max(number.intValue, lower), upper)
    }

    static func choice(_ key: NSString, _ values: NSArray, _ orig: AnyObject, _ start: UInt64) -> AnyObject {
        let value = RemoteFlags.shared.resolve(
            key as String, kind: .choice, orig: orig,
            options: values.compactMap { $0 as? String }, since: start
        )
        guard let string = value as? NSString, values.contains(string) else { return orig }
        return string
    }
}

class ConfigurationProviderHook: ClassHook<NSObject> {
    typealias Group = RemoteFlagsGroup
    static let targetName = "_TtC22RemoteConfigurationSDK25ConfigurationProviderImpl"

    func boolValueForId(_ key: NSString, defaultValue: Bool) -> Bool {
        let value = orig.boolValueForId(key, defaultValue: defaultValue)
        return Resolve.bool(key, value, mach_absolute_time())
    }

    func intValueForId(_ key: NSString, lower: Int, upper: Int, defaultValue: Int) -> Int {
        let value = orig.intValueForId(key, lower: lower, upper: upper, defaultValue: defaultValue)
        return Resolve.int(key, lower, upper, value, mach_absolute_time())
    }

    func enumValueForId(_ key: NSString, values: NSArray, defaultValue: AnyObject) -> AnyObject {
        let value = orig.enumValueForId(key, values: values, defaultValue: defaultValue)
        return Resolve.choice(key, values, value, mach_absolute_time())
    }
}

// Pure Swift class (no NSObject root), which Orion can't target; its @objc methods are swapped directly.
private enum ObservableProviderSwizzle {
    static let targetName = "_TtC22RemoteConfigurationSDK35ObservableConfigurationProviderImpl"

    static func install() -> Int {
        guard let cls = NSClassFromString(targetName) else { return 0 }
        var count = 0

        let boolSel = NSSelectorFromString("boolValueForId:defaultValue:")
        if let method = class_getInstanceMethod(cls, boolSel) {
            typealias Fn = @convention(c) (AnyObject, Selector, NSString, Bool) -> Bool
            let original = unsafeBitCast(method_getImplementation(method), to: Fn.self)
            let block: @convention(block) (AnyObject, NSString, Bool) -> Bool = { this, key, fallback in
                Resolve.bool(key, original(this, boolSel, key, fallback), mach_absolute_time())
            }
            method_setImplementation(method, imp_implementationWithBlock(block))
            count += 1
        }

        let intSel = NSSelectorFromString("intValueForId:lower:upper:defaultValue:")
        if let method = class_getInstanceMethod(cls, intSel) {
            typealias Fn = @convention(c) (AnyObject, Selector, NSString, Int, Int, Int) -> Int
            let original = unsafeBitCast(method_getImplementation(method), to: Fn.self)
            let block: @convention(block) (AnyObject, NSString, Int, Int, Int) -> Int = { this, key, lower, upper, fallback in
                Resolve.int(key, lower, upper, original(this, intSel, key, lower, upper, fallback), mach_absolute_time())
            }
            method_setImplementation(method, imp_implementationWithBlock(block))
            count += 1
        }

        let enumSel = NSSelectorFromString("enumValueForId:values:defaultValue:")
        if let method = class_getInstanceMethod(cls, enumSel) {
            typealias Fn = @convention(c) (AnyObject, Selector, NSString, NSArray, AnyObject) -> AnyObject
            let original = unsafeBitCast(method_getImplementation(method), to: Fn.self)
            let block: @convention(block) (AnyObject, NSString, NSArray, AnyObject) -> AnyObject = { this, key, values, fallback in
                Resolve.choice(key, values, original(this, enumSel, key, values, fallback), mach_absolute_time())
            }
            method_setImplementation(method, imp_implementationWithBlock(block))
            count += 1
        }
        return count
    }
}

func activateRemoteFlags() {
    _ = RemoteFlags.launchOverrides
    let flags = RemoteFlags.shared
    guard flags.needsHooks else {
        eeveeLog("[EeveeSpotify][Flags] Off (no overrides, catalog current)")
        return
    }
    guard NSClassFromString(ConfigurationProviderHook.targetName) != nil else {
        eeveeLog("[EeveeSpotify][Flags] Skipped: provider classes missing")
        return
    }
    let start = CFAbsoluteTimeGetCurrent()
    flags.prepare()
    RemoteFlagsGroup().activate()
    let observable = ObservableProviderSwizzle.install()
    eeveeLog("[EeveeSpotify][Flags] Active: %d overrides, %d forced, observable %d/3, catalog %@ (%.2f ms)",
          RemoteFlags.overrides.count, flags.forced.count, observable,
          flags.catalogIsCurrent ? "current" : "capturing",
          (CFAbsoluteTimeGetCurrent() - start) * 1000)
}
