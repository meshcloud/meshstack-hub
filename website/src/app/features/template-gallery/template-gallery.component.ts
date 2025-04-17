import { CommonModule } from '@angular/common';
import { Component, OnDestroy, OnInit } from '@angular/core';
import { ActivatedRoute } from '@angular/router';
import { Observable, Subscription, forkJoin, map } from 'rxjs';

import { DefinitionCard } from 'app/shared/definition-card/definition-card';
import { DefinitionCardComponent } from 'app/shared/definition-card/definition-card.component';
import { NavigationComponent } from 'app/shared/navigation';
import { PlatformData, PlatformService } from 'app/shared/platform-logo';
import { TemplateService } from 'app/shared/template';

@Component({
  selector: 'mst-template-gallery',
  imports: [CommonModule, DefinitionCardComponent, NavigationComponent],
  templateUrl: './template-gallery.component.html',
  styleUrl: './template-gallery.component.scss',
  standalone: true
})
export class TemplateGalleryComponent implements OnInit, OnDestroy {
  public templates$!: Observable<DefinitionCard[]>;

  public isSearch = false;

  private searchSubscription!: Subscription;

  private platformData$!: Observable<PlatformData>;

  constructor(
    private route: ActivatedRoute,
    private templateService: TemplateService,
    private platformLogoService: PlatformService
  ) {}

  public ngOnInit(): void {
    this.platformData$ = this.platformLogoService.getAllPlatformData();
    this.subscribeToSearchTerm();
  }

  public ngOnDestroy(): void {
    this.searchSubscription?.unsubscribe();
  }

  private subscribeToSearchTerm(): void {
    this.searchSubscription = this.route.queryParams.subscribe(params => {
      const searchTerm = params['searchTerm'];
      const templateObs$ = searchTerm
        ? this.handleSearch(searchTerm)
        : this.templateService.filterTemplatesByPlatformType('all');

      this.templates$ = this.getTemplatesWithLogos(templateObs$);
    });
  }

  private handleSearch(searchTerm: string): Observable<any> {
    this.isSearch = true;

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
}
