#include "update_bridge.h"

#include <winsparkle.h>
#include <atomic>
#include <string>

namespace {
std::atomic<HWND> callback_window{nullptr};
std::atomic<bool> can_shutdown{false};
constexpr WPARAM kDismissed = 1;
constexpr WPARAM kShutdown = 2;

void __cdecl Dismissed() {
  PostMessage(callback_window.load(), UpdateBridge::kMessage, kDismissed, 0);
}
void __cdecl Shutdown() {
  PostMessage(callback_window.load(), UpdateBridge::kMessage, kShutdown, 0);
}
int __cdecl CanShutdown() { return can_shutdown.load() ? 1 : 0; }
std::string Version() {
  return std::to_string(FLUTTER_VERSION_MAJOR) + "." +
      std::to_string(FLUTTER_VERSION_MINOR) + "." +
      std::to_string(FLUTTER_VERSION_PATCH);
}
}  // namespace

UpdateBridge::UpdateBridge(HWND window, flutter::BinaryMessenger* messenger) {
  callback_window.store(window);
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "mountain_fairytale/updates",
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        if (call.method_name() == "version") {
          result->Success(flutter::EncodableValue(
              Version() + "+" + std::to_string(FLUTTER_VERSION_BUILD)));
        } else if (call.method_name() == "initialize") {
          const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
          if (!args || initialized_) {
            result->Error("configuration", "Invalid or repeated initialization");
            return;
          }
          const auto key = args->find(flutter::EncodableValue("publicKey"));
          const auto feed = args->find(flutter::EncodableValue("feed"));
          if (key == args->end() || feed == args->end() ||
              !std::holds_alternative<std::string>(key->second) ||
              !std::holds_alternative<std::string>(feed->second)) {
            result->Error("configuration", "Missing public key or feed");
            return;
          }
          const auto& public_key = std::get<std::string>(key->second);
          const auto& feed_url = std::get<std::string>(feed->second);
          bool allowed_feed = feed_url ==
              "https://github.com/boradydev/mountain_fairytale/releases/latest/download/appcast.xml";
#if defined(_DEBUG)
          // Private acceptance feed, compiled out of Profile/Release builds.
          allowed_feed = allowed_feed || feed_url.rfind("http://127.0.0.1:", 0) == 0;
#endif
          if (!allowed_feed ||
              !win_sparkle_set_eddsa_public_key(public_key.c_str())) {
            result->Error("configuration", "Invalid public key or feed");
            return;
          }
          win_sparkle_set_appcast_url(feed_url.c_str());
          win_sparkle_set_lang("ru");
          // Keep the app's existing storage identity. Only updater registry
          // settings use this display name; Runner.rc remains unchanged.
          const std::string version = Version();
          const std::wstring wide_version(version.begin(), version.end());
          win_sparkle_set_app_details(L"boradydev", L"Mountain Fairytale",
                                     wide_version.c_str());
          // Compare complete semantic versions, then their build component.
          const std::string build = std::to_string(FLUTTER_VERSION_MAJOR) + "." +
              std::to_string(FLUTTER_VERSION_MINOR) + "." +
              std::to_string(FLUTTER_VERSION_PATCH) + "." +
              std::to_string(FLUTTER_VERSION_BUILD);
          const std::wstring wide_build(build.begin(), build.end());
          win_sparkle_set_app_build_version(wide_build.c_str());
          win_sparkle_set_automatic_check_for_updates(0);
          win_sparkle_set_can_shutdown_callback(CanShutdown);
          win_sparkle_set_shutdown_request_callback(Shutdown);
          win_sparkle_set_update_dismissed_callback(Dismissed);
          win_sparkle_init();
          initialized_ = true;
          result->Success();
        } else if (call.method_name() == "check") {
          if (!initialized_ || can_shutdown.exchange(true)) {
            result->Error("unavailable", "Updater not ready or already active");
            return;
          }
          // Dart has already acquired a modal work barrier and confirmed that
          // no editor is open. Never launch the installer from a passive check.
          win_sparkle_check_update_with_ui();
          result->Success();
        } else {
          result->NotImplemented();
        }
      });
}

UpdateBridge::~UpdateBridge() {
  can_shutdown.store(false);
  if (initialized_) win_sparkle_cleanup();
  callback_window.store(nullptr);
}

void UpdateBridge::HandleMessage(WPARAM event) {
  if (event == kShutdown) {
    channel_->InvokeMethod("shutdown", nullptr);
  } else if (event == kDismissed) {
    can_shutdown.store(false);
    channel_->InvokeMethod("dismissed", nullptr);
  }
}
