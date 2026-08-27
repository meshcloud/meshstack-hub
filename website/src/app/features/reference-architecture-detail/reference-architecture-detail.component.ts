import { Dialog } from '@angular/cdk/dialog';
import { CommonModule, isPlatformBrowser } from '@angular/common';
import { AfterViewChecked, Component, ElementRef, Inject, OnDestroy, OnInit, PLATFORM_ID } from '@angular/core';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { Observable, Subscription, forkJoin, map } from 'rxjs';
import { marked } from 'marked';

import { ReferenceArchitecture, SeoService } from 'app/core';
import { BreadcrumbComponent } from 'app/shared/breadcrumb';
import { BreadcrumbItem } from 'app/shared/breadcrumb/breadcrumb';
import { CardComponent } from 'app/shared/card';
import { DiagramViewerComponent } from 'app/shared/diagram-viewer';
import { Platform, PlatformService } from 'app/shared/platform';
import { ReferenceArchitectureService } from 'app/shared/reference-architecture';
import { TemplateService } from 'app/shared/template';

import { ImportDialogComponent } from '../template-details/import-dialog/import-dialog.component';

interface BuildingBlockLink {
  path: string;
  role: string;
  name: string | null;
  definitionId: string | null;
  logo: string | null;
}

interface RefArchDetailVm {
  id: string;
  name: string;
  description: string;
  cloudProviders: string[];
  buildingBlocks: BuildingBlockLink[];
  bodyHtml: string;
  sourceUrl: string | null;
  logo: string | null;
  platformLogos: { platformType: string; imageUrl: string }[];
  integrationSourceUrl: string | null;
  folderUrl: string | null;
  modulePath: string | null;
}

@Component({
  selector: 'mst-reference-architecture-detail',
  imports: [CommonModule, BreadcrumbComponent, CardComponent, RouterLink],
  templateUrl: './reference-architecture-detail.component.html',
  styleUrl: './reference-architecture-detail.component.scss',
  standalone: true
})
export class ReferenceArchitectureDetailComponent implements OnInit, OnDestroy, AfterViewChecked {
  public vm$!: Observable<RefArchDetailVm>;

  public breadcrumbs$!: Observable<BreadcrumbItem[]>;

  private routeSubscription!: Subscription;


  constructor(
    private route: ActivatedRoute,
    private refArchService: ReferenceArchitectureService,
    private platformService: PlatformService,
    private templateService: TemplateService,
    private dialog: Dialog,
    private el: ElementRef,
    @Inject(PLATFORM_ID) private platformId: object,
    private seoService: SeoService
  ) {}

  public ngOnInit(): void {
    this.routeSubscription = this.route.paramMap.subscribe(params => {
      const id = params.get('id');

      if (!id) {
        throw new Error('Reference architecture ID is required');
      }


      this.vm$ = forkJoin({
        arch: this.refArchService.getById(id),
        platforms: this.platformService.getAllPlatforms(),
        templates: this.templateService.retrieveData()
      }).pipe(
        map(({ arch, platforms, templates }) => {
          const vm = this.toVm(arch, platforms, templates.templates);
          this.seoService.set(vm.name, vm.description);
          return vm;
        })
      );

      this.breadcrumbs$ = this.vm$.pipe(
        map(vm => [
          { label: 'Home', routePath: '/' },
          { label: 'Reference Architectures', routePath: '/reference-architectures' },
          { label: vm.name, routePath: '' }
        ])
      );
    });
  }

  public ngAfterViewChecked(): void {
    if (!isPlatformBrowser(this.platformId)) {
      return;
    }

    const mermaidBlocks = this.el.nativeElement.querySelectorAll(
      'code.language-mermaid:not([data-mermaid-rendered])'
    );

    if (mermaidBlocks.length > 0) {
      // Mark blocks synchronously before the async render to prevent double-processing
      // when ngAfterViewChecked fires again during the async mermaid import.
      mermaidBlocks.forEach((block: Element) => block.setAttribute('data-mermaid-rendered', 'true'));
      this.renderMermaid(mermaidBlocks);
    }

    this.enhanceDiagramImages();
  }

  public ngOnDestroy(): void {
    this.routeSubscription?.unsubscribe();
  }

  public open(vm: RefArchDetailVm): void {
    if (!vm.modulePath) {
      return;
    }

    this.dialog.open(ImportDialogComponent, {
      width: '600px',
      data: { name: vm.name, modulePath: vm.modulePath }
    });
  }

