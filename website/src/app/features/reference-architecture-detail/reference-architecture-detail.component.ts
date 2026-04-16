import { CommonModule, isPlatformBrowser } from '@angular/common';
import { AfterViewChecked, Component, ElementRef, Inject, OnDestroy, OnInit, PLATFORM_ID } from '@angular/core';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { Observable, Subscription, forkJoin, map } from 'rxjs';
import { marked } from 'marked';

import { ReferenceArchitecture } from 'app/core';
import { BreadcrumbComponent } from 'app/shared/breadcrumb';
import { BreadcrumbItem } from 'app/shared/breadcrumb/breadcrumb';
import { CardComponent } from 'app/shared/card';
import { Platform, PlatformService } from 'app/shared/platform';
import { ReferenceArchitectureService } from 'app/shared/reference-architecture';
import { TemplateService } from 'app/shared/template';

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
  platformLogos: { platformType: string; imageUrl: string }[];
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
    private el: ElementRef,
    @Inject(PLATFORM_ID) private platformId: object
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
        map(({ arch, platforms, templates }) => this.toVm(arch, platforms, templates.templates))
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

    if (mermaidBlocks.length === 0) {
      return;
    }

    // Mark blocks synchronously before the async render to prevent double-processing
    // when ngAfterViewChecked fires again during the async mermaid import.
    mermaidBlocks.forEach((block: Element) => block.setAttribute('data-mermaid-rendered', 'true'));
    this.renderMermaid(mermaidBlocks);
  }

  public ngOnDestroy(): void {
    this.routeSubscription?.unsubscribe();
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
      platformLogos: arch.cloudProviders.map(cp => ({
        platformType: cp,
        imageUrl: platforms.find(p => p.platformType === cp)?.logo ?? 'assets/meshstack-logo.png'
      }))
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
        const wrapper = document.createElement('div');
        wrapper.classList.add('mermaid-diagram');
        wrapper.innerHTML = svg;
        pre.replaceWith(wrapper);
      } catch {
        // Leave the code block as-is if rendering fails
      }
    }
  }
}

