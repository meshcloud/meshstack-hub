import { CommonModule } from '@angular/common';
import { Component, OnDestroy, OnInit } from '@angular/core';
import { ActivatedRoute } from '@angular/router';
import { Observable, Subscription, combineLatest, forkJoin, map } from 'rxjs';

import { BreadcrumbComponent } from 'app/shared/breadcrumb';
import { BreadcrumbItem } from 'app/shared/breadcrumb/breadcrumb';
import { DefinitionCard } from 'app/shared/definition-card/definition-card';
import { DefinitionCardComponent } from 'app/shared/definition-card/definition-card.component';
import { PlatformData, PlatformService } from 'app/shared/platform-logo';
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

  private searchSubscription!: Subscription;

  private platformData$!: Observable<PlatformData>;

  constructor(
    private route: ActivatedRoute,
    private templateService: TemplateService,
    private platformService: PlatformService
  ) {}

  public ngOnInit(): void {
    this.platformData$ = this.platformService.getAllPlatformData();
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
    });
  }

  private getTemplatesWithLogos(templateObs$: Observable<any>): Observable<DefinitionCard[]> {
    return forkJoin({ templates: templateObs$, platforms: this.platformData$ })
      .pipe(
        map(({ templates, platforms }) =>
          templates.map(template => this.mapToDefinitionCard(template, platforms))
        )
      );
  }

  private getFilteredPlatformCards(searchTerm: string | undefined): Observable<PlatformCard[]> {
    return this.platformData$.pipe(
      map(logos => this.mapLogosToPlatformCards(logos)),
      map(cards => this.filterCardsBySearchTerm(cards, searchTerm))
    );
  }

  private getBreadcrumbs(): Observable<BreadcrumbItem[]> {
    return combineLatest([this.templates$, this.platformCards$])
      .pipe(
        map(([templates, platforms]) => this.createBreadcrumbs(templates.length + platforms.length))
      );
  }

  private mapToDefinitionCard(template: any, platformData: PlatformData): DefinitionCard {
    return {
      cardLogo: template.logo,
      title: template.name,
      description: template.description,
      routePath: `/definitions/${template.id}`,
      supportedPlatforms: template.supportedPlatforms.map(platform => ({
        platformType: platform,
        imageUrl: platformData[platform]?.logo ?? null
      }))
    };
  }

  private createBreadcrumbs(resultsCount: number): BreadcrumbItem[] {
    return [
      { label: 'Home', routePath: '/all' },
      { label: `${resultsCount} results found`, routePath: '' }
    ];
  }

  private mapLogosToPlatformCards(data: PlatformData): PlatformCard[] {
    return Object.entries(data)
      .map(([key, platform]) =>
        this.createPlatformCard(platform.name, platform.logo, `/platforms/${key}`)
      );
  }

  private createPlatformCard(title: string, logoUrl: string, routePath: string): PlatformCard {
    return { cardLogo: logoUrl, title, routePath };
  }

  private filterCardsBySearchTerm(cards: PlatformCard[], searchTerm: string | undefined): PlatformCard[] {
    const searchTermLower = (searchTerm ?? '').toLowerCase();

    return cards.filter(card => card.title.toLowerCase()
      .includes(searchTermLower));
  }
}
