import { curves } from '@kit.ArkUI';
import { hdsMaterial } from '@kit.UIDesignKit';
import { HdsMiniBarButton } from 'hds_button';

export class Constants {
  static readonly PAGE_PADDING: number = 12;
  static readonly FLOAT_WINDOW_WIDTH: number = 56;
  static readonly FLOAT_WINDOW_HEIGHT: number = 56;
  static readonly INIT_POSITION_Y: number = 300;
}

@Component
export struct FloatWindowMainPage {
  @Prop containerWidth: number = 0;
  @Prop containerHeight: number = 0;
  @State edge: Edges = { top: Constants.INIT_POSITION_Y, right: Constants.PAGE_PADDING };
  onButtonClick: () => void = () => {};
  private windowStartX: number = 0;
  private windowStartY: number = 0;

  onTouchEvent(event: TouchEvent): void {
    switch (event.type) {
      case TouchType.Down: {
        this.windowStartX = event.touches[0].windowX;
        this.windowStartY = event.touches[0].windowY;
        break;
      }
      case TouchType.Move: {
        const windowX: number = event.touches[0].windowX;
        const windowY: number = event.touches[0].windowY;
        this.getUIContext().animateTo({ curve: curves.responsiveSpringMotion() }, () => {
          if (this.edge.left !== undefined) {
            this.edge.left = this.edge.left as number + (windowX - this.windowStartX);
          } else {
            this.edge.right = this.edge.right as number - (windowX - this.windowStartX);
          }
          this.edge.top = this.edge.top as number + (windowY - this.windowStartY);
          this.windowStartX = windowX;
          this.windowStartY = windowY;
        })
        break;
      }
      case TouchType.Up: {
        let centerX: number;
        if (this.edge.left !== undefined) {
          centerX = this.edge.left as number + Constants.FLOAT_WINDOW_WIDTH / 2;
        } else {
          centerX = this.containerWidth - (this.edge.right as number) - Constants.FLOAT_WINDOW_WIDTH / 2;
        }
        animateTo({ curve: curves.springMotion() }, () => {
          if (centerX > (this.containerWidth / 2)) {
            this.edge.right = Constants.PAGE_PADDING;
            this.edge.left = undefined;
          } else {
            this.edge.right = undefined;
            this.edge.left = Constants.PAGE_PADDING;
          }
          if (this.edge.top as number < Constants.PAGE_PADDING) {
            this.edge.top = Constants.PAGE_PADDING;
          } else if (this.edge.top as number >
            this.containerHeight - Constants.FLOAT_WINDOW_HEIGHT - Constants.PAGE_PADDING) {
            this.edge.top = this.containerHeight - Constants.FLOAT_WINDOW_HEIGHT - Constants.PAGE_PADDING;
          }
        })
        break;
      }
      default: {
        break;
      }
    }
  }

  build() {
    HdsMiniBarButton({
      barWidth: Constants.FLOAT_WINDOW_WIDTH,
      barHeight: Constants.FLOAT_WINDOW_HEIGHT,
      iconResource: $r('sys.symbol.plus'),
      iconSize: 24,
      iconColor: [Color.Black],
      materialType: hdsMaterial.MaterialType.IMMERSIVE,
      materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE,
      onButtonClick: () => {
        this.onButtonClick();
      }
    })
      .position(this.edge)
      .onTouch((event: TouchEvent) => {
        this.onTouchEvent(event);
      })
  }
}
