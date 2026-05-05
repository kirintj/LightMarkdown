import { HdsNavDestination, HdsNavDestinationTitleMode, ScrollEffectType,
  hdsMaterial} from "@kit.UIDesignKit";
import { ConfigurationConstant } from "@kit.AbilityKit";
import { CardItem } from "common";

const  TITLE_BAR_HEIGHT_FREE: number = 56;
@Component
export struct Mine {
  @State blankHeight: number = TITLE_BAR_HEIGHT_FREE;
  @StorageProp('safeTop') safeTop: number = 0
  @StorageProp('safeBottom') safeBottom: number = 0
  @Consume('pathStack') pathStack: NavPathStack;
  @State titleMode: HdsNavDestinationTitleMode = HdsNavDestinationTitleMode.MINI;
  @StorageProp('currentColorMode') isDarkMode: number = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;

  build() {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.TopStart }){
        Scroll(){
          Column(){
            Blank().width('100%').height(this.blankHeight + this.safeTop)
            List({ space: 12 }) {
              ListItemGroup() {
                ListItem({ style: ListItemStyle.CARD }) {
                  CardItem({
                    isShow: true,
                    textContent: '深色模式',
                    symbolSrc: $r('sys.symbol.circle_filled_and_circle'),
                    onclick: () => {
                      this.pathStack.pushPathByName( 'DarkModeSetting', 0 )
                    },
                  })
                }
                .height(undefined)
                .width('100%')
              }
              .divider({
                strokeWidth: 1,
                color: $r('sys.color.comp_divider'),
                startMargin: $r('sys.float.padding_level24'),
                endMargin: $r('sys.float.padding_level6'),
              })
              .padding($r('sys.float.padding_level2'))
              .backgroundColor($r('sys.color.comp_background_primary'))
              .borderRadius($r('sys.float.corner_radius_level8'))
            }
            .height(undefined)
            .width('100%')
            .edgeEffect(EdgeEffect.Spring)
            .padding({left:16,right:16})
            Blank().height(56 + this.safeBottom + 8)
          }
          .width('100%')
          .constraintSize({ minHeight: '100%' })
        }
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .width('100%')
        .height('100%')
      }
    }
    .titleMode(this.titleMode)
    .hideBackButton(true)
    .backgroundColor($r('sys.color.background_secondary'))
    .hideTitleBar(false)
    .titleBar({
      style: {
        scrollEffectOpts: {
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.IMMERSIVE,
          materialLevel: hdsMaterial.MaterialLevel.EXQUISITE
        },
      },
      avoidLayoutSafeArea: true,
      content: {
        title: {
          mainTitle: '我的',
        },
      }
    })
  }
}

@Builder
export function MineBuilder() {
  Mine()
}