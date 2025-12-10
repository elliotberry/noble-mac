//
//  callbacks.cc
//  noble-mac-native
//
//  Created by Georg Vienna on 30.08.18.
//
#include "callbacks.h"

#include <algorithm>
#include <utility>

namespace {
Napi::String JsString(Napi::Env env, const std::string& val) {
    return Napi::String::New(env, val);
}

Napi::Boolean JsBool(Napi::Env env, bool val) {
    return Napi::Boolean::New(env, val);
}

Napi::Number JsNumber(Napi::Env env, double val) {
    return Napi::Number::New(env, val);
}
}  // namespace

Napi::String toUuid(Napi::Env& env, const std::string& uuid) {
    std::string str(uuid);
    str.erase(std::remove(str.begin(), str.end(), '-'), str.end());
    std::transform(str.begin(), str.end(), str.begin(), ::tolower);
    return JsString(env, str);
}

Napi::String toAddressType(Napi::Env& env, const AddressType& type) {
    if(type == PUBLIC) {
        return JsString(env, "public");
    } else if (type == RANDOM) {
        return JsString(env, "random");
    }
    return JsString(env, "unknown");
}

Napi::Buffer<uint8_t> toBuffer(Napi::Env& env, const Data& data) {
    if (data.empty()) {
        return Napi::Buffer<uint8_t>::New(env, 0);
    }
    return Napi::Buffer<uint8_t>::Copy(env, &data[0], data.size());
}

Napi::Array toUuidArray(Napi::Env& env, const std::vector<std::string>& data) {
    if (data.empty()) {
        return Napi::Array::New(env);
    }
    auto arr = Napi::Array::New(env, data.size());
    for (size_t i = 0; i < data.size(); i++) {
        arr.Set(i, toUuid(env, data[i]));
    }
    return arr;
}

Napi::Array toArray(Napi::Env& env, const std::vector<std::string>& data) {
    if (data.empty()) {
        return Napi::Array::New(env);
    }
    auto arr = Napi::Array::New(env, data.size());
    for (size_t i = 0; i < data.size(); i++) {
        arr.Set(i, JsString(env, data[i]));
    }
    return arr;
}

struct Emit::JsWork {
    std::function<void(Napi::Env, Napi::Function, const Napi::Object&)> fn;
};

void Emit::Wrap(const Napi::Value& receiver, const Napi::Function& callback) {
    receiverRef = Napi::Persistent(receiver.As<Napi::Object>());
    receiverRef.SuppressDestruct();

    tsfn = Napi::ThreadSafeFunction::New(
        callback.Env(),
        callback,
        "noble-mac-emit",
        0,
        1,
        this,
        [](Napi::Env, Emit* self) {
            if (self && self->receiverRef) {
                self->receiverRef.Unref();
            }
        });
}

void Emit::Dispatch(std::function<void(Napi::Env, Napi::Function, const Napi::Object&)> fn) {
    if (!tsfn) {
        return;
    }
    auto* work = new JsWork{std::move(fn)};
    napi_status status = tsfn.BlockingCall(
        work,
        [this](Napi::Env env, Napi::Function jsCallback, JsWork* data) {
            Napi::HandleScope scope(env);
            auto receiver = receiverRef.Value();
            data->fn(env, jsCallback, receiver);
            delete data;
        });
    if (status != napi_ok) {
        delete work;
    }
}

void Emit::RadioState(const std::string& state) {
    Dispatch([state](Napi::Env env, Napi::Function jsCallback, const Napi::Object& receiver) {
        jsCallback.Call(receiver, { JsString(env, "stateChange"), JsString(env, state) });
    });
}

void Emit::ScanState(bool start) {
    Dispatch([start](Napi::Env env, Napi::Function jsCallback, const Napi::Object& receiver) {
        jsCallback.Call(receiver, { JsString(env, start ? "scanStart" : "scanStop") });
    });
}

