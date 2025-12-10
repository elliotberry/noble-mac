//
//  noble_mac.mm
//  noble-mac-native
//
//  Created by Georg Vienna on 28.08.18.
//
#include "noble_mac.h"

#include "napi_objc.h"

#include <string>

namespace {

void EnsureManager(const Napi::CallbackInfo& info, BLEManager* manager) {
    if (!manager) {
        Napi::TypeError::New(info.Env(), "BLEManager has already been cleaned up").ThrowAsJavaScriptException();
        return;
    }
}

void EnsureArgs(const Napi::CallbackInfo& info, size_t expected, const std::string& signature) {
    if (info.Length() < expected) {
        Napi::TypeError::New(info.Env(), "Expected arguments: " + signature).ThrowAsJavaScriptException();
    }
}

NSString* RequireUuidString(const Napi::CallbackInfo& info, size_t idx, const std::string& label) {
    if (info.Length() <= idx || !info[idx].IsString()) {
        Napi::TypeError::New(info.Env(), "Expected string for " + label).ThrowAsJavaScriptException();
        return nil;
    }
    return napiToUuidString(info[idx].As<Napi::String>());
}

NSArray* OptionalUuidArray(const Napi::CallbackInfo& info, size_t idx) {
    if (info.Length() <= idx) {
        return nil;
    }
    return getUuidArray(info[idx]);
}

bool OptionalBool(const Napi::CallbackInfo& info, size_t idx, bool def) {
    if (info.Length() <= idx) {
        return def;
    }
    return getBool(info[idx], def);
}

NSData* RequireData(const Napi::CallbackInfo& info, size_t idx, const std::string& label) {
    if (info.Length() <= idx || !info[idx].IsBuffer()) {
        Napi::TypeError::New(info.Env(), "Expected Buffer for " + label).ThrowAsJavaScriptException();
        return nil;
    }
    return napiToData(info[idx].As<Napi::Buffer<Byte>>());
}

NSNumber* RequireNumber(const Napi::CallbackInfo& info, size_t idx, const std::string& label) {
    if (info.Length() <= idx || !info[idx].IsNumber()) {
        Napi::TypeError::New(info.Env(), "Expected number for " + label).ThrowAsJavaScriptException();
        return nil;
    }
    return napiToNumber(info[idx].As<Napi::Number>());
}

}  // namespace

NobleMac::NobleMac(const Napi::CallbackInfo& info) : ObjectWrap(info) {
}

NobleMac::~NobleMac() {
    Cleanup();
}

void NobleMac::Cleanup() {
    if (manager) {
        manager = nil;
    }
}

Napi::Value NobleMac::Init(const Napi::CallbackInfo& info) {
    Napi::Function emit = info.This().As<Napi::Object>().Get("emit").As<Napi::Function>();
    manager = [[BLEManager alloc] init:info.This() with:emit];
    return info.Env().Undefined();
}

// startScanning(serviceUuids, allowDuplicates)
Napi::Value NobleMac::Scan(const Napi::CallbackInfo& info) {
    EnsureManager(info, manager);
    if (info.Env().IsExceptionPending()) return info.Env().Undefined();
    NSArray* array = getUuidArray(info[0]);
    // default value NO
    auto duplicates = OptionalBool(info, 1, NO);
    [manager scan:array allowDuplicates:duplicates];
    return info.Env().Undefined();
}

// stopScanning()
Napi::Value NobleMac::StopScan(const Napi::CallbackInfo& info) {
    EnsureManager(info, manager);
    if (info.Env().IsExceptionPending()) return info.Env().Undefined();
    [manager stopScan];
    return info.Env().Undefined();
}

// connect(deviceUuid)
Napi::Value NobleMac::Connect(const Napi::CallbackInfo& info) {
    EnsureManager(info, manager);
    EnsureArgs(info, 1, "(string uuid)");
    if (info.Env().IsExceptionPending()) return info.Env().Undefined();
    auto uuid = RequireUuidString(info, 0, "deviceUuid");
    [manager connect:uuid];
    return info.Env().Undefined();
}

// disconnect(deviceUuid)
Napi::Value NobleMac::Disconnect(const Napi::CallbackInfo& info) {
    EnsureManager(info, manager);
    EnsureArgs(info, 1, "(string uuid)");
    if (info.Env().IsExceptionPending()) return info.Env().Undefined();
    auto uuid = RequireUuidString(info, 0, "deviceUuid");
    [manager disconnect:uuid];
    return info.Env().Undefined();
}

// updateRssi(deviceUuid)
Napi::Value NobleMac::UpdateRSSI(const Napi::CallbackInfo& info) {
    EnsureManager(info, manager);
    EnsureArgs(info, 1, "(string uuid)");
    if (info.Env().IsExceptionPending()) return info.Env().Undefined();
    auto uuid = RequireUuidString(info, 0, "deviceUuid");
    [manager updateRSSI:uuid];
    return info.Env().Undefined();
}

