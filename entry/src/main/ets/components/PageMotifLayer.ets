import { PAGE_BACKGROUND_MOTIFS, PageBackgroundMotif } from '../models/PageBackgroundMotifs';
import { PageMotifTile, pageMotifTiles } from '../utils/PageMotifLayout';

@Component
export struct PageMotifLayer {
  @Prop motifIds: string[] = [];
  @Prop density: number = 50;
  @Prop strength: number = 0.3;
  @Prop ink: number = -1;
  @Prop fixedWidth: number = 0;
  @Prop fixedHeight: number = 0;
  @Prop syncImages: boolean = false;
  @State private viewportWidth: number = 360;
  @State private viewportHeight: number = 640;

  private motifs(): PageBackgroundMotif[] {
    return PAGE_BACKGROUND_MOTIFS.filter((motif: PageBackgroundMotif): boolean => this.motifIds.indexOf(motif.id) >= 0);
  }
  private tiles(): PageMotifTile[] {
    return pageMotifTiles(this.fixedWidth > 0 ? this.fixedWidth : this.viewportWidth,
      this.fixedHeight > 0 ? this.fixedHeight : this.viewportHeight, this.density, this.motifs().length);
  }
  private imageFor(tile: PageMotifTile): Resource | undefined {
    const motifs: PageBackgroundMotif[] = this.motifs();
    return tile.motifIndex < motifs.length ? motifs[tile.motifIndex].image : undefined;
  }
  private keyFor(tile: PageMotifTile): string {
    const motifs: PageBackgroundMotif[] = this.motifs();
    return tile.key + ':' + (tile.motifIndex < motifs.length ? motifs[tile.motifIndex].id : 'empty');
  }
  private filter(): ColorFilter {
    return this.ink < 0 ? new ColorFilter([1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0]) :
      new ColorFilter([0, 0, 0, this.ink, 0, 0, 0, 0, this.ink, 0, 0, 0, 0, this.ink, 0, 0, 0, 0, 1, 0]);
  }
  build(): void {
    Stack({ alignContent: Alignment.TopStart }) {
      ForEach(this.tiles(), (tile: PageMotifTile) => {
        Image(this.imageFor(tile)).width($r('app.float.page_background_motif_size'))
          .height($r('app.float.page_background_motif_size')).objectFit(ImageFit.Contain).draggable(false)
          .colorFilter(this.filter()).rotate({ angle: tile.rotation }).position({ x: tile.x, y: tile.y }).syncLoad(this.syncImages)
      }, (tile: PageMotifTile): string => this.keyFor(tile))
    }.width('100%').height('100%').clip(true).opacity(this.strength * 0.5)
      .renderGroup(true).hitTestBehavior(HitTestMode.None)
      .onAreaChange((_old: Area, area: Area): void => {
        const width: number = Number(area.width); const height: number = Number(area.height);
        if (this.fixedWidth <= 0 && this.fixedHeight <= 0 && width > 0 && height > 0) {
          this.viewportWidth = width; this.viewportHeight = height;
        }
      })
  }
}
