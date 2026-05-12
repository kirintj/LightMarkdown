import { hdsMaterial, HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit';
import { Markdown, MarkdownController } from '@luvi/lv-markdown-in';
import { MarkdownFile } from '../class/MarkdownFile';
import { MdDbService } from '../service/MdDbService';
import { common } from '@kit.AbilityKit';
import { systemShare, harmonyShare } from '@kit.ShareKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { fileUri } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';

const TITLE_BAR_HEIGHT_FREE: number = 58 + 16;

@Component
export struct MarkdownViewerPage {
  @Consume('pathStack') pathStack: NavPathStack;
  @Consume('dataVersion') dataVersion: number;
  fileData: MarkdownFile = new MarkdownFile('', '', '', 0);
  private scroller: Scroller = new Scroller();
  @State blankHeight: number = TITLE_BAR_HEIGHT_FREE;
  @StorageProp('currentColorMode') currentColorMode: number = 0;
  controller: MarkdownController = new MarkdownController();
  private context = this.getUIContext().getHostContext() as common.UIAbilityContext;
  private shareController: systemShare.ShareController | null = null;

  aboutToAppear(): void {
    this.controller
      .setTitleColor($r("sys.color.title_primary_color"))
      .setTextColor($r("sys.color.ohos_fa_text_primary"))
      .setQuoteBackgroundColor($r("sys.color.background_secondary"))
      .setQuoteBorderColor($r('sys.color.brand'));

    this.controller.setCodeBlockTheme(this.currentColorMode === 0 ? 'dark' : 'light');

    this.recordView();
    this.registerHarmonyShareListeners();
  }

  aboutToDisappear(): void {
    this.unregisterHarmonyShareListeners();
    this.dismissShareController();
  }

  private async recordView(): Promise<void> {
    try {
      const dbService = MdDbService.getInstance(this.context);
      await dbService.init();
      await dbService.updateLastViewedAt(this.fileData.sandboxPath);
      this.dataVersion++;
    } catch (e) {
      console.error('[MarkdownViewerPage] 记录浏览时间失败:', JSON.stringify(e));
    }
  }

  private buildShareData(): systemShare.SharedData {
    const fileUriStr = fileUri.getUriFromPath(this.fileData.sandboxPath);
    const shareData: systemShare.SharedData = new systemShare.SharedData({
      utd: utd.UniformDataType.FILE,
      uri: fileUriStr,
      title: this.fileData.name,
      description: 'Markdown文档',
    });
    return shareData;
  }

  private doSystemShare(): void {
    try {
      const shareData = this.buildShareData();
      this.shareController = new systemShare.ShareController(shareData);
      this.shareController.on('shareCompleted', (result: systemShare.ShareOperationResult) => {
        console.info('[MarkdownViewerPage] 分享完成, 渠道: ' + result.targetAbilityInfo.name);
      });
      this.shareController.show(this.context, {
        previewMode: systemShare.SharePreviewMode.DEFAULT,
        selectionMode: systemShare.SelectionMode.SINGLE,
      });
    } catch (e) {
      const err = e as BusinessError;
      console.error('[MarkdownViewerPage] 拉起分享面板失败: ' + err.code + ' ' + err.message);
    }
  }

  private knockShareCallback = (sharableTarget: harmonyShare.SharableTarget): void => {
    try {
      const shareData = this.buildShareData();
      sharableTarget.share(shareData);
      console.info('[MarkdownViewerPage] 碰一碰分享已触发');
    } catch (e) {
      const err = e as BusinessError;
      console.error('[MarkdownViewerPage] 碰一碰分享失败: ' + err.code + ' ' + err.message);
      sharableTarget.reject(harmonyShare.SharableErrorCode.DOWNLOAD_ERROR);
    }
  }

  private gesturesShareCallback = (sharableTarget: harmonyShare.SharableTarget): void => {
    try {
      const shareData = this.buildShareData();
      sharableTarget.share(shareData);
      console.info('[MarkdownViewerPage] 隔空传送已触发');
    } catch (e) {
      const err = e as BusinessError;
      console.error('[MarkdownViewerPage] 隔空传送失败: ' + err.code + ' ' + err.message);
      sharableTarget.reject(harmonyShare.SharableErrorCode.DOWNLOAD_ERROR);
    }
  }

  private registerHarmonyShareListeners(): void {
    try {
      harmonyShare.on('knockShare', this.knockShareCallback);
      console.info('[MarkdownViewerPage] 碰一碰监听已注册');
    } catch (e) {
      const err = e as BusinessError;
      console.error('[MarkdownViewerPage] 注册碰一碰监听失败: ' + err.code + ' ' + err.message);
    }
    try {
      harmonyShare.on('gesturesShare', this.gesturesShareCallback);
      console.info('[MarkdownViewerPage] 隔空传送监听已注册');
    } catch (e) {
      const err = e as BusinessError;
      console.error('[MarkdownViewerPage] 注册隔空传送监听失败: ' + err.code + ' ' + err.message);
    }
  }

  private unregisterHarmonyShareListeners(): void {
    try {
      harmonyShare.off('knockShare', this.knockShareCallback);
    } catch (e) {
      console.error('[MarkdownViewerPage] 注销碰一碰监听失败: ' + JSON.stringify(e));
    }
    try {
      harmonyShare.off('gesturesShare', this.gesturesShareCallback);
    } catch (e) {
      console.error('[MarkdownViewerPage] 注销隔空传送监听失败: ' + JSON.stringify(e));
    }
  }

  private dismissShareController(): void {
    if (this.shareController) {
      this.shareController.off('shareCompleted');
      this.shareController = null;
    }
  }

  build() {
    HdsNavDestination() {
      Scroll(this.scroller) {
        Column() {
          Blank().width('100%').height(this.blankHeight);
          Markdown({
            mode: "sandbox",
            sandboxPath: this.fileData.sandboxPath,
            callback: {
              complete: () => console.info("Markdown Load Success"),
              fail: (code, msg) => console.error(`Error: ${code}, ${msg}`)
            },
            controller: this.controller
          }).width('100%');
        }.padding(16).width('100%');
      }
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .width('100%')
      .height('100%');
    }
    .titleBar({
      content: {
        title: { mainTitle: this.fileData.name },
        menu: {
          value: [{
            content: {
              label: '分享',
              icon: $r('sys.symbol.share'),
              isEnabled: true,
              action: () => {
                this.doSystemShare();
              }
            }
          }]
        }
      },
      style: {
        scrollEffectOpts: { scrollEffectType: ScrollEffectType.GRADIENT_BLUR },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.IMMERSIVE,
          materialLevel: hdsMaterial.MaterialLevel.EXQUISITE
        },
      },
      avoidLayoutSafeArea: true
    });
  }
}

@Builder
export function MarkdownViewerPageBuilder() {
  MarkdownViewerPage();
}
