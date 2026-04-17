import { CommonModule } from '@angular/common';
import { Component, OnDestroy, OnInit } from '@angular/core';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { Observable, Subscription, combineLatest, forkJoin, map } from 'rxjs';

import { ReferenceArchitecture, Template } from 'app/core';
import { BreadcrumbComponent } from 'app/shared/breadcrumb';
import { BreadcrumbItem } from 'app/shared/breadcrumb/breadcrumb';
import { CardComponent } from 'app/shared/card';
import { DefinitionCard } from 'app/shared/definition-card/definition-card';
import { DefinitionCardComponent } from 'app/shared/definition-card/definition-card.component';
import { Platform, PlatformService } from 'app/shared/platform';
import { ReferenceArchitectureService } from 'app/shared/reference-architecture';
import { TemplateService } from 'app/shared/template';

import { PlatformCardsComponent } from './platform-cards';
import { PlatformCard } from './platform-cards/platform-card';

interface RefArchCardVm {
  id: string;
  name: string;
  description: string;
  buildingBlockCount: number;
  platformLogos: { platformType: string; imageUrl: string }[];
}

@Component({
  selector: 'mst-template-gallery',
  imports: [CommonModule, DefinitionCardComponent, PlatformCardsComponent, BreadcrumbComponent, RouterLink, CardComponent],
  templateUrl: './template-gallery.component.html',
  styleUrl: './template-gallery.component.scss',
  standalone: true
})
export class TemplateGalleryComponent implements OnInit, OnDestroy {
  public templates$!: Observable<DefinitionCard[]>;

  public platformCards$!: Observable<PlatformCard[]>;

  public refArchCards$!: Observable<RefArchCardVm[]>;

  public breadcrumbs$!: Observable<BreadcrumbItem[]>;

  public isSearch = false;

  public platformCount = 0;

  public buildingBlockCount = 0;

  public refArchCount = 0;

  private searchSubscription!: Subscription;

  private platforms$!: Observable<Platform[]>;

  constructor(
    private route: ActivatedRoute,
    private templateService: TemplateService,
    private platformService: PlatformService,
    private refArchService: ReferenceArchitectureService
  ) {}

  public ngOnInit(): void {
    this.platforms$ = this.platformService.getAllPlatforms();
    this.loadRefArchitectures();
    this.subscribeToSearchTerm();
  }

  public ngOnDestroy(): void {
    this.searchSubscription?.unsubscribe();
  }

  private subscribeToSearchTerm(): void {
    this.searchSubscription = this.route.queryParams.subscribe(params => {
      const searchTerm = params['searchTerm'];
      this.isSearch = !!searchTerm;

      this.templates$ = this.getTemplatesWithLogos(
        searchTerm
          ? this.templateService.search(searchTerm)
          : this.templateService.filterTemplatesByPlatformType('all')
      );

      this.platformCards$ = this.getFilteredPlatformCards(searchTerm);

      this.breadcrumbs$ = this.getBreadcrumbs();

      // Calculate counts for hero section
      this.platformCards$.subscribe(cards => {
        this.platformCount = cards.length;
      });

      this.templates$.subscribe(templates => {
        this.buildingBlockCount = templates.length;
      });
    });
  }

  private getTemplatesWithLogos(templateObs$: Observable<Template[]>): Observable<DefinitionCard[]> {
    return forkJoin({ templates: templateObs$, platforms: this.platforms$ })
      .pipe(
        map(({ templates, platforms }) =>
          templates
            .map(template => this.mapToDefinitionCard(template, platforms))
            .sort((a, b) => {
              // Sort templates with terraform snippets first
              if (a.hasTerraformSnippet && !b.hasTerraformSnippet) return -1;
              if (!a.hasTerraformSnippet && b.hasTerraformSnippet) return 1;
              return 0;
            })
        )
      );
  }

  private getFilteredPlatformCards(searchTerm: string | undefined): Observable<PlatformCard[]> {
    return combineLatest([this.platforms$, this.templateService.filterTemplatesByPlatformType('all')])
      .pipe(
        map(([platforms, templates]) => this.mapLogosToPlatformCards(platforms, templates)),
        map(cards => this.filterCardsBySearchTerm(cards, searchTerm))
      );
  }

  private getBreadcrumbs(): Observable<BreadcrumbItem[]> {
    return combineLatest([this.templates$, this.platformCards$])
      .pipe(
        map(([templates, platforms]) => this.createBreadcrumbs(templates.length + platforms.length))
      );
  }

  private mapToDefinitionCard(template: Template, platforms: Platform[]): DefinitionCard {
    return {
      cardLogo: template.logo,
      title: template.name,
      description: template.description,
      routePath: `/definitions/${template.id}`,
      supportedPlatforms: (template.supportedPlatforms ?? []).map(platform => ({
        platformType: platform,
        imageUrl: platforms.find(p => p.platformType === platform)?.logo ?? 'assets/meshstack-logo.png'
      })),
      hasTerraformSnippet: !!template.terraformSnippet
    };
  }

  private createBreadcrumbs(resultsCount: number): BreadcrumbItem[] {
    return [
      { label: 'Home', routePath: '/all' },
      { label: `${resultsCount} results found`, routePath: '' }
    ];
  }

  private mapLogosToPlatformCards(data: Platform[], templates: Template[]): PlatformCard[] {
    return data.map(platform => {
      const buildingBlockCount = templates.filter(t => t.platformType === platform.platformType).length;

      return {
        title: platform.name,
        cardLogo: platform.logo,
        routePath: `/platforms/${platform.platformType}`,
        description: platform.description,
        buildingBlockCount,
        category: platform.category,
        benefits: platform.benefits,
        official: platform.official
      }
    });
  }

  private filterCardsBySearchTerm(cards: PlatformCard[], searchTerm: string | undefined): PlatformCard[] {
    const searchTermLower = (searchTerm ?? '').toLowerCase();

    return cards
      .filter(card => card.title.toLowerCase()
        .includes(searchTermLower))
      .sort((a, b) => this.sortByPriorityAndTitle(a, b));
  }

  private sortByPriorityAndTitle(a: PlatformCard, b: PlatformCard): number {
    const priority = ['Azure', 'Amazon Web Services', 'Google Cloud', 'GitHub'];
    const priorityIndexA = priority.indexOf(a.title);
    const priorityIndexB = priority.indexOf(b.title);

    if (priorityIndexA !== -1 && priorityIndexB !== -1) {
      return priorityIndexA - priorityIndexB;
    }

    if (priorityIndexA !== -1) {
      return -1;
    }

    if (priorityIndexB !== -1) {
      return 1;
    }

    return a.title.localeCompare(b.title);
  }

  private loadRefArchitectures(): void {
    this.refArchCards$ = forkJoin({
      archs: this.refArchService.getAll(),
      platforms: this.platforms$
    }).pipe(
      map(({ archs, platforms }) => archs.map(arch => this.toRefArchCard(arch, platforms)))
    );

    this.refArchCards$.subscribe(cards => {
      this.refArchCount = cards.length;
    });
  }

  private toRefArchCard(arch: ReferenceArchitecture, platforms: Platform[]): RefArchCardVm {
    return {
      id: arch.id,
      name: arch.name,
      description: arch.description,
      buildingBlockCount: arch.buildingBlocks.length,
      platformLogos: arch.cloudProviders.map(cp => ({
        platformType: cp,
        imageUrl: platforms.find(p => p.platformType === cp)?.logo ?? 'assets/meshstack-logo.png'
      }))
    };
  }
}
