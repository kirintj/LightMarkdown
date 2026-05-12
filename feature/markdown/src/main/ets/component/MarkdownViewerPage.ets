import { hdsMaterial, HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit';
import { Markdown, MarkdownController } from '@luvi/lv-markdown-in';
import { MarkdownFile } from '../class/MarkdownFile';
import { MdDbService } from '../service/MdDbService';
import { common } from '@kit.AbilityKit';
import { systemShare, harmonyShare } from '@kit.ShareKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { fileUri } from '@kit.CoreFileKit';
import { promptAction } from '@kit.ArkUI';

const TITLE_BAR_HEIGHT_FREE: number = 58 + 16 + 4;
const DEFAULT_SHARE_DESCRIPTION: string = 'Markdown文档';

@Component
export struct MarkdownViewerPage {
  // 路由状态
  @Consume('pathStack') pathStack: NavPathStack;
  @Consume('dataVersion') dataVersion: number;
  fileData: MarkdownFile = new MarkdownFile('', '', '', 0);

  // 滚动 & 控制器
  private scroller: Scroller = new Scroller();
  controller: MarkdownController = new MarkdownController();
  private context = this.getUIContext().getHostContext() as common.UIAbilityContext;

  // UI 状态
  @State blankHeight: number = TITLE_BAR_HEIGHT_FREE;
  @State isLoading: boolean = true;
  @State showMarkdown: boolean = false;

  // 主题
  @StorageProp('currentColorMode') @Watch('onColorModeChange') currentColorMode: number = 0;

  // 分享
  private shareController: systemShare.ShareController | null = null;

  // 防护标记
  private isShareListenerRegistered: boolean = false;
  private isDestroyed: boolean = false;

  aboutToAppear(): void {
    this.initMarkdownController();
    this.recordView();
    this.registerHarmonyShareListeners();
    setTimeout(() => {
      if (!this.isDestroyed) {
        this.showMarkdown = true;
      }
    }, 100);
  }

  aboutToDisappear(): void {
    this.isDestroyed = true;
    this.unregisterHarmonyShareListeners();
    this.dismissShareController();
  }

  private initMarkdownController(): void {
    this.controller
      .setTitleColor($r("sys.color.title_primary_color"))
      .setTextColor($r("sys.color.ohos_fa_text_primary"))
      .setQuoteBackgroundColor($r("sys.color.background_secondary"))
      .setQuoteBorderColor($r('sys.color.brand'));
    this.controller.setCodeBlockTheme(this.currentColorMode === 0 ? 'dark' : 'light');
  }

  onColorModeChange(): void {
    if (this.isDestroyed) return;
    this.controller.setCodeBlockTheme(this.currentColorMode === 0 ? 'dark' : 'light');
  }

  private async recordView(): Promise<void> {
    if (this.isDestroyed) return;
    if (!this.fileData.sandboxPath) return;
    try {
      const dbService = MdDbService.getInstance(this.context);
      await dbService.init();
      if (this.isDestroyed) return;
      await dbService.updateLastViewedAt(this.fileData.sandboxPath);
      this.dataVersion++;
    } catch (e) {
      console.error('[MarkdownViewerPage] 记录浏览时间失败: ' + JSON.stringify(e));
    }
  }

  private buildShareData(): systemShare.SharedData {
    const fileUriStr = fileUri.getUriFromPath(this.fileData.sandboxPath);
    return new systemShare.SharedData({
      utd: utd.UniformDataType.FILE,
      uri: fileUriStr,
      title: this.fileData.name,
      description: DEFAULT_SHARE_DESCRIPTION,
    });
  }

  private doSystemShare(): void {
    if (!this.fileData.sandboxPath) return;
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
      console.error('[MarkdownViewerPage] 拉起分享面板失败: ' + JSON.stringify(e));
      promptAction.showToast({ message: '分享失败' });
    }
  }

  private handleHarmonyShare(sharableTarget: harmonyShare.SharableTarget, shareType: string): void {
    try {
      const shareData = this.buildShareData();
      sharableTarget.share(shareData);
      console.info('[MarkdownViewerPage] ' + shareType + '已触发');
    } catch (e) {
      console.error('[MarkdownViewerPage] ' + shareType + '失败: ' + JSON.stringify(e));
      sharableTarget.reject(harmonyShare.SharableErrorCode.DOWNLOAD_ERROR);
    }
  }

  private knockShareCallback = (sharableTarget: harmonyShare.SharableTarget): void => {
    this.handleHarmonyShare(sharableTarget, '碰一碰分享');
  }

  private gesturesShareCallback = (sharableTarget: harmonyShare.SharableTarget): void => {
    this.handleHarmonyShare(sharableTarget, '隔空传送');
  }

  private registerHarmonyShareListeners(): void {
    if (this.isShareListenerRegistered) return;
    try {
      harmonyShare.on('knockShare', this.knockShareCallback);
    } catch (e) {
      console.error('[MarkdownViewerPage] 注册碰一碰监听失败: ' + JSON.stringify(e));
    }
    try {
      harmonyShare.on('gesturesShare', this.gesturesShareCallback);
    } catch (e) {
      console.error('[MarkdownViewerPage] 注册隔空传送监听失败: ' + JSON.stringify(e));
    }
    this.isShareListenerRegistered = true;
  }

  private unregisterHarmonyShareListeners(): void {
    if (!this.isShareListenerRegistered) return;
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
    this.isShareListenerRegistered = false;
  }

  private dismissShareController(): void {
    if (this.shareController) {
      try {
        this.shareController.off('shareCompleted');
      } catch (e) {
        console.error('[MarkdownViewerPage] 注销分享回调失败: ' + JSON.stringify(e));
      }
      this.shareController = null;
    }
  }

  @Builder
  viewingContent() {
    Scroll(this.scroller) {
      Column() {
        Blank().width('100%').height(this.blankHeight);
        if (this.showMarkdown) {
          Markdown({
            mode: "sandbox",
            sandboxPath: this.fileData.sandboxPath,
            callback: {
              complete: () => {
                this.isLoading = false;
              },
              fail: (code: number, msg: string) => {
                this.isLoading = false;
                console.error('[MarkdownViewerPage] Markdown加载失败: ' + code + ', ' + msg);
                promptAction.showToast({ message: '加载失败' });
              }
            },
            controller: this.controller
          })
            .width('100%')
            .transition(TransitionEffect.OPACITY.animation({ duration: 300 }))
        }
        if (this.isLoading) {
          Column() {
            LoadingProgress()
              .width(48)
              .height(48)
              .color($r('sys.color.brand'))
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .padding({ top: 32, bottom: 32 })
          .transition(TransitionEffect.OPACITY.animation({ duration: 300 }))
        }
      }.padding(16).width('100%');
    }
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .width('100%')
    .height('100%');
  }

  build() {
    HdsNavDestination() {
      this.viewingContent();
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
              action: () => { this.doSystemShare(); }
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
