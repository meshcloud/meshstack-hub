import { DIALOG_DATA, DialogRef } from '@angular/cdk/dialog';
import { CommonModule } from '@angular/common';
import {
  AfterViewInit,
  Component,
  ElementRef,
  HostListener,
  Inject,
  ViewChild
} from '@angular/core';

export interface DiagramViewerData {
  /** Title shown in the viewer toolbar. */
  title: string;
  /** The diagram to display — an `<img>` or `<svg>` element. It is cloned, never moved. */
  node: HTMLElement;
  /** Source URL of the diagram, when it has one. Enables "open original". */
  sourceUrl?: string | null;
}

const MIN_SCALE = 0.25;
const MAX_SCALE = 16;
const ZOOM_STEP = 1.25;

/**
 * Fullscreen diagram viewer with zoom and pan. Architecture diagrams are wide and detailed, so
 * browser zoom does not help: the page reflows and the diagram stays fitted to its column.
 */
@Component({
  selector: 'mst-diagram-viewer',
  imports: [CommonModule],
  templateUrl: './diagram-viewer.component.html',
  styleUrl: './diagram-viewer.component.scss',
  standalone: true
})
export class DiagramViewerComponent implements AfterViewInit {
  @ViewChild('canvas', { static: true })
  public canvas!: ElementRef<HTMLElement>;

  @ViewChild('stage', { static: true })
  public stage!: ElementRef<HTMLElement>;

  public scale = 1;

  public translateX = 0;

  public translateY = 0;

  public panning = false;

  private pointerId: number | null = null;

  private panStartX = 0;

  private panStartY = 0;

  private content: HTMLElement | null = null;

  /** Size the diagram renders at when fitted to the stage — the 100% zoom reference. */
  private baseWidth = 0;

  private baseHeight = 0;

  constructor(
    public dialogRef: DialogRef<DiagramViewerComponent>,
    @Inject(DIALOG_DATA) public data: DiagramViewerData
  ) {}

  public get zoomPercent(): number {
    return Math.round(this.scale * 100);
  }

  public ngAfterViewInit(): void {
    const clone = this.data.node.cloneNode(true) as HTMLElement;
    clone.removeAttribute('data-diagram-enhanced');
    clone.classList.add('diagram-viewer-content');
    this.canvas.nativeElement.appendChild(clone);
    this.content = clone;

    if (clone instanceof HTMLImageElement && !clone.complete) {
      clone.addEventListener('load', () => this.captureBaseSize(), { once: true });

      return;
    }

    this.captureBaseSize();
  }

  public zoomIn(): void {
    this.zoomBy(ZOOM_STEP);
  }

  public zoomOut(): void {
    this.zoomBy(1 / ZOOM_STEP);
  }

  /** Back to "fits the viewport" — the state the viewer opens in. */
  public resetView(): void {
    this.scale = 1;
    this.translateX = 0;
    this.translateY = 0;
    this.applyScale();
  }

  @HostListener('wheel', ['$event'])
  public onWheel(event: WheelEvent): void {
    event.preventDefault();
    // Trackpad pinch arrives as a wheel event with ctrlKey set; both gestures zoom.
    const factor = Math.pow(ZOOM_STEP, -event.deltaY / 100);
    this.zoomBy(factor, event.clientX, event.clientY);
  }

  public onPointerDown(event: PointerEvent): void {
    if (event.button !== 0) {
      return;
    }

    this.pointerId = event.pointerId;
    this.panning = true;
    this.panStartX = event.clientX - this.translateX;
    this.panStartY = event.clientY - this.translateY;
    (event.target as HTMLElement).setPointerCapture?.(event.pointerId);
    event.preventDefault();
  }

  public onPointerMove(event: PointerEvent): void {
    if (!this.panning || event.pointerId !== this.pointerId) {
      return;
    }

    this.translateX = event.clientX - this.panStartX;
    this.translateY = event.clientY - this.panStartY;
  }

  public onPointerUp(event: PointerEvent): void {
    if (event.pointerId !== this.pointerId) {
      return;
    }

    this.panning = false;
    this.pointerId = null;
  }

  public onDoubleClick(event: MouseEvent): void {
    if (this.scale > 1) {
      this.resetView();

      return;
    }

    this.zoomBy(ZOOM_STEP * ZOOM_STEP, event.clientX, event.clientY);
  }

  @HostListener('document:keydown', ['$event'])
  public onKeydown(event: KeyboardEvent): void {
    if (event.key === '+' || event.key === '=') {
      this.zoomIn();
    } else if (event.key === '-' || event.key === '_') {
      this.zoomOut();
    } else if (event.key === '0') {
      this.resetView();
    } else {
      return;
    }

    event.preventDefault();
  }

  /**
   * Scales by `factor`, keeping the point under the cursor fixed. Without an anchor the stage
   * centre stays put, which is what the toolbar buttons want.
   */
  private zoomBy(factor: number, anchorClientX?: number, anchorClientY?: number): void {
    const next = Math.min(MAX_SCALE, Math.max(MIN_SCALE, this.scale * factor));
    const applied = next / this.scale;

    if (applied === 1) {
      return;
    }

    if (anchorClientX !== undefined && anchorClientY !== undefined) {
      const rect = this.stage.nativeElement.getBoundingClientRect();
      // Transform origin is the stage centre, so anchor offsets are measured from there.
      const anchorX = anchorClientX - (rect.left + rect.width / 2);
      const anchorY = anchorClientY - (rect.top + rect.height / 2);
      this.translateX = anchorX - (anchorX - this.translateX) * applied;
      this.translateY = anchorY - (anchorY - this.translateY) * applied;
    }

    this.scale = next;
    this.applyScale();
  }

  private captureBaseSize(): void {
    if (!this.content) {
      return;
    }

    const rect = this.content.getBoundingClientRect();
    this.baseWidth = rect.width;
    this.baseHeight = rect.height;
    // The fit is now pinned as an explicit size, so the fit constraints have to go.
    this.content.style.maxWidth = 'none';
    this.content.style.maxHeight = 'none';
    this.applyScale();
  }

  /**
   * Zoom changes the diagram's layout size rather than applying a `scale()` transform: a
   * transform would rasterize the SVG once at fit size and blow up that bitmap, which is exactly
   * the blurry result users already get from browser zoom. Resizing makes the browser re-render
   * the vector, so text stays sharp at any zoom level.
   */
  private applyScale(): void {
    if (!this.content || !this.baseWidth) {
      return;
    }

    this.content.style.width = `${this.baseWidth * this.scale}px`;
    this.content.style.height = `${this.baseHeight * this.scale}px`;
  }
}
