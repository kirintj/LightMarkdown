import { AbilityConstant, Configuration ,ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { FileDataSource } from 'markdown';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    AppStorage.setOrCreate<ConfigurationConstant.ColorMode>('currentColorMode', this.context.config.colorMode);

    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {

    let windowClass: window.Window = windowStage.getMainWindowSync();

    // 1. 开启窗口全屏沉浸式
    windowClass.setWindowLayoutFullScreen(true);

    // 2. 获取并保存安全区域高度（用于后续避让）
    let topRectHeight = windowClass
      .getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM)
      .topRect.height;
    let bottomRectHeight = windowClass
      .getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR)
      .bottomRect.height;
    AppStorage.setOrCreate('safeTop', px2vp(topRectHeight));
    AppStorage.setOrCreate('safeBottom', px2vp(bottomRectHeight));
    AppStorage.setOrCreate('windowClass', windowClass);
    windowClass.on('avoidAreaChange', (data) => {
      if (data.type === window.AvoidAreaType.TYPE_SYSTEM) {
        AppStorage.setOrCreate('safeTop', px2vp(data.area.topRect.height));
      } else if (data.type === window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR) {
        AppStorage.setOrCreate('safeBottom', px2vp(data.area.bottomRect.height));
      }
    });

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    let newColorMode = newConfig.colorMode;
    let currentColorMode = AppStorage.get<ConfigurationConstant.ColorMode>('currentColorMode');
    if (newColorMode === currentColorMode) {
      return;
    }
    // 更新缓存中的颜色模式
    AppStorage.setOrCreate('currentColorMode', newConfig.colorMode);
  }
  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }

}