  private toVm(
    arch: ReferenceArchitecture,
    platforms: Platform[],
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    templates: any[]
  ): RefArchDetailVm {
    const buildingBlocks: BuildingBlockLink[] = arch.buildingBlocks.map(bb => {
      // Try to find a matching building block template by path
      // Template ids are like "azure-aks", "aks-github-connector" — derived from module path
      const possibleId = bb.path.replace(/\//g, '-');
      const matchingTemplate = templates.find(t => t.id === possibleId);

      return {
        path: bb.path,
        role: bb.role,
        name: matchingTemplate?.name ?? null,
        definitionId: matchingTemplate?.id ?? null,
        logo: matchingTemplate?.logo ?? null
      };
    });

    return {
      id: arch.id,
      name: arch.name,
      description: arch.description,
      cloudProviders: arch.cloudProviders,
      buildingBlocks,
      bodyHtml: marked.parse(arch.body) as string,
      sourceUrl: arch.sourceUrl,
      logo: arch.logo,
      platformLogos: arch.cloudProviders.map(cp => ({
        platformType: cp,
        imageUrl: platforms.find(p => p.platformType === cp)?.logo ?? 'assets/meshstack-logo.png'
      })),
      integrationSourceUrl: arch.integrationSourceUrl,
      folderUrl: arch.folderUrl,
      modulePath: arch.modulePath
    };
  }

  private async renderMermaid(codeBlocks: NodeListOf<HTMLElement>): Promise<void> {
    const mermaid = (await import('mermaid')).default;
    mermaid.initialize({ startOnLoad: false, theme: 'neutral' });

    for (let i = 0; i < codeBlocks.length; i++) {
      const codeEl = codeBlocks[i];
      const pre = codeEl.parentElement;

      if (!pre) {
        continue;
      }

      const graphDefinition = codeEl.textContent ?? '';
      const id = `mermaid-${i}`;

      try {
        const { svg } = await mermaid.render(id, graphDefinition);
        const holder = document.createElement('div');
        holder.innerHTML = svg;
        const svgEl = holder.firstElementChild as HTMLElement | null;

        if (!svgEl) {
          continue;
        }

        pre.replaceWith(svgEl);
        this.makeZoomable(svgEl, svgEl, 'Diagram', null);
      } catch {
        // Leave the code block as-is if rendering fails
      }
    }
  }

  /**
   * Diagrams in the markdown body are committed SVGs referenced as images. They are wide and
   * detailed, and browser zoom does not help — the page just reflows and the diagram stays fitted
   * to its column — so each one gets a fullscreen viewer with real zoom and pan.
   */
  private enhanceDiagramImages(): void {
    const images: NodeListOf<HTMLImageElement> = this.el.nativeElement.querySelectorAll(
      '.markdown-body img:not([data-diagram-enhanced])'
    );

    images.forEach(img =>
      this.makeZoomable(img, img, img.getAttribute('alt') || 'Diagram', img.getAttribute('src'))
    );
  }

  /**
   * Wraps `element` in a figure carrying a fullscreen affordance. `viewerNode` is what the viewer
   * clones and displays — the same element for images, the bare `<svg>` for rendered mermaid.
   */
  private makeZoomable(
    element: HTMLElement,
    viewerNode: HTMLElement,
    title: string,
    sourceUrl: string | null
  ): void {
    element.setAttribute('data-diagram-enhanced', 'true');

    const figure = document.createElement('figure');
    figure.className = 'diagram-figure';

    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'diagram-expand';
    button.setAttribute('aria-label', `View ${title} fullscreen`);
    button.innerHTML = '<i class="fa-solid fa-expand"></i><span>Fullscreen</span>';

    // A markdown image sits alone in its own paragraph — replace that paragraph so the figure does
    // not end up nested inside a <p>.
    const parent = element.parentElement;
    const replaced =
      parent?.tagName === 'P' && parent.childElementCount === 1 && !parent.textContent?.trim()
        ? parent
        : element;

    replaced.parentElement?.replaceChild(figure, replaced);
    figure.appendChild(element);
    figure.appendChild(button);

    figure.addEventListener('click', () => this.openDiagram(viewerNode, title, sourceUrl));
  }

  private openDiagram(node: HTMLElement, title: string, sourceUrl: string | null): void {
    this.dialog.open(DiagramViewerComponent, {
      panelClass: 'diagram-viewer-panel',
      data: { title, node, sourceUrl }
    });
  }
}