void Emit::Scan(const std::string& uuid, int rssi, const Peripheral& peripheral) {
    auto address = peripheral.address;
    auto addressType = peripheral.addressType;
    auto connectable = peripheral.connectable;
    auto name = peripheral.name;
    auto txPowerLevel = peripheral.txPowerLevel;
    auto manufacturerData = peripheral.manufacturerData;
    auto serviceData = peripheral.serviceData;
    auto serviceUuids = peripheral.serviceUuids;
    Dispatch([uuid, rssi, address, addressType, connectable, name, txPowerLevel, manufacturerData, serviceData, serviceUuids](Napi::Env env, Napi::Function jsCallback, const Napi::Object& receiver) {
        Napi::Object advertisment = Napi::Object::New(env);
        if (std::get<1>(name)) {
            advertisment.Set(JsString(env, "localName"), JsString(env, std::get<0>(name)));
        }

        if (std::get<1>(txPowerLevel)) {
            advertisment.Set(JsString(env, "txPowerLevel"), std::get<0>(txPowerLevel));
        }

        if (std::get<1>(manufacturerData)) {
            advertisment.Set(JsString(env, "manufacturerData"), toBuffer(env, std::get<0>(manufacturerData)));
        }

        if (std::get<1>(serviceData)) {
            auto array = std::get<0>(serviceData).empty() ? Napi::Array::New(env) : Napi::Array::New(env, std::get<0>(serviceData).size());
            for (size_t i = 0; i < std::get<0>(serviceData).size(); i++) {
                Napi::Object data = Napi::Object::New(env);
                data.Set(JsString(env, "uuid"), toUuid(env, std::get<0>(serviceData)[i].first));
                data.Set(JsString(env, "data"), toBuffer(env, std::get<0>(serviceData)[i].second));
                array.Set(i, data);
            }
            advertisment.Set(JsString(env, "serviceData"), array);
        }

        if (std::get<1>(serviceUuids)) {
            advertisment.Set(JsString(env, "serviceUuids"), toUuidArray(env, std::get<0>(serviceUuids)));
        }
        // emit('discover', deviceUuid, address, addressType, connectable, advertisement, rssi);
        jsCallback.Call(receiver, { JsString(env, "discover"), toUuid(env, uuid), JsString(env, address), toAddressType(env, addressType), JsBool(env, connectable), advertisment, JsNumber(env, rssi) });
    });
}

void Emit::Connected(const std::string& uuid, const std::string& error) {
    Dispatch([uuid, error](Napi::Env env, Napi::Function jsCallback, const Napi::Object& receiver) {
        // emit('connect', deviceUuid) error added here
        jsCallback.Call(receiver, { JsString(env, "connect"), toUuid(env, uuid), error.empty() ? env.Null() : JsString(env, error) });
    });
}

void Emit::Disconnected(const std::string& uuid) {
    Dispatch([uuid](Napi::Env env, Napi::Function jsCallback, const Napi::Object& receiver) {
        // emit('disconnect', deviceUuid);
        jsCallback.Call(receiver, { JsString(env, "disconnect"), toUuid(env, uuid) });
    });
}

void Emit::RSSI(const std::string & uuid, int rssi) {
    Dispatch([uuid, rssi](Napi::Env env, Napi::Function jsCallback, const Napi::Object& receiver) {
        // emit('rssiUpdate', deviceUuid, rssi);
        jsCallback.Call(receiver, { JsString(env, "rssiUpdate"), toUuid(env, uuid), JsNumber(env, rssi) });
    });
}

void Emit::ServicesDiscovered(const std::string & uuid, const std::vector<std::string>& serviceUuids) {
    Dispatch([uuid, serviceUuids](Napi::Env env, Napi::Function jsCallback, const Napi::Object& receiver) {
        // emit('servicesDiscover', deviceUuid, serviceUuids)
        jsCallback.Call(receiver, { JsString(env, "servicesDiscover"), toUuid(env, uuid), toUuidArray(env, serviceUuids) });
    });
}

void Emit::IncludedServicesDiscovered(const std::string & uuid, const std::string & serviceUuid, const std::vector<std::string>& serviceUuids) {
    Dispatch([uuid, serviceUuid, serviceUuids](Napi::Env env, Napi::Function jsCallback, const Napi::Object& receiver) {
        // emit('includedServicesDiscover', deviceUuid, serviceUuid, includedServiceUuids)
        jsCallback.Call(receiver, { JsString(env, "includedServicesDiscover"), toUuid(env, uuid), toUuid(env, serviceUuid), toUuidArray(env, serviceUuids) });
    });
}

void Emit::CharacteristicsDiscovered(const std::string & uuid, const std::string & serviceUuid, const std::vector<std::pair<std::string, std::vector<std::string>>>& characteristics) {
    Dispatch([uuid, serviceUuid, characteristics](Napi::Env env, Napi::Function jsCallback, const Napi::Object& receiver) {
        auto arr = characteristics.empty() ? Napi::Array::New(env) : Napi::Array::New(env, characteristics.size());
        for (size_t i = 0; i < characteristics.size(); i++) {
            Napi::Object characteristic = Napi::Object::New(env);
            characteristic.Set(JsString(env, "uuid"), toUuid(env, characteristics[i].first));
            characteristic.Set(JsString(env, "properties"), toArray(env, characteristics[i].second));
            arr.Set(i, characteristic);
        }
        // emit('characteristicsDiscover', deviceUuid, serviceUuid, { uuid, properties: ['broadcast', 'read', ...]})
        jsCallback.Call(receiver, { JsString(env, "characteristicsDiscover"), toUuid(env, uuid), toUuid(env, serviceUuid), arr });
    });
}

