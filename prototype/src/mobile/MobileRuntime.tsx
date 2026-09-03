import { useEffect, type PropsWithChildren } from "react";
import { MobileDeviceProvider, useMobileDevice } from "./Device";
import { KeyboardDock, KeyboardProvider, useKeyboard } from "./Keyboard";
import { PhoneFrame, type RuntimePresentation } from "./PhoneFrame";
import { HomeIndicator, StatusBar } from "./components";

type MobileRuntimeProps = PropsWithChildren<{
  presentation?: RuntimePresentation;
}>;

export function MobileRuntime({ children, presentation = "device" }: MobileRuntimeProps) {
  const isWeb = presentation === "web";

  return (
    <MobileDeviceProvider>
      <PhoneFrame presentation={presentation}>
        <KeyboardProvider nativeInput={isWeb}>
          {!isWeb ? <KeyboardPreview /> : null}
          {!isWeb ? <StatusBar /> : null}
          <MobileAppViewport presentation={presentation}>{children}</MobileAppViewport>
          {!isWeb ? <HomeIndicator /> : null}
          {!isWeb ? <KeyboardDock /> : null}
        </KeyboardProvider>
      </PhoneFrame>
    </MobileDeviceProvider>
  );
}

function MobileAppViewport({ children, presentation }: PropsWithChildren<{ presentation: RuntimePresentation }>) {
  const { device } = useMobileDevice();
  const keyboard = useKeyboard();

  return (
    <div
      className="mobile-app-viewport"
      data-keyboard-visible={keyboard.visible ? "true" : "false"}
      data-platform={device.platform}
      data-presentation={presentation}
      data-testid="mobile-app-viewport"
    >
      {children}
    </div>
  );
}

function KeyboardPreview() {
  const keyboard = useKeyboard();

  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    if (params.get("keyboard") === "1") {
      keyboard.show();
    }
  }, [keyboard]);

  return null;
}
