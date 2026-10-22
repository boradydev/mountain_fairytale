#ifndef RUNNER_UPDATE_BRIDGE_H_
#define RUNNER_UPDATE_BRIDGE_H_

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>
#include <memory>

// WinSparkle callbacks run on its worker thread; only window messages cross
// into the Flutter UI thread. No Flutter API is called from a worker thread.
class UpdateBridge {
 public:
  static constexpr UINT kMessage = WM_APP + 73;
  UpdateBridge(HWND window, flutter::BinaryMessenger* messenger);
  ~UpdateBridge();
  void HandleMessage(WPARAM event);

 private:
  bool initialized_ = false;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

#endif
