import { CommonModule } from '@angular/common';
import { Component, OnDestroy, OnInit } from '@angular/core';
import { ReactiveFormsModule } from '@angular/forms';
import { ActivatedRoute, Router } from '@angular/router';
import { Observable, Subscription, forkJoin, map } from 'rxjs';

import { PlatformType } from 'app/core';
import { CardComponent } from 'app/shared/card';
import { Card } from 'app/shared/card/card';
import { NavigationComponent } from 'app/shared/navigation';
import { PlatformLogoData, PlatformLogoService } from 'app/shared/platform-logo';
import { SearchService } from 'app/shared/search-bar/search.service';
import { TemplateService } from 'app/shared/template';

@Component({
  selector: 'mst-template-gallery',
  imports: [CommonModule, ReactiveFormsModule, CardComponent, NavigationComponent],
  templateUrl: './template-gallery.component.html',
  styleUrl: './template-gallery.component.scss',
  standalone: true
})
export class TemplateGalleryComponent implements OnInit, OnDestroy {
  public templates$!: Observable<Card[]>;

  public isSearch$!: Observable<boolean>;

  private paramSubscription!: Subscription;

  private searchSubscription!: Subscription;

  private logos$!: Observable<PlatformLogoData>;

  constructor(
    private router: Router,
    private route: ActivatedRoute,
    private templateService: TemplateService,
    private searchService: SearchService,
    private platformLogoService: PlatformLogoService
  ) { }

  public ngOnInit(): void {
    this.subscribeToRouteParams();
    this.subscribeToSearchTerm();
    this.isSearch$ = this.searchService.getSearchTerm$()
      .pipe(
        map(searchTerm =>
          searchTerm === '' ? false : true)
      );
  }

  public ngOnDestroy(): void {
    this.paramSubscription.unsubscribe();
    this.searchSubscription.unsubscribe();
  }

  private subscribeToRouteParams(): void {
    this.paramSubscription = this.route.paramMap.subscribe(params => {
      const type = params.get('type') ?? 'all';
      const templateObs$ = this.templateService.filterTemplatesByPlatformType(type as PlatformType);

      this.logos$ = this.platformLogoService.getLogoUrls();
      this.templates$ = this.getTemplatesWithLogos(templateObs$);
    });
  }

  private subscribeToSearchTerm(): void {
    this.searchSubscription = this.searchService.searchTerm$.subscribe(searchTerm => {
      this.templates$ = this.getTemplatesWithLogos(this.templateService.search(searchTerm));
      this.router.navigate(['/all']);
    });
  }

  private getTemplatesWithLogos(templateObs$: Observable<any>): Observable<Card[]> {
    return forkJoin({
      templates: templateObs$,
      logos: this.logos$
    })
      .pipe(
        map(({ templates, logos }) =>
          templates.map(item => ({
            cardLogo: item.logo,
            title: item.name,
            description: item.description,
            routePath: `/template/${item.id}`,
            supportedPlatforms: item.supportedPlatforms.map(platform => ({
              platformType: platform,
              imageUrl: logos[item.platformType] ?? null
            }))
          }))
        )
      );
  }
}
