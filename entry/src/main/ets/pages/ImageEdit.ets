import { STORAGE_KEY_PAGE_TRANSITION_MODE, DEFAULT_PAGE_TRANSITION_MODE } from '../services/PageTransitionSettingsStore';
import { pageSystemTransition, PageTransitionMotion } from '../utils/PageTransition';
import { APP_FONT_FAMILY_KEY, DEFAULT_APP_FONT_FAMILY } from '../services/AppFontStore';
import { common } from '@kit.AbilityKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { SymbolGlyphModifier, uiMaterial } from '@kit.ArkUI';
import {
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  HdsTabs,
  HdsTabsController,
  HdsTabsModifier,
  hdsMaterial,
  ScrollEffectType
} from '@kit.UIDesignKit';
import { ImageEditDrawingCanvas } from '../components/ImageEditDrawingCanvas';
import { destinationTitleBarStyle } from '../utils/DestinationTitleBar';
import {
  cardSurfaceColor,
  fieldSurfaceColor,
  pageSurfaceColor,
  secondaryButtonSurfaceColor
} from '../utils/ThemeColors';

const IMAGE_EDIT_PREVIEW_ID: string = 'harmonyx_image_edit_preview';
const FILTER_ORIGINAL: number = 0;
const TOOL_CROP: number = 0;
const TOOL_FILTER: number = 1;
const TOOL_TEXT: number = 2;
const TOOL_DRAW: number = 3;

interface ImageEditFilterPreset {
  title: Resource;
  colorBlend: string;
  brightness: number;
  contrast: number;
  saturation: number;
}

interface ImageEditHistoryEntry {
  drawingAction: boolean;
  ratioIndex: number;
  rotationQuarterTurns: number;
  flippedHorizontally: boolean;
  filterIndex: number;
  overlayText: string;
  overlayTextColor: string;
  overlayTextOffsetX: number;
  overlayTextOffsetY: number;
  penColor: string;
}

const IMAGE_EDIT_FILTERS: ImageEditFilterPreset[] = [
  { title: $r('app.string.image_edit_filter_original'), colorBlend: 'rgba(0,0,0,0)', brightness: 1, contrast: 1, saturation: 1 },
  { title: $r('app.string.image_edit_filter_vintage'), colorBlend: '#D4A574', brightness: 1.05, contrast: 1.1, saturation: 0.85 },
  { title: $r('app.string.image_edit_filter_black_white'), colorBlend: '#000000', brightness: 1.2, contrast: 1.2, saturation: 0 },
  { title: $r('app.string.image_edit_filter_warm'), colorBlend: '#FFA500', brightness: 1.08, contrast: 1.05, saturation: 1.15 },
  { title: $r('app.string.image_edit_filter_cool'), colorBlend: '#4169E1', brightness: 1, contrast: 1.1, saturation: 0.9 },
  { title: $r('app.string.image_edit_filter_sepia'), colorBlend: '#704214', brightness: 1.05, contrast: 1.05, saturation: 0.6 },
  { title: $r('app.string.image_edit_filter_fade'), colorBlend: '#FFFFFF', brightness: 1.1, contrast: 0.85, saturation: 0.8 },
  { title: $r('app.string.image_edit_filter_dramatic'), colorBlend: '#000000', brightness: 0.95, contrast: 1.4, saturation: 1.2 }
];

const IMAGE_EDIT_COLORS: string[] = ['#FFFFFF', '#101828', '#FFE17A', '#FF5C5C', '#30D158', '#5AC8FA'];

export interface ImageEditRouteParam {
  imageUri: string;
}

export interface ImageEditResult {
  imageUri: string;
}

@Builder
export function ImageEditBuilder(): void {
  ImageEditPage();
}

@Component
export struct ImageEditPage {
  @State private pageMotion: PageTransitionMotion = new PageTransitionMotion();
  @StorageProp(STORAGE_KEY_PAGE_TRANSITION_MODE) private pageTransitionMode: string = DEFAULT_PAGE_TRANSITION_MODE;
  @StorageProp(APP_FONT_FAMILY_KEY) private appFontFamily: string = DEFAULT_APP_FONT_FAMILY;
  @Consume('pageStack') pageStack: NavPathStack;
  @StorageProp('harmonyx.navigation_indicator_height') navigationIndicatorHeight: number =
    AppStorage.get<number>('harmonyx.navigation_indicator_height') ?? 0;
  @StorageLink('harmonyx.accent_color') accentColor: string = '#007DFF';
  @StorageProp('harmonyx.display_mode') private themeDisplayMode: string = '';
  @StorageProp('harmonyx.dark_surface') private themeDarkSurface: string = '';
  @StorageLink('harmonyx.title_bar_style_mode') titleBarStyleMode: number = 0;
  @State private previewPixelMap: image.PixelMap | null = null;
  @State private loading: boolean = true;
  @State private processing: boolean = false;
  @State private errorMessage: Resource = $r('app.string.image_edit_load_failed');
  @State private hasError: boolean = false;
  @State private canUndo: boolean = false;
  @State private canRedo: boolean = false;
  @State private ratioIndex: number = 0;
  @State private rotationQuarterTurns: number = 0;
  @State private flippedHorizontally: boolean = false;
  @State private activeTool: number = TOOL_CROP;
  @State private panelVisible: boolean = true;
  @State private toolTabsModifier: HdsTabsModifier = new HdsTabsModifier();
  @State private filterIndex: number = FILTER_ORIGINAL;
  @State private overlayText: string = '';
  @State private overlayTextColor: string = '#FFFFFF';
  @State private overlayTextOffsetX: number = 0;
  @State private overlayTextOffsetY: number = 0;
  @State private overlayTextSelected: boolean = false;
  @State private penColor: string = '#FF5C5C';
  @State private drawingCanvasMounted: boolean = false;
  @State private drawingStrokeCount: number = 0;
  @State private undoSignal: number = 0;
  @State private redoSignal: number = 0;
  @State private clearSignal: number = 0;
  @State private previewWidth: number = 0;
  @State private previewHeight: number = 0;
  @State private scrollViewportWidth: number = 0;
  @State private scrollViewportHeight: number = 0;
  private previewAreaWidth: number = 0;
  private previewAreaHeight: number = 0;
  private overlayTextDragStartX: number = 0;
  private overlayTextDragStartY: number = 0;
  private toolTabsController: HdsTabsController = new HdsTabsController();
  private undoHistory: ImageEditHistoryEntry[] = [];
  private redoHistory: ImageEditHistoryEntry[] = [];
  private imageUri: string = '';
  private imageFile: fileIo.File | null = null;
  private imageSource: image.ImageSource | null = null;

