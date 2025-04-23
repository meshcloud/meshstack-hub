import { CommonModule } from '@angular/common';
import { Component, OnDestroy, OnInit } from '@angular/core';
import { ActivatedRoute } from '@angular/router';
import { Observable, Subscription, forkJoin, map, tap } from 'rxjs';

import { BreadcrumbComponent } from 'app/shared/breadcrumb';
import { BreadcrumbItem } from 'app/shared/breadcrumb/breadcrumb';
import { DefinitionCard } from 'app/shared/definition-card/definition-card';
import { DefinitionCardComponent } from 'app/shared/definition-card/definition-card.component';
import { PlatformData, PlatformService } from 'app/shared/platform-logo';
import { TemplateService } from 'app/shared/template';

import { PlatformCardsComponent } from './platform-cards';

@Component({
  selector: 'mst-template-gallery',
  imports: [CommonModule, DefinitionCardComponent, PlatformCardsComponent, BreadcrumbComponent],
  templateUrl: './template-gallery.component.html',
  styleUrl: './template-gallery.component.scss',
  standalone: true
})
export class TemplateGalleryComponent implements OnInit, OnDestroy {
  public templates$!: Observable<DefinitionCard[]>;

  public breadcrumbs: BreadcrumbItem[] = [];

  public isSearch = false;

  public searchTerm = '';

  public resultsCount = 0;

  private searchSubscription!: Subscription;

  private platformData$!: Observable<PlatformData>;

  private definitionsCount = 0;

  constructor(
    private route: ActivatedRoute,
    private templateService: TemplateService,
    private platformLogoService: PlatformService
  ) { }

  public ngOnInit(): void {
    this.platformData$ = this.platformLogoService.getAllPlatformData();
    this.subscribeToSearchTerm();
  }

  public ngOnDestroy(): void {
    this.searchSubscription?.unsubscribe();
  }

  public updateCount(count: number): void {
    this.resultsCount = count + this.definitionsCount;
  }

  private subscribeToSearchTerm(): void {
    this.searchSubscription = this.route.queryParams.subscribe(params => {
      const searchTerm = params['searchTerm'];
      const templateObs$ = searchTerm
        ? this.handleSearch(searchTerm)
        : this.templateService.filterTemplatesByPlatformType('all');

      this.templates$ = this.getTemplatesWithLogos(templateObs$)
        .pipe(tap(x => this.definitionsCount = x.length));
    });
  }

  private handleSearch(searchTerm: string): Observable<any> {
    this.searchTerm = searchTerm;
    this.isSearch = true;
    this.breadcrumbs = this.createBreadcrumbs();

    return this.templateService.search(searchTerm);
  }

  private getTemplatesWithLogos(templateObs$: Observable<any>): Observable<DefinitionCard[]> {
    return forkJoin({ templates: templateObs$, platforms: this.platformData$ })
      .pipe(
        map(({ templates, platforms }) =>
          templates.map(template => this.mapToDefinitionCard(template, platforms))
        )
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
        imageUrl: platformData[platform].logo ?? null
      }))
    };
  }

  private createBreadcrumbs(): BreadcrumbItem[] {
    return  [
      { label: 'Overview', routePath: '/all' },
      { label: `${this.resultsCount} results found`, routePath: '' }
    ];
  }
}
