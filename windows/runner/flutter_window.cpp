#include "flutter_window.h"

#include <endpointvolume.h>
#include <flutter/standard_method_codec.h>
#include <mmdeviceapi.h>
#include <wrl/client.h>

#include <algorithm>
#include <cstdint>
#include <optional>
#include <stdexcept>
#include <string>
#include <variant>

#include "flutter/generated_plugin_registrant.h"

namespace {

Microsoft::WRL::ComPtr<IAudioEndpointVolume> GetDefaultEndpointVolume() {
  Microsoft::WRL::ComPtr<IMMDeviceEnumerator> enumerator;
  HRESULT hr = CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr,
                                CLSCTX_ALL, IID_PPV_ARGS(&enumerator));
  if (FAILED(hr)) {
    throw std::runtime_error("Audio device enumerator unavailable");
  }

  Microsoft::WRL::ComPtr<IMMDevice> device;
  hr = enumerator->GetDefaultAudioEndpoint(eRender, eConsole, &device);
  if (FAILED(hr)) {
    throw std::runtime_error("Default audio endpoint unavailable");
  }

  Microsoft::WRL::ComPtr<IAudioEndpointVolume> endpoint_volume;
  hr = device->Activate(__uuidof(IAudioEndpointVolume), CLSCTX_ALL, nullptr,
                        reinterpret_cast<void**>(endpoint_volume.GetAddressOf()));
  if (FAILED(hr)) {
    throw std::runtime_error("Audio endpoint volume unavailable");
  }
  return endpoint_volume;
}

double GetSystemVolumeLevel() {
  float level = 0.0f;
  const auto endpoint_volume = GetDefaultEndpointVolume();
  const HRESULT hr = endpoint_volume->GetMasterVolumeLevelScalar(&level);
  if (FAILED(hr)) {
    throw std::runtime_error("Could not read system volume");
  }
  return std::clamp(static_cast<double>(level), 0.0, 1.0);
}

double SetSystemVolumeLevel(double level) {
  const auto clamped = std::clamp(level, 0.0, 1.0);
  const auto endpoint_volume = GetDefaultEndpointVolume();
  const HRESULT hr =
      endpoint_volume->SetMasterVolumeLevelScalar(static_cast<float>(clamped),
                                                  nullptr);
  if (FAILED(hr)) {
    throw std::runtime_error("Could not set system volume");
  }
  return GetSystemVolumeLevel();
}

bool ReadDoubleArgument(const flutter::EncodableValue* arguments,
                        double* value) {
  if (!arguments) {
    return false;
  }
  if (const auto double_value = std::get_if<double>(arguments)) {
    *value = *double_value;
    return true;
  }
  if (const auto int_value = std::get_if<int>(arguments)) {
    *value = static_cast<double>(*int_value);
    return true;
  }
  return false;
}

bool ReadIntArgument(const flutter::EncodableValue* arguments, int* value) {
  if (!arguments) {
    return false;
  }
  if (const auto int_value = std::get_if<int>(arguments)) {
    *value = *int_value;
    return true;
  }
  if (const auto long_value = std::get_if<int64_t>(arguments)) {
    *value = static_cast<int>(*long_value);
    return true;
  }
  if (const auto double_value = std::get_if<double>(arguments)) {
    *value = static_cast<int>(*double_value);
    return true;
  }
  return false;
}

bool ReadIntFromMap(const flutter::EncodableValue* arguments,
                    const std::string& key,
                    int* value) {
  if (!arguments) {
    return false;
  }
  const auto map = std::get_if<flutter::EncodableMap>(arguments);
  if (!map) {
    return false;
  }
  const auto it = map->find(flutter::EncodableValue(key));
  if (it == map->end()) {
    return false;
  }
  return ReadIntArgument(&it->second, value);
}

void SendVerticalScroll(int wheel_delta) {
  INPUT input = {};
  input.type = INPUT_MOUSE;
  input.mi.dwFlags = MOUSEEVENTF_WHEEL;
  input.mi.mouseData = static_cast<DWORD>(wheel_delta);

  const UINT sent = SendInput(1, &input, sizeof(INPUT));
  if (sent != 1) {
    throw std::runtime_error("Could not send mouse wheel input");
  }
}

void SendMouseMove(int dx, int dy) {
  INPUT input = {};
  input.type = INPUT_MOUSE;
  input.mi.dx = dx;
  input.mi.dy = dy;
  input.mi.dwFlags = MOUSEEVENTF_MOVE;

  const UINT sent = SendInput(1, &input, sizeof(INPUT));
  if (sent != 1) {
    throw std::runtime_error("Could not send mouse move input");
  }
}

void SendLeftClick() {
  INPUT inputs[2] = {};
  inputs[0].type = INPUT_MOUSE;
  inputs[0].mi.dwFlags = MOUSEEVENTF_LEFTDOWN;
  inputs[1].type = INPUT_MOUSE;
  inputs[1].mi.dwFlags = MOUSEEVENTF_LEFTUP;

  const UINT sent = SendInput(2, inputs, sizeof(INPUT));
  if (sent != 2) {
    throw std::runtime_error("Could not send mouse click input");
  }
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  system_volume_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "openring/system_volume",
          &flutter::StandardMethodCodec::GetInstance());
  system_volume_channel_->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
             result) {
        try {
          if (call.method_name() == "getVolume") {
            result->Success(flutter::EncodableValue(GetSystemVolumeLevel()));
            return;
          }
          if (call.method_name() == "setVolume") {
            double volume = 0.0;
            if (!ReadDoubleArgument(call.arguments(), &volume)) {
              result->Error("bad_args", "Expected volume as double");
              return;
            }
            result->Success(flutter::EncodableValue(SetSystemVolumeLevel(volume)));
            return;
          }
          result->NotImplemented();
        } catch (const std::exception& e) {
          result->Error("system_volume_error", e.what());
        }
      });
  system_scroll_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "openring/system_scroll",
          &flutter::StandardMethodCodec::GetInstance());
  system_scroll_channel_->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
             result) {
        try {
          if (call.method_name() == "scrollVertical") {
            int wheel_delta = 0;
            if (!ReadIntArgument(call.arguments(), &wheel_delta)) {
              result->Error("bad_args", "Expected wheel delta as int");
              return;
            }
            SendVerticalScroll(wheel_delta);
            result->Success();
            return;
          }
          result->NotImplemented();
        } catch (const std::exception& e) {
          result->Error("system_scroll_error", e.what());
        }
      });
  system_mouse_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "openring/system_mouse",
          &flutter::StandardMethodCodec::GetInstance());
  system_mouse_channel_->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
             result) {
        try {
          if (call.method_name() == "moveRelative") {
            int dx = 0;
            int dy = 0;
            if (!ReadIntFromMap(call.arguments(), "dx", &dx) ||
                !ReadIntFromMap(call.arguments(), "dy", &dy)) {
              result->Error("bad_args", "Expected dx and dy as ints");
              return;
            }
            SendMouseMove(dx, dy);
            result->Success();
            return;
          }
          if (call.method_name() == "leftClick") {
            SendLeftClick();
            result->Success();
            return;
          }
          result->NotImplemented();
        } catch (const std::exception& e) {
          result->Error("system_mouse_error", e.what());
        }
      });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  system_mouse_channel_ = nullptr;
  system_scroll_channel_ = nullptr;
  system_volume_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