// discoverServices(deviceUuid, uuids)
Napi::Value NobleMac::DiscoverServices(const Napi::CallbackInfo& info) {
    EnsureManager(info, manager);
    EnsureArgs(info, 1, "(string uuid[, string[] serviceUuids])");
    if (info.Env().IsExceptionPending()) return info.Env().Undefined();
    auto uuid = RequireUuidString(info, 0, "deviceUuid");
    NSArray* array = OptionalUuidArray(info, 1);
    [manager discoverServices:uuid serviceUuids:array];
    return info.Env().Undefined();
}

// discoverIncludedServices(deviceUuid, serviceUuid, serviceUuids)
Napi::Value NobleMac::DiscoverIncludedServices(const Napi::CallbackInfo& info) {
    EnsureManager(info, manager);
    EnsureArgs(info, 2, "(string uuid, string serviceUuid[, string[] serviceUuids])");
    if (info.Env().IsExceptionPending()) return info.Env().Undefined();
    auto uuid = RequireUuidString(info, 0, "deviceUuid");
    auto service = RequireUuidString(info, 1, "serviceUuid");
    NSArray* serviceUuids = OptionalUuidArray(info, 2);
    [manager discoverIncludedServices:uuid forService:service services:serviceUuids];
    return info.Env().Undefined();
}

// discoverCharacteristics(deviceUuid, serviceUuid, characteristicUuids)
Napi::Value NobleMac::DiscoverCharacteristics(const Napi::CallbackInfo& info) {
    EnsureManager(info, manager);
    EnsureArgs(info, 2, "(string uuid, string serviceUuid[, string[] characteristicUuids])");
    if (info.Env().IsExceptionPending()) return info.Env().Undefined();
    auto uuid = RequireUuidString(info, 0, "deviceUuid");
    auto service = RequireUuidString(info, 1, "serviceUuid");
    NSArray* characteristics = OptionalUuidArray(info, 2);
    [manager discoverCharacteristics:uuid forService:service characteristics:characteristics];
    return info.Env().Undefined();
}

// read(deviceUuid, serviceUuid, characteristicUuid)
Napi::Value NobleMac::Read(const Napi::CallbackInfo& info) {
    EnsureManager(info, manager);
    EnsureArgs(info, 3, "(string uuid, string serviceUuid, string characteristicUuid)");
    if (info.Env().IsExceptionPending()) return info.Env().Undefined();
    auto uuid = RequireUuidString(info, 0, "deviceUuid");
    auto service = RequireUuidString(info, 1, "serviceUuid");
    auto characteristic = RequireUuidString(info, 2, "characteristicUuid");
    [manager read:uuid service:service characteristic:characteristic];
    return info.Env().Undefined();
}

// write(deviceUuid, serviceUuid, characteristicUuid, data, withoutResponse)
Napi::Value NobleMac::Write(const Napi::CallbackInfo& info) {
    EnsureManager(info, manager);
    EnsureArgs(info, 5, "(string uuid, string serviceUuid, string characteristicUuid, Buffer data, boolean withoutResponse)");
    if (info.Env().IsExceptionPending()) return info.Env().Undefined();
    auto uuid = RequireUuidString(info, 0, "deviceUuid");
    auto service = RequireUuidString(info, 1, "serviceUuid");
    auto characteristic = RequireUuidString(info, 2, "characteristicUuid");
    auto data = RequireData(info, 3, "data");
    auto withoutResponse = info[4].As<Napi::Boolean>().Value();
    [manager write:uuid service:service characteristic:characteristic data:data withoutResponse:withoutResponse];
    return info.Env().Undefined();
}

// notify(deviceUuid, serviceUuid, characteristicUuid, notify)
Napi::Value NobleMac::Notify(const Napi::CallbackInfo& info) {
    EnsureManager(info, manager);
    EnsureArgs(info, 4, "(string uuid, string serviceUuid, string characteristicUuid, boolean state)");
    if (info.Env().IsExceptionPending()) return info.Env().Undefined();
    auto uuid = RequireUuidString(info, 0, "deviceUuid");
    auto service = RequireUuidString(info, 1, "serviceUuid");
    auto characteristic = RequireUuidString(info, 2, "characteristicUuid");
    auto on = info[3].As<Napi::Boolean>().Value();
    [manager notify:uuid service:service characteristic:characteristic on:on];
    return info.Env().Undefined();
}

// discoverDescriptors(deviceUuid, serviceUuid, characteristicUuid)
Napi::Value NobleMac::DiscoverDescriptors(const Napi::CallbackInfo& info) {
    EnsureManager(info, manager);
    EnsureArgs(info, 3, "(string uuid, string serviceUuid, string characteristicUuid)");
    if (info.Env().IsExceptionPending()) return info.Env().Undefined();
    auto uuid = RequireUuidString(info, 0, "deviceUuid");
    auto service = RequireUuidString(info, 1, "serviceUuid");
    auto characteristic = RequireUuidString(info, 2, "characteristicUuid");
    [manager discoverDescriptors:uuid service:service characteristic:characteristic];
    return info.Env().Undefined();
}