void Emit::Read(const std::string & uuid, const std::string & serviceUuid, const std::string & characteristicUuid, const Data& data, bool isNotification) {
    Dispatch([uuid, serviceUuid, characteristicUuid, data, isNotification](Napi::Env env, Napi::Function jsCallback, const Napi::Object& receiver) {
        // emit('read', deviceUuid, serviceUuid, characteristicsUuid, data, isNotification);
        jsCallback.Call(receiver, { JsString(env, "read"), toUuid(env, uuid), toUuid(env, serviceUuid), toUuid(env, characteristicUuid), toBuffer(env, data), JsBool(env, isNotification) });
    });
}

void Emit::Write(const std::string & uuid, const std::string & serviceUuid, const std::string & characteristicUuid) {
    Dispatch([uuid, serviceUuid, characteristicUuid](Napi::Env env, Napi::Function jsCallback, const Napi::Object& receiver) {
        // emit('write', deviceUuid, servicesUuid, characteristicsUuid)
        jsCallback.Call(receiver, { JsString(env, "write"), toUuid(env, uuid), toUuid(env, serviceUuid), toUuid(env, characteristicUuid) });
    });
}

void Emit::Notify(const std::string & uuid, const std::string & serviceUuid, const std::string & characteristicUuid, bool state) {
    Dispatch([uuid, serviceUuid, characteristicUuid, state](Napi::Env env, Napi::Function jsCallback, const Napi::Object& receiver) {
        // emit('notify', deviceUuid, servicesUuid, characteristicsUuid, state)
        jsCallback.Call(receiver, { JsString(env, "notify"), toUuid(env, uuid), toUuid(env, serviceUuid), toUuid(env, characteristicUuid), JsBool(env, state) });
    });
}

void Emit::DescriptorsDiscovered(const std::string & uuid, const std::string & serviceUuid, const std::string & characteristicUuid, const std::vector<std::string>& descriptorUuids) {
    Dispatch([uuid, serviceUuid, characteristicUuid, descriptorUuids](Napi::Env env, Napi::Function jsCallback, const Napi::Object& receiver) {
        // emit('descriptorsDiscover', deviceUuid, servicesUuid, characteristicsUuid, descriptors: [uuids])
        jsCallback.Call(receiver, { JsString(env, "descriptorsDiscover"), toUuid(env, uuid), toUuid(env, serviceUuid), toUuid(env, characteristicUuid), toUuidArray(env, descriptorUuids) });
    });
}

void Emit::ReadValue(const std::string & uuid, const std::string & serviceUuid, const std::string & characteristicUuid, const std::string& descriptorUuid, const Data& data) {
    Dispatch([uuid, serviceUuid, characteristicUuid, descriptorUuid, data](Napi::Env env, Napi::Function jsCallback, const Napi::Object& receiver) {
        // emit('valueRead', deviceUuid, serviceUuid, characteristicUuid, descriptorUuid, data)
        jsCallback.Call(receiver, { JsString(env, "valueRead"), toUuid(env, uuid), toUuid(env, serviceUuid), toUuid(env, characteristicUuid), toUuid(env, descriptorUuid), toBuffer(env, data) });
    });
}

void Emit::WriteValue(const std::string & uuid, const std::string & serviceUuid, const std::string & characteristicUuid, const std::string& descriptorUuid) {
    Dispatch([uuid, serviceUuid, characteristicUuid, descriptorUuid](Napi::Env env, Napi::Function jsCallback, const Napi::Object& receiver) {
        // emit('valueWrite', deviceUuid, serviceUuid, characteristicUuid, descriptorUuid);
        jsCallback.Call(receiver, { JsString(env, "valueWrite"), toUuid(env, uuid), toUuid(env, serviceUuid), toUuid(env, characteristicUuid), toUuid(env, descriptorUuid) });
    });
}

void Emit::ReadHandle(const std::string & uuid, int descriptorHandle, const Data& data) {
    Dispatch([uuid, descriptorHandle, data](Napi::Env env, Napi::Function jsCallback, const Napi::Object& receiver) {
        // emit('handleRead', deviceUuid, descriptorHandle, data);
        jsCallback.Call(receiver, { JsString(env, "handleRead"), toUuid(env, uuid), JsNumber(env, descriptorHandle), toBuffer(env, data) });
    });
}

void Emit::WriteHandle(const std::string & uuid, int descriptorHandle) {
    Dispatch([uuid, descriptorHandle](Napi::Env env, Napi::Function jsCallback, const Napi::Object& receiver) {
        // emit('handleWrite', deviceUuid, descriptorHandle);
        jsCallback.Call(receiver, { JsString(env, "handleWrite"), toUuid(env, uuid), JsNumber(env, descriptorHandle) });
    });
}
