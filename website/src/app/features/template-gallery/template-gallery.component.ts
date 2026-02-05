import { CommonModule } from '@angular/common';
import { Component, OnDestroy, OnInit } from '@angular/core';
import { ActivatedRoute } from '@angular/router';
import { Observable, Subscription, combineLatest, forkJoin, map } from 'rxjs';

import { BreadcrumbComponent } from 'app/shared/breadcrumb';
import { BreadcrumbItem } from 'app/shared/breadcrumb/breadcrumb';
import { DefinitionCard } from 'app/shared/definition-card/definition-card';
import { DefinitionCardComponent } from 'app/shared/definition-card/definition-card.component';
import { Platform, PlatformService } from 'app/shared/platform';
import { TemplateService } from 'app/shared/template';

import { PlatformCardsComponent } from './platform-cards';
import { PlatformCard } from './platform-cards/platform-card';

@Component({
  selector: 'mst-template-gallery',
  imports: [CommonModule, DefinitionCardComponent, PlatformCardsComponent, BreadcrumbComponent],
  templateUrl: './template-gallery.component.html',
  styleUrl: './template-gallery.component.scss',
  standalone: true
})
export class TemplateGalleryComponent implements OnInit, OnDestroy {
  public templates$!: Observable<DefinitionCard[]>;

  public platformCards$!: Observable<PlatformCard[]>;

  public breadcrumbs$!: Observable<BreadcrumbItem[]>;

  public isSearch = false;

  public platformCount = 0;

  public buildingBlockCount = 0;

  private searchSubscription!: Subscription;

  private platforms$!: Observable<Platform[]>;

  constructor(
    private route: ActivatedRoute,
    private templateService: TemplateService,
    private platformService: PlatformService
  ) {}

  public ngOnInit(): void {
    this.platforms$ = this.platformService.getAllPlatforms();
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

  private getTemplatesWithLogos(templateObs$: Observable<any>): Observable<DefinitionCard[]> {
    return forkJoin({ templates: templateObs$, platforms: this.platforms$ })
      .pipe(
        map(({ templates, platforms }) =>
          templates.map(template => this.mapToDefinitionCard(template, platforms))
        )
      );
  }

  private getFilteredPlatformCards(searchTerm: string | undefined): Observable<PlatformCard[]> {
    return combineLatest([this.platforms$, this.templateService.filterTemplatesByPlatformType('all')]).pipe(
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

  private mapToDefinitionCard(template: any, platforms: Platform[]): DefinitionCard {
    return {
      cardLogo: template.logo,
      title: template.name,
      description: template.description,
      routePath: `/definitions/${template.id}`,
      supportedPlatforms: template.supportedPlatforms.map(platform => ({
        platformType: platform,
        imageUrl: platforms.find(p => p.platformType === platform)?.logo ?? null
      }))
    };
  }

  private createBreadcrumbs(resultsCount: number): BreadcrumbItem[] {
    return [
      { label: 'Home', routePath: '/all' },
      { label: `${resultsCount} results found`, routePath: '' }
    ];
  }

  private mapLogosToPlatformCards(data: Platform[], templates: any[]): PlatformCard[] {
    return data.map(platform => {
      const buildingBlockCount = templates.filter(t => t.platformType === platform.platformType).length;
      return this.createPlatformCard(
        platform.name,
        platform.logo,
        `/platforms/${platform.platformType}`,
        platform.description,
        buildingBlockCount,
        platform.category
      );
    });
  }

  private createPlatformCard(title: string, logoUrl: string, routePath: string, description?: string, buildingBlockCount?: number, category?: 'hyperscaler' | 'european' | 'china' | 'devops' | 'private-cloud'): PlatformCard {
    return { cardLogo: logoUrl, title, routePath, description, buildingBlockCount, category };
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
}