// readValue(deviceUuid, serviceUuid, characteristicUuid, descriptorUuid)
Napi::Value NobleMac::ReadValue(const Napi::CallbackInfo& info) {
    EnsureManager(info, manager);
    EnsureArgs(info, 4, "(string uuid, string serviceUuid, string characteristicUuid, string descriptorUuid)");
    if (info.Env().IsExceptionPending()) return info.Env().Undefined();
    auto uuid = RequireUuidString(info, 0, "deviceUuid");
    auto service = RequireUuidString(info, 1, "serviceUuid");
    auto characteristic = RequireUuidString(info, 2, "characteristicUuid");
    auto descriptor = RequireUuidString(info, 3, "descriptorUuid");
    [manager readValue:uuid service:service characteristic:characteristic descriptor:descriptor];
    return info.Env().Undefined();
}

// writeValue(deviceUuid, serviceUuid, characteristicUuid, descriptorUuid, data)
Napi::Value NobleMac::WriteValue(const Napi::CallbackInfo& info) {
    EnsureManager(info, manager);
    EnsureArgs(info, 5, "(string uuid, string serviceUuid, string characteristicUuid, string descriptorUuid, Buffer data)");
    if (info.Env().IsExceptionPending()) return info.Env().Undefined();
    auto uuid = RequireUuidString(info, 0, "deviceUuid");
    auto service = RequireUuidString(info, 1, "serviceUuid");
    auto characteristic = RequireUuidString(info, 2, "characteristicUuid");
    auto descriptor = RequireUuidString(info, 3, "descriptorUuid");
    auto data = RequireData(info, 4, "data");
    [manager writeValue:uuid service:service characteristic:characteristic descriptor:descriptor data: data];
    return info.Env().Undefined();
}

// readHandle(deviceUuid, handle)
Napi::Value NobleMac::ReadHandle(const Napi::CallbackInfo& info) {
    EnsureManager(info, manager);
    EnsureArgs(info, 2, "(string uuid, number handle)");
    if (info.Env().IsExceptionPending()) return info.Env().Undefined();
    auto uuid = RequireUuidString(info, 0, "deviceUuid");
    auto handle = RequireNumber(info, 1, "handle");
    [manager readHandle:uuid handle:handle];
    return info.Env().Undefined();
}

// writeHandle(deviceUuid, handle, data, (unused)withoutResponse)
Napi::Value NobleMac::WriteHandle(const Napi::CallbackInfo& info) {
    EnsureManager(info, manager);
    EnsureArgs(info, 3, "(string uuid, number handle, Buffer data)");
    if (info.Env().IsExceptionPending()) return info.Env().Undefined();
    auto uuid = RequireUuidString(info, 0, "deviceUuid");
    auto handle = RequireNumber(info, 1, "handle");
    auto data = RequireData(info, 2, "data");
    [manager writeHandle:uuid handle:handle data: data];
    return info.Env().Undefined();
}

Napi::Value NobleMac::Stop(const Napi::CallbackInfo& info) {
    EnsureManager(info, manager);
    if (info.Env().IsExceptionPending()) return info.Env().Undefined();
    Cleanup();
    return info.Env().Undefined();
}

Napi::Function NobleMac::GetClass(Napi::Env env) {
    return DefineClass(env, "NobleMac", {
        NobleMac::InstanceMethod("init", &NobleMac::Init),
        NobleMac::InstanceMethod("startScanning", &NobleMac::Scan),
        NobleMac::InstanceMethod("stopScanning", &NobleMac::StopScan),
        NobleMac::InstanceMethod("connect", &NobleMac::Connect),
        NobleMac::InstanceMethod("disconnect", &NobleMac::Disconnect),
        NobleMac::InstanceMethod("updateRssi", &NobleMac::UpdateRSSI),
        NobleMac::InstanceMethod("discoverServices", &NobleMac::DiscoverServices),
        NobleMac::InstanceMethod("discoverIncludedServices", &NobleMac::DiscoverIncludedServices),
        NobleMac::InstanceMethod("discoverCharacteristics", &NobleMac::DiscoverCharacteristics),
        NobleMac::InstanceMethod("read", &NobleMac::Read),
        NobleMac::InstanceMethod("write", &NobleMac::Write),
        NobleMac::InstanceMethod("notify", &NobleMac::Notify),
        NobleMac::InstanceMethod("discoverDescriptors", &NobleMac::DiscoverDescriptors),
        NobleMac::InstanceMethod("readValue", &NobleMac::ReadValue),
        NobleMac::InstanceMethod("writeValue", &NobleMac::WriteValue),
        NobleMac::InstanceMethod("readHandle", &NobleMac::ReadHandle),
        NobleMac::InstanceMethod("writeHandle", &NobleMac::WriteHandle),
        NobleMac::InstanceMethod("stop", &NobleMac::Stop),
    });
}

Napi::Object Init(Napi::Env env, Napi::Object exports) {
    Napi::String name = Napi::String::New(env, "NobleMac");
    exports.Set(name, NobleMac::GetClass(env));
    return exports;
}

NODE_API_MODULE(addon, Init)
