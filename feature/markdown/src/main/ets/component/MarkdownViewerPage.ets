import { hdsMaterial, HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit';
import { Markdown, MarkdownController } from '@luvi/lv-markdown-in';
import { MarkdownFile } from '../class/MarkdownFile';
const TITLE_BAR_HEIGHT_FREE: number = 58 + 16;

@Component
export struct MarkdownViewerPage {
  @Consume('pathStack') pathStack: NavPathStack;
  fileData: MarkdownFile = new MarkdownFile('', '', '', 0);
  private scroller: Scroller = new Scroller();
  @State blankHeight: number = TITLE_BAR_HEIGHT_FREE;
  @StorageProp('currentColorMode') currentColorMode: number = 0;
  controller: MarkdownController = new MarkdownController();

  aboutToAppear(): void {
    this.controller
      .setTitleColor($r("sys.color.title_primary_color"))
      .setTextColor($r("sys.color.ohos_fa_text_primary"))
      .setQuoteBackgroundColor($r("sys.color.background_secondary"))
      .setQuoteBorderColor($r('sys.color.brand'));

    this.controller.setCodeBlockTheme(this.currentColorMode === 0 ? 'dark' : 'light');
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
              action: () => {}
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
