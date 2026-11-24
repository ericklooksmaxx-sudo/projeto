#include "flutter_window.h"

#include <optional>
#include <windows.h>
#include <shellapi.h>

#include "flutter/generated_plugin_registrant.h"
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <flutter/encodable_value.h>

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
  
  SetupMethodChannel();
  
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

void FlutterWindow::SetupMethodChannel() {
  flutter::MethodChannel<flutter::EncodableValue> channel(
      flutter_controller_->engine()->messenger(), "xyz.kyzendlc.app/import",
      &flutter::StandardMethodCodec::GetInstance());

  channel.SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name().compare("openMinecraftUri") == 0) {
          const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
          if (arguments) {
            auto uri_it = arguments->find(flutter::EncodableValue("uri"));
            if (uri_it != arguments->end()) {
              std::string uri = std::get<std::string>(uri_it->second);
              
              // Convert string to wide string for Windows API
              int size_needed = MultiByteToWideChar(CP_UTF8, 0, &uri[0], (int)uri.size(), NULL, 0);
              std::wstring wuri(size_needed, 0);
              MultiByteToWideChar(CP_UTF8, 0, &uri[0], (int)uri.size(), &wuri[0], size_needed);
              
              // Use ShellExecute to launch the URI
              HINSTANCE shell_result = ShellExecuteW(NULL, L"open", wuri.c_str(), NULL, NULL, SW_SHOWNORMAL);
              
              if ((intptr_t)shell_result <= 32) {
                result->Error("LAUNCH_ERROR", "Failed to launch Minecraft URI", nullptr);
              } else {
                result->Success(flutter::EncodableValue(true));
              }
            } else {
              result->Error("INVALID_ARGUMENT", "URI argument is required", nullptr);
            }
          } else {
            result->Error("INVALID_ARGUMENT", "Arguments are required", nullptr);
          }
        } else if (call.method_name().compare("getContentUri") == 0) {
          const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
          if (arguments) {
            // similar to openMinecraftUri
            auto filePath_it = arguments->find(flutter::EncodableValue("filePath"));
            if (filePath_it != arguments->end()) {
              std::string filePath = std::get<std::string>(filePath_it->second);
              
              int size_needed = MultiByteToWideChar(CP_UTF8, 0, &filePath[0], (int)filePath.size(), NULL, 0);
              std::wstring wfilePath(size_needed, 0);
              MultiByteToWideChar(CP_UTF8, 0, &filePath[0], (int)filePath.size(), &wfilePath[0], size_needed);
              
              HINSTANCE shell_result = ShellExecuteW(NULL, L"open", wfilePath.c_str(), NULL, NULL, SW_SHOWNORMAL);
              
              if ((intptr_t)shell_result <= 32) {
                result->Error("LAUNCH_ERROR", "Could not open file", nullptr);
              } else {
                result->Success(flutter::EncodableValue("success"));
              }
            } else {
              result->Error("INVALID_ARGUMENT", "File path argument is required", nullptr);
            }
          } else {
            result->Error("INVALID_ARGUMENT", "Arguments are required", nullptr);
          }
        } else {
          result->NotImplemented();
        }
      });
}

void FlutterWindow::OnDestroy() {
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