  aboutToDisappear(): void {
    this.releaseImageResources();
  }

  aboutToAppear(): void {
    this.toolTabsModifier
      .vertical(false)
      .barPosition(BarPosition.End)
      .barHeight(56)
      .barFloatingStyle({
        adaptToHandedness: true,
        barBottomMargin: this.navigationIndicatorHeight,
        lightColor: this.accentColor,
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.IMMERSIVE,
          materialLevel: hdsMaterial.MaterialLevel.EXQUISITE
        }
      });
  }

  private text(resource: Resource): string {
    const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    return context.resourceManager.getStringSync(resource);
  }

  private readRoute(param: ImageEditRouteParam): void {
    this.imageUri = param.imageUri;
    void this.loadImage();
  }

  private async loadImage(): Promise<void> {
    if (this.imageUri.length === 0) {
      this.loading = false;
      this.hasError = true;
      return;
    }
    try {
      const opened: fileIo.File = fileIo.openSync(this.imageUri, fileIo.OpenMode.READ_ONLY);
      this.imageFile = opened;
      const source: image.ImageSource = image.createImageSource(opened.fd);
      this.imageSource = source;
      await this.refreshPreview();
    } catch (error) {
      this.loading = false;
      this.hasError = true;
    }
  }

  private currentFilter(): ImageEditFilterPreset {
    return IMAGE_EDIT_FILTERS[this.filterIndex];
  }

  private aspectRatioForSelection(): number {
    if (this.ratioIndex === 1) {
      return 1;
    }
    if (this.ratioIndex === 2) {
      return 4 / 3;
    }
    if (this.ratioIndex === 3) {
      return 16 / 9;
    }
    return 0;
  }

  private async refreshPreview(): Promise<void> {
    const source: image.ImageSource | null = this.imageSource;
    if (source === null || this.processing) {
      return;
    }
    this.processing = true;
    this.hasError = false;
    const previous: image.PixelMap | null = this.previewPixelMap;
    let workingPreview: image.PixelMap | null = null;
    try {
      const preview: image.PixelMap = await source.createPixelMap({ editable: true });
      workingPreview = preview;
      if (this.rotationQuarterTurns > 0) {
        await preview.rotate(this.rotationQuarterTurns * 90);
      }
      if (this.flippedHorizontally) {
        await preview.flip(true, false);
      }
      const ratio: number = this.aspectRatioForSelection();
      if (ratio > 0) {
        const size: image.Size = preview.getImageInfoSync().size;
        let cropWidth: number = size.width;
        let cropHeight: number = size.height;
        if (size.width / size.height > ratio) {
          cropWidth = Math.floor(size.height * ratio);
        } else {
          cropHeight = Math.floor(size.width / ratio);
        }
        const x: number = Math.floor((size.width - cropWidth) / 2);
        const y: number = Math.floor((size.height - cropHeight) / 2);
        const region: image.Region = {
          x: x,
          y: y,
          size: { width: cropWidth, height: cropHeight }
        };
        await preview.crop(region);
      }
      this.previewPixelMap = preview;
      workingPreview = null;
      this.updatePreviewBounds();
      this.loading = false;
      if (previous !== null) {
        try {
          await previous.release();
        } catch (error) {
        }
      }
    } catch (error) {
      if (workingPreview !== null) {
        try {
          await workingPreview.release();
        } catch (releaseError) {
        }
      }
      this.hasError = true;
      this.errorMessage = $r('app.string.image_edit_load_failed');
      this.loading = false;
    } finally {
      this.processing = false;
    }
  }

  private onPreviewAreaChanged(_oldValue: Area, newValue: Area): void {
    this.previewAreaWidth = Number(newValue.width);
    this.previewAreaHeight = Number(newValue.height);
    this.updatePreviewBounds();
  }

  private onScrollAreaChanged(_oldValue: Area, newValue: Area): void {
    const width: number = Number(newValue.width);
    const height: number = Number(newValue.height);
    if (width > 0 && Math.abs(width - this.scrollViewportWidth) > 1) {
      this.scrollViewportWidth = width;
    }
    if (height > 0 && Math.abs(height - this.scrollViewportHeight) > 1) {
      this.scrollViewportHeight = height;
    }
  }

  private editorStageHeight(): number {
    const preview: image.PixelMap | null = this.previewPixelMap;
    if (preview === null) {
      return 280;
    }
    const size: image.Size = preview.getImageInfoSync().size;
    if (size.width <= 0 || size.height <= 0) {
      return 280;
    }
    const contentWidth: number = this.scrollViewportWidth > 0 ? this.scrollViewportWidth : 360;
    return contentWidth / (size.width / size.height);
  }

  private updatePreviewBounds(): void {
    const preview: image.PixelMap | null = this.previewPixelMap;
    if (preview === null || this.previewAreaWidth <= 0 || this.previewAreaHeight <= 0) {
      return;
    }
    const size: image.Size = preview.getImageInfoSync().size;
    if (size.width <= 0 || size.height <= 0) {
      return;
    }
    const ratio: number = size.width / size.height;
    let width: number = this.previewAreaWidth;
    let height: number = width / ratio;
    if (height > this.previewAreaHeight) {
      height = this.previewAreaHeight;
      width = height * ratio;
    }
    this.previewWidth = width;
    this.previewHeight = height;
  }

  private historyEntry(drawingAction: boolean): ImageEditHistoryEntry {
    return {
      drawingAction: drawingAction,
      ratioIndex: this.ratioIndex,
      rotationQuarterTurns: this.rotationQuarterTurns,
      flippedHorizontally: this.flippedHorizontally,
      filterIndex: this.filterIndex,
      overlayText: this.overlayText,
      overlayTextColor: this.overlayTextColor,
      overlayTextOffsetX: this.overlayTextOffsetX,
      overlayTextOffsetY: this.overlayTextOffsetY,
      penColor: this.penColor
    };
  }

  private updateHistoryAvailability(): void {
    this.canUndo = this.undoHistory.length > 0;
    this.canRedo = this.redoHistory.length > 0;
  }

  private recordEditHistory(drawingAction: boolean): void {
    this.undoHistory.push(this.historyEntry(drawingAction));
    if (this.undoHistory.length > 50) {
      this.undoHistory.shift();
    }
    this.redoHistory = [];
    this.updateHistoryAvailability();
  }

  private restoreHistoryEntry(entry: ImageEditHistoryEntry): void {
    const cropChanged: boolean = this.ratioIndex !== entry.ratioIndex ||
      this.rotationQuarterTurns !== entry.rotationQuarterTurns ||
      this.flippedHorizontally !== entry.flippedHorizontally;
    this.ratioIndex = entry.ratioIndex;
    this.rotationQuarterTurns = entry.rotationQuarterTurns;
    this.flippedHorizontally = entry.flippedHorizontally;
    this.filterIndex = entry.filterIndex;
    this.overlayText = entry.overlayText;
    this.overlayTextColor = entry.overlayTextColor;
    this.overlayTextOffsetX = entry.overlayTextOffsetX;
    this.overlayTextOffsetY = entry.overlayTextOffsetY;
    this.penColor = entry.penColor;
    if (cropChanged) {
      void this.refreshPreview();
    }
  }

  private undoLastAction(): void {
    if (this.processing) {
      return;
    }
    const previous: ImageEditHistoryEntry | undefined = this.undoHistory.pop();
    if (previous === undefined) {
      return;
    }
    this.redoHistory.push(this.historyEntry(previous.drawingAction));
    if (previous.drawingAction) {
      this.undoSignal++;
    } else {
      this.restoreHistoryEntry(previous);
    }
    this.updateHistoryAvailability();
  }

  private redoLastAction(): void {
    if (this.processing) {
      return;
    }
    const next: ImageEditHistoryEntry | undefined = this.redoHistory.pop();
    if (next === undefined) {
      return;
    }
    this.undoHistory.push(this.historyEntry(next.drawingAction));
    if (next.drawingAction) {
      this.redoSignal++;
    } else {
      this.restoreHistoryEntry(next);
    }
    this.updateHistoryAvailability();
  }

  private clearDrawing(): void {
    if (this.processing || this.drawingStrokeCount === 0) {
      return;
    }
    this.recordEditHistory(true);
    this.clearSignal++;
  }

  private updateOverlayText(value: string): void {
    if (this.overlayText === value || this.processing) {
      return;
    }
    this.recordEditHistory(false);
    this.overlayText = value;
    if (value.trim().length === 0) {
      this.overlayTextOffsetX = 0;
      this.overlayTextOffsetY = 0;
      this.overlayTextSelected = false;
    }
  }

  private selectOverlayText(): void {
    if (!this.processing && this.overlayText.trim().length > 0) {
      this.overlayTextSelected = true;
    }
  }

  private beginOverlayTextDrag(): void {
    if (this.processing || this.overlayText.trim().length === 0) {
      return;
    }
    this.recordEditHistory(false);
    this.overlayTextSelected = true;
    this.overlayTextDragStartX = this.overlayTextOffsetX;
    this.overlayTextDragStartY = this.overlayTextOffsetY;
  }

  private moveOverlayText(event: GestureEvent): void {
    if (this.previewWidth <= 0 || this.previewHeight <= 0) {
      return;
    }
    const nextX: number = this.overlayTextDragStartX + event.offsetX / this.previewWidth;
    const nextY: number = this.overlayTextDragStartY + event.offsetY / this.previewHeight;
    this.overlayTextOffsetX = Math.min(0.44, Math.max(-0.44, nextX));
    this.overlayTextOffsetY = Math.min(0.44, Math.max(-0.44, nextY));
  }

  private editSelectedOverlayText(): void {
    if (this.processing) {
      return;
    }
    this.overlayTextSelected = false;
    this.selectTool(TOOL_TEXT);
  }

  private deleteOverlayText(): void {
    if (this.processing || this.overlayText.trim().length === 0) {
      return;
    }
    this.recordEditHistory(false);
    this.overlayText = '';
    this.overlayTextOffsetX = 0;
    this.overlayTextOffsetY = 0;
    this.overlayTextSelected = false;
  }

  private selectColor(color: string, forText: boolean): void {
    if (this.processing || (forText ? this.overlayTextColor === color : this.penColor === color)) {
      return;
    }
    this.recordEditHistory(false);
    if (forText) {
      this.overlayTextColor = color;
    } else {
      this.penColor = color;
    }
  }

  private selectRatio(index: number): void {
    if (this.processing || this.ratioIndex === index) {
      return;
    }
    this.recordEditHistory(false);
    this.ratioIndex = index;
    void this.refreshPreview();
  }

  private rotateLeft(): void {
    if (this.processing) {
      return;
    }
    this.recordEditHistory(false);
    this.rotationQuarterTurns = (this.rotationQuarterTurns + 3) % 4;
    void this.refreshPreview();
  }

  private rotateRight(): void {
    if (this.processing) {
      return;
    }
    this.recordEditHistory(false);
    this.rotationQuarterTurns = (this.rotationQuarterTurns + 1) % 4;
    void this.refreshPreview();
  }

  private flipHorizontal(): void {
    if (this.processing) {
      return;
    }
    this.recordEditHistory(false);
    this.flippedHorizontally = !this.flippedHorizontally;
    void this.refreshPreview();
  }

  private selectTool(tool: number): void {
    if (this.processing || this.loading || this.previewPixelMap === null) {
      return;
    }
    this.activeTool = tool;
    this.overlayTextSelected = false;
    this.panelVisible = true;
    if (tool === TOOL_DRAW) {
      this.drawingCanvasMounted = true;
    }
  }

  private selectFilter(index: number): void {
    if (this.processing || this.filterIndex === index) {
      return;
    }
    this.recordEditHistory(false);
    this.filterIndex = index;
  }

  private updateDrawingStrokeCount(count: number): void {
    this.drawingStrokeCount = count;
  }

  private hasEdits(): boolean {
    return this.rotationQuarterTurns !== 0 || this.flippedHorizontally || this.ratioIndex !== 0 ||
      this.filterIndex !== FILTER_ORIGINAL || this.overlayText.trim().length > 0 ||
      this.drawingStrokeCount > 0;
  }

  private captureScale(snapshot: image.PixelMap, target: image.PixelMap): number {
    const snapshotSize: image.Size = snapshot.getImageInfoSync().size;
    const targetSize: image.Size = target.getImageInfoSync().size;
    if (snapshotSize.width <= 0 || snapshotSize.height <= 0 ||
      targetSize.width <= 0 || targetSize.height <= 0) {
      return 1;
    }
    const targetRatio: number = targetSize.width / targetSize.height;
    let renderedWidth: number = snapshotSize.width;
    let renderedHeight: number = snapshotSize.height;
    if (renderedWidth / renderedHeight > targetRatio) {
      renderedWidth = renderedHeight * targetRatio;
    } else {
      renderedHeight = renderedWidth / targetRatio;
    }
    const scaleX: number = targetSize.width / renderedWidth;
    const scaleY: number = targetSize.height / renderedHeight;
    return Math.min(6, Math.max(1, Math.min(scaleX, scaleY)));
  }

  private async captureEditedPreview(): Promise<image.PixelMap> {
    const source: image.PixelMap | null = this.previewPixelMap;
    if (source === null) {
      throw new Error('Preview is not ready');
    }
    const snapshotApi = this.getUIContext().getComponentSnapshot();
    let captured: image.PixelMap = await snapshotApi.get(IMAGE_EDIT_PREVIEW_ID,
      { waitUntilRenderFinished: true });
    const scale: number = this.captureScale(captured, source);
    if (scale > 1.05) {
      await captured.release();
      captured = await snapshotApi.get(IMAGE_EDIT_PREVIEW_ID,
        { scale: scale, waitUntilRenderFinished: true });
    }
    const targetSize: image.Size = source.getImageInfoSync().size;
    const capturedSize: image.Size = captured.getImageInfoSync().size;
    const ratio: number = targetSize.width / targetSize.height;
    let cropWidth: number = capturedSize.width;
    let cropHeight: number = capturedSize.height;
    if (capturedSize.width / capturedSize.height > ratio) {
      cropWidth = Math.max(1, Math.floor(capturedSize.height * ratio));
    } else {
      cropHeight = Math.max(1, Math.floor(capturedSize.width / ratio));
    }
    const x: number = Math.floor((capturedSize.width - cropWidth) / 2);
    const y: number = Math.floor((capturedSize.height - cropHeight) / 2);
    const region: image.Region = {
      x: x,
      y: y,
      size: { width: cropWidth, height: cropHeight }
    };
    await captured.crop(region);
    return captured;
  }

  private async applyEdits(): Promise<void> {
    if (this.processing || this.loading || this.previewPixelMap === null) {
      return;
    }
    if (!this.hasEdits()) {
      const unchanged: ImageEditResult = { imageUri: this.imageUri };
      this.pageStack.pop(unchanged);
      return;
    }
    this.overlayTextSelected = false;
    this.processing = true;
    this.hasError = false;
    let outputFile: fileIo.File | undefined = undefined;
    let captured: image.PixelMap | null = null;
    let packer: image.ImagePacker | null = null;
    try {
      captured = await this.captureEditedPreview();
      const context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      const outputPath: string = context.cacheDir + '/harmonyx-edited-' + Date.now().toString() + '.jpg';
      outputFile = fileIo.openSync(outputPath,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      packer = image.createImagePacker();
      const data: ArrayBuffer = await packer.packToData(captured, {
        format: 'image/jpeg',
        quality: 92
      });
      fileIo.writeSync(outputFile.fd, data);
      const result: ImageEditResult = { imageUri: fileUri.getUriFromPath(outputPath) };
      this.pageStack.pop(result);
    } catch (error) {
      this.hasError = true;
      this.errorMessage = $r('app.string.image_edit_save_failed');
    } finally {
      if (outputFile !== undefined) {
        try {
          fileIo.closeSync(outputFile.fd);
        } catch (error) {
        }
      }
      if (packer !== null) {
        try {
          await packer.release();
        } catch (error) {
        }
      }
      if (captured !== null) {
        try {
          await captured.release();
        } catch (error) {
        }
      }
      this.processing = false;
    }
  }

  private releaseImageResources(): void {
    const pixelMap: image.PixelMap | null = this.previewPixelMap;
    this.previewPixelMap = null;
    if (pixelMap !== null) {
      pixelMap.release().catch((): void => {
      });
    }
    const source: image.ImageSource | null = this.imageSource;
    this.imageSource = null;
    if (source !== null) {
      source.release().catch((): void => {
      });
    }
    const file: fileIo.File | null = this.imageFile;
    this.imageFile = null;
    if (file !== null) {
      try {
        fileIo.closeSync(file.fd);
      } catch (error) {
      }
    }
  }

  private activeToolTitle(): Resource {
    if (this.activeTool === TOOL_FILTER) {
      return $r('app.string.image_edit_tool_filter');
    }
    if (this.activeTool === TOOL_TEXT) {
      return $r('app.string.image_edit_tool_text');
    }
    if (this.activeTool === TOOL_DRAW) {
      return $r('app.string.image_edit_tool_draw');
    }
    return $r('app.string.image_edit_tool_crop');
  }

  private controlPanelMaterial(): uiMaterial.Material | undefined {
    if (!deviceInfo.apiAvailable('26.0.0')) {
      return undefined;
    }
    return new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.REGULAR,
      interactive: true,
      applyShadow: false,
      colorInvert: true,
      lightEffect: {}
    });
  }

  private toolButtonMaterial(color: string): uiMaterial.Material | undefined {
    if (!deviceInfo.apiAvailable('26.0.0')) {
      return undefined;
    }
    let materialColor: string = color;
    if (color.length === 7 && color.substring(0, 1) === '#') {
      materialColor = '#55' + color.substring(1);
    }
    return new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.THIN,
      materialColor: materialColor,
      interactive: true,
      applyShadow: false,
      colorInvert: false,
      lightEffect: { color: color }
    });
  }

  private toolButtonSurfaceColor(color: string): string {
    if (color.length === 7 && color.substring(0, 1) === '#') {
      return '#33' + color.substring(1);
    }
    return color;
  }

  private imageScrollDirection(): ScrollDirection {
    if (this.activeTool === TOOL_TEXT || this.activeTool === TOOL_DRAW) {
      return ScrollDirection.None;
    }
    return ScrollDirection.Vertical;
  }

  private filterTint(index: number): string {
    if (index === 0) {
      return this.accentColor;
    }
    return IMAGE_EDIT_FILTERS[index].colorBlend;
  }

  private toolPanelHeight(): number {
    if (this.activeTool === TOOL_TEXT) {
      return 210;
    }
    if (this.activeTool === TOOL_DRAW) {
      return 144;
    }
    return 164;
  }

  @Builder
  private ToolPanelNavigation(): void {
    Navigation() {
      Column()
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.None)
    }
    .title({
      builder: (): void => {
        this.ToolPanel();
      },
      height: this.toolPanelHeight()
    }, { barStyle: BarStyle.STACK })
    .titleMode(NavigationTitleMode.Full)
    .mode(NavigationMode.Stack)
    .hideToolBar(true)
    .backgroundColor(Color.Transparent)
    .width('100%')
    .height(this.toolPanelHeight())
    .margin({ top: 12, bottom: 8 });
  }

  private toolTabBar(icon: Resource, label: Resource): BottomTabBarStyle {
    const normalGlyphModifier: SymbolGlyphModifier = new SymbolGlyphModifier(icon)
      .renderingStrategy(SymbolRenderingStrategy.SINGLE);
    normalGlyphModifier.fontColor([$r('sys.color.icon_primary')]);
    const selectedGlyphModifier: SymbolGlyphModifier = new SymbolGlyphModifier(icon)
      .renderingStrategy(SymbolRenderingStrategy.SINGLE);
    selectedGlyphModifier.fontColor([this.accentColor]);
    return BottomTabBarStyle.of({
      normal: normalGlyphModifier,
      selected: selectedGlyphModifier
    }, label)
      .labelStyle({
        unselectedColor: $r('sys.color.font_primary'),
        selectedColor: this.accentColor
      })
      .padding({ bottom: 0 });
  }

  @Builder
  private ToolTabs(): void {
    HdsTabs({ controller: this.toolTabsController, index: this.activeTool }) {
      TabContent() {
        Column().width('100%').height('100%').hitTestBehavior(HitTestMode.None);
      }
      .tabBar(this.toolTabBar($r('sys.symbol.slider_horizontal_2_square'),
        $r('app.string.image_edit_tool_crop')))

      TabContent() {
        Column().width('100%').height('100%').hitTestBehavior(HitTestMode.None);
      }
      .tabBar(this.toolTabBar($r('sys.symbol.wand_and_stars'), $r('app.string.image_edit_tool_filter')))

      TabContent() {
        Column().width('100%').height('100%').hitTestBehavior(HitTestMode.None);
      }
      .tabBar(this.toolTabBar($r('sys.symbol.textformat_size_square'), $r('app.string.image_edit_tool_text')))

      TabContent() {
        Column().width('100%').height('100%').hitTestBehavior(HitTestMode.None);
      }
      .tabBar(this.toolTabBar($r('sys.symbol.square_and_pencil'), $r('app.string.image_edit_tool_draw')))
    }
    .width('100%')
    .height(56 + this.navigationIndicatorHeight)
    .backgroundColor(Color.Transparent)
    .barPosition(BarPosition.End)
    .barOverlap(true)
    .scrollable(false)
    .enabled(!this.processing && !this.loading && this.previewPixelMap !== null)
    .attributeModifier(this.toolTabsModifier)
    .onChange((index: number): void => this.selectTool(index))
    .onTabBarClick((index: number): void => this.selectTool(index));
  }

  @Builder
  private EditorImageScroll(): void {
    Scroll() {
      Stack({ alignContent: Alignment.Center }) {
        if (this.previewPixelMap !== null && this.previewWidth > 0 && this.previewHeight > 0) {
          Stack({ alignContent: Alignment.Center }) {
            Image(this.previewPixelMap)
              .width('100%')
              .height('100%')
              .objectFit(ImageFit.Contain)
              .colorBlend(this.currentFilter().colorBlend)
              .brightness(this.currentFilter().brightness)
              .contrast(this.currentFilter().contrast)
              .saturate(this.currentFilter().saturation);
            if (this.drawingCanvasMounted) {
              ImageEditDrawingCanvas({
                active: this.activeTool === TOOL_DRAW,
                penColor: this.penColor,
                undoSignal: this.undoSignal,
                redoSignal: this.redoSignal,
                clearSignal: this.clearSignal,
                onStrokeStarted: (): void => this.recordEditHistory(true),
                onStrokeCountChanged: (count: number): void => this.updateDrawingStrokeCount(count)
              })
                .width('100%')
                .height('100%');
            }
            if (this.overlayText.trim().length > 0) {
              Column({ space: 8 }) {
                if (this.overlayTextSelected) {
                  Row({ space: 8 }) {
                    Button($r('app.string.image_edit_text_edit'),
                      { type: ButtonType.Capsule, stateEffect: true })
                      .height(32)
                      .fontSize($r('sys.float.Caption_M'))
                      .fontColor($r('app.color.text_primary'))
                      .backgroundColor(deviceInfo.apiAvailable('26.0.0') ? Color.Transparent :
                        this.toolButtonSurfaceColor('#5AC8FA'))
                      .systemMaterial(this.toolButtonMaterial('#5AC8FA'))
                      .enabled(!this.processing)
                      .onClick((): void => this.editSelectedOverlayText());
                    Button($r('app.string.image_edit_text_delete'),
                      { type: ButtonType.Capsule, stateEffect: true })
                      .height(32)
                      .fontSize($r('sys.float.Caption_M'))
                      .fontColor($r('app.color.text_primary'))
                      .backgroundColor(deviceInfo.apiAvailable('26.0.0') ? Color.Transparent :
                        this.toolButtonSurfaceColor('#FF5C5C'))
                      .systemMaterial(this.toolButtonMaterial('#FF5C5C'))
                      .enabled(!this.processing)
                      .onClick((): void => this.deleteOverlayText());
                  }
                  .alignItems(VerticalAlign.Center);
                }
                Text(this.overlayText).fontFamily(this.appFontFamily)
                  .width('88%')
                  .fontSize($r('sys.float.Title_M'))
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.overlayTextColor)
                  .textAlign(TextAlign.Center)
                  .maxLines(6)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .padding({ left: 12, right: 12, top: 8, bottom: 8 })
                  .backgroundColor('rgba(0,0,0,0.38)')
                  .borderRadius(12)
                  .border({ width: this.overlayTextSelected ? 2 : 0,
                    color: this.overlayTextSelected ? this.accentColor : Color.Transparent });
              }
              .width('100%')
              .alignItems(HorizontalAlign.Center)
              .translate({
                x: this.overlayTextOffsetX * this.previewWidth,
                y: this.overlayTextOffsetY * this.previewHeight - (this.overlayTextSelected ? 20 : 0)
              })
              .gesture(
                GestureGroup(GestureMode.Exclusive,
                  PanGesture({ fingers: 1, direction: PanDirection.All })
                    .onActionStart((): void => this.beginOverlayTextDrag())
                    .onActionUpdate((event: GestureEvent): void => this.moveOverlayText(event)),
                  TapGesture({ count: 1 }).onAction((): void => this.selectOverlayText())
                )
              );
            }
          }
          .width(this.previewWidth)
          .height(this.previewHeight)
          .id(IMAGE_EDIT_PREVIEW_ID);
        } else if (this.loading || this.processing) {
          LoadingProgress()
            .width(42)
            .height(42)
            .color(this.accentColor);
        }
        if (this.processing && this.previewPixelMap !== null) {
          LoadingProgress()
            .width(38)
            .height(38)
            .color(this.accentColor);
        }
        if (this.hasError) {
          Text(this.text(this.errorMessage)).fontFamily(this.appFontFamily)
            .fontSize($r('sys.float.Body_S'))
            .fontColor($r('app.color.danger'))
            .width('100%')
            .textAlign(TextAlign.Center);
        }
      }
      .width('100%')
      .height(this.editorStageHeight())
      .onAreaChange((oldValue: Area, newValue: Area): void => this.onPreviewAreaChanged(oldValue, newValue));
    }
    .width('100%')
    .height('100%')
    .scrollable(this.imageScrollDirection())
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .onAreaChange((oldValue: Area, newValue: Area): void => this.onScrollAreaChanged(oldValue, newValue));
  }

  @Builder
  private ToolPanelHeader(): void {
    Row({ space: 10 }) {
      Text(this.activeToolTitle()).fontFamily(this.appFontFamily)
        .layoutWeight(1)
        .fontSize($r('sys.float.Title_S'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .maxLines(1);

      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.xmark'))
          .fontSize(12)
          .fontColor([$r('app.color.text_primary')]);
      }
      .width(34)
      .height(34)
      .padding(0)
      .backgroundColor(deviceInfo.apiAvailable('26.0.0') ? Color.Transparent :
        this.toolButtonSurfaceColor('#8290A5'))
      .systemMaterial(this.toolButtonMaterial('#8290A5'))
      .onClick((): void => { this.panelVisible = false; });
    }
    .width('100%')
    .alignItems(VerticalAlign.Center);
  }

  @Builder
  private ToolPanel(): void {
    Column({ space: 10 }) {
      this.ToolPanelHeader();

      if (this.activeTool === TOOL_CROP) {
        Column({ space: 8 }) {
          Row({ space: 6 }) {
            this.RatioButton(0, $r('app.string.image_edit_original'));
            this.RatioButton(1, $r('app.string.image_edit_square'));
            this.RatioButton(2, $r('app.string.image_edit_ratio_4_3'));
            this.RatioButton(3, $r('app.string.image_edit_ratio_16_9'));
          }
          .width('100%');

          Row({ space: 8 }) {
            Button($r('app.string.image_edit_rotate_left'), { type: ButtonType.Capsule, stateEffect: true })
              .layoutWeight(1)
              .height(38)
              .fontSize($r('sys.float.Body_S'))
              .fontColor($r('app.color.text_primary'))
              .backgroundColor(deviceInfo.apiAvailable('26.0.0') ? Color.Transparent :
                this.toolButtonSurfaceColor('#5AC8FA'))
              .systemMaterial(this.toolButtonMaterial('#5AC8FA'))
              .enabled(!this.processing)
              .onClick((): void => this.rotateLeft());
            Button($r('app.string.image_edit_rotate_right'), { type: ButtonType.Capsule, stateEffect: true })
              .layoutWeight(1)
              .height(38)
              .fontSize($r('sys.float.Body_S'))
              .fontColor($r('app.color.text_primary'))
              .backgroundColor(deviceInfo.apiAvailable('26.0.0') ? Color.Transparent :
                this.toolButtonSurfaceColor('#007DFF'))
              .systemMaterial(this.toolButtonMaterial('#007DFF'))
              .enabled(!this.processing)
              .onClick((): void => this.rotateRight());
            Button($r('app.string.image_edit_flip'), { type: ButtonType.Capsule, stateEffect: true })
              .layoutWeight(1)
              .height(38)
              .fontSize($r('sys.float.Body_S'))
              .fontColor($r('app.color.text_primary'))
              .backgroundColor(deviceInfo.apiAvailable('26.0.0') ? Color.Transparent :
                this.toolButtonSurfaceColor('#AF52DE'))
              .systemMaterial(this.toolButtonMaterial('#AF52DE'))
              .enabled(!this.processing)
              .onClick((): void => this.flipHorizontal());
          }
          .width('100%');
        }
        .width('100%');
      } else if (this.activeTool === TOOL_FILTER) {
        Scroll() {
          Row({ space: 7 }) {
            ForEach(IMAGE_EDIT_FILTERS, (preset: ImageEditFilterPreset, index: number) => {
              this.FilterCell(index, preset);
            }, (preset: ImageEditFilterPreset, index: number): string => index.toString());
          }
          .padding({ left: 2, right: 2, top: 2, bottom: 2 });
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%');
      } else if (this.activeTool === TOOL_TEXT) {
        Column({ space: 8 }) {
          TextArea({ text: this.overlayText, placeholder: $r('app.string.image_edit_text_placeholder') }).fontFamily(this.appFontFamily)
            .keyboardAppearance(KeyboardAppearance.IMMERSIVE)
            .height(58)
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('app.color.text_primary'))
            .placeholderColor($r('app.color.text_secondary'))
            .backgroundColor(fieldSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
            .borderRadius(14)
            .enabled(!this.processing)
            .onChange((value: string): void => this.updateOverlayText(value));
          Row({ space: 6 }) {
            Text($r('app.string.image_edit_text_color')).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Caption_M'))
              .fontColor($r('app.color.text_secondary'));
            Blank();
            Button($r('app.string.image_edit_text_clear'), { type: ButtonType.Capsule, stateEffect: true })
              .fontSize($r('sys.float.Caption_M'))
              .fontColor($r('app.color.danger'))
              .backgroundColor(deviceInfo.apiAvailable('26.0.0') ? Color.Transparent :
                this.toolButtonSurfaceColor('#FF5C5C'))
              .systemMaterial(this.toolButtonMaterial('#FF5C5C'))
              .enabled(!this.processing && this.overlayText.length > 0)
              .onClick((): void => this.deleteOverlayText());
          }
          .width('100%');
          Scroll() {
            Row({ space: 6 }) {
              ForEach(IMAGE_EDIT_COLORS, (color: string): void => {
                this.ColorButton(color, true);
              }, (color: string): string => color);
            }
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .width('100%');
        }
        .width('100%');
      } else if (this.activeTool === TOOL_DRAW) {
        Column({ space: 8 }) {
          Row({ space: 6 }) {
            Text($r('app.string.image_edit_brush_color')).fontFamily(this.appFontFamily)
              .fontSize($r('sys.float.Caption_M'))
              .fontColor($r('app.color.text_secondary'));
            Blank();
            Button($r('app.string.image_edit_draw_clear'), { type: ButtonType.Capsule, stateEffect: true })
              .fontSize($r('sys.float.Caption_M'))
              .fontColor($r('app.color.danger'))
              .backgroundColor(deviceInfo.apiAvailable('26.0.0') ? Color.Transparent :
                this.toolButtonSurfaceColor('#FF5C5C'))
              .systemMaterial(this.toolButtonMaterial('#FF5C5C'))
              .enabled(!this.processing && this.drawingStrokeCount > 0)
              .onClick((): void => this.clearDrawing());
          }
          .width('100%');
          Scroll() {
            Row({ space: 6 }) {
              ForEach(IMAGE_EDIT_COLORS, (color: string): void => {
                this.ColorButton(color, false);
              }, (color: string): string => color);
            }
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .width('100%');
        }
        .width('100%');
      }
    }
    .width('100%')
    .height(this.toolPanelHeight())
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .backgroundColor(deviceInfo.apiAvailable('26.0.0') ? Color.Transparent :
      cardSurfaceColor(this.themeDisplayMode, this.themeDarkSurface))
    .border({ width: deviceInfo.apiAvailable('26.0.0') ? 0 : 1, color: $r('app.color.divider') })
    .borderRadius(26)
    .clip(true)
    .systemMaterial(this.controlPanelMaterial());
  }

  @Builder
  private RatioButton(index: number, label: Resource): void {
    Button(label, { type: ButtonType.Capsule, stateEffect: true })
      .layoutWeight(1)
      .height(38)
      .fontSize($r('sys.float.Body_S'))
      .fontColor(this.ratioIndex === index ? $r('app.color.text_on_brand') : $r('app.color.text_primary'))
      .backgroundColor(deviceInfo.apiAvailable('26.0.0') ? Color.Transparent :
        (this.ratioIndex === index ? this.accentColor :
          this.toolButtonSurfaceColor('#718096')))
      .systemMaterial(this.toolButtonMaterial(this.ratioIndex === index ? this.accentColor : '#718096'))
      .enabled(!this.processing)
      .onClick((): void => this.selectRatio(index));
  }

  @Builder
  private FilterCell(index: number, preset: ImageEditFilterPreset): void {
    Button() {
      Column({ space: 6 }) {
        if (this.previewPixelMap !== null) {
          Image(this.previewPixelMap)
            .width(62)
            .height(48)
            .objectFit(ImageFit.Cover)
            .borderRadius(9)
            .colorBlend(preset.colorBlend)
            .brightness(preset.brightness)
            .contrast(preset.contrast)
            .saturate(preset.saturation);
        }
        Text(preset.title).fontFamily(this.appFontFamily)
          .fontSize($r('sys.float.Caption_M'))
          .fontColor(this.filterIndex === index ? $r('app.color.text_primary') : $r('app.color.text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center);
    }
    .width(78)
    .height(82)
    .padding(4)
    .backgroundColor(deviceInfo.apiAvailable('26.0.0') ? Color.Transparent :
      this.toolButtonSurfaceColor(this.filterTint(index)))
    .borderRadius(14)
    .border({ width: this.filterIndex === index ? 2 : 1,
      color: this.filterIndex === index ? this.accentColor : this.filterTint(index) })
    .clip(true)
    .systemMaterial(this.toolButtonMaterial(this.filterTint(index)))
    .enabled(!this.processing)
    .onClick((): void => this.selectFilter(index));
  }

  @Builder
  private ColorButton(color: string, forText: boolean): void {
    Button() {
      Stack({ alignContent: Alignment.Center }) {
        if (forText) {
          Text('A').fontFamily(this.appFontFamily)
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(color === '#FFFFFF' || color === '#FFE17A' || color === '#5AC8FA' ? '#101828' : '#FFFFFF');
        } else {
          Text('●').fontFamily(this.appFontFamily)
            .fontSize(11)
            .fontColor(color === '#FFFFFF' || color === '#FFE17A' || color === '#5AC8FA' ? '#101828' : '#FFFFFF');
        }
      }
      .width(32)
      .height(32)
      .backgroundColor(color)
      .borderRadius(16)
      .border({ width: (forText ? this.overlayTextColor : this.penColor) === color ? 2 : 1,
        color: (forText ? this.overlayTextColor : this.penColor) === color ? this.accentColor :
          $r('app.color.text_secondary') });
    }
    .width(38)
    .height(38)
    .padding(3)
    .backgroundColor(Color.Transparent)
    .systemMaterial(this.toolButtonMaterial(color))
    .enabled(!this.processing)
    .onClick((): void => this.selectColor(color, forText));
  }

  build(): void {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.Bottom }) {
        this.EditorImageScroll();

        Column() {
          Blank().layoutWeight(1);

          if (this.panelVisible && this.previewPixelMap !== null && !this.loading) {
            this.ToolPanelNavigation();
          }

          this.ToolTabs();
        }
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.Transparent);
      }
      .width('100%')
      .height('100%')
      .backgroundColor(pageSurfaceColor(this.themeDisplayMode, this.themeDarkSurface));
    }
    .scale({ x: this.pageMotion.scale, y: this.pageMotion.scale })
    .opacity(this.pageMotion.opacity)
    .systemTransition(pageSystemTransition(this.pageTransitionMode))
    .onReady((context: NavDestinationContext): void => {
      this.pageMotion.attach(context);
      const param: ImageEditRouteParam = context.pathInfo?.param as ImageEditRouteParam;
      if (param !== undefined && param !== null) {
        this.readRoute(param);
      }
    })
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .hideBackButton(false)
    .titleBar({
      avoidLayoutSafeArea: true,
      content: {
        title: { mainTitle: $r('app.string.image_edit_title') },
        menu: {
          value: [
            {
              content: {
                icon: $r('sys.symbol.arrowshape_turn_up_left'),
                label: this.text($r('app.string.image_edit_undo')),
                isEnabled: this.canUndo && !this.processing,
                action: (): void => this.undoLastAction()
              }
            },
            {
              content: {
                icon: $r('sys.symbol.arrowshape_turn_up_right'),
                label: this.text($r('app.string.image_edit_redo')),
                isEnabled: this.canRedo && !this.processing,
                action: (): void => this.redoLastAction()
              }
            },
            {
              content: {
                icon: $r('sys.symbol.checkmark'),
                label: this.text($r('app.string.image_edit_done')),
                isEnabled: !this.processing && !this.loading && this.previewPixelMap !== null,
                action: (): void => {
                  void this.applyEdits();
                }
              }
            }
          ]
        }
      },
      style: destinationTitleBarStyle(ScrollEffectType.GRADIENT_BLUR, this.themeDisplayMode,
        this.themeDarkSurface, this.titleBarStyleMode)
    })
    .onBackPressed((): boolean => {
      if (!this.processing) {
        this.pageStack.pop();
      }
      return true;
    })
    .backgroundColor(pageSurfaceColor(this.themeDisplayMode, this.themeDarkSurface));
  }
}
